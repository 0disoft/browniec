module tests::m2::struct_call_assignment;
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
fn void flat_nested_and_all_scalar_bits_assign_into_existing_mutable_roots() {
    value(b"module main;fn i32 main(){var P p=P{.x=0};p=make();return p.x;}fn P make(){return P{.x=42};}struct P{i32 x;}",8);
    value(b"module main;struct P{i32 x;}struct R{P a;P b;}fn R make(){return R{.a=P{.x=20},.b=P{.x=22}};}fn i32 main(){var R r=R{.a=P{.x=0},.b=P{.x=0}};r=make();return r.a.x+r.b.x;}",16);
    value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn P make(){return P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};}fn i32 main(){var P p=P{.a=false,.b=0,.c=0,.d=0,.e=0,.f=0};p=make();if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}",64);
}

@test
fn void old_values_remain_visible_and_mutable_mixed_arguments_capture_left_to_right() {
    value(b"module main;struct P{i32 x;}fn P id(P p){return p;}fn i32 main(){var P p=P{.x=42};let P before=p;p=id(p);p.x=0;return before.x;}",16);
    value(b"module main;struct P{i32 x;}fn P take(P before,i32 n,P after,i32[1] a){return P{.x=before.x*10+n+after.x+a[0]};}fn i32 main(){var P p=P{.x=2};var i32[1] a=[1;1];let Option<i32> o=.none;p=take(p,switch(o){case .some(v):{v}case .none:{p.x=4;17}},p,a);return p.x;}",40);
}

@test
fn void early_scalar_record_and_propagated_returns_keep_the_pending_result_dead() {
    value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){var P p=P{.x=0};let Option<i32> o=.none;p=take(p,switch(o){case .some(v):{v}case .none:{return 42;}});return 0;}",8);
    value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn P outer(P p){var P q=p;let Option<i32> o=.none;q=take(q,switch(o){case .some(v):{v}case .none:{return p;}});return q;}fn i32 main(){let P p=P{.x=42};let P q=outer(p);return q.x;}",16);
    value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn Option<i32> f(Option<i32> o){var P p=P{.x=42};p=take(p,o?);return .some(p.x);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",12);
}

@test
fn void outer_loop_transfers_release_captures_and_inner_loops_preserve_them() {
    value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){var P p=P{.x=42};var i32 n=0;while(n<2){var P q=P{.x=0};let Option<i32> o=.none;q=take(q,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return p.x;}",12);
    value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){var P p=P{.x=42};while(true){var P q=P{.x=0};let Option<i32> o=.none;q=take(q,switch(o){case .some(v):{v}case .none:{break;}});}return p.x;}",12);
    value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){var P p=P{.x=42};let Option<i32> o=.none;p=take(p,switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<1){p.x=0;n=n+1;continue;}n}});return p.x;}",12);
}

@test
fn void repeated_calls_release_temporary_extents_and_match_explicit_scoped_assignment() {
    value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){var P p=P{.x=0};var i32 n=0;while(n<3){p=make();if(p.x!=42){return 0;}n=n+1;}return p.x;}",8);
    let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){var P p=P{.x=0};p=make();return p.x;}");
    let ir::Program named=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){var P p=P{.x=0};{let P temporary=make();p=temporary;}return p.x;}");
    assert(p.count==named.count && p.records.count==named.records.count);
    var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
    assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
    assert(pc+2<p.count && p.code[(pc+1)*8]==46 && p.code[(pc+2)*8]==45);
    assert(p.code[pc*8+1] as usize==144+p.code[(pc+1)*8+2] as usize);
    assert(p.code[(pc+1)*8+2]==p.code[(pc+2)*8+1]);
    var ir::Program bad=p;bad.code[(pc+2)*8]=19;bad.code[(pc+2)*8+1]=0;
    assert(ir::patch(ref mut bad,pc+2,pc+3,0).is_ok);
    assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void immutable_nominal_nonrecord_shadowed_and_unsupported_targets_are_rejected() {
    rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){let P p=P{.x=0};p=make();return 42;}");
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn Q make(){return Q{.x=42};}fn i32 main(){var P p=P{.x=0};p=make();return 42;}");
    rejected(b"module main;struct P{i32 x;}fn i32 make(){return 42;}fn i32 main(){var P p=P{.x=0};p=make();return 42;}");
    rejected(b"module main;struct P{i32 x;}fn i32[1] make(){return [42;1];}fn i32 main(){var P p=P{.x=0};p=make();return 42;}");
    rejected(b"module main;struct P{i32 x;}fn Option<i32> make(){return .some(42);}fn i32 main(){var P p=P{.x=0};p=make();return 42;}");
    rejected(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p=missing();return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){var P p=P{.x=0};let i32 make=0;p=make();return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(i32 n){return P{.x=n};}fn i32 main(){var P p=P{.x=0};p=make();return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){var P p=P{.x=0};for(;false;p=make()){}return 42;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){var i32 n=0;n=make();return 42;}");
}
