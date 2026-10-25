module tests::m2::array_return_calls;

import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void result(ref u8[] source,usize limit) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,limit)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void direct_returns_transfer_a_single_payload_across_forward_calls() {
    result(b"module main;fn i32 main(){var i32[2] a=forward(21);a[0]=20;a[1]=22;return a[0]+a[1];}fn i32[2] forward(i32 n){return make(n);}fn i32[2] make(i32 n){let i32[2] a=[n;2];return a;}",8);
    result(b"module main;fn bool[4096] forward(){return make();}fn bool[4096] make(){let bool[4096] a=[true;4096];return a;}fn i32 main(){let bool[4096] a=forward();if(a[4095]){return 42;}return 0;}",4096);
    result(b"module main;fn i64[4096] forward(){return make();}fn i64[4096] make(){let i64[4096] a=[-9223372036854775808;4096];return a;}fn i32 main(){let i64[4096] a=forward();if(a[4095]==-9223372036854775808){return 42;}return 0;}",32768);
}
@test
fn void arguments_keep_order_and_return_cleanup_drops_locals_parameters_and_captures() {
    result(b"module main;fn i32[1] take(i32[1] a,i32 n){return a;}fn i32[1] forward(i32[1] a){let i32[1] scratch=[0;1];return take(a,0);}fn i32 main(){let i32[1] a=[42;1];var i32[1] b=forward(a);b[0]=0;return a[0];}",16);
    result(b"module main;fn i32[1] take(i32[1] before,i32 n,i32[1] after){let i32[1] a=[before[0]*10+n+after[0];1];return a;}fn i32[1] forward(){var i32[1] a=[2;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{a[0]=4;18}},a);}fn i32 main(){let i32[1] a=forward();return a[0];}",24);
    result(b"module main;fn i32[1] make(){let i32[1] a=[42;1];return a;}fn i32[1] forward(){let i32[1] scratch=[0;1];return make();}fn i32 main(){var i32 n=0;while(n<42){let i32[1] a=forward();if(a[0]!=42){return 0;}n=n+1;}return n;}",8);
}
@test
fn void argument_return_and_loop_exits_never_drop_a_pending_return_destination() {
    result(b"module main;fn i32 take(i32[1] a,i32 n){return n;}fn i32[1] make(i32 n){let i32[1] a=[n;1];return a;}fn i32[1] forward(){var i32[1] a=[0;1];let Option<i32> o=.none;return make(take(a,switch(o){case .some(v):{v}case .none:{return make(42);}}));}fn i32 main(){let i32[1] a=forward();return a[0];}",12);
    result(b"module main;fn i32[1] take(i32[1] a,i32 n){return a;}fn i32[1] forward(){var i32 n=0;while(n<42){var i32[1] a=[0;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}let i32[1] a=[n;1];return a;}fn i32 main(){let i32[1] a=forward();return a[0];}",8);
    result(b"module main;fn i32[1] take(i32[1] a,i32 n){return a;}fn i32[1] forward(){while(true){var i32[1] a=[0;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{break;}});}let i32[1] a=[42;1];return a;}fn i32 main(){let i32[1] a=forward();return a[0];}",8);
}
@test
fn void direct_recursive_and_mutual_returns_keep_existing_frames_and_exact_fuel() {
    result(b"module main;fn i32[1] f(i32 n){if(n==0){let i32[1] a=[42;1];return a;}return f(n-1);}fn i32 main(){let i32[1] a=f(30);return a[0];}",4);
    result(b"module main;fn i32 main(){let i32[1] a=f(4);return a[0];}fn i32[1] f(i32 n){if(n==0){let i32[1] a=[42;1];return a;}return g(n-1);}fn i32[1] g(i32 n){return f(n-1);}",4);
    let ir::Program p=compiled(b"module main;fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32[1] g(){return f();}fn i32 main(){let i32[1] a=g();return a[0];}");
    assert(switch(vm::run_with_array_limit(ref p,294,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,293,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
