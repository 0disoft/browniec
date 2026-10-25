module tests::m2::array_result_source;

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
fn void named_results_cover_all_scalar_elements_without_a_second_payload() {
    result(b"module main; fn i32[2] f(i32 x){let i32[2] a=[x;2];return a;}fn i32 main(){let i32[2] b=f(21);return b[0]+b[1];}",8);
    result(b"module main; fn bool[4096] f(){let bool[4096] a=[true;4096];return a;}fn i32 main(){let bool[4096] b=f();if(b[4095] && b.len==4096){return 42;}return 0;}",4096);
    result(b"module main; fn u8[1] f(){let u8[1] a=[255;1];return a;}fn i32 main(){let u8[1] b=f();if(b[0]==255){return 42;}return 0;}",1);
    result(b"module main; fn i64[1] f(){let i64[1] a=[-9223372036854775808;1];return a;}fn i32 main(){let i64[1] b=f();if(b[0]==-9223372036854775808){return 42;}return 0;}",8);
    result(b"module main; fn u32[1] f(){let u32[1] a=[4294967295;1];return a;}fn i32 main(){let u32[1] b=f();if(b[0]==4294967295){return 42;}return 0;}",4);
    result(b"module main; fn usize[1] f(){let usize[1] a=[18446744073709551615;1];return a;}fn i32 main(){let usize[1] b=f();if(b[0]==18446744073709551615){return 42;}return 0;}",8);
}
@test
fn void returned_parameter_is_independent_and_destination_controls_mutability() {
    result(b"module main; fn i32[1] f(i32[1] a,i32 n){let i32[1] scratch=[n;1];return a;}fn i32 main(){let i32[1] a=[21;1];var i32[1] b=f(a,0);b[0]=0;let i32[1] c=[21;1];b=c;let i32[1] d=b;return a[0]+d[0];}",16);
    let ir::Program p=compiled(b"module main; fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32 main(){let i32[1] a=f();return a[0];}");
    assert(p.arrays.count==3 && p.array_results[0]!=0);
    assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
@test
fn void forward_recursive_and_mutual_results_keep_separate_frame_bindings() {
    result(b"module main; fn i32 main(){let i32[1] a=f(4);return a[0];}fn i32[1] f(i32 n){if(n==0){let i32[1] a=[42;1];return a;}let i32[1] a=f(n-1);return a;}",4);
    result(b"module main; fn i32 main(){let i32[1] a=f(4);return a[0];}fn i32[1] f(i32 n){if(n==0){let i32[1] a=[42;1];return a;}let i32[1] a=g(n-1);return a;}fn i32[1] g(i32 n){let i32[1] a=f(n-1);return a;}",4);
}
@test
fn void early_argument_exits_release_captures_without_dropping_pending_destinations() {
    result(b"module main; fn i32[1] take(i32[1] a,i32 n){return a;}fn Option<i32> f(Option<i32> x){var i32[1] a=[42;1];let i32[1] b=take(a,x?);return .some(b[0]);}fn i32 main(){var i32 n=0;while(n<42){switch(f(.none)){case .some(v):{return 0;}case .none:{n=n+1;}}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",12);
    result(b"module main; fn i32 take(i32[1] a,i32 n){return n;}fn i32[1] f(){var i32[1] a=[42;1];let Option<i32> o=.none;let i32 n=take(a,switch(o){case .some(v):{v}case .none:{return a;}});return a;}fn i32 main(){let i32[1] b=f();return b[0];}",8);
    result(b"module main; fn i32[1] take(i32[1] a,i32 n){return a;}fn i32 main(){var i32 n=0;while(n<42){var i32[1] a=[1;1];let Option<i32> o=.none;let i32[1] b=take(a,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return n;}",8);
}
@test
fn void mutable_captures_precede_later_effects_and_normal_cleanup_reclaims_holes() {
    result(b"module main; fn i32[1] f(i32[1] before,i32 n,i32[1] after){let i32[1] b=[before[0]*10+n+after[0];1];return b;}fn i32 main(){var i32[1] a=[2;1];let Option<i32> o=.none;let i32[1] b=f(a,switch(o){case .some(v):{v}case .none:{a[0]=4;18}},a);return b[0];}",24);
    result(b"module main; fn i32[1] f(){let i32[1] scratch=[0;1];let i32[1] a=[42;1];return a;}fn i32 main(){var i32 i=0;while(i<42){let i32[1] a=f();i=i+1;if(a[0]!=42){return 0;}}return i;}",8);
}
@test
fn void source_result_fuel_is_prepaid_at_the_exact_boundary() {
    let ir::Program p=compiled(b"module main;fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32 main(){let i32[1] a=f();return a[0];}");
    assert(switch(vm::run_with_array_limit(ref p,228,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,227,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
@test
fn void independent_verifier_requires_cleanup_of_nonreturned_owners() {
    let ir::Program good=compiled(b"module main;fn i32[1] f(){let i32[1] scratch=[0;1];let i32[1] a=[42;1];return a;}fn i32 main(){let i32[1] a=f();return a[0];}");
    assert(verifier::verify(ref good).is_ok);var ir::Program bad=good;
    var usize pc=bad.starts[0];
    while(pc<bad.ends[0] && bad.code[pc*8]!=37){pc+=1;}
    assert(pc<bad.ends[0]);bad.code[pc*8]=19;bad.code[pc*8+1]=0;
    assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok);
    assert(!verifier::verify(ref bad).is_ok);
}
@test
fn void unsupported_result_forms_and_shapes_fail_compilation() {
    assert(!compiler::compile(b"module main; fn i32[1] f(){return 42;}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){let i32[2] a=[42;2];return a;}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){let i32[1] a=[42;1];return a[0];}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){let i32[1] a=[42;1];return (a);}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){return [42;1];}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32[2] g(){return f();}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32 main(){return f();}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32 main(){let i32[2] a=f();return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32 main(){let u32[1] a=f();return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main(){let i32[1] a=main();return 42;}").is_ok);
}
