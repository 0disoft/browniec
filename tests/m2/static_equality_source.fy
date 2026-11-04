module tests::m2::static_equality_source;
import compiler as compiler;
import program_image as programs;
import static_image as images;
import slice_result_ir as ir;
import ir as ordinary;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import errors as errors;

fn Result<execution::Scalar,errors::Error> run(ref programs::Program p,usize fuel,usize backing){
    var runtime::State state=runtime::empty(backing);var u8[64] data=[0;64];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let ref ir::Program code=programs::code(p);let ref ordinary::Program body=ref code.body;
    let Result<execution::Scalar,errors::Error> result=programs::run_scalar(p,body.entry,
        ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data[..backing],fuel);
    assert(state.runtime.authority.depth==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}return result;
}
fn void value(ref u8[] source,i64 expected){
    let programs::Program p=switch(compiler::compile_image(source,8192)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(run(ref p,16000000,64)){case .ok(v):{assert(v.value==expected);}case .err(_):{assert(false);}};
}
fn void rejected(ref u8[] source){assert(!compiler::compile_image(source,8192).is_ok);}
fn void code_error(ref u8[] source,u8 kind){
    switch(compiler::compile_image(source,8192)){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){
            case .Code:{assert(e.code.kind==kind);}case .Literal:{assert(false);}
        }}
    };
}
@test fn void immutable_byte_equality_covers_contents_kinds_and_named_view_liveness(){
    value(b"module main;fn i32 main(){if(text::equal(b\"abc\",b\"abc\")){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){if(text::equal(b\"abc\",b\"abd\")){return 0;}return 42;}",42);
    value(b"module main;fn i32 main(){if(text::equal(b\"\",b\"\")){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){if(text::equal(b\"a\",b\"\")){return 0;}return 42;}",42);
    value(b"module main;fn i32 main(){if(text::equal(b\"\\0\\xFF\",b\"\\0\\xFF\")){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){let ref u8[] a=b\"*\";let bool same=text::equal(a,ref a);if(same){return a[0] as i32;}return 0;}",42);
    value(b"module main;fn i32 main(){let ref str t=\"한\";if(text::equal(text::bytes(t),b\"\\xED\\x95\\x9C\")){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){if(text::equal(text::bytes(\"\"),b\"\")){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){if(text::equal((b\"*\"),(b\"*\"))){return 42;}return 0;}",42);
}

@test fn void equality_reuses_static_sites_across_loops_short_circuit_and_scalar_calls(){
    value(b"module main;fn i32 main(){if(false && text::equal(b\"*\",b\"*\")){return 0;}if(true || text::equal(b\"a\",b\"b\")){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){var i32 n=0;for(var bool go=true;go;go=text::equal(b\"A\",b\"B\")){n=n+42;}return n;}",42);
    value(b"module main;fn i32 main(){for(var bool go=true;go;go=text::equal(b\"A\",b\"B\")){return 42;}return 0;}",42);
    value(b"module main;fn bool eq(){return text::equal(b\"*\",b\"*\");}fn i32 main(){let ref u8[] a=b\"*\";if(eq() && text::equal(a,a)){return a[0] as i32;}return 0;}",42);
    value(b"module main;fn i32 main(){let ref str text=\"*\";var i32 n=0;var usize i=0;while(i<3){if(text::equal(text::bytes(text),b\"*\")){n=n+14;}i=i+1;}return n;}",42);
}

fn void exact(ref u8[] source,usize work,usize image_quota,usize payload){
    let programs::Program p=switch(compiler::compile_image(source,image_quota)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(images::payload_bytes(programs::literals(ref p))==payload);
    let usize price=runtime::cost()+runtime::leave_cost()+work;
    switch(run(ref p,price-1,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run(ref p,price,0)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run(ref p,price+1,0)){case .ok(v):{assert(v.value==42 && v.remaining==1);}case .err(_):{assert(false);}};
}
@test fn void source_equality_precharges_full_lengths_with_exact_invocation_fuel(){
    exact(b"module main;fn i32 main(){if(text::equal(b\"*\",b\"*\")){return 42;}return 0;}",58,577,1);
    exact(b"module main;fn i32 main(){if(text::equal(b\"abc\",b\"xbc\")){return 0;}return 42;}",62,582,6);
    exact(b"module main;fn i32 main(){if(text::equal(b\"\",b\"\")){return 42;}return 0;}",56,576,0);
}

@test fn void equality_signature_requires_two_bytes_views_and_keeps_public_admission_gated(){
    code_error(b"module main;fn i32 main(){if(text::equal(\"a\",b\"a\")){return 42;}return 0;}",3);
    code_error(b"module main;fn i32 main(){if(text::equal(b\"a\",\"a\")){return 42;}return 0;}",3);
    code_error(b"module main;fn i32 main(){let ref str t=\"a\";if(text::equal(t,t)){return 42;}return 0;}",3);
    code_error(b"module main;fn i32 main(){if(text::equal(42,b\"a\")){return 42;}return 0;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"a\";if(text::equal(text::bytes(a),a)){return 42;}return 0;}",3);
    code_error(b"module main;fn i32 main(){let u8[1] raw=[42;1];let ref u8[] a=ref raw;if(text::equal(a,a)){return 42;}return 0;}",3);
    rejected(b"module main;fn i32 main(){if(text::equal()){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){if(text::equal(b\"a\")){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){if(text::equal(b\"a\",b\"a\",b\"a\")){return 42;}return 0;}");
    assert(!compiler::compile(b"module main;fn i32 main(){if(text::equal(b\"a\",b\"a\")){return 42;}return 0;}").is_ok);
}

@test fn void converted_arguments_share_the_existing_global_static_site_limit(){
    value(b"module main;fn i32 main(){let ref str t=\"*\";let bool same0=text::equal(text::bytes(t),text::bytes(t));let bool same1=text::equal(text::bytes(t),text::bytes(t));let bool same2=text::equal(text::bytes(t),text::bytes(t));let bool same3=text::equal(text::bytes(t),text::bytes(t));let bool same4=text::equal(text::bytes(t),text::bytes(t));let bool same5=text::equal(text::bytes(t),text::bytes(t));let bool same6=text::equal(text::bytes(t),text::bytes(t));let ref str alias=t;if(same6){return 42;}return 0;}",42);
    code_error(b"module main;fn i32 main(){let ref str t=\"*\";let bool same0=text::equal(text::bytes(t),text::bytes(t));let bool same1=text::equal(text::bytes(t),text::bytes(t));let bool same2=text::equal(text::bytes(t),text::bytes(t));let bool same3=text::equal(text::bytes(t),text::bytes(t));let bool same4=text::equal(text::bytes(t),text::bytes(t));let bool same5=text::equal(text::bytes(t),text::bytes(t));let bool same6=text::equal(text::bytes(t),text::bytes(t));let bool same7=text::equal(text::bytes(t),text::bytes(t));return 42;}",4);
}
