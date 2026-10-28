module tests::m2::array_call_reads;
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
fn void forward_index_length_operators_and_nested_index_calls() {
 value(b"module main;fn i32 main(){return make()[0];}fn i32[1] make(){return [42;1];}",4);
 value(b"module main;fn i32[42] make(){return [0;42];}fn i32 main(){if(make().len==42){return 42;}return 0;}",168);
 value(b"module main;fn i32[1] make(){return [21;1];}fn i32 main(){return -make()[0]+63;}",4);
 value(b"module main;fn i32[1] make(){return [42;1];}fn usize[1] index(){return [0;1];}fn i32 main(){return make()[index()[0]];}",16);
 value(b"module main;struct P{i32 x;}fn i32[1] make(){return [22;1];}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){return take(P{.x=20},make()[0]);}",128);
}

@test
fn void evaluation_order_propagation_and_loop_exits_release_results() {
 value(b"module main;fn i32[1] make(i32 n){return [n;1];}fn i32 main(){var i32 n=0;let Option<i32> o=.none;return make(switch(o){case .some(v):{0}case .none:{n=n+1;21}})[switch(o){case .some(v):{0}case .none:{n=n+1;0}}]+n+19;}",4);
 value(b"module main;fn i32[1] make(){return [0;1];}fn i32 main(){let Option<i32> o=.none;return make()[switch(o){case .some(v):{0}case .none:{return 42;}}];}",4);
 value(b"module main;fn i32[1] make(){return [42;1];}fn Option<i32> f(Option<i32> o){return .some(make()[switch(o){case .some(v):{0}case .none:{let i32 n=o?;0}}]);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",4);
 value(b"module main;fn i32[1] make(){return [0;1];}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let i32 k=make()[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}];}return n+40;}",4);
 value(b"module main;fn i32[1] make(){return [0;1];}fn i32 main(){let Option<i32> o=.none;while(true){let i32 k=make()[switch(o){case .some(v):{0}case .none:{break;}}];}return 42;}",4);
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){let Option<i32> o=.none;return make()[switch(o){case .some(v):{0}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}0}}];}",4);
}

@test
fn void immediate_release_pending_call_and_independent_verification() {
 value(b"module main;fn i32[1] make(){return [21;1];}fn i32 main(){return make()[0]+make()[0];}",4);
 value(b"module main;fn i32[1] make(){return [1;1];}fn i32 main(){var i32 n=0;while(n<42){n=n+make()[0];}return n;}",4);
 value(b"module main;fn i32[1] make(i32 n){return [n;1];}fn i32 main(){let Option<i32> o=.none;return make(switch(o){case .some(v):{0}case .none:{return 42;}})[0];}",0);
 value(b"module main;fn i32[1] make(){return [0;1];}fn i32[1] wrap(i32 n){return [n;1];}fn i32[1] outer(){let i32[1] keep=[42;1];let Option<i32> o=.none;return wrap(make()[switch(o){case .some(v):{0}case .none:{return keep;}}]);}fn i32 main(){let i32[1] a=outer();return a[0];}",8);
 let ir::Program p=compiled(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){return make()[0];}");
 let ir::Program named=compiled(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){let i32[1] a=make();return a[0];}");
 assert(p.count==named.count && p.arrays.count==named.arrays.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
 let ir::Program length=compiled(b"module main;fn i32[1] make(){return [0;1];}fn i32 main(){if(make().len==1){return 42;}return 0;}");
 assert(verifier::verify(ref length).is_ok);
 assert(switch(vm::run_with_array_limit(ref length,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref length,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});

 var usize pc=0;while(pc<p.count && p.code[pc*8]!=37){pc+=1;}
 assert(pc<p.count);var ir::Program bad=p;bad.code[pc*8]=19;bad.code[pc*8+1]=0;
 assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void invalid_indices_members_shadowing_and_bare_results_fail() {
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){return make();}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){return make()[true];}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){let i32 n=0;return make()[n];}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){return make()[-1];}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){return make().other;}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){let i32 make=0;return make()[0];}");
 rejected(b"module main;fn i32[1] make(i32 n){return [n;1];}fn i32 main(){return make()[0];}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){return make().len;}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 take(i32[1] a){return a[0];}fn i32 main(){return take(make()[0]);}");
 rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){return (make());}");
}
