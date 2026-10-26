module tests::m2::struct_child_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn ir::Program compiled(ref u8[] source) {
 return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source) {
 let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,1000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void child_snapshots_preserve_all_scalar_types_and_independence() {
 value(b"module main;struct I{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{I i;i32 tail;}fn i32 main(){var I i=I{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};let R p=R{.i=i,.tail=42};i.c=0;if(p.i.a && p.i.b==255 && p.i.c==-2147483648 && p.i.d==-9223372036854775808 && p.i.e==4294967295 && p.i.f==18446744073709551615){return p.tail;}return 0;}");
}
@test
fn void child_capture_precedes_later_sibling_effects() {
 value(b"module main;struct I{i32 x;}struct R{I a;I b;}fn i32 main(){var I i=I{.x=20};let Option<i32> f=.some(1);let R p=R{.a=i,.b=I{.x=switch(f){case .some(_):{i.x=22;i.x}case .none:{0}}}};i.x=0;return p.a.x+p.b.x;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var I i=I{.x=0};let Option<i32> f=.some(1);let R p=R{.i=I{.x=switch(f){case .some(_):{i.x=42;42}case .none:{0}}}};let R q=R{.i=i};return q.i.x;}");
}
@test
fn void nested_bindings_and_constructor_name_disambiguation_work() {
 value(b"module main;struct I{i32 x;}struct C{I i;i32 y;}struct R{C c;i32 tail;}fn i32 main(){let C child=C{.i=I{.x=20},.y=22};let R p=R{.c=child,.tail=0};return p.c.i.x+p.c.y;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I I=I{.x=42};let R p=R{.i=I};return p.i.x;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};{let I i=I{.x=42};let R q=R{.i=i};p=q;}return p.i.x;}");
}
@test
fn void child_capture_adds_no_temporary_owner_and_has_exact_fuel() {
 let ir::Program p=compiled(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I i=I{.x=42};let R p=R{.i=i};return p.i.x;}");
 assert(p.records.count==2 && p.arrays.count==0);
 var usize pc=0;var usize reads=0;
 while(pc<p.count){assert(p.code[pc*8]!=42);if(p.code[pc*8]==43){reads+=1;}pc+=1;}
 assert(reads==2);
 assert(switch(vm::run_with_array_limit(ref p,174997,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,174996,8)){case .err(e):{e.kind==8}case .ok(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void later_transfers_skip_pending_root_and_invalid_sources_are_rejected() {
 value(b"module main;struct I{i32 x;}struct R{I i;i32 tail;}fn i32 main(){let I i=I{.x=40};var i32 n=0;let Option<i32> f=.some(1);while(n<2){let i32[1] a=[1;1];let R p=R{.i=i,.tail=switch(f){case .some(_):{n=n+a[0];continue;}case .none:{0}}};}return i.x+n;}");
 value(b"module main;struct I{i32 x;}struct R{I i;i32 tail;}fn i32 main(){let I i=I{.x=42};let Option<i32> f=.some(1);let R p=R{.i=i,.tail=switch(f){case .some(_):{return i.x;}case .none:{0}}};return 0;}");
 value(b"module main;struct I{i32 x;}struct R{I i;i32 tail;}fn i32 main(){let I i=I{.x=40};let Option<i32> f=.some(1);while(true){let R p=R{.i=i,.tail=switch(f){case .some(_):{break;}case .none:{0}}};}return i.x+2;}");
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){let J j=J{.x=42};let R p=R{.i=j};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=p};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I i=I{.x=42};let R p=R{.i=i.x};return 42;}").is_ok);
}
