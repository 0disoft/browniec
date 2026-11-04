module tests::m2::static_ranges_source;
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
fn void trapped(ref u8[] source,u8 kind){
    let programs::Program p=switch(compiler::compile_image(source,8192)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(run(ref p,16000000,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}};
}
fn void exact(ref u8[] source,usize work,i64 expected){
    let programs::Program p=switch(compiler::compile_image(source,8192)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize budget=runtime::cost()+runtime::leave_cost()+work;
    switch(run(ref p,budget-1,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run(ref p,budget,0)){case .ok(v):{assert(v.value==expected && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run(ref p,budget+1,0)){case .ok(v):{assert(v.value==expected && v.remaining==1);}case .err(_):{assert(false);}};
}
@test fn void ranges_lower_literals_named_views_conversions_and_computed_endpoints(){
    value(b"module main;fn usize lo(){return 1;}fn usize hi(){return 2;}fn i32 main(){let ref u8[] a=b\"x*y\";let ref u8[] b=ref a[lo()..hi()];return b[0] as i32;}",42);
    value(b"module main;fn i32 main(){return b\"x*y\"[1..2][0] as i32;}",42);
    value(b"module main;fn i32 main(){return text::bytes(\"x*\")[1..][0] as i32;}",42);
    value(b"module main;fn i32 main(){return ((b\"x*y\")[1..2])[0] as i32;}",42);
    value(b"module main;fn i32 main(){let ref u8[] a=b\"x*y\";let ref u8[] b=(a[1..])[..1];let ref u8[] c=b;return c[0] as i32;}",42);
    value(b"module main;fn i32 main(){let ref str t=\"*\";let ref u8[] b=text::bytes((t))[..];return (b)[0] as i32;}",42);
    value(b"module main;fn i32 main(){if(b\"\"[..].len==0){return 42;}return 0;}",42);
}

@test fn void range_equality_compares_actual_spans_and_keeps_named_arguments_live(){
    value(b"module main;fn i32 main(){let ref u8[] a=b\"x*y\";if(text::equal(a[1..2],b\"*\")){return a[1] as i32;}return 0;}",42);
    value(b"module main;fn i32 main(){if(text::equal((b\"x*\")[1..],text::bytes(\"*\")[..])){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){if(text::equal(b\"x*\"[1..],b\"x*\"[..])){return 0;}return 42;}",42);
    value(b"module main;fn i32 main(){if(text::equal(b\"\"[..],b\"x\"[1..])){return 42;}return 0;}",42);
}

@test fn void both_endpoints_retain_owned_parents_through_early_returns(){
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let ref u8[] a=b\"*\"[switch(o){case .some(v):{0}case .none:{return 42;}}..1];return a[0] as i32;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let ref u8[] a=text::bytes(\"*\")[0..switch(o){case .some(v):{1}case .none:{return 42;}}];return a[0] as i32;}",42);
    value(b"module main;fn i32 main(){let ref u8[] a=b\"*\";let Option<i32> o=.none;return a[0..switch(o){case .some(v):{1}case .none:{return 42;}}][0] as i32;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;return b\"x*\"[1..][0..switch(o){case .some(v):{1}case .none:{return 42;}}][0] as i32;}",42);
}

@test fn void equality_retains_the_left_temporary_through_right_endpoint_exits(){
    value(b"module main;fn i32 main(){let Option<i32> o=.none;if(text::equal(b\"*\",b\"*\"[switch(o){case .some(v):{0}case .none:{return 42;}}..1])){return 0;}return 0;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;if(text::equal(b\"x*\"[1..],text::bytes(\"*\")[0..switch(o){case .some(v):{1}case .none:{return 42;}}])){return 0;}return 0;}",42);
}

@test fn void propagation_cleans_range_parents_and_pending_equality_arguments(){
    value(b"module main;fn Option<i32> f(Option<i32> o){let ref u8[] a=b\"*\"[0..switch(o){case .some(v):{1}case .none:{let i32 n=o?;1}}];return .some(a[0] as i32);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{return 42;}}}",42);
    value(b"module main;fn Option<i32> f(Option<i32> o){if(text::equal(b\"*\",b\"*\"[0..switch(o){case .some(v):{1}case .none:{let i32 n=o?;1}}])){return .some(0);}return .some(0);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{return 42;}}}",42);
}

@test fn void loop_transfers_close_only_pending_views_and_preserve_outer_bindings(){
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let ref str t=\"*\";var i32 n=0;while(n<2){let ref u8[] a=text::bytes(t)[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}..1];}return n+40;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;while(true){if(text::equal(b\"*\",b\"*\"[0..switch(o){case .some(v):{1}case .none:{break;}}])){return 0;}}return 42;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;var i32 n=0;while(n<2){if(text::equal(b\"*\",b\"*\"[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}..1])){return 0;}}return n+40;}",42);
}

@test fn void ranges_reenter_with_new_endpoints_and_preserve_recursive_frame_words(){
    value(b"module main;fn i32 main(){let ref u8[] a=b\"\\x14\\x16\";var usize i=0;var i32 n=0;while(i<2){let ref u8[] b=a[i..i+1];n=n+(b[0] as i32);i=i+1;}return n;}",42);
    value(b"module main;fn i32 main(){var i32 n=0;for(var usize i=0;i<2;i=i+(b\"\\x01\"[..][0] as usize)){n=n+21;}return n;}",42);
    value(b"module main;fn i32 f(usize i){let ref u8[] a=b\"\\x14\\x16\";let ref u8[] b=a[i..i+1];if(i==1){let i32 n=f(0);}return b[0] as i32;}fn i32 main(){return f(1)+20;}",42);
}

@test fn void ranges_and_dynamic_equality_have_exact_whole_invocation_fuel(){
    exact(b"module main;fn i32 main(){return b\"x*\"[1..2][0] as i32;}",170,42);
    exact(b"module main;fn i32 main(){if(b\"\"[..].len==0){return 42;}return 0;}",187,42);
    exact(b"module main;fn i32 main(){if(text::equal(b\"x*\"[1..2],b\"*\")){return 42;}return 0;}",189,42);
}

@test fn void guest_bounds_are_relative_and_invalid_programs_do_not_gain_public_admission(){
    trapped(b"module main;fn i32 main(){return b\"x*\"[1..2][1] as i32;}",14);
    trapped(b"module main;fn i32 main(){return b\"x*\"[1..2][0..2][0] as i32;}",14);
    trapped(b"module main;fn i32 main(){return b\"x*\"[2..1][0] as i32;}",14);
    trapped(b"module main;fn i32 main(){return b\"x*\"[0..3][0] as i32;}",14);
    code_error(b"module main;fn i32 main(){let ref str t=\"*\";let ref u8[] a=t[..];return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\"[true..1];return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\"[0..false];return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref str a=b\"*\"[..];return 42;}",3);
    code_error(b"module main;fn i32 main(){let ref u8[] a=b\"*\"[-1..1];return 42;}",3);
    value(b"module main;fn i32 main(){return b\"*\"[..][..][..][..][..][..][..][..][..][..][..][..][..][..][..][0] as i32;}",42);
    code_error(b"module main;fn i32 main(){return b\"*\"[..][..][..][..][..][..][..][..][..][..][..][..][..][..][..][..][0] as i32;}",4);
}

@test fn void member_dots_and_nested_reads_are_not_range_delimiters(){
    value(b"module main;fn i32 main(){let ref u8[] a=b\"x*\";return a[a.len-1..][0] as i32;}",42);
    value(b"module main;fn i32 main(){return b\"x*\"[b\"x\".len..][0] as i32;}",42);
    value(b"module main;fn i32 main(){return b\"x*\"[b\"x\"[..].len..][0] as i32;}",42);
    trapped(b"module main;fn i32 main(){return b\"*\"[0/0..1][0] as i32;}",7);
    trapped(b"module main;fn i32 main(){return b\"*\"[99..1/0][0] as i32;}",7);
}

@test fn void source_range_syntax_keeps_the_ordinary_public_compiler_gate(){
    assert(!compiler::compile(b"module main;fn i32 main(){return b\"*\"[..][0] as i32;}").is_ok);
}
