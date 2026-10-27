module tests::m2::struct_function_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
 return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source) {
 let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,3000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void scalar_fields_and_function_owned_sites_execute() {
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 helper(){var P p=P{.a=false,.b=0,.c=0,.d=0,.e=0,.f=0};p.a=true;p.b=255;p.c=-2147483648;p.d=-9223372036854775808;p.e=4294967295;p.f=18446744073709551615;if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}fn i32 main(){return helper();}");
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=20};return p.x+helper();}fn i32 helper(){let P p=P{.x=10};return p.x+last();}fn i32 last(){let P p=P{.x=12};return p.x;}");
 assert(p.records.count==3 && p.record_functions[0]==0 && p.record_functions[1]==1 && p.record_functions[2]==2);
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,3000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void nested_copies_extraction_and_replacement_stay_in_the_callee() {
 value(b"module main;struct I{i32 x;}struct R{I a;I b;}fn i32 helper(){var R p=R{.a=I{.x=20},.b=I{.x=22}};let R q=p;let I child=p.a;p.a=q.b;p.b=I{.x=child.x};p=R{.a=p.b,.b=q.b};p.a.x=20;return p.a.x+p.b.x;}fn i32 main(){let I p=I{.x=0};return helper()+p.x;}");
 value(b"module main;struct P{i32 x;}fn i32 helper(){var P p=P{.x=20};let P q=P{.x=22};p=q;return p.x+20;}fn i32 main(){return helper();}");
}
@test
fn void recursive_forward_and_mutual_calls_preserve_caller_fields() {
 value(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=14};return sum(7)+p.x;}fn i32 sum(i32 n){let P p=P{.x=n};if(n==0){return p.x;}return sum(n-1)+p.x;}");
 value(b"module main;struct P{i32 x;}fn i32 a(i32 n){let P p=P{.x=6};if(n==0){return p.x;}return b(n-1)+p.x;}fn i32 b(i32 n){let P p=P{.x=6};if(n==0){return p.x;}return a(n-1)+p.x;}fn i32 main(){return a(6);}");
}
@test
fn void lexical_returns_propagation_and_array_results_clean_up() {
 value(b"module main;struct P{i32 x;}fn Option<i32> helper(Option<i32> arg){let P p=P{.x=42};let i32 n=arg?;return .some(p.x+n);}fn i32 main(){let Option<i32> miss=helper(.none);let Option<i32> good=helper(.some(0));return switch(miss){case .none:{switch(good){case .some(n):{n}case .none:{0}}}case .some(_):{0}};}");
 value(b"module main;struct P{i32 x;}fn i32[1] helper(){let P p=P{.x=42};let i32[1] a=[p.x;1];return a;}fn i32 main(){let P p=P{.x=0};let i32[1] a=helper();return a[0]+p.x;}");
 value(b"module main;struct P{i32 x;}fn i32[1] helper(){let P p=P{.x=42};return [p.x;1];}fn i32 main(){let i32[1] a=helper();return a[0];}");
 value(b"module main;struct P{i32 x;}fn i32[1] inner(i32 n){return [n;1];}fn i32[1] helper(){let P p=P{.x=42};return inner(p.x);}fn i32 main(){let i32[1] a=helper();return a[0];}");
 value(b"module main;struct P{i32 x;}fn i32 helper(){let P outer=P{.x=42};let Option<i32> f=.some(1);let P pending=P{.x=switch(f){case .some(_):{return outer.x;}case .none:{0}}};return 0;}fn i32 main(){return helper();}");
 value(b"module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=40};var i32 n=0;while(n<2){let i32[1] a=[1;1];let P q=P{.x=a[0]};n=n+q.x;continue;}while(true){let P q=P{.x=0};let i32[1] a=[q.x;1];break;}return p.x+n;}fn i32 main(){return helper();}");
}
@test
fn void exact_fuel_payload_and_shared_owner_limits_are_enforced() {
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};return p.x;}fn i32 main(){return helper();}");
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run_with_array_limit(ref p,87502,4)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,87501,4)){case .err(e):{e.kind==8}case .ok(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,3000000,3)){case .err(e):{e.kind==13}case .ok(_):{false}});
 let ir::Program deep=compiled(b"module main;struct P{i32 x;}fn i32 sum(i32 n){let P p=P{.x=n};if(n==0){return p.x;}return sum(n-1)+p.x;}fn i32 main(){return sum(8)+6;}");
 assert(switch(vm::run_with_array_limit(ref deep,3000000,36)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref deep,3000000,35)){case .err(e):{e.kind==13}case .ok(_):{false}});
 let ir::Program full=compiled(b"module main;struct P{i32 x;}fn i32 helper(i32 n){let P p=P{.x=0};if(n==0){return 42;}return helper(n-1)+p.x;}fn i32 main(){let i32[1] a=[0;1];return helper(14)+a[0];}");
 assert(switch(vm::run_with_array_limit(ref full,3000000,64)){case .ok(n):{n==42}case .err(_):{false}});
 let ir::Program over=compiled(b"module main;struct P{i32 x;}fn i32 helper(i32 n){let P p=P{.x=0};if(n==0){return 42;}return helper(n-1)+p.x;}fn i32 main(){let i32[1] a=[0;1];return helper(15)+a[0];}");
 assert(switch(vm::run_with_array_limit(ref over,3000000,128)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void signatures_borrows_scope_and_entry_reentry_remain_rejected() {
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(P p){return p.x;}fn i32 main(){return helper(P{.x=42});}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn P helper(){let P p=P{.x=42};return p;}fn i32 main(){return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(ref P p){return p.x;}fn i32 main(){return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};p.x=0;return p.x;}fn i32 main(){return helper();}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(){for(let P p=P{.x=0};false;){}return 42;}fn i32 main(){return helper();}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(){{let P p=P{.x=42};}return p.x;}fn i32 main(){return helper();}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};return main();}fn i32 main(){return helper();}").is_ok);
}
