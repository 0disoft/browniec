module tests::m2::struct_parameters_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void value(ref u8[] source,usize limit){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,16000000,limit)){case .ok(n):{n==42}case .err(_):{false}});}
fn void rejected(ref u8[] source){assert(!compiler::compile(source).is_ok);}
@test
fn void scalar_and_nested_record_formals_bind_nominal_immutable_sites(){
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 take(P p){if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}fn i32 main(){let P p=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};return take(p);}",128);
 value(b"module main;struct I{i32 x;}struct R{I a;I b;}fn i32 take(R r){let I a=r.a;var R q=r;q.a.x=0;return r.a.x+r.b.x;}fn i32 main(){let R r=R{.a=I{.x=20},.b=I{.x=22}};return take(r);}",64);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let P p=P{.x=42};return take(p);}");
 assert(p.records.count==2 && p.record_parameters[0]==1 && p.types[0]==0 && !p.records.mutable[0]);var usize pc=0;var usize copies=0;while(pc<p.count){if(p.code[pc*8]==42){copies+=1;}pc+=1;}assert(copies==0);
}
@test
fn void mutable_record_arguments_capture_before_later_argument_effects(){
 value(b"module main;struct P{i32 x;}fn i32 take(P before,i32 stamp,P after){return before.x*10+stamp+after.x;}fn i32 main(){var P p=P{.x=2};var i32 n=0;let Option<i32> o=.none;let i32 r=take(p,switch(o){case .some(v):{v}case .none:{n=n+1;p.x=4;18}},p);return r+n-1;}",20);
 value(b"module main;struct P{i32 x;}fn i32 take(P p){var P q=p;q.x=0;return p.x;}fn i32 main(){var P p=P{.x=42};return take(p);}",16);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){var P p=P{.x=42};return take(p);}");var usize pc=0;var usize copies=0;while(pc<p.count){if(p.code[pc*8]==42){copies+=1;}pc+=1;}assert(copies==1);
 assert(switch(vm::run_with_array_limit(ref p,4000000,11)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void forward_recursive_and_mutual_calls_keep_each_invocations_record(){
 value(b"module main;fn i32 main(){let P p=P{.x=7};return sum(p,5);}fn i32 sum(P p,i32 n){if(n==0){return p.x;}return p.x+sum(p,n-1);}struct P{i32 x;}",28);
 value(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=7};return f(p,5);}fn i32 f(P p,i32 n){if(n==0){return p.x;}return p.x+g(p,n-1);}fn i32 g(P p,i32 n){if(n==0){return p.x;}return p.x+f(p,n-1);}",28);
 value(b"module main;struct P{i32 x;}fn i32 one(){let P p=P{.x=0};return p.x;}fn i32 two(i32 n,P p){let P q=p;return q.x+n;}fn i32 main(){let P p=P{.x=42};return one()+two(0,p);}",12);
}
@test
fn void mixed_scalar_array_record_parameters_and_array_results_compose(){
 value(b"module main;struct P{i32 x;}fn i32 take(i32 n,P p,i32[1] a){return p.x+a[0]+n;}fn i32 main(){var P p=P{.x=20};var i32[1] a=[22;1];return take(0,p,a);}",24);
 value(b"module main;struct P{i32 x;}fn i32[1] take(P p,i32[1] a){return [p.x+a[0];1];}fn i32 main(){let P p=P{.x=20};let i32[1] a=[22;1];let i32[1] b=take(p,a);return b[0];}",20);
 value(b"module main;struct P{i32 x;}fn i32[1] take(P p){return [p.x;1];}fn i32[1] forward(P p){return take(p);}fn i32 main(){let P p=P{.x=42};let i32[1] a=forward(p);return a[0];}",16);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){let P p=P{.x=21};return take(p,take(p,0));}",12);
}
@test
fn void propagation_and_early_returns_drop_formals_and_pending_captures(){
 value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x+n;}fn Option<i32> f(Option<i32> x){var P p=P{.x=21};let i32 n=take(p,take(p,x?));return .some(n);}fn i32 main(){var i32 i=0;while(i<42){switch(f(.none)){case .some(v):{return 0;}case .none:{i=i+1;}}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",16);
 value(b"module main;struct P{i32 x;}fn Option<i32> f(P p,Option<i32> x){return .some(p.x+x?);}fn i32 main(){let P p=P{.x=21};var i32 i=0;while(i<42){switch(f(p,.none)){case .some(v):{return 0;}case .none:{i=i+1;}}}switch(f(p,.some(21))){case .some(v):{return v;}case .none:{return 0;}}}",8);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){var P p=P{.x=1};let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{return 42;}});}",8);
}
@test
fn void outer_loop_transfers_drop_captures_and_inner_loops_preserve_them(){
 value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){var i32 i=0;while(i<42){var P p=P{.x=1};let Option<i32> o=.none;i=i+take(p,switch(o){case .some(v):{v}case .none:{i=i+1;continue;}});}return i;}",8);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){while(true){var P p=P{.x=1};let Option<i32> o=.none;let i32 n=take(p,switch(o){case .some(v):{v}case .none:{break;}});}return 42;}",8);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){var P p=P{.x=21};let Option<i32> o=.none;return take(p,switch(o){case .some(v):{v}case .none:{var i32 i=0;while(i<21){i=i+1;continue;}i}});}",12);
}
@test
fn void eight_forward_record_formals_share_catalog_and_owner_caps(){
 value(b"module main;struct P{i32 x;}fn i32 main(){let P a=P{.x=1};let P b=P{.x=2};let P c=P{.x=3};let P d=P{.x=4};let P e=P{.x=5};let P f=P{.x=6};let P g=P{.x=7};let P h=P{.x=8};return sum(a,b,c,d,e,f,g,h);}fn i32 sum(P a,P b,P c,P d,P e,P f,P g,P h){return a.x+b.x*2+c.x*3+d.x*4+e.x*5+f.x*6+g.x*7+h.x*8-162;}",64);
}
@test
fn void mismatched_nominal_types_writes_and_general_aggregate_arguments_stay_rejected(){
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let Q q=Q{.x=42};return take(q);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){p.x=0;return 42;}fn i32 main(){let P p=P{.x=42};return take(p);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){let P q=P{.x=0};p=q;return 42;}fn i32 main(){let P p=P{.x=42};return take(p);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p.x);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let i32[1] a=[42;1];return take(a);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(42);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(ref P p){return 42;}fn i32 main(){return 42;}");
 value(b"module main;struct P{i32 x;}fn P take(P p){return p;}fn i32 main(){return 42;}",4);
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){let P p=P{.x=42};return p.x;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let P p=P{.x=42};for(var i32 n=take(p);n<1;n=n+1){}return 42;}");
}
