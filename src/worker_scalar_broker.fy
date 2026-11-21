module worker_scalar_broker;

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
    let result::Expected expected=result::Expected{.run=run==1,.source_bytes=source_length,.instructions=256};
    let ref u8[] payload=unsafe{byte_slice::from_raw_parts(ref expected,data,length)};
    return if(result::parse(payload,expected).is_ok){1}else{0};
}

@effects(console,filesystem)
pub fn i32 execute(bool external_profile){
    let usize operation_at=if(external_profile){3}else{2};
    var u8[8] operation=[0;8];
    let usize size=switch(process::arg(operation_at,ref mut operation)){
        case .ok(v):{v}case .err(_):{return report(false,errors::absent(10,0));}
    };
    let ref u8[] word=ref operation[..size];
    let bool run=bytes::equal(word,b"run");
    if(!run && !bytes::equal(word,b"check")){return report(false,errors::absent(10,0));}
    var u8[64] profile=[0;64];
    var usize profile_length=0;
    if(external_profile){
        profile_length=switch(process::arg(2,ref mut profile)){
            case .ok(v):{v}case .err(_):{return report(run,errors::absent(10,0));}
        };
        if(profile_length==0){return report(run,errors::absent(11,0));}
    }
    let input::Source source=switch(input::read_source(operation_at+1)){
        case .ok(v):{v}case .err(e):{return report(run,e);}
    };
    return invoke(ref profile[..profile_length],ref source,run);
}

@effects(console)
fn i32 invoke(ref u8[] profile,ref input::Source snapshot,bool run){
    let ref u8[] source=ref snapshot.data[..snapshot.length];
    var u8[256] reply=[0;256];
    var usize length=0;
    let ptr u8 profile_name=if(profile.len==0){null}else{unsafe{profile as ptr u8}};
    let u32 status=unsafe{bc_scalar_broker_invoke(profile_name,profile.len,
        source as ptr u8,source.len,if(run){1}else{0},if(run){fuel::cli_default()}else{0},
        ref mut reply[..] as ptr mut u8,ref mut length as ptr mut usize)};
    if(status!=1 || length==0 || length>result::byte_limit()){
        let u8 kind=if(status==2){errors::deadline_kind()}else if(status==3){errors::cancelled_kind()}else{11};
        return report(run,errors::absent(kind,0));
    }
    let result::Expected expected=result::Expected{.run=run,.source_bytes=source.len,.instructions=256};
    let result::Outcome outcome=switch(result::parse(ref reply[..length],expected)){
        case .ok(v):{v}case .err(_):{return report(run,errors::absent(11,0));}
    };
    return switch(outcome.status){
        case .Checked:{render::selected_outcome(.Json,false,false,0,errors::absent(0,0),0)}
        case .Completed:{render::selected_outcome(.Json,true,false,outcome.value,errors::absent(0,0),0)}
        case .Failed:{report(run,outcome.error)}
    };
}

@effects(console)
fn i32 report(bool run,errors::Error error){
    return render::selected_outcome(.Json,run,true,0,error,0);
}
