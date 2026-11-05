module tests::m2::project_program;
import project_program as programs;
import project_manifest as project;
import project_sources as binding;
import module_index as modules;
import module_entry as entries;
import source_snapshot as sources;
import std::bytes as bytes;

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);builder()}};}
fn void added(ref mut sources::Builder b,ref u8[] path,ref u8[] source){assert(sources::add(b,path,source).is_ok);}
fn sources::Snapshot snapshot(ref u8[] app,ref u8[] library){
    var sources::Builder b=builder();added(ref mut b,b"src/math.fy",library);added(ref mut b,b"src/main.fy",app);
    return switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{assert(false);return snapshot(app,library);}};
}
fn project::Project metadata(bool requirements){
    let ref u8[] source=if(requirements){
        b"{\"schema\":\"brownie.project/0.3\",\"name\":\"test\",\"entry\":{\"module\":\"app\",\"function\":\"start\"},\"sources\":[{\"module\":\"app\",\"path\":\"src/main.fy\"},{\"module\":\"lib\",\"path\":\"src/math.fy\"}],\"requires\":[\"fs.read\",\"net.http\"]}"
    }else{
        b"{\"schema\":\"brownie.project/0.3\",\"name\":\"test\",\"entry\":{\"module\":\"app\",\"function\":\"start\"},\"sources\":[{\"module\":\"app\",\"path\":\"src/main.fy\"},{\"module\":\"lib\",\"path\":\"src/math.fy\"}],\"requires\":[]}"
    };
    return switch(project::parse(source)){case .ok(v):{v}case .err(_):{assert(false);metadata(false)}};
}
fn entries::Entry selected(ref project::Project metadata,ref u8[] app,ref u8[] library){
    return switch(binding::select(metadata,snapshot(app,library))){case .ok(v):{v}case .err(_):{
        assert(false);return selected(metadata,b"module app;pub fn i32 start(){return 0;}",b"module lib;");
    }};
}
fn entries::Entry unchecked(sources::Snapshot input,ref u8[] name){
    let modules::Index index=switch(modules::build(input)){case .ok(v):{v}case .err(_):{assert(false);return unchecked(snapshot(b"module app;pub fn i32 start(){return 0;}",b"module lib;"),name);}};
    return switch(entries::select_i32(index,b"app",name)){case .ok(v):{v}case .err(_):{assert(false);return unchecked(snapshot(b"module app;pub fn i32 start(){return 0;}",b"module lib;"),name);}};
}
fn programs::Program kept(ref u8[] app,ref u8[] library,bool requirements){
    let project::Project p=metadata(requirements);let entries::Entry e=selected(ref p,app,library);
    return switch(programs::compile(p,e,65536)){
        case .ok(v):{v}case .err(_):{assert(false);return kept(b"module app;pub fn i32 start(){return 0;}",b"module lib;",false);}
    };
}
fn u8 code(programs::Failure kind){return switch(kind){case .Binding:{0}case .Compile:{1}case .Requirements:{2}case .Runtime:{3}};}
fn void result(ref programs::Program p,usize fuel,i64 expected){
    switch(programs::run(p,fuel)){case .ok(v):{assert(v==expected);}case .err(_):{assert(false);}};
}
fn void append(ref mut bytes::Buffer b,ref u8[] value){assert(bytes::append(b,value).is_ok);}
@test fn void sealed_project_owns_metadata_and_original_sources_for_reused_execution(){
    let programs::Program p=kept(b"module app;import lib as m;pub fn i32 start(){return m::answer();}",
        b"module lib;pub fn i32 answer(){return 42;}",false);
    assert(bytes::equal(project::name(programs::metadata(ref p)),b"test"));
    assert(bytes::equal(project::entry_function(programs::metadata(ref p)),b"start"));
    assert(project::requirements(programs::metadata(ref p))==0);
    assert(sources::count(programs::snapshot(ref p))==2 && programs::profile(ref p)==0);
    assert(switch(sources::name(programs::snapshot(ref p),0)){case .ok(v):{bytes::equal(v,b"src/math.fy")}case .err(_):{false}});
    result(ref p,4,42);result(ref p,4,42);
}
@test fn void retained_requirements_are_denied_before_fuel_or_guest_failure(){
    let programs::Program p=kept(b"module app;pub fn i32 start(){let i32 zero=0;return 42/zero;}",b"module lib;",true);
    assert(project::requirements(programs::metadata(ref p))==2);
    assert(switch(project::requirement(programs::metadata(ref p),1)){case .ok(v):{bytes::equal(v,b"net.http")}case .err(_):{false}});
    switch(programs::run(ref p,0)){case .ok(_):{assert(false);}case .err(e):{
        assert(code(e.kind)==2 && e.diagnostic.code.kind==11 && e.diagnostic.at.source==16);
    }};
    switch(programs::run(ref p,16000000)){case .ok(_):{assert(false);}case .err(e):{assert(code(e.kind)==2);}};
}
@test fn void independently_selected_entries_cannot_bypass_the_exact_project_binding(){
    var sources::Builder b=builder();
    added(ref mut b,b"src/math.fy",b"module app;pub fn i32 start(){return 42;}");
    added(ref mut b,b"src/main.fy",b"module lib;");
    let sources::Snapshot swapped=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(programs::compile(metadata(false),unchecked(swapped,b"start"),65536)){
        case .ok(_):{assert(false);}case .err(e):{assert(code(e.kind)==0 && e.binding.at.source==0);}
    };
    let entries::Entry wrong=unchecked(snapshot(b"module app;pub fn i32 start(){return 42;}pub fn i32 other(){return 99;}",b"module lib;"),b"other");
    switch(programs::compile(metadata(false),wrong,65536)){
        case .ok(_):{assert(false);}case .err(e):{assert(code(e.kind)==0 && e.binding.at.source==1);}
    };
}
@test fn void all_bodies_are_admitted_and_compile_errors_keep_original_file_spans(){
    let ref u8[] source=b"module lib;fn i32 unused(){return true;}";
    let project::Project p=metadata(false);let entries::Entry e=selected(ref p,b"module app;pub fn i32 start(){return 42;}",source);
    switch(programs::compile(p,e,65536)){
        case .ok(_):{assert(false);}case .err(e):{
            assert(code(e.kind)==1 && e.diagnostic.code.kind==3 && e.diagnostic.at.source==0);
            assert(e.diagnostic.at.start<source.len && e.diagnostic.at.end<=source.len);
        }
    };
}
@test fn void runtime_fuel_and_arithmetic_failures_keep_the_admitted_project_reusable(){
    let programs::Program p=kept(b"module app;pub fn i32 start(){return 42;}",b"module lib;",false);
    switch(programs::run(ref p,1)){case .ok(_):{assert(false);}case .err(e):{assert(code(e.kind)==3 && e.diagnostic.code.kind==8);}};
    result(ref p,2,42);
    let programs::Program failure=kept(
        b"module app;import lib as m;pub fn i32 start(){return m::divide(0);}",
        b"module lib;pub fn i32 divide(i32 n){return 42/n;}",false);
    switch(programs::run(ref failure,16000000)){case .ok(_):{assert(false);}case .err(e):{
        assert(code(e.kind)==3 && e.diagnostic.code.kind==7 && e.diagnostic.at.source==0);
        assert(switch(sources::view(programs::snapshot(ref failure),e.diagnostic.at)){
            case .ok(v):{bytes::equal(v,b"/")}case .err(_):{false}
        });
    }};
}
@test fn void admitted_literals_and_shared_byte_results_execute_through_project_ownership(){
    let programs::Program p=kept(b"module app;import lib as m;pub fn i32 start(){return m::data()[0] as i32;}",
        b"module lib;pub fn ref u8[] data(){return b\"*\";}",false);
    assert(programs::profile(ref p)==8);result(ref p,16000000,42);
}
fn void depth(usize n,bool retained,bool pass){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module app;import lib as m;pub fn i32 start(){");
    if(retained){append(ref mut source,b"let ref u8[] marker=b\"*\";");}append(ref mut source,b"return ");
    var usize i=0;while(i<n){append(ref mut source,b"m::id(");i+=1;}append(ref mut source,b"42");
    i=0;while(i<n){append(ref mut source,b")");i+=1;}append(ref mut source,b";}");
    let ref u8[] library=b"module lib;pub fn i32 id(i32 x){return x;}";
    if(pass){
        let programs::Program p=kept(bytes::view(ref source),library,false);result(ref p,16000000,42);
    }else{
            let project::Project p=metadata(false);let entries::Entry e=selected(ref p,bytes::view(ref source),library);
        switch(programs::compile(p,e,65536)){
            case .ok(_):{assert(false);}case .err(e):{
                assert(code(e.kind)==1 && e.diagnostic.code.kind==4 && e.diagnostic.at.source==1);
            }
        };
    }
}
@test fn void project_ownership_keeps_32_deep_legacy_and_retained_calls_without_stack_overrides(){
    depth(32,false,true);depth(32,true,true);depth(33,false,false);depth(33,true,false);
}

