module tests::m2::struct_result_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void value(ref u8[] source,usize limit){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,16000000,limit)){case .ok(n):{n==42}case .err(_):{false}});}
fn void rejected(ref u8[] source){assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==3}});}

@test
fn void flat_nested_and_forward_factories_return_exact_nominal_values(){
 value(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn i32 main(){let P p=make();return p.x;}",4);
 value(b"module main;fn i32 main(){let R r=make();return r.a.x+r.b.x;}fn R make(){let R r=R{.a=P{.x=20},.b=P{.x=22}};return r;}struct R{P a;P b;}struct P{i32 x;}",8);
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn P make(){let P p=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};return p;}fn i32 main(){let P p=make();if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}",32);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P make(){let P p=P{.x=42};return p;}fn i32 main(){let P p=make();return p.x;}");
 assert(p.return_types[0]==0 && p.record_results[0]==1 && p.records.count==3);var usize pc=0;var usize returns=0;
 while(pc<p.count){if(p.code[pc*8]==50){returns+=1;}pc+=1;}assert(returns==1);
}
@test
fn void returned_formals_reuse_the_anchor_and_caller_mutability_is_independent(){
 value(b"module main;struct P{i32 x;}fn P id(P p){return p;}fn i32 main(){let P p=P{.x=42};var P q=id(p);q.x=0;return p.x;}",8);
 value(b"module main;struct P{i32 x;}fn P make(){var P p=P{.x=0};p.x=42;return p;}fn i32 main(){let P q=make();return q.x;}",4);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P id(P p){return p;}fn i32 main(){let P p=P{.x=42};let P q=id(p);return q.x;}");
 assert(p.record_results[0]==p.record_parameters[0] && p.records.count==3 && p.types[0]==0);
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
@test
fn void mixed_parameter_and_local_cleanup_retains_only_the_selected_record(){
 value(b"module main;struct P{i32 x;}fn P make(P p,i32[1] a,i32 n){let P local=p;let i32[1] scratch=[n;1];let P answer=P{.x=local.x+a[0]};return answer;}fn i32 main(){let P p=P{.x=20};let i32[1] a=[22;1];let P q=make(p,a,0);return q.x;}",28);
 value(b"module main;struct P{i32 x;}fn P make(){let i32[1] a=[0;1];let P p=P{.x=0};let P q=P{.x=42};return q;}fn i32 main(){var i32 i=0;while(i<2){let P p=make();if(p.x!=42){return 0;}i=i+1;}return 42;}",12);
}
@test
fn void recursive_and_mutual_source_calls_forward_named_results(){
 value(b"module main;struct P{i32 x;}fn P make(i32 n){if(n==0){let P p=P{.x=42};return p;}let P q=make(n-1);return q;}fn i32 main(){let P p=make(2);return p.x;}",4);
 value(b"module main;struct P{i32 x;}fn P f(i32 n){if(n==0){let P p=P{.x=42};return p;}let P q=g(n-1);return q;}fn P g(i32 n){if(n==0){let P p=P{.x=42};return p;}let P q=f(n-1);return q;}fn i32 main(){let P p=f(3);return p.x;}",4);
}
@test
fn void pending_destinations_and_snapshots_are_absent_on_early_returns_and_propagation(){
 value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){var P p=P{.x=1};let Option<i32> o=.none;let P q=take(p,switch(o){case .some(v):{v}case .none:{return 42;}});return q.x;}",8);
 value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn P outer(P p){let Option<i32> o=.none;let P q=take(p,switch(o){case .some(v):{v}case .none:{return p;}});return q;}fn i32 main(){let P p=P{.x=42};let P q=outer(p);return q.x;}",8);
 value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn Option<i32> f(Option<i32> x){var P p=P{.x=42};let P q=take(p,x?);return .some(q.x);}fn i32 main(){var i32 i=0;while(i<2){switch(f(.none)){case .some(v):{return 0;}case .none:{i=i+1;}}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",12);
}
@test
fn void loop_transfers_discard_pending_results_and_release_or_preserve_captures(){
 value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){var i32 i=0;while(i<2){var P p=P{.x=1};let Option<i32> o=.none;let P q=take(p,switch(o){case .some(v):{v}case .none:{i=i+1;continue;}});}return i+40;}",8);
 value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){while(true){var P p=P{.x=1};let Option<i32> o=.none;let P q=take(p,switch(o){case .some(v):{v}case .none:{break;}});}return 42;}",8);
 value(b"module main;struct P{i32 x;}fn P take(P p,i32 n){return p;}fn i32 main(){var P p=P{.x=42};let Option<i32> o=.none;let P q=take(p,switch(o){case .some(v):{v}case .none:{var i32 i=0;while(i<1){i=i+1;continue;}i}});return q.x;}",12);
}
@test
fn void nominal_mismatches_scalar_contexts_and_unimplemented_return_forms_fail(){
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn P f(){let Q q=Q{.x=42};return q;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn P f(){let P p=P{.x=42};return p;}fn i32 main(){let Q q=f();return q.x;}");
 rejected(b"module main;struct P{i32 x;}fn P f(){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P f(){let i32[1] a=[42;1];return a;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P f(P p){return p;}fn i32 main(){let P p=P{.x=42};return f(p);}");
 rejected(b"module main;struct P{i32 x;}fn P f(P p){return p;}fn i32 main(){let P p=P{.x=42};let i32 n=f(p);return n;}");
 rejected(b"module main;struct P{i32 x;}fn P f(P p){let Option<i32> o=.some(0);let i32 n=o?;return p;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P f(P p){for(let P q=p;false;){}return p;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P f(P p){return p;}fn i32 main(){let P p=f(p);return p.x;}");
 rejected(b"module main;struct P{i32 x;}fn P f(P p){return p;}fn i32 main(){let P f=P{.x=42};let P q=f(f);return q.x;}");
 rejected(b"module main;struct P{i32 x;}fn P f(P p){return p;}fn i32 main(){let P p=P{.x=42};let P q=f(p);q.x=0;return 42;}");
}
@test
fn void result_and_parameter_sites_keep_the_existing_sixteen_site_bound(){
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P f(){let P p=P{.x=42};return p;}fn i32 main(){let P v0=f();let P v1=f();let P v2=f();let P v3=f();let P v4=f();let P v5=f();let P v6=f();let P v7=f();let P v8=f();let P v9=f();let P v10=f();let P v11=f();let P v12=f();let P v13=f();return v13.x;}");assert(p.records.count==16 && verifier::verify(ref p).is_ok);
 assert(switch(compiler::compile(b"module main;struct P{i32 x;}fn P f(){let P p=P{.x=42};return p;}fn i32 main(){let P v0=f();let P v1=f();let P v2=f();let P v3=f();let P v4=f();let P v5=f();let P v6=f();let P v7=f();let P v8=f();let P v9=f();let P v10=f();let P v11=f();let P v12=f();let P v13=f();let P extra=f();return extra.x;}")){case .ok(_):{false}case .err(e):{e.kind==4}});
}
