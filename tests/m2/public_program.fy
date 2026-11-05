module tests::m2::public_program;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import errors as errors;

// Public source admission is intentionally tested through only the retained
// PublicProgram surface. Private compiler/program-image constructors remain in
// the existing focused suites and are used here only for the API-gate group.
fn programs::PublicProgram kept(ref u8[] source,usize image_limit){
    return switch(compiler::compile_program(source,image_limit)){
        case .ok(value):{value}
        case .err(_):{assert(false);return kept(b"module main;fn i32 main(){return 0;}",image_limit);}
    };
}

fn u8 profile(ref programs::PublicProgram program){
    return programs::public_profile(program);
}

fn void result(Result<i64,errors::Error> value,i64 expected){
    switch(value){
        case .ok(actual):{assert(actual==expected);}
        case .err(error):{assert(false);assert(error.kind==0);}
    };
}

fn void failure(Result<i64,errors::Error> value,u8 kind){
    switch(value){
        case .ok(_):{assert(false);}
        case .err(error):{assert(error.kind==kind);}
    };
}

fn void value(ref u8[] source,i64 expected){
    let programs::PublicProgram program=kept(source,65536);
    assert(profile(ref program)==8);
    result(programs::run_public(ref program,16000000),expected);
}

fn void rejected(ref u8[] source){
    switch(compiler::compile_program(source,65536)){
        case .ok(_):{assert(false);}
        case .err(error):{assert(error.kind==1 || error.kind==2 || error.kind==3 ||
            error.kind==4 || error.kind==5);}
    };
}

@test fn void source_routing_keeps_legacy_profiles_and_admits_the_extended_path(){
    let programs::PublicProgram scalar=kept(
        b"module main;fn i32 main(){return 42;}",65536);
    assert(profile(ref scalar)==0);
    let ref ir::Program scalar_body=programs::public_body(ref scalar);
    assert(scalar_body.count!=0 && scalar_body.entry<scalar_body.function_count);
    failure(programs::run_public(ref scalar,1),8);
    result(programs::run_public(ref scalar,2),42);
    result(programs::run_public(ref scalar,256),42);

    let programs::PublicProgram array=kept(
        b"module main;fn i32 main(){let i32[1] a=[42;1];return a[0];}",65536);
    assert(profile(ref array)==1);
    result(programs::run_public(ref array,16000000),42);

    let programs::PublicProgram bytes=kept(
        b"module main;fn i32 main(){return b\"*\"[0] as i32;}",65536);
    assert(profile(ref bytes)==8);
    let ref ir::Program byte_body=programs::public_body(ref bytes);
    assert(byte_body.count!=0 && byte_body.entry<byte_body.function_count);
    result(programs::run_public(ref bytes,16000000),42);

    let programs::PublicProgram declarations=kept(
        b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){return same(ref [42;1])[0] as i32;}",65536);
    assert(profile(ref declarations)==8);
    result(programs::run_public(ref declarations,16000000),42);
}

@test fn void public_literal_text_range_and_equality_views_execute_from_their_image(){
    value(b"module main;fn i32 main(){return b\"*\"[0] as i32;}",42);
    value(b"module main;fn i32 main(){return text::bytes(\"\xED\x95\x9C\")[0] as i32;}",237);
    value(b"module main;fn i32 main(){let ref u8[] text=b\"*42\";let ref u8[] tail=ref text[1..];return tail[0] as i32;}",52);
    value(b"module main;fn i32 main(){if(text::equal(b\"abc\",b\"abc\")){return 42;}return 0;}",42);
}

@test fn void shared_parameters_results_temporary_owners_and_nesting_use_fresh_runs(){
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];return same(ref a)[0] as i32;}",42);
    value(b"module main;fn ref u8[] literal(){return b\"*\";}fn i32 main(){return literal()[0] as i32;}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref a;}fn i32 main(){let ref u8[] selected=pick(ref [42;2],ref [42;2]);var u8[2] unused=[42;2];unused[0]=7;let ref u8[] alias=ref selected;if(alias[1]==42 && unused[0]==7){return 42;}return 0;}",42);
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref b;}fn ref u8[] nested(ref u8[] a,ref u8[] b){return pick(ref a,ref pick(ref b,ref a));}fn i32 main(){let ref u8[] p=nested(ref [42;3],ref b\"*\");var i32 answer=0;{let ref u8[] q=pick(ref b\"!\",ref id(ref p[1..3]));answer=(q[0] as i32)+(q[1] as i32);}if(p[0]==42 && answer==84){return 42;}return 0;}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] empty=same(ref a[1..]);if(empty.len==0){return 42;}return 0;}",42);
}

