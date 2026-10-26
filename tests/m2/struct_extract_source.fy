module tests::m2::struct_extract_source;
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
fn void extraction_preserves_scalar_extremes_and_source_independence() {
 value(b"module main;struct I{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{u8 head;I i;}fn i32 main(){var R p=R{.head=255,.i=I{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615}};let I i=p.i;p.i.c=0;if(i.a && i.b==255 && i.c==-2147483648 && i.d==-9223372036854775808 && i.e==4294967295 && i.f==18446744073709551615){return 42;}return 0;}");
}
@test
fn void nested_endpoints_and_preceding_subtrees_resolve_exact_leaf_ranges() {
 value(b"module main;struct I{i32 x;i32 y;}struct C{I left;I right;}struct R{u8 head;C c;i32 tail;}fn i32 main(){let R p=R{.head=255,.c=C{.left=I{.x=1,.y=2},.right=I{.x=20,.y=22}},.tail=0};var I i=p.c.right;i.x=21;return i.x+i.y-1;}");
 value(b"module main;struct I{i32 x;}struct C{I i;i32 y;}struct R{C c;}fn i32 main(){let R p=R{.c=C{.i=I{.x=20},.y=22}};let C c=p.c;return c.i.x+c.y;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R I=R{.i=I{.x=42}};let I i=I.i;return i.x;}");
}
@test
fn void extracted_owners_follow_normal_scope_and_loop_cleanup() {
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var I keep=I{.x=0};{let R p=R{.i=I{.x=42}};let I i=p.i;keep=i;}return keep.x;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var i32 n=0;while(n<42){let R p=R{.i=I{.x=21}};let I i=p.i;n=n+i.x;continue;}return n;}");
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};while(true){let I i=p.i;break;}return p.i.x;}");
}
@test
fn void extraction_uses_two_roots_and_consecutive_read_inputs() {
 let ir::Program p=compiled(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let I i=p.i;return i.x;}");
 assert(p.records.count==2 && p.arrays.count==0);
 var usize pc=0;var usize reads=0;
 while(pc<p.count){assert(p.code[pc*8]!=42);if(p.code[pc*8]==43){reads+=1;}pc+=1;}
 assert(reads==2);
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void extraction_rejects_wrong_nominal_types_and_non_record_endpoints() {
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let J i=p.i;return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let I i=p.i.x;return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I i=i.i;return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let I i=p.i;return p.i;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};p.i=p.i;return 42;}").is_ok);
}
