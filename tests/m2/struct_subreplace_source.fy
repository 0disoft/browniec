module tests::m2::struct_subreplace_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn ir::Program compiled(ref u8[] source) {
 return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source) {
 let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,2000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void scalar_extremes_replace_only_the_selected_child() {
 value(b"module main;struct I{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{u8 head;I i;usize tail;}fn i32 main(){var R p=R{.head=17,.i=I{.a=false,.b=0,.c=0,.d=0,.e=0,.f=0},.tail=23};p.i=I{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};if(p.head==17 && p.tail==23 && p.i.a && p.i.b==255 && p.i.c==-2147483648 && p.i.d==-9223372036854775808 && p.i.e==4294967295 && p.i.f==18446744073709551615){return 42;}return 0;}");
}
@test
fn void staged_self_reads_preserve_new_sibling_effects_and_nested_replacements() {
 value(b"module main;struct I{i32 x;i32 y;}struct R{u8 head;I i;i32 tail;}fn i32 main(){var R p=R{.head=17,.i=I{.x=20,.y=22},.tail=23};p.i=I{.x=p.i.y,.y=p.i.x};if(p.head==17 && p.tail==23 && p.i.x==22 && p.i.y==20){return p.i.x+p.i.y;}return 0;}");
 value(b"module main;struct I{i32 x;i32 y;}struct R{u8 head;I i;i32 tail;}fn i32 main(){var R p=R{.head=0,.i=I{.x=20,.y=0},.tail=0};var i32 n=0;let Option<i32> f=.some(1);p.i=I{.x=switch(f){case .some(_):{n=n+1;p.i.x}case .none:{0}},.y=switch(f){case .some(_):{n=n+1;p.head=17;p.tail=23;p.i.x=99;22}case .none:{0}}};if(n==2 && p.head==17 && p.tail==23 && p.i.x==20){return p.i.x+p.i.y;}return 0;}");
 value(b"module main;struct I{i32 x;i32 y;}struct R{u8 head;I i;i32 tail;}fn i32 main(){var R p=R{.head=0,.i=I{.x=20,.y=0},.tail=0};let Option<i32> f=.some(1);p.i=I{.x=p.i.x,.y=switch(f){case .some(_):{p=R{.head=17,.i=I{.x=0,.y=0},.tail=23};22}case .none:{0}}};if(p.head==17 && p.tail==23){return p.i.x+p.i.y;}return 0;}");
}
@test
fn void deep_targets_snapshot_binding_path_and_inline_children() {
 value(b"module main;struct I{i32 x;}struct C{I a;I b;}struct R{u8 head;C c;i32 tail;}fn i32 main(){var R p=R{.head=17,.c=C{.a=I{.x=20},.b=I{.x=22}},.tail=23};p.c=C{.a=p.c.b,.b=p.c.a};if(p.head==17 && p.tail==23 && p.c.a.x==22 && p.c.b.x==20){return p.c.a.x+p.c.b.x;}return 0;}");
 value(b"module main;struct I{i32 x;}struct C{I a;I b;}struct R{u8 head;C c;i32 tail;}fn i32 main(){var R p=R{.head=17,.c=C{.a=I{.x=0},.b=I{.x=20}},.tail=23};p.c.a=I{.x=p.c.b.x+22};if(p.head==17 && p.tail==23 && p.c.b.x==20){return p.c.a.x;}return 0;}");
 value(b"module main;struct I{i32 x;}struct C{I a;I b;}struct R{C c;}fn i32 main(){let I I=I{.x=20};var R p=R{.c=C{.a=I{.x=0},.b=I{.x=0}}};p.c=C{.a=I,.b=I{.x=22}};return p.c.a.x+p.c.b.x;}");
}
@test
fn void early_return_break_and_continue_skip_outer_commit() {
 value(b"module main;struct I{i32 x;i32 y;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=40,.y=2}};let Option<i32> f=.some(1);p.i=I{.x=0,.y=switch(f){case .some(_):{let i32[1] a=[2;1];return p.i.x+a[0];}case .none:{0}}};return 0;}");
 value(b"module main;struct I{i32 x;i32 y;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=20,.y=22}};let Option<i32> f=.some(1);while(true){let i32[1] a=[0;1];p.i=I{.x=0,.y=switch(f){case .some(_):{break;}case .none:{0}}};}return p.i.x+p.i.y;}");
 value(b"module main;struct I{i32 x;i32 y;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=40,.y=0}};var i32 n=0;let Option<i32> f=.some(1);while(n<2){let i32[1] a=[1;1];p.i=I{.x=0,.y=switch(f){case .some(_):{n=n+a[0];continue;}case .none:{0}}};}return p.i.x+n;}");
 value(b"module main;struct I{i32 x;}struct R{i32 head;I i;}fn i32 main(){var R p=R{.head=0,.i=I{.x=2}};let Option<i32> f=.some(1);while(true){p.i=I{.x=switch(f){case .some(_):{p.head=40;break;}case .none:{0}}};}return p.head+p.i.x;}");
}
@test
fn void one_subreplace_uses_the_existing_site_extent_and_full_owner_table() {
 let ir::Program p=compiled(b"module main;struct I{i32 x;}struct R{i32 head;I i;i32 tail;}fn i32 main(){var R p=R{.head=17,.i=I{.x=0},.tail=23};p.i=I{.x=42};return p.i.x;}");
 assert(verifier::verify(ref p).is_ok && p.records.count==1 && p.arrays.count==0);
 var usize at=0;var usize replacements=0;var usize inits=0;
 while(at<p.count){let u8 op=p.code[at*8];assert(op!=42 && op!=44 && op!=46 && op!=47 && op!=48);if(op==49){replacements+=1;assert(p.code[at*8+1]==0 && p.code[at*8+3]==0 && p.code[at*8+4]==1);}if(op==41){inits+=1;}at+=1;}
 assert(replacements==1 && inits==1);
 assert(switch(vm::run_with_array_limit(ref p,2000000,12)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,174622,12)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,174621,12)){case .err(e):{e.kind==8}case .ok(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,2000000,11)){case .err(e):{e.kind==13}case .ok(_):{false}});
 let ir::Program full=compiled(b"module main;struct I{i32 x;}struct R{i32 head;I i;i32 tail;}fn i32 main(){let i32[1] a0=[0;1];let i32[1] a1=[0;1];let i32[1] a2=[0;1];let i32[1] a3=[0;1];let i32[1] a4=[0;1];let i32[1] a5=[0;1];let i32[1] a6=[0;1];let i32[1] a7=[0;1];let i32[1] a8=[0;1];let i32[1] a9=[0;1];let i32[1] a10=[0;1];let i32[1] a11=[0;1];let i32[1] a12=[0;1];let i32[1] a13=[0;1];let i32[1] a14=[0;1];var R p=R{.head=17,.i=I{.x=0},.tail=23};p.i=I{.x=42};return p.i.x;}");
 assert(verifier::verify(ref full).is_ok && full.arrays.count==15 && full.records.count==1);
 assert(switch(vm::run_with_array_limit(ref full,2000000,72)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void immutable_wrong_nominal_scalar_targets_and_headers_remain_rejected() {
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=0}};p.i=I{.x=42};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};p.i=J{.x=42};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};p.i.x=I{.x=42};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};p.i=I{.x=true};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct I{i32 x;}struct R{I i;}fn i32 main(){var R p=R{.i=I{.x=0}};for(;false;p.i=I{.x=42}){}return 42;}").is_ok);
 value(b"module main;struct I{i32 x;}struct R{I i;}fn i32 helper(){var R p=R{.i=I{.x=0}};p.i=I{.x=42};return p.i.x;}fn i32 main(){return helper();}");
}
