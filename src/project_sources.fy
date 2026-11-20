module project_sources;
import project_manifest as project;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import module_input_entry as input_entries;
import std::bytes as bytes;

// Pure native snapshot binding. The caller retains project requirements;
// selection proves neither filesystem origin nor grants/executable bodies.
fn usize no_mapping(){return 32;}
fn modules::Error error(modules::Failure kind,sources::Span at){return modules::Error{.kind=kind,.at=at};}
fn Result<usize,modules::Error> file_map(ref project::Project map,ref sources::Snapshot snapshot,ref mut usize[] order){
    let usize count=project::count(map);
    if(count>sources::file_limit()){return .err(error(.Limit,sources::no_source()));}
    if(count!=sources::count(snapshot) || order.len!=sources::file_limit()){
        return .err(error(.Missing,sources::no_source()));
    }
    var usize id=0;
    while(id<count){
        let sources::Span at=switch(sources::whole(snapshot,id)){
            case .ok(v):{v}case .err(_):{return .err(error(.Missing,sources::no_source()));}
        };
        let ref u8[] name=switch(sources::name(snapshot,id)){
            case .ok(v):{v}case .err(_):{return .err(error(.Missing,at));}
        };
        var usize found=no_mapping();var usize row=0;
        while(row<count){
            let ref u8[] path=switch(project::path(map,row)){
                case .ok(v):{v}case .err(_):{return .err(error(.Bounds,at));}
            };
            if(bytes::equal(name,path)){found=row;break;}row+=1;
        }
        if(found==no_mapping()){return .err(error(.Missing,at));}
        order[id]=found;id+=1;
    }
    return .ok(count);
}
fn Result<usize,modules::Error> headers(ref project::Project map,ref modules::Index index,ref usize[] order){
    let usize count=modules::count(index);var usize id=0;
    while(id<count){
        let usize row=order[id];
        let modules::Module declaration=switch(modules::module_at(index,id)){
            case .ok(v):{v}case .err(e):{return .err(e);}
        };
        let ref u8[] expected=switch(project::module_name(map,row)){
            case .ok(v):{v}case .err(_):{return .err(error(.Kind,declaration.path));}
        };
        let ref u8[] actual=switch(modules::module_name(index,id)){
            case .ok(v):{v}case .err(e):{return .err(e);}
        };
        if(!bytes::equal(actual,expected)){return .err(error(.Kind,declaration.path));}id+=1;
    }
    return .ok(count);
}
// Match exact decoded path identities irrespective of snapshot order, prove
// every matching canonical header, then select the named public i32() entry.
// Existing Index checks all imports/declarations; body admission follows later.
fn Result<modules::Index,modules::Error> build_index(ref project::Project map,sources::Snapshot snapshot){
    var usize[16] order=[32;16];let usize mapped=file_map(map,ref snapshot,ref mut order)?;
    let modules::Index index=modules::build(snapshot)?;
    let usize checked=headers(map,ref index,ref order)?;
    return .ok(index);
}
pub fn Result<entries::Entry,modules::Error> select(ref project::Project map,sources::Snapshot snapshot){
    let modules::Index index=build_index(map,snapshot)?;
    // Preserve the existing owning result and original diagnostic directly.
    // Reboxing Entry into a second error domain amplifies native stack slots.
    return entries::select_i32(index,project::entry_module(map),project::entry_function(map));
}
pub fn Result<entries::Entry,modules::Error> select_host(ref project::Project map,sources::Snapshot snapshot,usize token_limit){
    var usize[16] order=[32;16];let usize mapped=file_map(map,ref snapshot,ref mut order)?;
    let modules::Index index=modules::build_host(snapshot,token_limit)?;
    let usize checked=headers(map,ref index,ref order)?;
    return entries::select_i32(index,project::entry_module(map),project::entry_function(map));
}
pub fn Result<input_entries::InputEntry,modules::Error> select_input(ref project::Project map,sources::Snapshot snapshot){
    let modules::Index index=build_index(map,snapshot)?;
    return input_entries::select_i32_input(index,project::entry_module(map),project::entry_function(map));
}

// Recheck independently selected native entries before project admission.
pub fn Result<usize,modules::Error> verify(ref project::Project map,ref entries::Entry selected){
    let ref modules::Index index=entries::index(selected);var usize[16] order=[32;16];
    let usize mapped=file_map(map,modules::snapshot(index),ref mut order)?;
    let usize checked=headers(map,index,ref order)?;
    let usize expected=modules::entry(index,project::entry_module(map),project::entry_function(map))?;
    if(expected!=entries::selected(selected)){return .err(error(.Kind,entries::signature_span(selected)));}
    return .ok(expected);
}
