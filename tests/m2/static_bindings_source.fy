module tests::m2::static_bindings_source;
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
@test fn void byte_and_text_locals_aliases_and_explicit_conversion_preserve_kinds(){
    value(b"module main;fn i32 main(){let ref u8[] a=b\"*\";let ref u8[] b=a;return b[0] as i32;}",42);
    value(b"module main;fn i32 main(){let ref str t=\"한\";let ref str alias=ref t;let ref u8[] b=text::bytes(alias);if(b.len==3){return b[0] as i32;}return 0;}",237);
    value(b"module main;fn i32 main(){let ref str text=\"*\";return text::bytes(text)[0] as i32;}",42);
    value(b"module main;fn i32 main(){let ref str t=\"\";if(text::bytes(t).len==0){return 42;}return 0;}",42);
}

@test fn void scopes_value_arms_and_loop_transfers_close_only_their_static_suffix(){
    value(b"module main;fn i32 main(){let ref u8[] a=b\"*\";{let ref u8[] b=ref a;let i32 n=b[0] as i32;}return a[0] as i32;}",42);
    value(b"module main;fn i32 main(){let ref u8[] a=b\"\\x0E\";var usize i=0;var i32 n=0;while(i<4){let ref u8[] b=a;i=i+1;if(i==1){continue;}n=n+(b[0] as i32);if(i==4){break;}}return n;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;return switch(o){case .some(v):{0}case .none:{let ref str t=\"*\";text::bytes(t)[0] as i32}};}",42);
}

@test fn void owned_projection_temporaries_survive_index_exits_without_leaking(){
    value(b"module main;fn i32 main(){let ref str t=\"*\";let Option<i32> o=.none;return text::bytes(t)[switch(o){case .some(v):{0}case .none:{return 42;}}] as i32;}",42);
    value(b"module main;fn i32 main(){let ref str t=\"*\";let Option<i32> o=.none;var i32 n=0;while(n<2){let i32 x=text::bytes(t)[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}] as i32;}return n+40;}",42);
    value(b"module main;fn i32 main(){let ref str t=\"*\";let Option<i32> o=.none;while(true){let i32 x=text::bytes(t)[switch(o){case .some(v):{0}case .none:{break;}}] as i32;}return 42;}",42);
    value(b"module main;fn Option<i32> f(Option<i32> o){let ref str t=\"*\";return .some(text::bytes(t)[switch(o){case .some(v):{0}case .none:{let i32 n=o?;0}}] as i32);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{return 42;}}}",42);
}

@test fn void aggregate_returns_close_static_locals_and_existing_runtime_slices_stay_distinct(){
    value(b"module main;fn u8[1] make(){let ref str t=\"*\";let u8[1] a=[text::bytes(t)[0];1];return a;}fn i32 main(){let u8[1] a=make();return a[0] as i32;}",42);
    value(b"module main;struct R{i32 x;}fn R make(){let ref str t=\"*\";let R r=R{.x=text::bytes(t)[0] as i32};return r;}fn i32 main(){let R r=make();return r.x;}",42);
    value(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] b=ref a;return b[0] as i32;}",42);
}

@test fn void static_binding_fuel_is_exact_and_bounds_fail_after_precharge(){
    let programs::Program p=switch(compiler::compile_image(b"module main;fn i32 main(){let ref u8[] a=b\"*\";let ref u8[] b=a;return b[0] as i32;}",577)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(images::payload_bytes(programs::literals(ref p))==1);
    let usize exact=runtime::cost()+runtime::leave_cost()+57;
    switch(run(ref p,exact-1,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run(ref p,exact,0)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run(ref p,exact+1,0)){case .ok(v):{assert(v.value==42 && v.remaining==1);}case .err(_):{assert(false);}};
    let programs::Program empty=switch(compiler::compile_image(b"module main;fn i32 main(){let ref str t=\"\";return text::bytes(t)[0] as i32;}",576)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(run(ref empty,16000000,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}};
}

@test fn void static_types_lifetimes_and_public_admission_remain_independent(){
    code_error(b"module main;fn i32 main(){let ref str t=b\"*\";return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref str t=\"*\";let ref u8[] a=t;return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\";let ref str t=a;return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\";return text::bytes(a)[0] as i32;}",3);
    code_error(b"module main;fn i32 main(){let ref str t=\"*\";return t[0] as i32;}",3);
    code_error(b"module main;fn i32 main(){let ref str t=\"*\";return t.len as i32;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\";a[0]=0;return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\";a=b\"*\";return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\";let ref u8[] a=b\"*\";return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref str a=a;return 42;}",3);
    code_error(b"module main;fn i32 main(){{let ref u8[] a=b\"*\";}return a[0] as i32;}",3);
    rejected(b"module main;fn i32 main(){var ref str t=\"*\";return 42;}");
    rejected(b"module main;fn i32 main(){let ref mut u8[] a=b\"*\";return 42;}");
    rejected(b"module main;fn i32 main(){let ref str t=\"*\" return 42;}");
    rejected(b"module main;fn ref str text(){return \"*\";}fn i32 main(){return 42;}");
    assert(!compiler::compile(b"module main;fn i32 main(){let ref str t=\"*\";return text::bytes(t)[0] as i32;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){let ref str t=\"\";return text::bytes(t)[0] as i32;}").is_ok);
}

@test fn void all_static_kinds_share_the_sixteen_definition_limit(){
    value(b"module main;fn i32 main(){let ref u8[] a0=b\"*\";let ref u8[] a1=a0;let ref u8[] a2=a1;let ref u8[] a3=a2;let ref u8[] a4=a3;let ref u8[] a5=a4;let ref u8[] a6=a5;let ref u8[] a7=a6;let ref u8[] a8=a7;let ref u8[] a9=a8;let ref u8[] a10=a9;let ref u8[] a11=a10;let ref u8[] a12=a11;let ref u8[] a13=a12;let ref u8[] a14=a13;let ref u8[] a15=a14;return a15[0] as i32;}",42);
    code_error(b"module main;fn i32 main(){let ref u8[] a0=b\"*\";let ref u8[] a1=a0;let ref u8[] a2=a1;let ref u8[] a3=a2;let ref u8[] a4=a3;let ref u8[] a5=a4;let ref u8[] a6=a5;let ref u8[] a7=a6;let ref u8[] a8=a7;let ref u8[] a9=a8;let ref u8[] a10=a9;let ref u8[] a11=a10;let ref u8[] a12=a11;let ref u8[] a13=a12;let ref u8[] a14=a13;let ref u8[] a15=a14;let ref u8[] a16=a15;return 42;}",4);
}
