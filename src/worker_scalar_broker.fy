module worker_scalar_broker;

import anchored_source_loader as anchored;
import cli_input as input;
import errors as errors;
import fuel as fuel;
import render as render;
import worker_scalar_result as result;
import std::bytes as bytes;
import std::process as process;

unsafe extern C fn u32 bc_scalar_broker_invoke(ptr u8 profile,usize profile_length,
    ptr u8 source,usize source_length,u32 run,usize fuel,ptr mut u8 reply,ptr mut usize reply_length);

// The C gate calls this only with its complete, bounded RESULT span.
fn u32 validate_result(ptr u8 data,usize length,u32 run,usize source_length){
    if(data==null || length==0 || length>result::byte_limit() || run>1 || source_length>4096){return 0;}
    let result::Expected expected=result::Expected{.run=run==1,.output=false,.source_bytes=source_length,.instructions=256};
    let ref u8[] payload=unsafe{byte_slice::from_raw_parts(ref expected,data,length)};
    return if(result::parse(payload,expected).is_ok){1}else{0};
}

@effects(console,filesystem)
pub fn i32 execute(bool external_profile){
    let usize operation_at=if(external_profile){3}else{2};
    var u8[8] operation=[0;8];
    let usize size=switch(process::arg(operation_at,ref mut operation)){
        case .ok(v):{v}case .err(_):{return report(.Json,false,errors::absent(10,0));}
    };
    let ref u8[] word=ref operation[..size];
    let bool run=bytes::equal(word,b"run");
    if(!run && !bytes::equal(word,b"check")){return report(.Json,false,errors::absent(10,0));}
    var u8[64] profile=[0;64];
    var usize profile_length=0;
    if(external_profile){
        profile_length=switch(process::arg(2,ref mut profile)){
            case .ok(v):{v}case .err(_):{return report(.Json,run,errors::absent(10,0));}
        };
        if(profile_length==0){return report(.Json,run,errors::absent(11,0));}
    }
    return acquire(ref profile[..profile_length],operation_at+1,.Json,run,fuel::cli_default());
}

@effects(console,filesystem)
pub fn i32 execute_managed(render::Format format,bool run,usize fuel){
    return acquire(b"",2,format,run,fuel);
}

@effects(console)
fn i32 acquire(ref u8[] profile,usize argument,render::Format format,bool run,usize fuel){
    let input::Source source=switch(read_source(argument)){
        case .ok(v):{v}case .err(e):{return report(format,run,e);}
    };
    return invoke(profile,ref source,format,run,fuel);
}

// Use the same explicit local-file acquisition as project manifests.
fn Result<input::Source,errors::Error> read_source(usize argument){
    var u8[3072] path=[0;3072];
    let usize size=switch(process::arg(argument,ref mut path)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(9,0));}
    };
    var input::Source source=input::Source{.data=[0;4096],.length=0};
    let anchored::Root root=switch(anchored::open_project(ref path[..size],ref mut source.data[..])){
        case .ok(v):{v}
        case .err(e):{
            return .err(switch(e){
                case .Limit:{errors::make(4,4096)}
                case .Allocation:{errors::absent(15,0)}
                case .Input:{errors::absent(9,0)}
            });
        }
    };
    source.length=anchored::manifest_bytes(ref root);
    return .ok(source);
}

@effects(console)
fn i32 invoke(ref u8[] profile,ref input::Source snapshot,render::Format format,bool run,usize fuel){
    let ref u8[] source=ref snapshot.data[..snapshot.length];
    var u8[256] reply=[0;256];
    var usize length=0;
    let ptr u8 profile_name=if(profile.len==0){null}else{unsafe{profile as ptr u8}};
    let u32 status=unsafe{bc_scalar_broker_invoke(profile_name,profile.len,
        source as ptr u8,source.len,if(run){1}else{0},if(run){fuel}else{0},
        ref mut reply[..] as ptr mut u8,ref mut length as ptr mut usize)};
    if(status!=1 || length==0 || length>result::byte_limit()){
        let u8 kind=if(status==2){errors::deadline_kind()}else if(status==3){errors::cancelled_kind()}else{11};
        return report(format,run,errors::absent(kind,0));
    }
    let result::Expected expected=result::Expected{.run=run,.output=false,.source_bytes=source.len,.instructions=256};
    let result::Outcome outcome=switch(result::parse(ref reply[..length],expected)){
        case .ok(v):{v}case .err(_):{return report(format,run,errors::absent(11,0));}
    };
    return switch(outcome.status){
        case .Checked:{render::selected_outcome(format,false,false,0,errors::absent(0,0),0)}
        case .Completed:{render::selected_outcome(format,true,false,outcome.value,errors::absent(0,0),0)}
        case .Failed:{report(format,run,outcome.error)}
    };
}

@effects(console)
fn i32 report(render::Format format,bool run,errors::Error error){
    return render::selected_outcome(format,run,true,0,error,0);
}
