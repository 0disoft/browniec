module tests::m2::struct_replace_source;
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
fn void replacement_preserves_all_scalar_extremes_and_types() {
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 main(){var P p=P{.a=false,.b=0,.c=0,.d=0,.e=0,.f=0};p=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}");
}
@test
fn void self_reads_are_staged_in_order_before_replacement() {
 value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=22};p=P{.x=p.y,.y=p.x};if(p.x==22 && p.y==20){return p.x+p.y;}return 0;}");
 value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=0};var i32 n=0;let Option<i32> f=.some(1);p=P{.x=switch(f){case .some(_):{n=n+1;p.x}case .none:{0}},.y=switch(f){case .some(_):{n=n+1;p.x=99;22}case .none:{0}}};if(n==2 && p.x==20){return p.x+p.y;}return 0;}");
 value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=22};let Option<i32> f=.some(1);p=P{.x=p.x,.y=switch(f){case .some(_):{p=P{.x=0,.y=0};22}case .none:{0}}};return p.x+p.y;}");
}
@test
fn void nested_child_snapshots_and_type_name_bindings_work() {
 value(b"module main;struct I{i32 x;}struct R{I left;I right;}fn i32 main(){var R p=R{.left=I{.x=20},.right=I{.x=22}};p=R{.left=p.right,.right=p.left};if(p.left.x==22 && p.right.x==20){return p.left.x+p.right.x;}return 0;}");
 value(b"module main;struct I{i32 x;}struct R{I i;i32 tail;}fn i32 main(){var I q=I{.x=20};var R p=R{.i=I{.x=0},.tail=0};let Option<i32> f=.some(1);p=R{.i=q,.tail=switch(f){case .some(_):{q.x=0;22}case .none:{0}}};return p.i.x+p.tail;}");
 value(b"module main;struct P{i32 x;}fn i32 main(){var P P=P{.x=0};P=P{.x=42};return P.x;}");
}
@test
fn void early_transfers_skip_replacement_and_preserve_rhs_effects() {
 value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=40,.y=2};let Option<i32> f=.some(1);p=P{.x=0,.y=switch(f){case .some(_):{let i32[1] a=[2;1];return p.x+a[0];}case .none:{0}}};return 0;}");
 value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=22};let Option<i32> f=.some(1);while(true){let i32[1] a=[0;1];p=P{.x=0,.y=switch(f){case .some(_):{break;}case .none:{0}}};}return p.x+p.y;}");
 value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=40,.y=0};var i32 n=0;let Option<i32> f=.some(1);while(n<2){let i32[1] a=[1;1];p=P{.x=0,.y=switch(f){case .some(_):{n=n+a[0];continue;}case .none:{0}}};}return p.x+n;}");
 value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=0,.y=2};let Option<i32> f=.some(1);while(true){p=P{.x=0,.y=switch(f){case .some(_):{p.x=40;break;}case .none:{0}}};}return p.x+p.y;}");
}
@test
fn void one_existing_site_and_extent_emit_one_atomic_instruction() {
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p=P{.x=42};return p.x;}");
 assert(verifier::verify(ref p).is_ok && p.records.count==1 && p.arrays.count==0);
 var usize at=0;var usize replacements=0;var usize inits=0;
 while(at<p.count){let u8 op=p.code[at*8];assert(op!=42 && op!=44 && op!=46 && op!=47);if(op==48){replacements+=1;assert(p.code[at*8+1]==0 && p.code[at*8+3]==0);}if(op==41){inits+=1;}at+=1;}
 assert(replacements==1 && inits==1);
 assert(switch(vm::run_with_array_limit(ref p,2000000,4)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,2000000,3)){case .err(e):{e.kind==13}case .ok(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,133648,4)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,133647,4)){case .err(e):{e.kind==8}case .ok(_):{false}});
 assert(switch(vm::run(ref p,0)){case .err(e):{e.kind==8}case .ok(_):{false}});
 let ir::Program full=compiled(b"module main;struct P{i32 x;}fn i32 main(){let i32[1] a0=[0;1];let i32[1] a1=[0;1];let i32[1] a2=[0;1];let i32[1] a3=[0;1];let i32[1] a4=[0;1];let i32[1] a5=[0;1];let i32[1] a6=[0;1];let i32[1] a7=[0;1];let i32[1] a8=[0;1];let i32[1] a9=[0;1];let i32[1] a10=[0;1];let i32[1] a11=[0;1];let i32[1] a12=[0;1];let i32[1] a13=[0;1];let i32[1] a14=[0;1];var P p=P{.x=0};p=P{.x=42};return p.x;}");
 assert(verifier::verify(ref full).is_ok && full.arrays.count==15 && full.records.count==1);
 assert(switch(vm::run_with_array_limit(ref full,2000000,64)){case .ok(n):{n==42}case .err(_):{false}});
 let ir::Program sites=compiled(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};let P q0=p;let P q1=p;let P q2=p;let P q3=p;let P q4=p;let P q5=p;let P q6=p;let P q7=p;let P q8=p;let P q9=p;let P q10=p;let P q11=p;let P q12=p;let P q13=p;let P q14=p;p=P{.x=42};return p.x;}");
 assert(verifier::verify(ref sites).is_ok && sites.records.count==16);
 assert(switch(vm::run_with_array_limit(ref sites,2000000,64)){case .ok(n):{n==42}case .err(_):{false}});

}
@test
fn void immutable_nominal_field_and_header_errors_remain_rejected() {
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=0};p=P{.x=42};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){var P p=P{.x=0};p=Q{.x=42};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=0,.y=0};p=P{.y=22,.x=20};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p=P{.x=true};return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};for(;false;p=P{.x=42}){}return 42;}").is_ok);
 value(b"module main;struct P{i32 x;}fn i32 helper(){var P p=P{.x=0};p=P{.x=42};return p.x;}fn i32 main(){return helper();}");
}
