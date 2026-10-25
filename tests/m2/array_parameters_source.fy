module tests::m2::array_parameters_source;

import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)) {case .ok(p):{p} case .err(_):{assert(false);ir::empty()}};
}
fn void result(ref u8[] source,usize limit) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,limit)) {case .ok(n):{n==42} case .err(_):{false}});
}
fn void rejected(ref u8[] source) {assert(!compiler::compile(source).is_ok);}

@test
fn void exact_array_parameters_work_for_all_elements_and_mixed_scalar_positions() {
    result(b"module main; fn i32 f(i32 n,i32[2] a){return n+a[0]+a[1];} fn i32 main(){let i32[2] a=[21;2]; return f(0,a);}",16);
    result(b"module main; fn i32 f(bool[2] a,bool n){if(a[0] && a[1]==n && a.len==2){return 42;}return 0;} fn i32 main(){let bool[2] a=[true;2];return f(a,true);}",4);
    result(b"module main; fn i32 f(u8[1] a){if(a[0]==255){return 42;}return 0;} fn i32 main(){let u8[1] a=[255;1];return f(a);}",2);
    result(b"module main; fn i32 f(i64[1] a){if(a[0]==-9223372036854775808){return 42;}return 0;} fn i32 main(){let i64[1] a=[-9223372036854775808;1];return f(a);}",16);
    result(b"module main; fn i32 f(u32[1] a){if(a[0]==4294967295){return 42;}return 0;} fn i32 main(){let u32[1] a=[4294967295;1];return f(a);}",8);
    result(b"module main; fn i32 main(){let usize[1] a=[18446744073709551615;1];return f(a);} fn i32 f(usize[1] a){if(a[0]==18446744073709551615){return 42;}return 0;}",16);
}

@test
fn void mutable_arguments_capture_once_left_to_right_before_later_effects() {
    let ref u8[] source=b"module main; fn i32 f(i32[1] before,i32 stamp,i32[1] after){return before[0]*10+stamp+after[0];} fn i32 main(){var i32[1] a=[2;1];var i32 n=0;let Option<i32> o=.none;let i32 r=f(a,switch(o){case .some(v):{v}case .none:{n=n+1;a[0]=4;18}},a);return r+n-1;}";
    result(source,20);
    let ir::Program p=compiled(source);
    assert(switch(vm::run_with_array_limit(ref p,1000000,19)) {case .ok(_):{false}case .err(e):{e.kind==13}});
    result(b"module main; fn i32 f(i32[1] a){var i32[1] b=a;b[0]=0;return a[0]+21;} fn i32 main(){var i32[1] a=[21;1];return f(a);}",16);
}

@test
fn void nested_call_question_mark_failures_release_all_pending_captures() {
    result(b"module main; fn i32 take(i32[1] a,i32 n){return a[0]+n;} fn Option<i32> f(Option<i32> x){var i32[1] a=[21;1];let i32 n=take(a,take(a,x?));return .some(n);} fn i32 main(){var i32 i=0;while(i<42){switch(f(.none)){case .some(v):{return 0;}case .none:{i=i+1;}}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",16);
    result(b"module main; fn Option<i32> f(i32[1] a,Option<i32> x){return .some(a[0]+x?);} fn i32 main(){let i32[1] a=[21;1];var i32 i=0;while(i<42){switch(f(a,.none)){case .some(v):{return 0;}case .none:{i=i+1;}}}switch(f(a,.some(21))){case .some(v):{return v;}case .none:{return 0;}}}",8);
}

@test
fn void early_returns_and_outer_loop_transfers_drop_captures_but_inner_loops_preserve_them() {
    result(b"module main; fn i32 take(i32[1] a,i32 n){return a[0]+n;} fn i32 main(){var i32[1] a=[1;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{return 42;}});}",8);
    result(b"module main; fn i32 take(i32[1] a,i32 n){return a[0]+n;} fn i32 main(){var i32 i=0;while(i<42){var i32[1] a=[1;1];let Option<i32> o=.none;i=i+take(a,switch(o){case .some(v):{v}case .none:{i=i+1;continue;}});}return i;}",8);
    result(b"module main; fn i32 take(i32[1] a,i32 n){return a[0]+n;} fn i32 main(){while(true){var i32[1] a=[1;1];let Option<i32> o=.none;let i32 n=take(a,switch(o){case .some(v):{v}case .none:{break;}});}return 42;}",8);
    result(b"module main; fn i32 take(i32[1] a,i32 n){return a[0]+n;} fn i32 main(){var i32[1] a=[21;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{var i32 i=0;while(i<21){i=i+1;continue;}i}});}",12);
}

