module tests::m2::struct_return_paths;
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
fn void forward_nested_endpoints_copy_the_correct_leaf_range_and_scalar_bits() {
    value(b"module main;fn i32 main(){let P p=make();return p.x;}fn P make(){let R r=R{.head=255,.p=P{.x=42},.tail=0};return r.p;}struct P{i32 x;}struct R{u8 head;P p;u8 tail;}",16);
    value(b"module main;struct P{i32 x;i32 y;}struct C{P left;P right;}struct R{u8 head;C c;}fn P make(){let R r=R{.head=255,.c=C{.left=P{.x=1,.y=2},.right=P{.x=20,.y=22}}};return r.c.right;}fn i32 main(){let P p=make();return p.x+p.y;}",28);
    value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{u8 head;P p;}fn P make(){let R r=R{.head=255,.p=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615}};return r.p;}fn i32 main(){let P p=make();if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}",72);
}

@test
fn void formal_and_mutable_sources_copy_independently_and_anchor_reuse_is_safe() {
    value(b"module main;struct P{i32 x;}struct R{P p;i32 tail;}fn P pick(R r){return r.p;}fn i32 main(){let R r=R{.p=P{.x=42},.tail=0};var P p=pick(r);p.x=0;return r.p.x;}",20);
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P pick(R r,P fallback){return r.p;}fn i32 main(){let R r=R{.p=P{.x=42}};let P fallback=P{.x=0};let P p=pick(r,fallback);return p.x;}",20);
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){var R r=R{.p=P{.x=0}};r.p.x=42;return r.p;}fn i32 main(){var P p=make();return p.x;}",8);
}

@test
fn void mixed_locals_and_pending_call_or_assignment_captures_cleanup_before_subrecord_return() {
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P pick(R r){let i32[1] a=[0;1];return r.p;}fn i32 main(){let R r=R{.p=P{.x=42}};let P p=pick(r);return p.x;}",16);
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(P p,i32 n){return p;}fn P pick(R r){var P p=P{.x=0};let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{return r.p;}});}fn i32 main(){let R r=R{.p=P{.x=42}};let P p=pick(r);return p.x;}",20);
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(P p,i32 n){return p;}fn P pick(R r){var P p=P{.x=0};let Option<i32> o=.none;p=take(p,switch(o){case .some(v):{v}case .none:{return r.p;}});return p;}fn i32 main(){let R r=R{.p=P{.x=42}};let P p=pick(r);return p.x;}",20);
}

@test
fn void recursive_and_mutual_forwarding_preserve_independent_frame_owners() {
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P pick(R r,i32 n){if(n==0){return r.p;}return pick(r,n-1);}fn i32 main(){let R r=R{.p=P{.x=42}};let P p=pick(r,2);return p.x;}",20);
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P f(R r,i32 n){if(n==0){return r.p;}return g(r,n-1);}fn P g(R r,i32 n){return f(r,n-1);}fn i32 main(){let R r=R{.p=P{.x=42}};let P p=f(r,2);return p.x;}",20);
}

@test
fn void extraction_matches_named_return_ir_and_requires_both_extents_until_cleanup() {
    value(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){let R r=R{.p=P{.x=42}};return r.p;}fn i32 main(){var i32 n=0;while(n<2){let P p=make();if(p.x!=42){return 0;}n=n+1;}return 42;}",8);
    let ir::Program direct=compiled(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){let R r=R{.p=P{.x=42}};return r.p;}fn i32 main(){let P p=make();return p.x;}");
    let ir::Program named=compiled(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){let R r=R{.p=P{.x=42}};let P p=r.p;return p;}fn i32 main(){let P p=make();return p.x;}");
    assert(verifier::verify(ref direct).is_ok && verifier::verify(ref named).is_ok);
    assert(direct.count==named.count && direct.records.count==named.records.count);
    var usize i=0;while(i<direct.count*8){assert(direct.code[i]==named.code[i]);i+=1;}
    assert(switch(vm::run_with_array_limit(ref direct,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref direct,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
}

@test
fn void wrong_nominal_scalar_nonrecord_and_general_expression_returns_are_rejected() {
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{Q p;}fn P pick(R r){return r.p;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{i32 x;}fn P pick(R r){return r.x;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P pick(R r){return r.missing;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P pick(R r){return (r.p);}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn R make(){return R{.p=P{.x=42}};}fn P pick(){return make().p;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P pick(){let i32 r=0;return r.p;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P pick(){return missing.p;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P pick(){let Option<i32> r=.none;return r.p;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn R pick(R r){return r.p;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P pick(R r){return r;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P pick(R r){return r.p.missing;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32[1] pick(R r){return r.p;}fn i32 main(){return 42;}");
}
