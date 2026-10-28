module tests::m2::array_result_arguments;
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
fn void forward_exact_shapes_lengths_and_unsigned_extrema() {
 value(b"module main;fn i32 main(){return take(make());}fn i32 take(i32[1] a){return a[0];}fn i32[1] make(){return [42;1];}",128);
 value(b"module main;fn i32[2] make(){return [21;2];}fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){return take(make());}",128);
 value(b"module main;fn usize[1] make(){return [18446744073709551615;1];}fn i32 take(usize[1] a){if(a[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){return take(make());}",128);
}

@test
fn void nested_array_calls_and_record_or_wrapper_consumers() {
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32[1] id(i32[1] a){return a;}fn i32 main(){let i32[1] a=id(id(make()));return a[0];}",128);
 value(b"module main;struct P{i32 x;}fn i32[1] make(){return [42;1];}fn P take(i32[1] a){return P{.x=a[0]};}fn i32 main(){let P p=take(make());return p.x;}",128);
 value(b"module main;fn i32[1] make(){return [42;1];}fn Option<i32> take(i32[1] a){return .some(a[0]);}fn i32 main(){switch(take(make())){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void mixed_record_array_captures_and_later_mutation() {
 value(b"module main;fn i32[1] pick(i32[1] a){return a;}fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){var i32[1] a=[20;1];let Option<i32> o=.none;return take(pick(a),switch(o){case .some(v):{v}case .none:{a[0]=0;22}});}",128);
 value(b"module main;struct P{i32 x;}fn i32[1] pick(i32[1] a){return a;}fn P last(i32 n){return P{.x=n};}fn i32 take(P p,i32[1] a,P q,i32 n){return p.x*10+a[0]+q.x+n;}fn i32 main(){var i32[1] a=[1;1];let Option<i32> o=.none;return take(P{.x=2},pick(a),last(switch(o){case .some(v):{v}case .none:{a[0]=0;4}}),17);}",128);
 value(b"module main;fn i32[1] id(i32[1] a){return a;}fn i32[1] make(i32 n){return [n;1];}fn i32 take(i32[1] a,i32[1] b,i32 n){return a[0]*10+b[0]+n;}fn i32 main(){let i32[1] a=[2;1];return take(id(a),make(4),18);}",128);
}

@test
fn void early_scalar_array_and_propagation_exits_release_results() {
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;return take(make(),switch(o){case .some(v):{v}case .none:{return 42;}});}",128);
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32[1] take(i32[1] a,i32 n){return a;}fn i32[1] outer(){let i32[1] keep=[42;1];let Option<i32> o=.none;return take(make(),switch(o){case .some(v):{v}case .none:{return keep;}});}fn i32 main(){let i32[1] a=outer();return a[0];}",128);
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a,i32 n){return a[0];}fn Option<i32> f(Option<i32> o){return .some(take(make(),o?));}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void loop_transfers_ir_equivalence_and_two_live_extents() {
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a,i32 n){return 0;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let i32 k=take(make(),switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return n+40;}",128);
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;while(true){let i32 k=take(make(),switch(o){case .some(v):{v}case .none:{break;}});}return 42;}",128);
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a,i32 n){return a[0];}fn i32 main(){let Option<i32> o=.none;return take(make(),switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}n}});}",128);
 let ir::Program p=compiled(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make());}");
 let ir::Program named=compiled(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){let i32[1] temporary=make();return take(temporary);}");
 assert(p.count==named.count && p.arrays.count==named.arrays.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
 pc+=1;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
 assert(pc+1<p.count && p.code[(pc+1)*8]==37);
 var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
 let ir::Program pending=compiled(b"module main;fn i32[1] make(i32 n){return [n;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){let Option<i32> o=.none;return take(make(switch(o){case .some(v):{v}case .none:{return 42;}}));}");
 assert(verifier::verify(ref pending).is_ok);
 assert(switch(vm::run_with_array_limit(ref pending,1000000,0)){case .ok(n):{n==42}case .err(_):{false}});
}

@test
fn void invalid_shapes_and_general_array_argument_forms_fail() {
 rejected(b"module main;fn i32[2] make(){return [42;2];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make());}");
 rejected(b"module main;fn u32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make());}");
 rejected(b"module main;fn i32 make(){return 42;}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make());}");
 rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make());}");
 rejected(b"module main;fn Option<i32> make(){return .some(42);}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make());}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(missing());}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){let i32 make=0;return take(make());}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make(1));}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take((make()));}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make()[0]);}");
 rejected(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(([42;1]));}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){a[0]=0;return a[0];}fn i32 main(){return take(make());}");
}
