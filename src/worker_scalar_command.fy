module worker_scalar_command;

import compiler as compiler;
import fuel as meter;
import ir as ir;
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

fn result::Outcome compute(ref u8[] source,bool run,usize fuel){
    let ir::Program program=switch(compiler::compile(source)){
        case .ok(v):{v}case .err(e):{return result::failed(e);}
    };
    if(!run){
        return switch(verifier::verify(ref program)){
            case .ok(_):{result::checked()}case .err(e):{result::failed(e)}
        };
    }
    return switch(vm::run(ref program,fuel)){
        case .ok(value):{result::completed(value)}case .err(e):{result::failed(e)}
    };
}

fn i32 respond(ref u8[] source,bool run,usize fuel){
    let result::Expected expected=result::Expected{.run=run,.source_bytes=source.len,.instructions=256};
    let result::Outcome outcome=compute(source,run,fuel);
    let bytes::Buffer payload=switch(result::encode(outcome,expected)){
        case .ok(v):{v}case .err(_):{return 4;}
    };
    let ref u8[] data=bytes::view(ref payload);
    return if(unsafe{bc_scalar_worker_finish(data as ptr u8,data.len)}!=0){0}else{4};
}
