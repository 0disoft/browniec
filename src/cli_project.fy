module cli_project;

import anchored_source_loader as anchored;
import json_tokens as json;
import project_source_loader as loader;
import project_manifest as manifest;
import project_sources as binding;
import module_entry as entries;
import module_program as programs;
import module_index as modules;
import module_input_program as input_programs;
import module_input_entry as input_entries;
import cli_project_input as binary;
import cli_configured_project as configured;
import runtime_input as input;
import source_snapshot as sources;
import source_error as diagnostics;
import static_image as images;
import errors as errors;
import render as render;
import std::bytes as bytes;
import std::process as process;

resource ProjectInput {
    manifest::Project metadata;
    sources::Snapshot snapshot;
    cleanup { }
}

pub fn bool selected(){
    var u8[9] flag=[0;9];
    let usize size=switch(process::arg(2,ref mut flag)){case .ok(v):{v}case .err(_):{return false;}};
    return size==9 && bytes::equal(ref flag,b"--project");
}
@effects(console,filesystem)
pub fn i32 execute(render::Format format,bool run,usize fuel,binary::Selection selection){
    var u8[3072] path=[0;3072];
    let usize size=switch(process::arg(3,ref mut path)){
        case .ok(v):{v}case .err(_):{return failure(format,run,errors::absent(10,0),0);}
    };
    let ProjectInput project=switch(acquire(ref path[..size])){
        case .ok(v):{v}case .err(e):{return failure(format,run,e,0);}
    };
    if(selection.stdin || selection.argument!=0){return execute_with_input(ref project,format,fuel,selection);}
    return execute_project(ref project,format,run,fuel);
}
@effects(console,filesystem)
pub fn i32 execute_configured(render::Format format,bool run,configured::Selection settings,binary::Selection selection){
    var u8[3072] path=[0;3072];
    let usize size=switch(process::arg(3,ref mut path)){
        case .ok(v):{v}case .err(_):{return failure(format,run,errors::absent(10,0),0);}
    };
    var bytes::Buffer data=bytes::empty();
    var anchored::Root root=switch(open_manifest(ref path[..size],ref mut data)){
        case .ok(v):{v}case .err(e):{return failure(format,run,e,0);}
    };
    let manifest::Project project=switch(parse_manifest(ref root,bytes::view(ref data))){
        case .ok(v):{v}case .err(e):{return failure(format,run,e,0);}
    };
    return configured::execute(format,run,settings,selection,ref project,ref mut root);
}

fn Result<ProjectInput,errors::Error> acquire(ref u8[] path){
    var bytes::Buffer data=bytes::empty();
    var anchored::Root root=open_manifest(path,ref mut data)?;
    let manifest::Project project=parse_manifest(ref root,bytes::view(ref data))?;
    if(manifest::requirements(ref project)!=0){return .err(errors::absent(11,0));}
    let sources::Snapshot snapshot=switch(loader::load_from(ref project,ref mut root,sources::source_limit())){
        case .ok(v):{v}case .err(e):{return .err(errors::absent(switch(e){case .Limit:{4}case .Acquisition:{9}case .Binding:{3}case .Compile:{3}},0));}
    };
    return .ok(ProjectInput{.metadata=project,.snapshot=snapshot});
}

// Retain the anchor independently of the manifest buffer and decoded metadata.
pub fn Result<anchored::Root,errors::Error> open_manifest(ref u8[] path,ref mut bytes::Buffer data){
    if(!bytes::resize_zeroed(data,json::byte_limit()).is_ok){return .err(errors::absent(15,0));}
    return switch(anchored::open_project(path,bytes::view_mut(data))){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(errors::absent(switch(e){case .Input:{9}case .Limit:{10}case .Allocation:{15}},0))}
    };
}

pub fn Result<manifest::Project,errors::Error> parse_manifest(ref anchored::Root root,ref u8[] data){
    return switch(manifest::parse(data[..anchored::manifest_bytes(root)])){
        case .ok(v):{.ok(v)}
        case .err(e):{
            let u8 kind=switch(e.kind){
                case .Allocation:{15}case .Json:{10}case .Limit:{10}case .Unknown:{10}
                case .Duplicate:{10}case .Missing:{10}case .Value:{10}case .Bounds:{10}
            };
            .err(errors::make(kind,e.offset))
        }
    };
}
@effects(console)
fn i32 execute_project(ref ProjectInput project,render::Format format,bool run,usize fuel){
    let ref sources::Snapshot snapshot=ref project.snapshot;
    // Keep the original bytes available if binding or compilation consumes its input.
    let entries::Entry entry=switch(binding::select(ref project.metadata,sources::duplicate(snapshot))){
        case .ok(v):{v}
        case .err(e):{return binding_failure(format,run,snapshot,e);}
    };
    return execute_entry(entry,snapshot,format,run,fuel);
}
@effects(console)
fn i32 failure(render::Format format,bool run,errors::Error error,u8 profile){
    return render::selected_outcome(format,run,true,0,error,profile);
}
@effects(console)
fn i32 execute_entry(entries::Entry entry,ref sources::Snapshot snapshot,render::Format format,bool run,usize fuel){
    let programs::Program program=switch(programs::compile(entry,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return render::project_failure(format,run,e.code,snapshot,e.at,0);}
    };
    let u8 profile=programs::profile(ref program);
    if(!run){return render::selected_outcome(format,false,false,0,errors::absent(0,0),profile);}
    return switch(programs::run(ref program,fuel)){
        case .ok(v):{render::selected_outcome(format,true,false,v,errors::absent(0,0),profile)}
        case .err(e):{render::project_failure(format,true,e.code,programs::snapshot(ref program),e.at,profile)}
    };
}

@effects(console)
fn i32 binding_failure(render::Format format,bool run,ref sources::Snapshot snapshot,modules::Error e){
    return render::project_failure(format,run,diagnostics::binding(e),snapshot,e.at,0);
}
@effects(console,filesystem)
fn i32 execute_with_input(ref ProjectInput project,render::Format format,usize fuel,binary::Selection selection){
    let ref sources::Snapshot snapshot=ref project.snapshot;
    let input_entries::InputEntry entry=switch(binding::select_input(ref project.metadata,sources::duplicate(snapshot))){
        case .ok(v):{v}case .err(e):{return binding_failure(format,true,snapshot,e);}
    };
    let input_programs::Program program=switch(input_programs::compile(entry,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return render::project_failure(format,true,e.code,snapshot,e.at,0);}
    };
    let input::Snapshot payload=switch(binary::read(selection)){
        case .ok(v):{v}case .err(e):{return failure(format,true,e,8);}
    };
    return switch(input_programs::run(ref program,ref payload,fuel)){
        case .ok(v):{render::selected_outcome(format,true,false,v.value,errors::absent(0,0),8)}
        case .err(e):{render::project_failure(format,true,e.code,input_programs::snapshot(ref program),e.at,8)}
    };
}
