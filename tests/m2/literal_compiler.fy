module tests::m2::literal_compiler;
import compiler as compiler;
import program_image as programs;
import static_image as images;
import literal_collection as collection;
import slice_result_ir as ir;
import ir as ordinary;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import errors as errors;
import std::bytes as bytes;

fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<execution::Scalar,errors::Error> run(ref programs::Program p,usize fuel){
    var runtime::State state=runtime::empty(0);var u8[1] data=[0];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let ref ir::Program code=programs::code(p);let ref ordinary::Program body=ref code.body;
    let Result<execution::Scalar,errors::Error> result=programs::run_scalar(p,body.entry,
        ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data[..0],fuel);
    drained(ref state);return result;
}
fn void value(ref u8[] source,i64 expected){
    let programs::Program p=switch(compiler::compile_image(source,8192)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(run(ref p,1000000)){case .ok(v):{assert(v.value==expected);}case .err(_):{assert(false);}};
}
fn void source_error(ref u8[] source,u8 kind){
    switch(compiler::compile_image(source,8192)){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){
            case .Code:{assert(e.code.kind==kind);}case .Literal:{assert(false);}
        }}
    };
}
fn bool quota(images::Error e){return switch(e){
    case .Quota:{true}case .State:{false}case .Limit:{false}case .Literals:{false}
    case .Utf8:{false}case .Kind:{false}case .Bounds:{false}case .Allocation:{false}case .Provider:{false}
};}

@test fn void source_byte_projection_executes_with_exact_fuel_and_no_guest_backing(){
    let programs::Program p=switch(compiler::compile_image(b"module main;fn i32 main(){return b\"\\x2A\"[0] as i32;}",577)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(images::payload_bytes(programs::literals(ref p))==1);
    let usize exact=runtime::cost()+runtime::leave_cost()+39;
    switch(run(ref p,exact)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run(ref p,exact-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run(ref p,exact+1)){case .ok(v):{assert(v.value==42 && v.remaining==1);}case .err(_):{assert(false);}};
}

@test fn void computed_indices_calls_and_loop_reentry_use_the_same_static_sites(){
    value(b"module main;fn i32 main(){var i32 total=0;for(var usize i=0;i<3;i=i+(b\"\\x01\"[0] as usize)){total=total+14;}return total;}",42);
    value(b"module main;fn usize index(){return 1;}fn i32 main(){return b\"\\0*\"[index()] as i32;}",42);
    value(b"module main;fn i32 main(){var usize i=0;var i32 total=0;while(i<3){total=total+(b\"\\x0E\"[0] as i32);i=i+1;}return total;}",42);
    value(b"module main;fn i32 main(){return b\"\\xFF\"[0] as i32;}",255);
}

@test fn void explicit_text_bytes_projects_cooked_utf8_and_byte_lengths(){
    value(b"module main;fn i32 main(){if(text::bytes(\"\\u{D55C}\").len==3){return text::bytes(\"한\")[0] as i32;}return 0;}",237);
    value(b"module main;fn i32 main(){if(b\"\".len==0) {return 42;}return 0;}",42);
}

@test fn void source_spelling_dedup_retains_one_exact_used_prefix(){
    let programs::Program p=switch(compiler::compile_image(b"module main;fn i32 main(){let i32 a=b\"A\"[0] as i32;return a+(b\"\\x41\"[0] as i32)-88;}",577)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(images::payload_bytes(programs::literals(ref p))==1);
    switch(run(ref p,1000000)){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
}

@test fn void byte_bounds_follow_complete_read_precharge_and_image_quota_is_separate(){
    let programs::Program p=switch(compiler::compile_image(b"module main;fn i32 main(){return b\"*\"[1] as i32;}",577)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(run(ref p,runtime::cost()+35)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run(ref p,runtime::cost()+36)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}};
    switch(compiler::compile_image(b"module main;fn i32 main(){return b\"*\"[1] as i32;}",576)){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){
            case .Code:{assert(false);}case .Literal:{assert(quota(e.literal));}
        }}
    };
    source_error(b"module main;fn i32 main(){return b\"\\q\"[0] as i32;}",1);
    source_error(b"module main;fn i32 main(){return text::bytes(\"\\xFF\")[0] as i32;}",1);
    source_error(b"module main;fn i32 main(){let i32 i=0;return b\"*\"[i] as i32;}",3);
    source_error(b"module main;fn i32 main(){return text::bytes(b\"*\")[0] as i32;}",3);
    source_error(b"module main;fn ref u8[] f(ref u8[] a){return ref a;}fn i32 main(){return 42;}",3);
}

fn void unchanged(ref images::Builder a,ref images::Builder b){
    let ref u8[] x=ref a.data;let ref u8[] y=ref b.data;assert(bytes::equal(x,y));
    assert(a.limit==b.limit && a.catalog.count==b.catalog.count && a.catalog.used==b.catalog.used);
    var usize i=0;while(i<16){assert(a.catalog.starts[i]==b.catalog.starts[i] &&
        a.catalog.ends[i]==b.catalog.ends[i] && a.catalog.text[i]==b.catalog.text[i]);i+=1;}
}
@test fn void whole_literal_collection_rolls_back_lexical_and_image_failures(){
    var images::Builder b=switch(images::builder(16)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(images::intern_bytes(ref mut b,b"seed")){case .ok(_):{}case .err(_):{assert(false);}};
    let images::Builder before=b;
    switch(collection::collect(ref mut b,b"b\"ok\" b\"\\q\"")){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){
            case .Source:{assert(e.source.kind==1);}case .Image:{assert(false);}
        }}
    };
    unchanged(ref b,ref before);
    var images::Builder small=switch(images::builder(4)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(images::intern_bytes(ref mut small,b"seed")){case .ok(_):{}case .err(_):{assert(false);}};
    let images::Builder old=small;
    switch(collection::collect(ref mut small,b"b\"x\"")){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){
            case .Source:{assert(false);}case .Image:{assert(quota(e.image));}
        }}
    };unchanged(ref small,ref old);
}

