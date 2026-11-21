module worker_project_broker;

import anchored_source_loader as anchored;
import cli_project as cli;
import errors as errors;
import fuel as meter;
import project_manifest as manifest;
import project_source_loader as loader;
import render as render;
import source_snapshot as sources;
import worker_project_wire as wire;
import std::bytes as bytes;
import std::process as process;

unsafe extern C fn u32 bc_project_broker_invoke(ptr u8 request,usize request_length,u32 run,
    ptr u8 lengths,usize lengths_count,ptr mut u8 reply,ptr mut usize reply_length);

fn u32 validate_result(ptr u8 data,usize length,u32 run,ptr u8 bounds,usize count){
    if(data==null || length==0 || length>wire::result_limit() || run>1 ||
       bounds==null || count==0 || count>32 || count%2!=0){return 0;}
    let ref u8[] payload=unsafe{byte_slice::from_raw_parts(ref length,data,length)};
    let ref u8[] lengths=unsafe{byte_slice::from_raw_parts(ref count,bounds,count)};
    return if(wire::parse_result(payload,run==1,lengths).is_ok){1}else{0};
}

@effects(console,filesystem)
pub fn i32 execute(){
    var u8[8] operation=[0;8];
    let usize size=switch(process::arg(2,ref mut operation)){
        case .ok(v):{v}case .err(_):{return failure(false,errors::absent(10,0));}
    };
    let ref u8[] op=ref operation[..size];
    let bool run=bytes::equal(op,b"run");
    if(!run && !bytes::equal(op,b"check")){return failure(false,errors::absent(10,0));}
    var u8[3072] path=[0;3072];
    let usize length=switch(process::arg(3,ref mut path)){
        case .ok(v):{v}case .err(_):{return failure(run,errors::absent(10,0));}
    };
    return acquire(ref path[..length],run);
}

@effects(console)
fn i32 acquire(ref u8[] path,bool run){
    var bytes::Buffer data=bytes::empty();
    var anchored::Root root=switch(cli::open_manifest(path,ref mut data)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    let ref u8[] raw=bytes::view(ref data);
    let manifest::Project project=switch(cli::parse_manifest(ref root,raw)){
        case .ok(v):{v}case .err(e):{return failure(run,e);}
    };
    if(manifest::requirements(ref project)!=0){return failure(run,errors::absent(11,0));}
    let sources::Snapshot snapshot=switch(loader::load_from(ref project,ref mut root,sources::source_limit())){
        case .ok(v):{v}
        case .err(e):{return failure(run,errors::absent(cli::acquisition_kind(e),0));}
    };
    return invoke(raw[..anchored::manifest_bytes(ref root)],ref project,ref snapshot,run);
}

@effects(console)
fn i32 invoke(ref u8[] manifest_bytes,ref manifest::Project project,ref sources::Snapshot snapshot,bool run){
    var u8[32] limits=[0;32];
    let usize limit_bytes=2*sources::count(snapshot);
    let bytes::Buffer request=switch(wire::pack(manifest_bytes,project,snapshot,run,
        if(run){meter::cli_default()}else{0},ref mut limits[..limit_bytes])){
        case .ok(v):{v}
        case .err(e):{return failure(run,errors::absent(switch(e){case .Shape:{11}case .Limit:{4}case .Allocation:{15}},0));}
    };
    let ref u8[] input=bytes::view(ref request);
    let ref u8[] bounds=ref limits[..limit_bytes];
    var u8[260] reply=[0;260];
    var usize length=0;
    let u32 status=unsafe{bc_project_broker_invoke(input as ptr u8,input.len,if(run){1}else{0},
        bounds as ptr u8,bounds.len,ref mut reply[..] as ptr mut u8,ref mut length as ptr mut usize)};
    if(status!=1 || length==0 || length>wire::result_limit()){
        let u8 kind=if(status==2){errors::deadline_kind()}else if(status==3){errors::cancelled_kind()}else{11};
        return failure(run,errors::absent(kind,0));
    }
    let wire::Outcome outcome=switch(wire::parse_result(ref reply[..length],run,bounds)){
        case .ok(v):{v}case .err(_):{return failure(run,errors::absent(11,0));}
    };
    return switch(outcome.value.status){
        case .Checked:{render::selected_outcome(.JsonV2,false,false,0,errors::absent(0,0),outcome.profile)}
        case .Completed:{render::selected_outcome(.JsonV2,true,false,outcome.value.value,errors::absent(0,0),outcome.profile)}
        case .Failed:{render::project_failure(.JsonV2,run,outcome.value.error,snapshot,outcome.span,outcome.profile)}
    };
}

@effects(console)
fn i32 failure(bool run,errors::Error error){
    return render::selected_outcome(.JsonV2,run,true,0,error,0);
}
