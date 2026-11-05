module tests::m2::struct_call_path_returns;
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
fn void forward_deep_paths_and_independent_returned_values() {
 value(b"module main;fn i32 main(){let P p=pick();return p.x;}fn P pick(){return make().child;}struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}",8);
 value(b"module main;struct P{i32 x;i32 y;}struct R{P left;P right;}struct S{u8 pad;R child;}fn S make(){return S{.pad=255,.child=R{.left=P{.x=1,.y=2},.right=P{.x=20,.y=22}}};}fn P pick(){return make().child.right;}fn i32 main(){var P p=pick();p.x=21;return p.x+p.y-1;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R id(R r){return r;}fn P pick(R r){return id(r).child;}fn i32 main(){var R r=R{.child=P{.x=42}};var P p=pick(r);p.x=0;return r.child.x;}",128);
}
@test
fn void mixed_cleanup_argument_snapshots_and_nested_returns() {
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn P pick(){let i32[1] a=[0;1];var P p=P{.x=0};let Option<i32> o=.none;return make(switch(o){case .some(v):{0}case .none:{p.x=p.x+1;41+p.x}}).child;}fn i32 main(){let P p=pick();return p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(P p,i32 n){return R{.child=P{.x=p.x+n}};}fn P pick(){var P p=P{.x=20};let Option<i32> o=.none;return make(p,switch(o){case .some(v):{0}case .none:{p.x=0;22}}).child;}fn i32 main(){let P p=pick();return p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn P pick(){let Option<i32> o=.none;return make(switch(o){case .some(v):{0}case .none:{return P{.x=42};}}).child;}fn i32 main(){let P p=pick();return p.x;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn P pick(){var i32 n=0;let Option<i32> o=.none;while(n<2){return make(switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}).child;}return P{.x=42};}fn i32 main(){let P p=pick();return p.x;}",4);
}
@test
fn void recursion_loop_reuse_and_release_before_child_creation() {
 value(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn P pick(i32 n){if(n==0){return make().child;}return pick(n-1);}fn i32 main(){let P p=pick(2);return p.x;}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn P pick(){let Option<i32> o=.none;while(true){return make(switch(o){case .some(v):{0}case .none:{break;}}).child;}return P{.x=42};}fn i32 main(){let P p=pick();return p.x;}",4);
 value(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn P pick(){return make().child;}fn i32 main(){var i32 n=0;while(n<3){let P p=pick();if(p.x!=42){return 0;}n=n+1;continue;}return 42;}",8);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn P pick(){return make().child;}fn i32 main(){let P p=pick();return p.x;}");
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=p.starts[1];while(pc<p.ends[1] && p.code[pc*8]!=9){pc+=1;}
 assert(pc+4<p.ends[1] && p.code[(pc+1)*8]==43 && p.code[(pc+2)*8]==45 && p.code[(pc+3)*8]==41 && p.code[(pc+4)*8]==50);
 var ir::Program bad=p;bad.code[(pc+2)*8]=19;bad.code[(pc+2)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+2,pc+3,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}
@test
fn void wrong_nominal_scalar_and_unsupported_return_forms_reject() {
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{Q child;}fn R make(){return R{.child=Q{.x=42}};}fn P pick(){return make().child;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn P pick(){return make().child.x;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn P pick(){return make().missing;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn P pick(){let i32 make=0;return make().child;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 make(){return 42;}fn P pick(){return make().child;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P pick(){return missing().child;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn P pick(){return make().child;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn P pick(){let Option<i32> o=.some(42);return make(o?).child;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){return make().child;}");
}
