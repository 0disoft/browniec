module cli_project;

import anchored_source_loader as anchored;
import project_source_loader as loader;
import project_manifest as manifest;
import project_sources as binding;
import module_entry as entries;
import module_program as programs;
import source_snapshot as sources;
import source_error as diagnostics;
import static_image as images;
import errors as errors;
import json_tokens as json;
import render as render;
import std::bytes as bytes;
import std::process as process;

pub fn bool selected(){
    var u8[9] flag=[0;9];
    let usize size=switch(process::arg(2,ref mut flag)){case .ok(v):{v}case .err(_):{return false;}};
    return size==9 && bytes::equal(ref flag,b"--project");
}
@effects(console,filesystem)
pub fn i32 execute(render::Format format,bool run,usize fuel){
    var u8[3072] path=[0;3072];
    let usize size=switch(process::arg(3,ref mut path)){
        case .ok(v):{v}case .err(_):{return failure(format,run,errors::absent(10,0),0);}
    };
    let entries::Entry entry=switch(acquire(ref path[..size])){
        case .ok(v):{v}case .err(e):{return failure(format,run,e,0);}
    };
    return execute_entry(entry,format,run,fuel);
}
fn Result<entries::Entry,errors::Error> acquire(ref u8[] path){
    let usize limit=json::byte_limit();
    var bytes::Buffer data=switch(bytes::with_capacity(limit)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(15,0));}
    };
    if(!bytes::resize_zeroed(ref mut data,limit).is_ok){return .err(errors::absent(15,0));}
    var anchored::Root root=switch(anchored::open_project(path,bytes::view_mut(ref mut data))){
        case .ok(v):{v}
        case .err(e):{return .err(errors::absent(switch(e){case .Input:{9}case .Limit:{10}case .Allocation:{15}},0));}
    };
    let ref u8[] view=bytes::view(ref data);
    let manifest::Project project=switch(manifest::parse(view[..anchored::manifest_bytes(ref root)])){
        case .ok(v):{v}
        case .err(e):{
            let u8 kind=switch(e.kind){
                case .Allocation:{15}case .Json:{10}case .Limit:{10}case .Unknown:{10}
                case .Duplicate:{10}case .Missing:{10}case .Value:{10}case .Bounds:{10}
            };
            return .err(errors::make(kind,e.offset));
        }
    };
    if(manifest::requirements(ref project)!=0){return .err(errors::absent(11,0));}
    let sources::Snapshot snapshot=switch(loader::load_from(ref project,ref mut root,sources::source_limit())){
        case .ok(v):{v}
        case .err(e):{return .err(errors::absent(switch(e){case .Limit:{4}case .Acquisition:{9}case .Binding:{3}case .Compile:{3}},0));}
    };
    return switch(binding::select(ref project,snapshot)){
        case .ok(v):{.ok(v)}
        case .err(e):{
            let u8 kind=switch(e.kind){
                case .Lexical:{1}case .Syntax:{2}case .Limit:{4}case .Allocation:{15}
                case .Duplicate:{3}case .Missing:{3}case .Private:{3}case .Reserved:{3}case .Bounds:{3}case .Kind:{3}
            };
            .err(if(e.at.source==sources::no_source().source){errors::absent(kind,0)}else{errors::make(kind,e.at.start)})
        }
    };
}
fn errors::Error project_error(diagnostics::Error e){
    if(e.code.location==errors::instruction_location()){return e.code;}
    return if(e.at.source==sources::no_source().source){errors::absent(e.code.kind,0)}else{errors::make(e.code.kind,e.at.start)};
}
@effects(console)
fn i32 failure(render::Format format,bool run,errors::Error error,u8 profile){
    return render::selected_outcome(format,run,true,0,error,profile);
}
@effects(console)
fn i32 execute_entry(entries::Entry entry,render::Format format,bool run,usize fuel){
    let programs::Program program=switch(programs::compile(entry,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return failure(format,run,project_error(e),0);}
    };
    let u8 profile=programs::profile(ref program);
    if(!run){return render::selected_outcome(format,false,false,0,errors::absent(0,0),profile);}
    return switch(programs::run(ref program,fuel)){
        case .ok(v):{render::selected_outcome(format,true,false,v,errors::absent(0,0),profile)}
        case .err(e):{failure(format,true,project_error(e),profile)}
    };
}