@test fn void lifetime_drop_write_and_exclusive_violations_fail_before_publication(){
    rejected(b"module main;fn ref u8[] leak(){let u8[1] a=[42;1];return ref a;}fn i32 main(){return 0;}");
    rejected(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=same(ref a);a=[42;1];return p[0] as i32;}");
    rejected(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=same(ref a);a[0]=0;return p[0] as i32;}");
    rejected(b"module main;fn ref mut u8[] exclusive(ref mut u8[] p){return ref mut p;}fn i32 main(){return 0;}");
}

@test fn void retained_source_stays_frozen_after_the_callers_buffer_changes(){
    let ref u8[] original=b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){return same(ref [42;2])[1] as i32;}";
    var u8[256] copy=[0;256];
    assert(original.len<=copy.len);
    var usize i=0;
    while(i<original.len){copy[i]=original[i];i+=1;}
    let programs::PublicProgram program=kept(ref copy[..original.len],65536);
    assert(profile(ref program)==8);
    copy[0]=0;
    copy[original.len-1]=0;
    result(programs::run_public(ref program,16000000),42);
    result(programs::run_public(ref program,16000000),42);
}

@test fn void image_quota_is_exact_and_independent_of_the_public_backing_limit(){
    let ref u8[] one=b"module main;fn i32 main(){return b\"*\"[0] as i32;}";
    switch(compiler::compile_program(one,576)){
        case .ok(_):{assert(false);}
        case .err(error):{assert(error.kind==4);}
    };
    switch(compiler::compile_program(one,577)){
        case .ok(program):{result(programs::run_public(ref program,16000000),42);}
        case .err(_):{assert(false);}
    };
    let ref u8[] empty=b"module main;fn i32 main(){if(b\"\".len==0){return 42;}return 0;}";
    switch(compiler::compile_program(empty,575)){
        case .ok(_):{assert(false);}
        case .err(error):{assert(error.kind==4);}
    };
    switch(compiler::compile_program(empty,576)){
        case .ok(program):{result(programs::run_public(ref program,16000000),42);}
        case .err(_):{assert(false);}
    };
    let programs::PublicProgram standard=kept(
        b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[4096] a=[42;4096];return same(ref a)[4095] as i32;}",65536);
    result(programs::run_public(ref standard,20000000),42);
}

@test fn void missing_wrong_typed_and_mixed_origin_results_are_rejected(){
    rejected(b"module main;fn i32 main(){if(text::equal(b\"a\")){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){if(text::equal(\"a\",b\"a\")){return 42;}return 0;}");
    rejected(b"module main;fn ref u8[] mixed(ref u8[] p,bool choose){if(choose){return ref p;}return b\"*\";}fn i32 main(){return 0;}");
    rejected(b"module main;fn ref u8[] conflicting(ref u8[] a,ref u8[] b,bool choose){if(choose){return ref a;}return ref b;}fn i32 main(){return 0;}");
    rejected(b"module main;fn ref i32[] wrong(ref i32[] p){return ref p;}fn i32 main(){return 0;}");
}

@test fn void private_api_gates_and_native_host_budgets_remain_unchanged(){
    let ref u8[] extended=b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){return same(ref [42;1])[0] as i32;}";
    assert(!compiler::compile(extended).is_ok);
    assert(!compiler::compile_image(extended,65536).is_ok);
    assert(!compiler::compile_references(extended,65536).is_ok);
    assert(compiler::compile_reference_returns(extended,65536).is_ok);

    let ir::Program legacy=switch(compiler::compile(
        b"module main;fn i32 main(){return 42;}")){
        case .ok(value):{value}
        case .err(_):{assert(false);return;}
    };
    failure(vm::run(ref legacy,1),8);
    result(vm::run(ref legacy,2),42);
    result(vm::run(ref legacy,16000001),42);

    let programs::PublicProgram host=kept(
        b"module main;fn i32 main(){return 42;}",65536);
    result(programs::run_public(ref host,16000001),42);
}
