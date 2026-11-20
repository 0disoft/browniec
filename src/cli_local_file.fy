module cli_local_file;

import errors as errors;
import std::process as process;

// Explicit host-selected disk files, using the Windows project path rules.
unsafe extern C fn ptr mut void bc_cli_read_input(ptr u8 path,usize length,usize limit,ptr mut u32 status);
unsafe extern C fn ptr mut void bc_cli_read_stdin(usize limit,ptr mut u32 status);
unsafe extern C fn usize bc_cli_input_length(ptr mut void owner);
unsafe extern C fn ptr u8 bc_cli_input_bytes(ptr mut void owner);
unsafe extern C fn void bc_cli_input_close(ptr mut void owner);
unsafe extern C fn u32 bc_cli_write_output(ptr u8 path,usize length,ptr u8 data,usize count);

@effects(filesystem)
pub fn bool write_output(usize argument,ref u8[] data){
    var u8[3072] path=[0;3072];
    let usize length=switch(process::arg(argument,ref mut path)){
        case .ok(v):{v}case .err(_):{return false;}
    };
    let ref u8[] name=ref path[..length];
    return unsafe{bc_cli_write_output(name as ptr u8,length,data as ptr u8,data.len)}!=0;
}

pub resource File { ptr mut void owner; cleanup { unsafe {bc_cli_input_close(this.owner)}; } }

@effects(filesystem)
pub fn Result<File,errors::Error> open(usize argument,usize limit,u8 limit_kind){
    var u8[3072] path=[0;3072];
    let usize length=switch(process::arg(argument,ref mut path)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(9,0));}
    };
    let ref u8[] name=ref path[..length];
    var u32 status=0;
    let ptr mut void address=unsafe{bc_cli_read_input(name as ptr u8,length,limit,ref mut status as ptr mut u32)};
    return adopt(address,status,limit_kind);
}

@effects(filesystem)
pub fn Result<File,errors::Error> open_stdin(usize limit,u8 limit_kind){
    var u32 status=0;
    let ptr mut void address=unsafe{bc_cli_read_stdin(limit,ref mut status as ptr mut u32)};
    return adopt(address,status,limit_kind);
}

fn Result<File,errors::Error> adopt(ptr mut void address,u32 status,u8 limit_kind){
    if(address==null){
        let u8 kind=if(status==2){limit_kind}else if(status==5){15}else{9};
        return .err(errors::absent(kind,0));
    }
    return .ok(File{.owner=address});
}

pub fn ref u8[] view(ref File file){
    let usize length=unsafe{bc_cli_input_length(file.owner)};
    let ptr u8 data=unsafe{bc_cli_input_bytes(file.owner)};
    return unsafe{byte_slice::from_raw_parts(file,data,length)};
}
