module tests::m2::struct_result_arguments;
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
fn void forward_nested_nominal_results_and_scalar_extrema() {
 value(b"module main;fn i32 main(){return take(make());}fn i32 take(P p){return p.x;}fn P make(){return P{.x=42};}struct P{i32 x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn R make(){return R{.p=P{.x=42}};}fn i32 take(R r){return r.p.x;}fn i32 main(){return take(make());}",128);
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn P make(){return P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};}fn i32 take(P p){if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}fn i32 main(){return take(make());}",128);
}

@test
fn void nested_record_calls_and_array_or_wrapper_consumers() {
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn P id(P p){return p;}fn i32 main(){let P p=id(id(make()));return p.x;}",128);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32[1] take(P p){return [p.x;1];}fn i32 main(){let i32[1] a=take(make());return a[0];}",128);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn Option<i32> take(P p){return .some(p.x);}fn i32 main(){switch(take(make())){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void earlier_results_and_mixed_arguments_survive_later_mutation() {
 value(b"module main;struct P{i32 x;}fn P pick(P p){return p;}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){var P p=P{.x=20};let Option<i32> o=.none;return take(pick(p),switch(o){case .some(v):{v}case .none:{p.x=0;22}});}",128);
 value(b"module main;struct P{i32 x;}fn P pick(P p){return p;}fn P last(i32 n){return P{.x=n};}fn i32 take(P first,i32[1] a,P last,i32 n){return first.x*10+a[0]+last.x+n;}fn i32 main(){var P p=P{.x=2};var i32[1] a=[1;1];let Option<i32> o=.none;return take(pick(p),a,last(switch(o){case .some(v):{v}case .none:{p.x=4;a[0]=0;4}}),17);}",128);
}

@test
fn void early_scalar_record_and_propagation_exits_drop_ready_results() {
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p,i32 n){return 0;}fn i32 main(){let i32[1] a=[0;1];let Option<i32> o=.none;return take(make(),switch(o){case .some(v):{v}case .none:{return 42;}});}",128);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn P take(P p,i32 n){return p;}fn P outer(){let P keep=P{.x=42};let Option<i32> o=.none;return take(make(),switch(o){case .some(v):{v}case .none:{return keep;}});}fn i32 main(){let P p=outer();return p.x;}",128);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p,i32 n){return p.x;}fn Option<i32> f(Option<i32> o){return .some(take(make(),o?));}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void outer_loop_transfers_drop_results_and_inner_loops_preserve_them() {
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p,i32 n){return 0;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let i32 k=take(make(),switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return n+40;}",128);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;while(true){let i32 k=take(make(),switch(o){case .some(v):{v}case .none:{break;}});}return 42;}",128);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p,i32 n){return p.x;}fn i32 main(){let Option<i32> o=.none;return take(make(),switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}n}});}",128);
}

@test
fn void repeated_calls_match_named_ir_and_require_live_argument_and_formal() {
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){var i32 n=0;while(n<2){if(take(make())!=42){return 0;}n=n+1;}return 42;}",128);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make());}");
 let ir::Program named=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){let P temporary=make();return take(temporary);}");
 assert(p.count==named.count && p.records.count==named.records.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){assert(p.code[pc*8]!=42);pc+=1;}
 let usize temporary=p.code[pc*8+1] as usize-144;
 pc+=1;while(pc<p.count && p.code[pc*8]!=9){assert(p.code[pc*8]!=42);pc+=1;}
 assert(pc+1<p.count && p.code[(pc+1)*8]==45 && p.code[(pc+1)*8+1] as usize==temporary);
 var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void invalid_nested_results_and_unsupported_aggregate_forms_fail() {
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn Q make(){return Q{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make());}");
 rejected(b"module main;struct P{i32 x;}fn i32 make(){return 42;}fn i32 take(P p){return p.x;}fn i32 main(){return take(make());}");
 rejected(b"module main;struct P{i32 x;}fn i32[1] make(){return [42;1];}fn i32 take(P p){return p.x;}fn i32 main(){return take(make());}");
 rejected(b"module main;struct P{i32 x;}fn Option<i32> make(){return .some(42);}fn i32 take(P p){return p.x;}fn i32 main(){return take(make());}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take(missing());}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){let i32 make=0;return take(make());}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make(1));}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 take(P p){return p.x;}fn i32 main(){let R r=R{.p=P{.x=42}};return take(r.p.x);}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().x);}");
}

// Grouping now preserves the same complete record value in these contexts.
@test fn void grouped_record_forms_now_compile_in_existing_contexts(){
    assert(compiler::compile(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){return take((make()));}").is_ok);
    assert(compiler::compile(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take((P{.x=42}));}").is_ok);
    assert(compiler::compile(b"module main;struct P{i32 x;}fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take((make()));}").is_ok);
}
