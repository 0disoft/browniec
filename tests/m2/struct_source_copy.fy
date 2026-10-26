module tests::m2::struct_source_copy;
import compiler as compiler;
import ir as ir;
import vm as vm;
import verifier as verifier;
fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,2000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void copies_and_assignments_preserve_all_scalar_fields() {
    value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 main(){let P p=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};var P q=p;let P r=q;q.a=false;q=r;if(q.a && q.b==255 && q.c==-2147483648 && q.d==-9223372036854775808 && q.e==4294967295 && q.f==18446744073709551615){return 42;}return 0;}");
}
@test
fn void copies_are_independent_and_assignment_does_not_alias() {
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=20};var P q=p;p.x=40;if(q.x!=20){return 0;}q=p;p.x=2;return q.x+p.x;}");
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=42};let P q=p;p.x=0;return q.x;}");
}
@test
fn void copies_follow_mixed_lexical_and_loop_cleanup() {
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=14};var i32 n=0;while(n<3){let i32[1] a=[1;1];let P q=p;var P r=q;r=q;n=n+a[0];if(n<3){continue;}break;}return p.x*3;}");
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};let P q=P{.x=42};let Option<i32> f=.some(1);let i32 n=switch(f){case .some(_):{let P r=q;p=r;p.x}case .none:{0}};return n;}");
    value(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};let Option<i32> f=.some(1);return switch(f){case .some(_):{let P q=p;return q.x;}case .none:{0}};}");
}
@test
fn void self_assignment_reuses_one_extent_and_copy_requires_another() {
    let ir::Program self=compiled(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=42};p=p;return p.x;}");
    assert(self.records.count==1);
    assert(switch(vm::run_with_array_limit(ref self,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
    let ir::Program copy=compiled(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};let P q=p;return q.x;}");
    assert(copy.records.count==2);
    assert(switch(vm::run_with_array_limit(ref copy,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref copy,1000000,7)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void nominal_identity_mutability_and_visibility_are_required() {
    assert(!compiler::compile(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){let P p=P{.x=42};let Q q=p;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){var P p=P{.x=42};let Q q=Q{.x=42};p=q;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};p=p;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=p;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){{let P p=P{.x=42};}let P q=p;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let i32[1] a=[42;1];let P p=a;return 42;}").is_ok);
}
@test
fn void constructor_and_copy_names_are_unambiguous_and_emit_existing_opcodes() {
    value(b"module main;struct P{i32 x;}fn i32 main(){let P P=P{.x=42};let P q=P;var P r=P{.x=0};r=q;return r.x;}");
    let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};var P q=p;q=p;return q.x;}");
    var usize at=0;var usize copies=0;var usize assigns=0;
    while(at<p.count){if(p.code[at*8]==42){copies+=1;}if(p.code[at*8]==46){assigns+=1;}at+=1;}
    assert(copies==1 && assigns==1 && p.records.count==2);
}
