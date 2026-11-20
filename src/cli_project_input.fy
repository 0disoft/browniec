module cli_project_input;

import cli_local_file as files;
import errors as errors;
import render as render;
import runtime_input as input;

@effects(filesystem)
pub fn Result<input::Snapshot,errors::Error> read(usize argument){
    let files::File file=files::open(argument,input::hard_limit(),render::input_limit_kind())?;
    // Host acquisition is outside guest Fuel. The VM charges its input work.
    var usize fuel=0;
    return switch(input::snapshot(files::view(ref file),input::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(errors::absent(switch(e){
            case .Allocation:{15}case .Limit:{render::input_limit_kind()}case .Bounds:{9}case .Fuel:{8}
        },0))}
    };
}
