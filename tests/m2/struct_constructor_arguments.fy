module tests::m2::struct_constructor_arguments;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn ir::Program compiled(ref u8[] source) {
 return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source,usize limit) {
 let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run_with_array_limit(ref p,16000000,limit)){case .ok(n):{n==42}case .err(_):{false}});
}
fn void rejected(ref u8[] source) {
 assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==3}});
}

@test
fn void forward_nested_constructors_and_scalar_extrema() {
 value(b"module main;fn i32 main(){return take(P{.x=42});}fn i32 take(P p){return p.x;}struct P{i32 x;}",128);
 value(b"module main;struct P{i32 x;}struct R{u8 head;P p;}fn i32 take(R r){return r.p.x;}fn i32 main(){return take(R{.head=255,.p=P{.x=42}});}",128);
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 take(P p){if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}fn i32 main(){return take(P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615});}",128);
}

@test
fn void field_order_child_calls_and_mixed_argument_effects() {
 value(b"module main;struct P{i32 x;i32 y;}fn i32 take(P p,i32 n){return p.x+p.y+n;}fn i32 main(){var i32 x=20;let Option<i32> o=.none;return take(P{.x=x,.y=switch(o){case .some(v):{v}case .none:{x=0;22}}},x);}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;i32 tail;}fn P make(){return P{.x=20};}fn i32 take(R r){return r.p.x+r.tail;}fn i32 main(){let Option<i32> o=.none;return take(R{.p=make(),.tail=switch(o){case .some(v):{v}case .none:{22}}});}",128);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,i32[1] a,P q,i32 n){return p.x*10+a[0]+q.x+n;}fn i32 main(){var i32[1] a=[1;1];let Option<i32> o=.none;return take(P{.x=2},a,P{.x=switch(o){case .some(v):{v}case .none:{a[0]=0;4}}},17);}",128);
}

@test
fn void record_array_and_wrapper_returning_consumers() {
 value(b"module main;struct P{i32 x;}fn P id(P p){return p;}fn i32 main(){let P p=id(P{.x=42});return p.x;}",128);
 value(b"module main;struct P{i32 x;}fn i32[1] take(P p){return [p.x;1];}fn i32 main(){let i32[1] a=take(P{.x=42});return a[0];}",128);
 value(b"module main;struct P{i32 x;}fn Option<i32> take(P p){return .some(p.x);}fn i32 main(){switch(take(P{.x=42})){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void pending_constructor_and_prior_captures_cleanup_on_early_exits() {
 value(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let Option<i32> o=.none;return take(P{.x=switch(o){case .some(v):{v}case .none:{return 42;}}});}",128);
 value(b"module main;struct P{i32 x;}fn P take(P p){return p;}fn P outer(){let P keep=P{.x=42};let Option<i32> o=.none;return take(P{.x=switch(o){case .some(v):{v}case .none:{return keep;}}});}fn i32 main(){let P p=outer();return p.x;}",128);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,P q){return p.x+q.x;}fn Option<i32> f(Option<i32> o){return .some(take(P{.x=20},P{.x=o?}));}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void loop_transfers_ir_equivalence_and_two_live_extents() {
 value(b"module main;struct P{i32 x;}fn i32 take(P p,P q){return 0;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let i32 k=take(P{.x=0},P{.x=switch(o){case .some(v):{v}case .none:{n=n+1;continue;}}});}return n+40;}",128);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,P q){return 0;}fn i32 main(){let Option<i32> o=.none;while(true){let i32 k=take(P{.x=0},P{.x=switch(o){case .some(v):{v}case .none:{break;}}});}return 42;}",128);
 value(b"module main;struct P{i32 x;}fn i32 take(P p,P q){return p.x+q.x;}fn i32 main(){let Option<i32> o=.none;return take(P{.x=20},P{.x=switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}22}}});}",128);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(P{.x=42});}");
 let ir::Program named=compiled(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let P temporary=P{.x=42};return take(temporary);}");
 assert(p.count==named.count && p.records.count==named.records.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 let ir::Program pending=compiled(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let Option<i32> o=.none;return take(P{.x=switch(o){case .some(v):{v}case .none:{return 42;}}});}");
 assert(verifier::verify(ref pending).is_ok);
 assert(switch(vm::run_with_array_limit(ref pending,1000000,0)){case .ok(n):{n==42}case .err(_):{false}});
 let ir::Program child=compiled(b"module main;struct P{i32 x;}struct R{P p;i32 tail;}fn P make(){return P{.x=20};}fn i32 take(R r){return r.p.x+r.tail;}fn i32 main(){let Option<i32> o=.none;return take(R{.p=make(),.tail=switch(o){case .some(v):{v}case .none:{return 42;}}});}");
 assert(verifier::verify(ref child).is_ok);
 assert(switch(vm::run_with_array_limit(ref child,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
 var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
 assert(pc+1<p.count && p.code[(pc+1)*8]==45);
 var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void wrong_types_fields_and_general_expressions_remain_rejected() {
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(Q{.x=42});}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take((P{.x=42}));}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(P{.x=42}.x);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(P{.x=true});}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(P{.bad=42});}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(Missing{.x=42});}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(P{.x=42} as P);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(P{.x=42}==P{.x=42});}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(i32 p){return p;}fn i32 main(){return take(P{.x=42});}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){p.x=0;return p.x;}fn i32 main(){return take(P{.x=42});}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(P{.x=42},0);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}struct Q{i32 x;}fn i32 take(R r){return r.p.x;}fn i32 main(){return take(R{.p=Q{.x=42}});}");
}
