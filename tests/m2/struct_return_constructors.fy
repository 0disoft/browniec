module tests::m2::struct_return_constructors;
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
fn void flat_nested_forward_and_scalar_extrema_return_without_copying_the_result() {
    value(b"module main;fn i32 main(){var P p=make();p.x=42;return p.x;}fn P make(){return P{.x=0};}struct P{i32 x;}",4);
    value(b"module main;struct P{i32 x;}struct R{P a;P b;}fn R make(){return R{.a=P{.x=20},.b=P{.x=22}};}fn i32 main(){let R r=make();return r.a.x+r.b.x;}",8);
    value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn P make(){return P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};}fn i32 main(){let P p=make();if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}",32);
    value(b"module main;struct P{i32 x;}fn P make(){let i32 P=0;return P{.x=P+42};}fn i32 main(){let P p=make();return p.x;}",4);
}

@test
fn void fields_evaluate_once_in_order_and_child_paths_snapshot_before_later_effects() {
    value(b"module main;struct P{i32 x;i32 y;}fn P make(){var i32 n=0;let Option<i32> o=.none;return P{.x=switch(o){case .some(v):{v}case .none:{n=n+1;n*20}},.y=switch(o){case .some(v):{v}case .none:{n=n+1;n+20}}};}fn i32 main(){let P p=make();return p.x+p.y;}",8);
    value(b"module main;struct P{i32 x;}struct R{P a;i32 b;}struct W{P p;}fn R make(){var W w=W{.p=P{.x=20}};let Option<i32> o=.none;return R{.a=w.p,.b=switch(o){case .some(v):{v}case .none:{w.p.x=0;22}}};}fn i32 main(){let R r=make();return r.a.x+r.b;}",12);
}

@test
fn void early_returns_and_loop_transfers_never_publish_or_drop_a_pending_constructor() {
    value(b"module main;struct P{i32 x;}fn P make(){let i32[1] a=[0;1];let Option<i32> o=.none;return P{.x=switch(o){case .some(v):{v}case .none:{return P{.x=42};}}};}fn i32 main(){let P p=make();return p.x;}",8);
    value(b"module main;struct P{i32 x;}fn P make(){var i32 n=0;while(n<2){let i32[1] a=[0;1];let P p=P{.x=0};let Option<i32> o=.none;return P{.x=switch(o){case .some(v):{v}case .none:{n=n+1;continue;}}};}return P{.x=42};}fn i32 main(){let P p=make();return p.x;}",8);
    value(b"module main;struct P{i32 x;}fn P make(){while(true){let P p=P{.x=0};let Option<i32> o=.none;return P{.x=switch(o){case .some(v):{v}case .none:{break;}}};}return P{.x=42};}fn i32 main(){let P p=make();return p.x;}",4);
}

@test
fn void mixed_formals_captures_and_recursive_base_constructors_use_existing_cleanup() {
    value(b"module main;struct P{i32 x;}fn P make(P p,i32[1] a){return P{.x=p.x+a[0]};}fn i32 main(){var P p=P{.x=20};let i32[1] a=[22;1];let P q=make(p,a);return q.x;}",24);
    value(b"module main;struct P{i32 x;}fn P f(i32 n){if(n==0){return P{.x=42};}return f(n-1);}fn i32 main(){let P p=f(3);return p.x;}",4);
}

@test
fn void constructor_and_named_returns_emit_identical_instructions_and_keep_payload_bounds() {
    let ir::Program direct=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){let P p=make();return p.x;}");
    let ir::Program named=compiled(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn i32 main(){let P p=make();return p.x;}");
    assert(verifier::verify(ref direct).is_ok && verifier::verify(ref named).is_ok);
    assert(direct.count==named.count && direct.records.count==named.records.count && direct.records.count==3);
    var usize i=0;while(i<direct.count*8){assert(direct.code[i]==named.code[i]);i+=1;}
    assert(switch(vm::run_with_array_limit(ref direct,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref direct,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}

@test
fn void nominal_mismatches_field_types_and_general_record_expressions_remain_rejected() {
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn P make(){return Q{.x=42};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=true};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;i32 y;}fn P make(){return P{.y=20,.x=22};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;i32 y;}fn P make(){return P{.x=20,.x=22};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{P p;}fn R make(){return R{.p=Q{.x=42}};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{P p;}fn R make(){let Q q=Q{.x=42};return R{.p=q};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){let Option<i32> o=.some(42);return P{.x=o?};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=missing};}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct R{P p;}fn R make(){return R{.p=42};}fn i32 main(){return 42;}");
}
