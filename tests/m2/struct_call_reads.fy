module tests::m2::struct_call_reads;
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
fn void forward_deep_paths_scalar_types_and_operators() {
 value(b"module main;fn i32 main(){return make().x;}struct P{i32 x;}fn P make(){return P{.x=42};}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}struct S{R child;}fn S make(){return S{.child=R{.child=P{.x=42}}};}fn i32 main(){return make().child.child.x;}",4);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=21};}fn i32 main(){return -make().x+63;}",4);
 value(b"module main;struct P{usize x;}fn P make(){return P{.x=18446744073709551615};}fn i32 main(){if(make().x==18446744073709551615){return 42;}return 0;}",8);
}

@test
fn void mixed_argument_captures_nested_reads_and_single_evaluation() {
 value(b"module main;struct P{i32 x;}fn P make(i32 n){return P{.x=n};}fn i32 main(){var i32 n=0;let Option<i32> o=.none;return make(switch(o){case .some(v):{0}case .none:{n=n+1;41}}).x+n;}",4);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=22};}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){return take(P{.x=20},make().x);}",8);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=22};}fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){return take([20;1],make().x);}",8);
 value(b"module main;struct P{i32 x;}fn P make(i32 n){return P{.x=n};}fn i32 main(){return make(make(42).x).x;}",4);
 value(b"module main;struct P{usize x;}fn P make(){return P{.x=0};}fn i32[1] array(){return [42;1];}fn i32 main(){return array()[make().x];}",16);
}

@test
fn void scalar_consumers_pending_exits_and_immediate_payload_reuse() {
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn Option<i32> f(){return .some(make().x);}fn i32 main(){switch(f()){case .some(v):{return v;}case .none:{return 0;}}}",4);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn P outer(){return P{.x=make().x};}fn i32 main(){return outer().x;}",4);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=21};}fn i32 main(){return make().x+make().x;}",4);
 value(b"module main;struct P{i32 x;}fn P make(){return P{.x=1};}fn i32 main(){var i32 n=0;while(n<2){n=n+make().x;}return n+40;}",4);
 value(b"module main;struct P{i32 x;}fn P make(i32 n){return P{.x=n};}fn i32 main(){let Option<i32> o=.none;return make(switch(o){case .some(v):{0}case .none:{return 42;}}).x;}",0);
 value(b"module main;struct P{i32 x;}fn P make(i32 n){return P{.x=n};}fn i32 take(P p,i32 n){return n;}fn i32 main(){let Option<i32> o=.none;return take(P{.x=0},make(switch(o){case .some(v):{0}case .none:{return 42;}}).x);}",4);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){return make().x;}");
 let ir::Program named=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){let P p=make();return p.x;}");
 assert(p.count==named.count && p.records.count==named.records.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
 let ir::Program cap=compiled(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){let i32 n0=make().x;let i32 n1=make().x;let i32 n2=make().x;let i32 n3=make().x;let i32 n4=make().x;let i32 n5=make().x;let i32 n6=make().x;let i32 n7=make().x;let i32 n8=make().x;let i32 n9=make().x;let i32 n10=make().x;let i32 n11=make().x;let i32 n12=make().x;let i32 n13=make().x;return n13;}");
 assert(cap.records.count==16 && verifier::verify(ref cap).is_ok);
 assert(switch(vm::run_with_array_limit(ref cap,16000000,4)){case .ok(n):{n==42}case .err(_):{false}});

 var usize pc=0;while(pc<p.count && p.code[pc*8]!=45){pc+=1;}
 assert(pc<p.count);var ir::Program bad=p;bad.code[pc*8]=19;bad.code[pc*8+1]=0;
 assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void wrong_members_shadowing_nominal_endpoints_and_bare_results_fail() {
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){return make();}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){return make().other;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){return make().child;}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){let i32 make=0;return make().x;}");
 rejected(b"module main;struct P{i32 x;}fn P make(i32 n){return P{.x=n};}fn i32 main(){return make().x;}");
 rejected(b"module main;struct P{bool x;}fn P make(){return P{.x=true};}fn i32 main(){return make().x;}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().x);}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){return missing().x;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){return make().child.other;}");
}

// Grouping now preserves the same complete record value in these contexts.
@test fn void grouped_record_forms_now_compile_in_existing_contexts(){
    assert(compiler::compile(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){return (make()).x;}").is_ok);
}
