module tests::m2::array_return_literals;

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
fn void repeated_return_fills_once_and_context_types_the_scalar() {
    result(b"module main;fn i32[2] f(){var i32 n=20;let Option<i32> o=.none;return [switch(o){case .some(v):{v}case .none:{n=n+1;n}};2];}fn i32 main(){let i32[2] a=f();return a[0]+a[1];}",8);
    result(b"module main;fn bool[4096] f(){return [true;4096];}fn i32 main(){let bool[4096] a=f();if(a[4095]){return 42;}return 0;}",4096);
    result(b"module main;fn i64[4096] f(){return [-9223372036854775808;4096];}fn i32 main(){let i64[4096] a=f();if(a[4095]==-9223372036854775808){return 42;}return 0;}",32768);
}
@test
fn void cleanup_preserves_parameter_values_and_reclaims_literal_results_on_loops() {
    result(b"module main;fn i32[1] f(i32[1] a){let i32[1] scratch=[0;1];return [a[0];1];}fn i32 main(){let i32[1] a=[42;1];var i32[1] b=f(a);b[0]=0;return a[0];}",16);
    result(b"module main;fn i32[1] f(){let i32[1] scratch=[0;1];return [42;1];}fn i32 main(){var i32 n=0;while(n<42){let i32[1] a=f();if(a[0]!=42){return 0;}n=n+1;}return n;}",8);
    result(b"module main;fn i32 take(i32[1] a,i32 n){return n;}fn i32[1] f(){var i32[1] a=[0;1];let Option<i32> o=.none;let i32 unused=take(a,switch(o){case .some(v):{v}case .none:{return [42;1];}});return [42;1];}fn i32 main(){let i32[1] a=f();return a[0];}",12);
}
@test
fn void filler_early_returns_and_loop_exits_do_not_create_a_pending_owner() {
    result(b"module main;fn i32[1] f(){let Option<i32> o=.none;return [switch(o){case .some(v):{v}case .none:{return [42;1];}};1];}fn i32 main(){let i32[1] a=f();return a[0];}",4);
    result(b"module main;fn i32[1] f(){var i32 n=0;while(n<42){var i32[1] a=[0;1];let Option<i32> o=.none;return [switch(o){case .some(v):{v}case .none:{n=n+1;continue;}};1];}return [n;1];}fn i32 main(){let i32[1] a=f();return a[0];}",4);
    result(b"module main;fn i32[1] f(){while(true){let i32[1] a=[0;1];let Option<i32> o=.none;return [switch(o){case .some(v):{v}case .none:{break;}};1];}return [42;1];}fn i32 main(){let i32[1] a=f();return a[0];}",4);
}
@test
fn void literals_mix_with_named_and_direct_returns_at_existing_fuel_and_frame_limits() {
    result(b"module main;fn i32[1] f(i32 n){if(n==0){return [42;1];}return f(n-1);}fn i32 main(){let i32[1] a=f(30);return a[0];}",4);
    result(b"module main;fn i32[1] f(bool take){if(take){return [42;1];}let i32[1] a=[42;1];return a;}fn i32 main(){let i32[1] a=f(true);let i32[1] b=f(false);return a[0]+b[0]-42;}",8);
    let ir::Program p=compiled(b"module main;fn i32[1] f(){return [42;1];}fn i32 main(){let i32[1] a=f();return a[0];}");
    assert(switch(vm::run_with_array_limit(ref p,228,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,227,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
