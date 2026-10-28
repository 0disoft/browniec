module tests::m2::array_literal_arguments;
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

fn void malformed(ref u8[] source) {
 assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==2}});
}

@test
fn void forward_exact_shapes_and_contextual_scalar_types() {
 value(b"module main;fn i32 main(){return take([42;1]);}fn i32 take(i32[1] a){return a[0];}",128);
 value(b"module main;fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){return take([21;2]);}",128);
 value(b"module main;fn i32 take(usize[1] a){if(a[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){return take([18446744073709551615;1]);}",128);
}

@test
fn void filler_runs_once_before_later_argument_effects() {
 value(b"module main;fn i32 take(i32[2] a,i32 n){return a[0]+a[1]+n-1;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;return take([switch(o){case .some(v):{v}case .none:{n=n+1;21}};2],n);}",128);
 value(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){var i32 n=20;let Option<i32> o=.none;return take([n;1],switch(o){case .some(v):{v}case .none:{n=0;22}});}",128);
 value(b"module main;struct P{i32 x;}fn i32[1] make(){return [1;1];}fn i32 take(P p,i32[1] a,i32[1] b,i32 n){return p.x*10+a[0]+b[0]+n;}fn i32 main(){return take(P{.x=2},[3;1],make(),18);}",128);
}

@test
fn void nested_calls_and_array_record_or_wrapper_consumers() {
 value(b"module main;fn i32[1] id(i32[1] a){return a;}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(id([42;1]));}",128);
 value(b"module main;struct P{i32 x;}fn P take(i32[1] a){return P{.x=a[0]};}fn i32 main(){let P p=take([42;1]);return p.x;}",128);
 value(b"module main;fn Option<i32> take(i32[1] a){return .some(a[0]);}fn i32 main(){switch(take([42;1])){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void pending_and_prior_captures_cleanup_on_early_exits() {
 value(b"module main;fn i32 take(i32[1] a,i32[1] b){return 0;}fn i32 main(){let Option<i32> o=.none;return take([0;1],[switch(o){case .some(v):{v}case .none:{return 42;}};1]);}",128);
 value(b"module main;fn i32[1] take(i32[1] a,i32 n){return a;}fn i32[1] outer(){let i32[1] keep=[42;1];let Option<i32> o=.none;return take([0;1],switch(o){case .some(v):{v}case .none:{return keep;}});}fn i32 main(){let i32[1] a=outer();return a[0];}",128);
 value(b"module main;fn i32 take(i32[1] a,i32[1] b){return b[0];}fn Option<i32> f(Option<i32> o){return .some(take([0;1],[o?;1]));}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void loop_transfers_ir_equivalence_and_payload_boundaries() {
 value(b"module main;fn i32 take(i32[1] a,i32[1] b){return 0;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let i32 k=take([0;1],[switch(o){case .some(v):{v}case .none:{n=n+1;continue;}};1]);}return n+40;}",128);
 value(b"module main;fn i32 take(i32[1] a,i32[1] b){return 0;}fn i32 main(){let Option<i32> o=.none;while(true){let i32 k=take([0;1],[switch(o){case .some(v):{v}case .none:{break;}};1]);}return 42;}",128);
 value(b"module main;fn i32 take(i32[1] a,i32[1] b){return a[0];}fn i32 main(){let Option<i32> o=.none;return take([42;1],[switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}n}};1]);}",128);
 let ir::Program p=compiled(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take([42;1]);}");
 let ir::Program named=compiled(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){let i32[1] temporary=[42;1];return take(temporary);}");
 assert(p.count==named.count && p.arrays.count==named.arrays.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
 assert(pc+1<p.count && p.code[(pc+1)*8]==37);
 var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
 let ir::Program pending=compiled(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){let Option<i32> o=.none;return take([switch(o){case .some(v):{v}case .none:{return 42;}};1]);}");
 assert(verifier::verify(ref pending).is_ok);
 assert(switch(vm::run_with_array_limit(ref pending,1000000,0)){case .ok(n):{n==42}case .err(_):{false}});
}

@test
fn void wrong_shapes_types_and_general_literal_forms_are_rejected() {
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take([42;2]);}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take([42;0]);}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take([42;4097]);}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take([true;1]);}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){let u32 n=42;return take([n;1]);}");
 rejected(b"module main;fn i32 take(u32[1] a){return 42;}fn i32 main(){return take([-1;1]);}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(([42;1]));}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take([42;1][0]);}");
 malformed(b"module main;fn i32 take(i32 a){return a;}fn i32 main(){return take([42;1]);}");
 rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take([42;1]);}");
 rejected(b"module main;fn i32 take(i32[1] a){a[0]=0;return a[0];}fn i32 main(){return take([42;1]);}");
 malformed(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take([[42;1];1]);}");
}
