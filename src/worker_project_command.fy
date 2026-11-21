module worker_project_command;

import errors as errors;
import module_entry as entries;
import module_program as programs;
import project_manifest as manifest;
import project_sources as binding;
import source_error as diagnostics;
import source_snapshot as sources;
import static_image as images;
import worker_project_wire as wire;
import worker_scalar_result as scalar;
import std::bytes as bytes;

unsafe extern C fn usize bc_scalar_worker_start(ptr mut u8 buffer,usize capacity);
unsafe extern C fn u32 bc_scalar_worker_finish(ptr u8 result,usize length);

pub fn i32 execute(){
    let usize capacity=wire::request_limit();
    var bytes::Buffer request=switch(bytes::with_capacity(capacity)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    if(!bytes::resize_zeroed(ref mut request,capacity).is_ok){return 4;}
    let usize length=unsafe{bc_scalar_worker_start(bytes::view_mut(ref mut request) as ptr mut u8,capacity)};
    if(length==0 || length>capacity){return 4;}
    return respond(bytes::view(ref request)[..length]);
}

fn i32 respond(ref u8[] request){
    let wire::Header header=switch(wire::header(request)){case .ok(v):{v}case .err(_):{return 4;}};
    let manifest::Project project=switch(manifest::parse(request[9..header.manifest_end])){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let sources::Snapshot snapshot=switch(wire::unpack(request[header.manifest_end..request.len],ref project)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let wire::Outcome outcome=compute(ref project,snapshot,header);
    let bytes::Buffer payload=switch(wire::encode_result(outcome,header.run)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let ref u8[] data=bytes::view(ref payload);
    return if(unsafe{bc_scalar_worker_finish(data as ptr u8,data.len)}!=0){0}else{4};
}

fn wire::Outcome compute(ref manifest::Project project,sources::Snapshot snapshot,wire::Header header){
    let entries::Entry entry=switch(binding::select(project,snapshot)){
        case .ok(v):{v}
        case .err(e):{return failed(diagnostics::Error{.code=diagnostics::binding(e),.at=e.at},0);}
    };
    let programs::Program program=switch(programs::compile(entry,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return failed(e,0);}
    };
    let u8 profile=programs::profile(ref program);
    if(!header.run){return success(scalar::checked(),profile);}
    return switch(programs::run(ref program,header.fuel)){
        case .ok(v):{success(scalar::completed(v),profile)}case .err(e):{failed(e,profile)}
    };
}

fn wire::Outcome success(scalar::Outcome value,u8 profile){
    return wire::Outcome{.value=value,.profile=profile,.span=sources::no_source()};
}

fn wire::Outcome failed(diagnostics::Error error,u8 profile){
    if(error.code.location==errors::instruction_location()){return success(scalar::failed(error.code),profile);}
    if(error.at.source==sources::no_source().source){
        return success(scalar::failed(errors::absent(error.code.kind,0)),profile);
    }
    return wire::Outcome{.value=scalar::failed(errors::make(error.code.kind,error.at.start)),
        .profile=profile,.span=error.at};
}