@test
fn void recursive_and_mutual_parameter_forwarding_preserves_each_invocation() {
    result(b"module main; fn i32 sum(i32[1] a,i32 n){if(n==0){return a[0];}return a[0]+sum(a,n-1);} fn i32 main(){let i32[1] a=[7;1];return sum(a,5);}",28);
    result(b"module main; fn i32 main(){let i32[1] a=[7;1];return f(a,5);} fn i32 f(i32[1] a,i32 n){if(n==0){return a[0];}return a[0]+g(a,n-1);} fn i32 g(i32[1] a,i32 n){if(n==0){return a[0];}return a[0]+f(a,n-1);}",28);
}

@test
fn void eight_distinct_forward_arguments_keep_order_at_both_catalog_and_owner_caps() {
    result(b"module main; fn i32 main(){let i32[1] a=[1;1];let i32[1] b=[2;1];let i32[1] c=[3;1];let i32[1] d=[4;1];let i32[1] e=[5;1];let i32[1] f=[6;1];let i32[1] g=[7;1];let i32[1] h=[8;1];return sum(a,b,c,d,e,f,g,h);} fn i32 sum(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return a[0]+b[0]*2+c[0]*3+d[0]*4+e[0]*5+f[0]*6+g[0]*7+h[0]*8-162;}",64);
}

@test
fn void invalid_shapes_mutability_aggregate_forms_and_for_header_calls_are_rejected() {
    rejected(b"module main; fn i32 f(i32[1] a){a[0]=0;return 42;}fn i32 main(){let i32[1] a=[42;1];return f(a);}");
    rejected(b"module main; fn i32 f(i32[1] a){let i32[1] b=[1;1];a=b;return 42;}fn i32 main(){let i32[1] a=[42;1];return f(a);}");
    rejected(b"module main; fn i32 f(i32[2] a){return a[0];}fn i32 main(){let i32[1] a=[42;1];return f(a);}");
    rejected(b"module main; fn i32 f(u32[1] a){return 42;}fn i32 main(){let i32[1] a=[42;1];return f(a);}");
    rejected(b"module main; fn i32 f(i32[1] a){return 42;}fn i32 main(){return f(42);}");
    rejected(b"module main; fn i32 f(i32[1] a){return 42;}fn i32 main(){let i32[1] a=[42;1];return f((a));}");
    rejected(b"module main; fn i32 f(i32[1] a){return 42;}fn i32 main(){let i32[1] a=[42;1];return f(a[0]);}");
    rejected(b"module main; fn i32 f(i32[1] a){return a;}fn i32 main(){let i32[1] a=[42;1];return f(a);}");
    rejected(b"module main; fn i32 f(i32[1] a){let i32 a=42;return a;}fn i32 main(){return 42;}");
    rejected(b"module main; fn i32 f(i32[1] a){return 0;}fn i32 main(){let i32[1] a=[42;1];for(var i32 n=f(a);n<1;n=n+1){}return 42;}");
}

@test
fn void independent_verifier_rejects_missing_pending_capture_cleanup() {
    let ir::Program good=compiled(b"module main; fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn Option<i32> f(Option<i32> x){var i32[1] a=[21;1];return .some(take(a,take(a,x?)));}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{return 42;}}}");
    assert(verifier::verify(ref good).is_ok);var ir::Program bad=good;
    let usize capture=bad.arrays.count-1;var usize pc=bad.starts[1];
    while(pc<bad.ends[1] && (bad.code[pc*8]!=37 || bad.code[pc*8+1] as usize!=capture)) {pc+=1;}
    assert(pc<bad.ends[1]);bad.code[pc*8]=19;bad.code[pc*8+1]=0;
    assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok);
    assert(!verifier::verify(ref bad).is_ok);
}
