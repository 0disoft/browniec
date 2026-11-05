module tests::m2::struct_call_path_arguments;
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
fn void forward_deep_exact_nominal_paths_and_multiple_leaves() {
 value(b"module main;fn i32 main(){return take(make().child);}struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 take(P p){return p.x;}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}struct S{R child;}fn S make(){return S{.child=R{.child=P{.x=42}}};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().child.child);}",8);
 value(b"module main;struct P{i32 x;i32 y;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=20,.y=22}};}fn i32 take(P p){return p.x+p.y;}fn i32 main(){return take(make().child);}",16);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn P id(P p){return p;}fn i32 take(P p){return p.x;}fn i32 main(){return take(id(make().child));}",12);
}

@test
fn void single_evaluation_mixed_captures_and_consumer_result_kinds() {
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 take(P p,i32 n){return p.x+n;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;return take(make(switch(o){case .some(v):{0}case .none:{n=n+1;41}}).child,n);}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 take(P p,i32[1] a,i32 n){return p.x+a[0]+n;}fn i32 main(){var i32 n=20;let Option<i32> o=.none;return take(make(n).child,[1;1],switch(o){case .some(v):{0}case .none:{n=0;21}});}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn P take(P p){return p;}fn i32 main(){let P p=take(make().child);return p.x;}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32[1] take(P p){return [p.x;1];}fn i32 main(){let i32[1] a=take(make().child);return a[0];}",12);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn Option<i32> take(P p){return .some(p.x);}fn i32 main(){switch(take(make().child)){case .some(v):{return v;}case .none:{return 0;}}}",8);
}

@test
fn void early_exits_loop_reuse_and_drop_before_creation() {
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=0}};}fn i32 take(P p,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;return take(make().child,switch(o){case .some(v):{0}case .none:{return 42;}});}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 take(P p,i32 n){return p.x;}fn Option<i32> f(Option<i32> o){return .some(take(make().child,o?));}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=0}};}fn i32 take(P p,i32 n){return 0;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let i32 k=take(make().child,switch(o){case .some(v):{0}case .none:{n=n+1;continue;}});}return n+40;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=0}};}fn i32 take(P p,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;while(true){let i32 k=take(make().child,switch(o){case .some(v):{0}case .none:{break;}});}return 42;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 take(P p,i32 n){return p.x;}fn i32 main(){let Option<i32> o=.none;return take(make().child,switch(o){case .some(v):{0}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}0}});}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 take(P p){return p.x;}fn i32 main(){let Option<i32> o=.none;return take(make(switch(o){case .some(v):{0}case .none:{return 42;}}).child);}",0);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().child);}");
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=p.starts[p.entry];while(pc<p.ends[p.entry] && p.code[pc*8]!=45){pc+=1;}
 assert(pc>0 && pc+1<p.ends[p.entry] && p.code[(pc-1)*8]==43 && p.code[(pc+1)*8]==41);
 var ir::Program bad=p;bad.code[pc*8]=19;bad.code[pc*8+1]=0;
 assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void wrong_nominal_endpoints_and_general_forms_are_rejected() {
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{Q child;}fn R make(){return R{.child=Q{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().child);}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().child.x);}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().missing);}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){let i32 make=0;return take(make().child);}");
 rejected(b"module main;struct P{i32 x;}fn i32 make(){return 42;}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().child);}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().child);}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn i32 take(P p){return p.x;}fn i32 main(){return take(missing().child);}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 take(P p){p.x=0;return p.x;}fn i32 main(){return take(make().child);}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){return take(make().child as P);}");
}
