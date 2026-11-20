module cli_project_input;

import errors as errors;
import render as render;
import runtime_input as input;
import std::process as process;

unsafe extern C fn ptr mut void bc_cli_read_input(ptr u8 path,usize length,usize limit,ptr mut u32 status);
unsafe extern C fn usize bc_cli_input_length(ptr mut void owner);
unsafe extern C fn ptr u8 bc_cli_input_bytes(ptr mut void owner);
unsafe extern C fn void bc_cli_input_close(ptr mut void owner);

resource Native { ptr mut void owner; cleanup { unsafe {bc_cli_input_close(this.owner)}; } }

@effects(filesystem)
pub fn Result<input::Snapshot,errors::Error> read(usize argument) {
    var u8[3072] path=[0;3072];
    let usize length=switch(process::arg(argument,ref mut path)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(9,0));}
    };
    let ref u8[] name=ref path[..length];
    var u32 status=0;
    let ptr mut void address=unsafe{bc_cli_read_input(name as ptr u8,length,input::hard_limit(),ref mut status as ptr mut u32)};
    if(address==null){
        let u8 kind=if(status==2){render::input_limit_kind()}else if(status==5){15}else{9};
        return .err(errors::absent(kind,0));
    }
    return adopt(Native{.owner=address});
}

fn Result<input::Snapshot,errors::Error> adopt(Native native){
    let usize length=unsafe{bc_cli_input_length(native.owner)};
    let ptr u8 data=unsafe{bc_cli_input_bytes(native.owner)};
    let ref u8[] view=unsafe{byte_slice::from_raw_parts(ref native,data,length)};
    // Host acquisition is outside guest Fuel. The VM charges its input work.
    var usize fuel=0;
    return switch(input::snapshot(view,input::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(errors::absent(switch(e){
            case .Allocation:{15}case .Limit:{render::input_limit_kind()}case .Bounds:{9}case .Fuel:{8}
        },0))}
    };
}
