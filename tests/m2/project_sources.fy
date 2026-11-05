module tests::m2::project_sources;
import project_manifest as project;
import project_sources as binding;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import module_program as programs;
import std::bytes as bytes;

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);builder()}};}
fn void added(ref mut sources::Builder b,ref u8[] name,ref u8[] data){assert(sources::add(b,name,data).is_ok);}
fn sources::Snapshot frozen(ref sources::Builder b){
    return switch(sources::freeze(b)){case .ok(v):{v}case .err(_):{assert(false);frozen(b)}};
}
fn project::Project parsed(ref u8[] json){return switch(project::parse(json)){case .ok(v):{v}case .err(_):{assert(false);parsed(b"")}};}
fn project::Project map(){
    return parsed(b"{\"schema\":\"brownie.project/0.3\",\"name\":\"test\",\"entry\":{\"module\":\"app\",\"function\":\"start\"},\"sources\":[{\"module\":\"app\",\"path\":\"src/main.fy\"},{\"module\":\"util::math\",\"path\":\"src/math.fy\"}],\"requires\":[\"fs.read\"]}");
}
fn sources::Snapshot pair(ref u8[] app,ref u8[] lib,bool reverse){
    var sources::Builder b=builder();
    if(reverse){added(ref mut b,b"src/math.fy",lib);added(ref mut b,b"src/main.fy",app);}
    else{added(ref mut b,b"src/main.fy",app);added(ref mut b,b"src/math.fy",lib);}
    return frozen(ref b);
}
fn entries::Entry selected(ref project::Project p,sources::Snapshot snapshot){
    return switch(binding::select(p,snapshot)){case .ok(v):{v}case .err(_):{
        assert(false);var sources::Builder b=builder();return selected(p,frozen(ref b));
    }};
}
fn u8 module_code(modules::Failure kind){return switch(kind){
    case .Lexical:{0}case .Syntax:{1}case .Limit:{2}case .Duplicate:{3}case .Missing:{4}
    case .Private:{5}case .Reserved:{6}case .Bounds:{7}case .Kind:{8}
};}
fn modules::Error denied(ref project::Project p,sources::Snapshot snapshot,u8 kind){
    return switch(binding::select(p,snapshot)){
        case .err(e):{assert(module_code(e.kind)==kind);e}
        case .ok(_):{assert(false);modules::Error{.kind=.Bounds,.at=sources::no_source()}}
    };
}
fn void append(ref mut bytes::Buffer b,ref u8[] value){assert(bytes::append(b,value).is_ok);}
fn void number(ref mut bytes::Buffer b,usize n){assert(bytes::append_usize(b,n).is_ok);}

