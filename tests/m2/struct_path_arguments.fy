module tests::m2::struct_path_arguments;
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
fn void forward_deep_paths_and_scalar_extrema() {
 value(b"module main;fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p);}fn i32 take(P p){return p.x;}struct P{i32 x;}struct R{P p;}",128);
 value(b"module main;struct P{i32 x;}struct R{u8 head;P p;i32 tail;}struct T{u8 lead;R r;}fn i32 take(P p){return p.x;}fn i32 main(){let T t=T{.lead=255,.r=R{.head=1,.p=P{.x=42},.tail=0}};return take(t.r.p);}",128);
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{u8 head;P p;}fn i32 take(P p){if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}fn i32 main(){let R r=R{.head=255,.p=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615}};return take(r.p);}",128);
}

@test
fn void mutable_sources_formals_and_array_or_wrapper_consumers() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){var R r=R{.p=P{.x=20}};let Option<i32> o=.none;return take(r.p,switch(o){case .some(v):{v}case .none:{r.p.x=0;22}});}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P id(P p){return p;}fn P pick(R r){return id(r.p);}fn i32[1] take(P p){return [p.x;1];}fn i32 main(){let R r=R{.p=P{.x=42}};let P p=pick(r);let i32[1] a=take(r.p);return p.x+a[0]-42;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn Option<i32> take(P p){return .some(p.x);}fn i32 main(){let R r=R{.p=P{.x=42}};switch(take(r.p)){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void mixed_arguments_and_earlier_captures_preserve_evaluation_order() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P make(i32 n){return P{.x=n};}fn i32 take(P p,i32[1] a,P q,i32 n){return p.x*10+a[0]+q.x+n;}fn i32 main(){var R r=R{.p=P{.x=2}};var i32[1] a=[1;1];let Option<i32> o=.none;return take(r.p,a,make(switch(o){case .some(v):{v}case .none:{r.p.x=0;a[0]=0;4}}),17);}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p,P q){return p.x+q.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p,r.p)-42;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P id(P p){return p;}fn i32 take(P p,P q,i32 n){return p.x+q.x+n;}fn i32 main(){var R r=R{.p=P{.x=20}};let Option<i32> o=.none;return take(id(r.p),r.p,switch(o){case .some(v):{v}case .none:{r.p.x=0;2}});}",128);
}

@test
fn void early_scalar_record_and_propagation_exits_drop_path_captures() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p,i32 n){return 0;}fn i32 main(){let R r=R{.p=P{.x=42}};let i32[1] a=[0;1];let Option<i32> o=.none;return take(r.p,switch(o){case .some(v):{v}case .none:{return 42;}});}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(P p,i32 n){return p;}fn P outer(){let R r=R{.p=P{.x=42}};let P keep=P{.x=42};let Option<i32> o=.none;return take(r.p,switch(o){case .some(v):{v}case .none:{return keep;}});}fn i32 main(){let P p=outer();return p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p,i32 n){return p.x;}fn Option<i32> f(Option<i32> o){let R r=R{.p=P{.x=42}};return .some(take(r.p,o?));}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void loop_transfers_ir_equivalence_and_three_live_extents() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p,i32 n){return 0;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let R r=R{.p=P{.x=42}};let i32 k=take(r.p,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return n+40;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;while(true){let R r=R{.p=P{.x=42}};let i32 k=take(r.p,switch(o){case .some(v):{v}case .none:{break;}});}return 42;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p,i32 n){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};let Option<i32> o=.none;return take(r.p,switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}n}});}",128);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p);}");
 let ir::Program named=compiled(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};let P temporary=r.p;return take(temporary);}");
 assert(p.count==named.count && p.records.count==named.records.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,12)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,11)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
 assert(pc+1<p.count && p.code[(pc+1)*8]==45);
 var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void wrong_endpoints_and_general_argument_expressions_are_rejected() {
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{Q p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=Q{.x=42}};return take(r.p);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p.x);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.missing);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let i32 r=0;return take(r.p);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){return take(missing.p);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let Option<i32> r=.none;return take(r.p);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(R r){return r.p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p as P);}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p==r.p);}");
}

// Grouping now preserves the same complete record value in these contexts.
@test fn void grouped_record_forms_now_compile_in_existing_contexts(){
    assert(compiler::compile(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take((r.p));}").is_ok);
    assert(compiler::compile(b"module main;struct P{i32 x;}struct R{P p;}fn R make(){return R{.p=P{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){return take((make().p));}").is_ok);
    assert(compiler::compile(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){return take((P{.x=42}));}").is_ok);
}