@test fn void occurrence_and_ir_site_bounds_are_distinct_and_preserve_existing_limits(){
    value(b"module main;fn i32 main(){let u8 a0=b\"*\"[0];let u8 a1=b\"*\"[0];let u8 a2=b\"*\"[0];let u8 a3=b\"*\"[0];let u8 a4=b\"*\"[0];let u8 a5=b\"*\"[0];let u8 a6=b\"*\"[0];let u8 a7=b\"*\"[0];let u8 a8=b\"*\"[0];let u8 a9=b\"*\"[0];let u8 a10=b\"*\"[0];let u8 a11=b\"*\"[0];let u8 a12=b\"*\"[0];let u8 a13=b\"*\"[0];let u8 a14=b\"*\"[0];let u8 a15=b\"*\"[0];return 42;}",42);
    source_error(b"module main;fn i32 main(){let u8 a0=b\"*\"[0];let u8 a1=b\"*\"[0];let u8 a2=b\"*\"[0];let u8 a3=b\"*\"[0];let u8 a4=b\"*\"[0];let u8 a5=b\"*\"[0];let u8 a6=b\"*\"[0];let u8 a7=b\"*\"[0];let u8 a8=b\"*\"[0];let u8 a9=b\"*\"[0];let u8 a10=b\"*\"[0];let u8 a11=b\"*\"[0];let u8 a12=b\"*\"[0];let u8 a13=b\"*\"[0];let u8 a14=b\"*\"[0];let u8 a15=b\"*\"[0];let u8 a16=b\"*\"[0];return 42;}",4);
    source_error(b"module main;fn i32 main(){let u8 a0=text::bytes(\"*\")[0];let u8 a1=text::bytes(\"*\")[0];let u8 a2=text::bytes(\"*\")[0];let u8 a3=text::bytes(\"*\")[0];let u8 a4=text::bytes(\"*\")[0];let u8 a5=text::bytes(\"*\")[0];let u8 a6=text::bytes(\"*\")[0];let u8 a7=text::bytes(\"*\")[0];let u8 a8=text::bytes(\"*\")[0];return 42;}",4);
}

@test fn void ordinary_compilation_keeps_literal_execution_and_text_values_gated(){
    switch(compiler::compile(b"module main;fn i32 main(){return b\"*\"[0] as i32;}")){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==2);}
    };
    switch(compiler::compile(b"module main;fn i32 main(){return text::bytes(\"*\")[0] as i32;}")){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==2);}
    };
}
