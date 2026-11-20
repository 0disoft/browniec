module cli_source_input;

import cli_project_input as binary;
import errors as errors;
import module_index as modules;
import module_input_entry as entries;
import module_input_program as programs;
import render as render;
import runtime_input as input;
import source_error as diagnostics;
import source_snapshot as sources;
import static_image as images;

@effects(console,filesystem)
pub fn i32 run(ref u8[] source,render::Format format,usize fuel,binary::Selection selection){
    let entries::InputEntry entry=switch(select(source)){
        case .ok(v):{v}case .err(e):{return failure(format,e,0);}
    };
    let programs::Program program=switch(programs::compile(entry,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return failure(format,e.code,0);}
    };
    let input::Snapshot payload=switch(binary::read(selection)){
        case .ok(v):{v}case .err(e):{return failure(format,e,8);}
    };
    return switch(programs::run(ref program,ref payload,fuel)){
        case .ok(v):{render::selected_outcome(format,true,false,v.value,errors::absent(0,0),8)}
        case .err(e):{failure(format,e.code,8)}
    };
}

// The snapshot's internal name is never rendered for single-source diagnostics.
fn Result<entries::InputEntry,errors::Error> select(ref u8[] source){
    let ref u8[] name=b"source.brc";
    var sources::Builder builder=switch(sources::builder(sources::source_limit(),name.len)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(4,0));}
    };
    switch(sources::add(ref mut builder,name,source)){
        case .ok(_):{}
        case .err(e):{return .err(switch(e){case .Utf8:{errors::make(1,0)}case .State:{errors::absent(4,0)}
            case .Limit:{errors::absent(4,0)}case .Name:{errors::absent(4,0)}
            case .Duplicate:{errors::absent(4,0)}case .Bounds:{errors::absent(4,0)}});}
    };
    let sources::Snapshot snapshot=switch(sources::freeze(ref builder)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(4,0));}
    };
    let modules::Index index=switch(modules::build(snapshot)){
        case .ok(v):{v}case .err(e):{return .err(diagnostics::binding(e));}
    };
    return switch(entries::select_i32_input(index,b"main",b"main")){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(diagnostics::binding(e))}
    };
}

@effects(console)
fn i32 failure(render::Format format,errors::Error error,u8 profile){
    return render::selected_outcome(format,true,true,0,error,profile);
}
