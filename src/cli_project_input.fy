module cli_project_input;

import cli_local_file as files;
import errors as errors;
import render as render;
import runtime_input as input;

pub struct Selection { usize argument; bool stdin; }

@effects(filesystem)
pub fn Result<input::Snapshot,errors::Error> read(Selection selection){
    return read_with_limit(selection,input::hard_limit(),0);
}

@effects(filesystem)
pub fn Result<input::Snapshot,errors::Error> read_with_limit(Selection selection,usize requested,usize stdin_deadline_ms){
    let usize hard=input::hard_limit();
    let usize limit=if(requested<hard){requested}else{hard};
    if(selection.argument==0 && !selection.stdin){return snapshot(b"",limit);}
    let u8 limit_kind=render::input_limit_kind();
    let files::File file=(if(selection.stdin){
        files::open_stdin(limit,limit_kind,stdin_deadline_ms)
    }else{
        files::open(selection.argument,limit,limit_kind)
    })?;
    return snapshot(files::view(ref file),limit);
}

fn Result<input::Snapshot,errors::Error> snapshot(ref u8[] data,usize limit){
    // Host acquisition is outside guest Fuel. The VM charges its input work.
    var usize fuel=0;
    return switch(input::snapshot(data,limit,0,ref mut fuel)){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(errors::absent(switch(e){
            case .Allocation:{15}case .Limit:{render::input_limit_kind()}case .Bounds:{9}case .Fuel:{8}
        },0))}
    };
}
