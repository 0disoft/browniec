module tests::m2::struct_child_path_source;
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
fn void path_capture_preserves_scalar_extremes_and_independence() {
 value(b"module main;struct I{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct S{u8 head;I i;}struct R{I i;i32 tail;}fn i32 main(){var S p=S{.head=255,.i=I{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615}};let R q=R{.i=p.i,.tail=42};p.i.c=0;if(q.i.a && q.i.b==255 && q.i.c==-2147483648 && q.i.d==-9223372036854775808 && q.i.e==4294967295 && q.i.f==18446744073709551615){return q.tail;}return 0;}");
}
@test
fn void nested_sibling_offsets_and_capture_order_are_preserved() {
 value(b"module main;struct I{i32 x;}struct C{I left;I right;}struct S{u8 head;C c;i32 tail;}struct R{I a;I b;}fn i32 main(){var S p=S{.head=1,.c=C{.left=I{.x=0},.right=I{.x=20}},.tail=0};let Option<i32> f=.some(1);let R q=R{.a=p.c.right,.b=I{.x=switch(f){case .some(_):{p.c.right.x=22;p.c.right.x}case .none:{0}}}};p.c.right.x=0;return q.a.x+q.b.x;}");
 value(b"module main;struct I{i32 x;}struct C{I i;i32 y;}struct S{C c;}struct R{C c;}fn i32 main(){let S p=S{.c=C{.i=I{.x=20},.y=22}};let R q=R{.c=p.c};return q.c.i.x+q.c.y;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R I=R{.i=I{.x=42}};let R q=R{.i=I.i};return q.i.x;}");
}
@test
fn void capture_reuses_two_roots_with_exact_fuel_and_payload_limits() {
 let ir::Program p=compiled(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let R q=R{.i=p.i};return q.i.x;}");
 assert(p.records.count==2 && p.arrays.count==0);
 var usize pc=0;var usize reads=0;var usize roots=0;
 while(pc<p.count){let u8 op=p.code[pc*8];assert(op!=42 && op!=46 && op!=47);if(op==43){reads+=1;}if(op==41){roots+=1;}pc+=1;}
 assert(reads==2 && roots==2);
 assert(switch(vm::run_with_array_limit(ref p,174997,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,174996,8)){case .err(e):{e.kind==8}case .ok(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void later_transfers_never_release_a_pending_parent() {
 value(b"module main;struct I{i32 x;}struct R{I i;i32 tail;}fn i32 main(){let R p=R{.i=I{.x=40},.tail=0};var i32 n=0;let Option<i32> f=.some(1);while(n<2){let i32[1] a=[1;1];let R q=R{.i=p.i,.tail=switch(f){case .some(_):{n=n+a[0];continue;}case .none:{0}}};}return p.i.x+n;}");
 value(b"module main;struct I{i32 x;}struct R{I i;i32 tail;}fn i32 main(){let R p=R{.i=I{.x=42},.tail=0};let Option<i32> f=.some(1);let R q=R{.i=p.i,.tail=switch(f){case .some(_):{return p.i.x;}case .none:{0}}};return 0;}");
 value(b"module main;struct I{i32 x;}struct R{I i;i32 tail;}fn i32 main(){let R p=R{.i=I{.x=40},.tail=0};let Option<i32> f=.some(1);while(true){let R q=R{.i=p.i,.tail=switch(f){case .some(_):{break;}case .none:{0}}};}return p.i.x+2;}");
}
@test
fn void nominal_identity_visibility_and_scalar_endpoints_are_checked() {
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct J{i32 x;}struct S{J i;}struct R{I i;}fn i32 main(){let S p=S{.i=J{.x=42}};let R q=R{.i=p.i};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let R q=R{.i=p.i.x};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R q=R{.i=q.i};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){{let R p=R{.i=I{.x=42}};}let R q=R{.i=p.i};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let R q=R{.i=p.missing};return 42;}").is_ok);
}
