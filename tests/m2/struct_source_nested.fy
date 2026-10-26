module tests::m2::struct_source_nested;
import compiler as compiler;
import ir as ir;
import vm as vm;
import verifier as verifier;
fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,1000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void nested_sibling_ordinals_and_padding_preserve_all_scalar_tags() {
    value(b"module main;struct I{bool a;u8 b;i64 c;u32 d;usize e;}struct R{u8 head;I inner;i32 tail;}fn i32 main(){let R p=R{.head=255,.inner=I{.a=true,.b=255,.c=-9223372036854775808,.d=4294967295,.e=18446744073709551615,},.tail=42,};if(p.head==255 && p.inner.a && p.inner.b==255 && p.inner.c==-9223372036854775808 && p.inner.d==4294967295 && p.inner.e==18446744073709551615){return p.tail;}return 0;}");
    value(b"module main;struct P{i32 x;i32 y;}struct R{P a;P b;i32 z;}fn i32 main(){let R p=R{.a=P{.x=1,.y=2},.b=P{.x=3,.y=4},.z=32};return p.a.x+p.a.y+p.b.x+p.b.y+p.z;}");
}
@test
fn void chained_writes_run_rhs_once_and_final_chains_remain_values() {
    value(b"module main;struct I{u8 x;bool b;}struct R{I i;i32 y;}fn i32 main(){var R p=R{.i=I{.x=0,.b=false},.y=0};let Option<i32> f=.some(1);var i32 n=0;p.i.x=switch(f){case .some(_):{n=n+1;p.i.b=true;42}case .none:{0}};let u8 v=switch(f){case .some(_):{p.y=1;p.i.x}case .none:{0}};if(n==1 && p.i.b && p.y==1 && v==42){return 42;}return 0;}");
    value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};for(var i32 n=0;p.i.x<2;n=n+1){p.i.x=p.i.x+1;}return p.i.x+40;}");
}
@test
fn void nested_root_copies_and_assignment_are_independent() {
    value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=20}};var R q=p;p.i.x=40;if(q.i.x!=20){return 0;}q=p;p.i.x=2;return q.i.x+p.i.x;}");
    value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};{let R q=R{.i=I{.x=42}};p=q;}p=p;return p.i.x;}");
}
@test
fn void initializer_order_and_transfers_publish_only_complete_roots() {
    value(b"module main;struct I{i32 x;i32 y;}struct R{I i;i32 z;}fn i32 main(){var i32 n=20;let Option<i32> f=.some(1);let R p=R{.i=I{.x=n,.y=switch(f){case .some(_):{n=22;n}case .none:{0}}},.z=0};return p.i.x+p.i.y;}");
    value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I outer=I{.x=42};let Option<i32> f=.some(1);let R p=R{.i=I{.x=switch(f){case .some(_):{return outer.x;}case .none:{0}}}};return 0;}");
    value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I outer=I{.x=40};var i32 n=0;let Option<i32> f=.some(1);while(n<2){let i32[1] a=[1;1];let R p=R{.i=I{.x=switch(f){case .some(_):{n=n+a[0];continue;}case .none:{0}}}};}return outer.x+n;}");
    value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=40}};let Option<i32> f=.some(1);while(true){let R q=R{.i=I{.x=switch(f){case .some(_):{break;}case .none:{0}}}};}p.i.x=p.i.x+2;return p.i.x;}");
}
@test
fn void children_share_one_owner_and_root_extent() {
    let ir::Program p=compiled(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=42}};p=p;return p.i.x;}");
    assert(p.records.count==1);
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void nested_types_mutability_and_scalar_path_endpoints_are_checked() {
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=R{.i=I{.x=42}}};return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let i32 n=42;let R p=R{.i=n};return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};p.i.x=0;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=42}};p.i.x=true;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=42}};let I i=p.i;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=42}};p.i=p.i;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=p.i.x}};return 42;}").is_ok);
}
