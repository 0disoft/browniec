module worker_scalar_command;

import array_source as arrays;
import compiler as compiler;
import errors as errors;
import source_features as features;
import fuel as meter;
import ir as ir;
import program_image as programs;
import static_image as images;
import verifier as verifier;
import vm as vm;
import worker_scalar_result as result;
import std::bytes as bytes;

unsafe extern C fn usize bc_scalar_worker_start(ptr mut u8 buffer,usize capacity);
unsafe extern C fn u32 bc_scalar_worker_finish(ptr u8 result,usize length);

// Private worker route. Native admission must succeed before a source byte is compiled.
pub fn i32 execute(){
    var bytes::Buffer request=switch(bytes::with_capacity(4101)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    if(!bytes::resize_zeroed(ref mut request,4101).is_ok){return 4;}
    let usize size=unsafe{bc_scalar_worker_start(bytes::view_mut(ref mut request) as ptr mut u8,4101)};
    if(size<5 || size>4101){return 4;}
    let ref u8[] wire=bytes::view(ref request);
    if(wire[0]>1){return 4;}
    let bool run=wire[0]==1;
    var usize fuel=0;
    var usize i=5;
    while(i>1){i-=1;fuel=fuel*256+wire[i] as usize;}
    if(fuel>meter::cli_limit() || (!run && fuel!=0)){return 4;}
    return respond(wire[5..size],run,fuel);
}

fn result::Profiled uncompiled(errors::Error error){
    return result::Profiled{.outcome=result::failed(error),.profile=0};
}

fn result::Profiled compute(ref u8[] source,bool run,usize fuel){
    let bool retained=switch(features::retained(source)){
        case .ok(v):{v}case .err(e):{return uncompiled(e);}
    };
    if(retained){return compute_retained(source,run,fuel);}
    return compute_ordinary(source,run,fuel);
}

// Keep the owning image and the ordinary compiler's IR in separate call frames.
fn result::Profiled compute_retained(ref u8[] source,bool run,usize fuel){
    let programs::ReferenceReturnProgram program=switch(compiler::compile_reference_returns(
        source,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return uncompiled(compiler::public_error(e));}
    };
    let result::Outcome outcome=if(run){
        switch(programs::run_public_references(ref program,fuel)){
            case .ok(value):{result::completed(value)}case .err(e):{result::failed(e)}
        }
    }else{result::checked()};
    return result::Profiled{.outcome=outcome,.profile=8};
}

fn result::Profiled compute_ordinary(ref u8[] source,bool run,usize fuel){
    let ir::Program program=switch(compiler::compile(source)){
        case .ok(v):{v}case .err(e):{return uncompiled(e);}
    };
    let u8 profile=arrays::profile(ref program);
    let result::Outcome outcome=if(run){
        switch(vm::run(ref program,fuel)){
            case .ok(value):{result::completed(value)}case .err(e):{result::failed(e)}
        }
    }else{
        switch(verifier::verify(ref program)){
            case .ok(_):{result::checked()}case .err(e):{result::failed(e)}
        }
    };
    return result::Profiled{.outcome=outcome,.profile=profile};
}

fn i32 respond(ref u8[] source,bool run,usize fuel){
    let result::Expected expected=result::Expected{.run=run,.output=false,.source_bytes=source.len,.instructions=256};
    let result::Profiled outcome=compute(source,run,fuel);
    let bytes::Buffer payload=switch(result::encode_profiled(outcome,expected)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let ref u8[] data=bytes::view(ref payload);
    return if(unsafe{bc_scalar_worker_finish(data as ptr u8,data.len)}!=0){0}else{4};
}
