module tests::m2::array_call_assignment;

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
fn void result_assignment_preserves_destination_storage_and_parameter_independence() {
    result(b"module main;fn i32[2] make(i32 n){return [n;2];}fn i32 main(){var i32[2] a=[0;2];a=make(21);return a[0]+a[1];}",16);
    result(b"module main;fn i32[1] id(i32[1] a){return a;}fn i32 main(){var i32[1] a=[42;1];a=id(a);return a[0];}",12);
    result(b"module main;fn bool[4096] make(){return [true;4096];}fn i32 main(){var bool[4096] a=[false;4096];a=make();if(a[4095]){return 42;}return 0;}",8192);
    result(b"module main;fn i32[1] make(){return [42;1];}fn i32[1] f(){var i32[1] a=[0;1];a=make();return a;}fn i32 main(){let i32[1] a=f();return a[0];}",8);
}
@test
fn void assignments_evaluate_captures_and_later_effects_before_copying() {
    result(b"module main;fn i32[1] f(i32[1] before,i32 n,i32[1] after){return [before[0]*10+n+after[0];1];}fn i32 main(){var i32[1] a=[2;1];let Option<i32> o=.none;a=f(a,switch(o){case .some(v):{v}case .none:{a[0]=4;18}},a);return a[0];}",24);
    result(b"module main;fn i32[1] f(){return [42;1];}fn i32 main(){var i32[1] a=[0;1];var i32 n=0;while(n<42){a=f();if(a[0]!=42){return 0;}n=n+1;}return n;}",8);
}
@test
fn void argument_early_exits_release_captures_and_keep_pending_results_dead() {
    result(b"module main;fn i32[1] take(i32[1] a,i32 n){return a;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;a=take(a,switch(o){case .some(v):{v}case .none:{return 42;}});return 0;}",8);
    result(b"module main;fn i32[1] take(i32[1] a,i32 n){return a;}fn i32 main(){var i32[1] a=[0;1];var i32 n=0;while(n<42){let Option<i32> o=.none;a=take(a,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return n;}",8);
    result(b"module main;fn i32[1] take(i32[1] a,i32 n){return a;}fn Option<i32> f(Option<i32> x){var i32[1] a=[42;1];a=take(a,x?);return .some(a[0]);}fn i32 main(){var i32 n=0;while(n<42){switch(f(.none)){case .some(v):{return 0;}case .none:{n=n+1;}}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",12);
}
@test
fn void exact_fuel_quota_and_independent_verifier_cover_temporary_lifetimes() {
    let ir::Program p=compiled(b"module main;fn i32[1] f(){return [42;1];}fn i32 main(){var i32[1] a=[0;1];a=f();return a[0];}");
    assert(switch(vm::run_with_array_limit(ref p,435,8)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,434,8)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=38){pc+=1;}
    assert(pc<p.count);let usize temporary=p.code[pc*8+2] as usize;
    assert(p.code[(pc+1)*8]==37 && p.code[(pc+1)*8+1] as usize==temporary);
    var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
    assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok);
    assert(!verifier::verify(ref bad).is_ok);
}