@test fn void reordered_snapshots_bind_exact_paths_normalized_headers_and_the_named_entry(){
    let project::Project p=map();
    let entries::Entry e=selected(ref p,pair(
        b"module app;import util::math as m;pub fn i32 start(){return m::answer();}",
        b"module util /*split*/ :: math;pub fn i32 answer(){return 42;}",true));
    let ref modules::Index index=entries::index(ref e);
    assert(entries::signature_span(ref e).source==1);
    assert(switch(modules::module_name(index,0)){case .ok(v):{bytes::equal(v,b"util::math")}case .err(_):{false}});
    assert(switch(sources::name(modules::snapshot(index),1)){case .ok(v):{bytes::equal(v,b"src/main.fy")}case .err(_):{false}});
    // Selection is not a grant: the caller's declaration remains intact.
    assert(project::requirements(ref p)==1);
}
@test fn void matching_source_selection_composes_with_complete_module_admission_and_execution(){
    let project::Project p=map();
    let entries::Entry e=selected(ref p,pair(
        b"module app;import util::math as m;pub fn i32 start(){return m::answer();}",
        b"module util::math;pub fn i32 answer(){return 42;}",true));
    let programs::Program program=switch(programs::compile(e,65536)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(switch(programs::run(ref program,4)){case .ok(v):{v==42}case .err(_):{false}});
    assert(switch(programs::run(ref program,3)){case .ok(_):{false}case .err(e):{e.code.kind==8}});
}
@test fn void missing_extra_unknown_or_case_changed_snapshot_identities_fail_before_binding(){
    let project::Project p=map();var sources::Builder short=builder();
    added(ref mut short,b"src/main.fy",b"module app;pub fn i32 start(){return 42;}");
    let modules::Error missing=denied(ref p,frozen(ref short),4);assert(missing.at.source==16);
    var sources::Builder extra=builder();
    added(ref mut extra,b"src/main.fy",b"module app;pub fn i32 start(){return 42;}");
    added(ref mut extra,b"src/math.fy",b"module util::math;");added(ref mut extra,b"src/extra.fy",b"module extra;");
    let modules::Error excessive=denied(ref p,frozen(ref extra),4);assert(excessive.at.source==16);
    var sources::Builder changed=builder();
    added(ref mut changed,b"SRC/main.fy",b"module app;pub fn i32 start(){return 42;}");
    added(ref mut changed,b"src/math.fy",b"module util::math;");
    let modules::Error wrong=denied(ref p,frozen(ref changed),4);
    assert(wrong.at.source==0);
}
@test fn void swapped_headers_fail_with_original_file_and_exact_header_span(){
    let project::Project p=map();
    let modules::Error failure=denied(ref p,pair(b"module util::math;",b"module app;pub fn i32 start(){return 42;}",true),8);
    assert(failure.at.source==0);
    assert(failure.at.start==7 && failure.at.end==10);
}
@test fn void import_visibility_and_entry_signature_errors_preserve_original_locations(){
    let project::Project p=map();
    let modules::Error missing=denied(ref p,pair(
        b"module app;import absent as a;pub fn i32 start(){return 42;}",b"module util::math;",true),4);
    assert(module_code(missing.kind)==4 && missing.at.source==1);
    let modules::Error private_entry=denied(ref p,pair(
        b"module app;fn i32 start(){return 42;}",b"module util::math;",false),5);
    assert(module_code(private_entry.kind)==5 && private_entry.at.source==0);
    let modules::Error wrong=denied(ref p,pair(
        b"module app;pub fn i32 start(i32 a){return a;}",b"module util::math;",false),8);
    assert(module_code(wrong.kind)==8 && wrong.at.source==0);
}
@test fn void existing_source_lexical_failures_are_not_hidden_by_map_selection(){
    let project::Project p=map();
    let modules::Error failure=denied(ref p,pair(
        b"module app;pub fn i32 start(){return 42;}",b"module util::math;\x00",true),0);
    assert(module_code(failure.kind)==0 && failure.at.source==0);
}
@test fn void all_16_compiler_files_bind_and_the_17th_manifest_source_is_a_limit_error(){
    var sources::Builder b=builder();var bytes::Buffer json=bytes::empty();
    append(ref mut json,b"{\"schema\":\"brownie.project/0.3\",\"name\":\"full\",\"entry\":{\"module\":\"m0\",\"function\":\"go\"},\"requires\":[],\"sources\":[");
    var usize i=0;
    while(i<17){
        if(i!=0){append(ref mut json,b",");}
        append(ref mut json,b"{\"module\":\"m");number(ref mut json,i);append(ref mut json,b"\",\"path\":\"src/m");
        number(ref mut json,i);append(ref mut json,b".fy\"}");
        if(i<16){
            var bytes::Buffer name=bytes::empty();append(ref mut name,b"src/m");number(ref mut name,i);append(ref mut name,b".fy");
            var bytes::Buffer source=bytes::empty();append(ref mut source,b"module m");number(ref mut source,i);
            append(ref mut source,b";pub fn i32 go(){return 42;}");
            added(ref mut b,bytes::view(ref name),bytes::view(ref source));
        }
        if(i==15){
            var bytes::Buffer complete=switch(bytes::copy(bytes::view(ref json))){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
            append(ref mut complete,b"]}");let project::Project p=parsed(bytes::view(ref complete));
            let entries::Entry e=selected(ref p,frozen(ref b));assert(modules::count(entries::index(ref e))==16);
        }
        i+=1;
    }
    append(ref mut json,b"]}");let project::Project p=parsed(bytes::view(ref json));
    let modules::Error failure=denied(ref p,frozen(ref b),2);
    assert(failure.at.source==16);
}
