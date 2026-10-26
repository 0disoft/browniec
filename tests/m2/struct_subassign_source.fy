module tests::m2::struct_subassign_source;
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
fn void nominal_child_assignment_preserves_all_scalar_types_and_neighbors() {
 value(b"module main;struct I{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{u8 head;I i;}struct S{I child;usize tail;}fn i32 main(){let S q=S{.child=I{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615},.tail=0};var R p=R{.head=17,.i=I{.a=false,.b=0,.c=0,.d=0,.e=0,.f=0}};p.i=q.child;if(p.head==17 && p.i.a && p.i.b==255 && p.i.c==-2147483648 && p.i.d==-9223372036854775808 && p.i.e==4294967295 && p.i.f==18446744073709551615){return 42;}return 0;}");
}
@test
fn void sibling_self_and_nested_assignments_use_independent_snapshots() {
 value(b"module main;struct I{i32 x;i32 y;}struct R{I a;I b;}fn i32 main(){var R p=R{.a=I{.x=20,.y=22},.b=I{.x=0,.y=0}};p.b=p.a;p.a.x=0;if(p.b.x!=20){return 0;}p.b=p.b;return p.b.x+p.b.y;}");
 value(b"module main;struct I{i32 x;}struct C{I i;i32 y;}struct R{C c;}fn i32 main(){var R q=R{.c=C{.i=I{.x=20},.y=22}};var R p=R{.c=C{.i=I{.x=0},.y=0}};p.c=q.c;q.c.i.x=0;return p.c.i.x+p.c.y;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I i=I{.x=42};var R p=R{.i=I{.x=0}};p.i=i;return p.i.x;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};var I i=I{.x=0};i=p.i;return i.x;}");
}
@test
fn void writes_reuse_sites_owners_and_payload_without_copy_or_init() {
 let ir::Program p=compiled(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R q=R{.i=I{.x=42}};var R p=R{.i=I{.x=0}};p.i=q.i;return p.i.x;}");
 assert(p.records.count==2 && p.arrays.count==0);
 var usize pc=0;var usize inits=0;var usize reads=0;var usize writes=0;var usize copies=0;
 while(pc<p.count){let u8 op=p.code[pc*8];assert(op!=42);if(op==41){inits+=1;}if(op==43){reads+=1;}if(op==44){writes+=1;}if(op==47){copies+=1;}pc+=1;}
 assert(inits==2 && reads==1 && writes==0 && copies==1);
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .err(e):{e.kind==13}case .ok(_):{false}});
 assert(switch(vm::run(ref p,0)){case .err(e):{e.kind==8}case .ok(_):{false}});
}
@test
fn void assigned_values_survive_source_exit_and_loop_cleanup() {
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};while(true){let R q=R{.i=I{.x=42}};p.i=q.i;break;}return p.i.x;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var i32 n=0;while(n<2){let R q=R{.i=I{.x=21}};var R p=R{.i=I{.x=0}};p.i=q.i;n=n+1;if(n<2){continue;}return p.i.x*2;}return 0;}");
}
@test
fn void subrecord_writes_reject_immutable_wrong_nominal_and_scalar_operands() {
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};p.i=p.i;return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){let J j=J{.x=42};var R p=R{.i=I{.x=0}};p.i=j;return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=42}};p.i=p.i.x;return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=42}};p.i=42;return 42;}").is_ok);
}
