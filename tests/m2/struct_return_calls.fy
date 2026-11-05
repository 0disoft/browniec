module tests::m2::struct_return_calls;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source,usize limit) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,16000000,limit)){case .ok(n):{n==42}case .err(_):{false}});
}
fn void rejected(ref u8[] source) {
    assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==3}});
}

@test
fn void forward_calls_transfer_flat_nested_and_all_scalar_bits_without_another_extent() {
    value(b"module main;fn i32 main(){let P p=forward(42);return p.x;}fn P forward(i32 n){return make(n);}fn P make(i32 n){let P p=P{.x=n};return p;}struct P{i32 x;}",4);
    value(b"module main;struct P{i32 x;}struct R{P a;P b;}fn R make(){let R r=R{.a=P{.x=20},.b=P{.x=22}};return r;}fn R forward(){return make();}fn i32 main(){var R r=forward();return r.a.x+r.b.x;}",8);
    value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn P make(){let P p=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};return p;}fn P forward(){return make();}fn i32 main(){let P p=forward();if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}",32);
}

@test
fn void mixed_arguments_capture_left_to_right_and_cleanup_preserves_only_the_result() {
    value(b"module main;struct P{i32 x;}fn P id(P p){return p;}fn P forward(P p){return id(p);}fn i32 main(){let P p=P{.x=42};var P q=forward(p);q.x=0;return p.x;}",12);
    value(b"module main;struct P{i32 x;}fn P take(P before,i32 n,P after,i32[1] old){let P answer=P{.x=before.x*10+n+after.x+old[0]};return answer;}fn P forward(){var P p=P{.x=2};var i32[1] a=[1;1];let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{p.x=4;17}},p,a);}fn i32 main(){let P p=forward();return p.x;}",36);
    value(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P forward(){let i32[1] a=[0;1];let P p=P{.x=0};return make();}fn i32 main(){var i32 n=0;while(n<2){let P p=forward();if(p.x!=42){return 0;}n=n+1;}return n+40;}",12);
}

@test
fn void pending_destinations_stay_dead_across_early_record_returns_and_loop_transfers() {
    value(b"module main;struct P{i32 x;}fn P make(i32 n){let P p=P{.x=n};return p;}fn P take(P p,i32 n){return p;}fn P forward(){var P p=P{.x=0};let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{return make(42);}});}fn i32 main(){let P p=forward();return p.x;}",12);
    value(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P take(P p,i32 n){return p;}fn P forward(){var i32 n=0;while(n<2){var P p=P{.x=0};let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return make();}fn i32 main(){let P p=forward();return p.x;}",8);
    value(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P take(P p,i32 n){return p;}fn P forward(){while(true){var P p=P{.x=0};let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{break;}});}return make();}fn i32 main(){let P p=forward();return p.x;}",8);
    value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn P forward(){var P p=P{.x=42};let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<1){p.x=0;n=n+1;continue;}n}});}fn i32 main(){let P p=forward();return p.x;}",12);
}

@test
fn void recursive_and_mutual_direct_returns_keep_frame_and_payload_bounds() {
    value(b"module main;struct P{i32 x;}fn P f(i32 n){if(n==0){let P p=P{.x=42};return p;}return f(n-1);}fn i32 main(){let P p=f(30);return p.x;}",4);
    value(b"module main;struct P{i32 x;}fn P f(i32 n){if(n==0){let P p=P{.x=42};return p;}return g(n-1);}fn P g(i32 n){return f(n-1);}fn i32 main(){let P p=f(4);return p.x;}",4);
    let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P f(i32 n){if(n==0){let P p=P{.x=42};return p;}return f(n-1);}fn i32 main(){let P p=f(31);return p.x;}");
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,16000000,4)){case .ok(_):{false}case .err(e):{e.kind==12}});
}

@test
fn void direct_and_named_forwarding_have_identical_ir_and_exact_fuel() {
    let ir::Program direct=compiled(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P forward(){return make();}fn i32 main(){let P p=forward();return p.x;}");
    let ir::Program named=compiled(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P forward(){let P p=make();return p;}fn i32 main(){let P p=forward();return p.x;}");
    assert(verifier::verify(ref direct).is_ok && verifier::verify(ref named).is_ok);
    assert(direct.count==named.count && direct.records.count==named.records.count);
    var usize i=0;while(i<direct.count*8){assert(direct.code[i]==named.code[i]);i+=1;}
    assert(switch(vm::run_with_array_limit(ref direct,171728,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref named,171728,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref direct,171727,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref direct,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}

@test
fn void nominal_types_call_shapes_and_unsupported_expressions_still_fail() {
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn Q make(){let Q q=Q{.x=42};return q;}fn P forward(){return make();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn i32 make(){return 42;}fn P forward(){return make();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn i32[1] make(){let i32[1] a=[42;1];return a;}fn P forward(){return make();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn Option<i32> make(){return .some(42);}fn P forward(){return make();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P forward(){return missing();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P forward(){return main();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P forward(){let i32 make=0;return make();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(i32 n){let P p=P{.x=n};return p;}fn P forward(){return make();}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P forward(){return make().x;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn P forward(){return make()+1;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(i32 n){let P p=P{.x=n};return p;}fn P forward(){let Option<i32> o=.some(42);return make(o?);}fn i32 main(){return 42;}");
}
