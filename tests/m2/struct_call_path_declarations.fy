module tests::m2::struct_call_path_declarations;
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
fn void forward_deep_paths_mutability_and_independent_values() {
 value(b"module main;fn i32 main(){let P p=make().child;return p.x;}struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}",8);
 value(b"module main;struct P{i32 x;i32 y;}struct R{P left;P right;}struct S{R child;}fn S make(){return S{.child=R{.left=P{.x=1,.y=2},.right=P{.x=20,.y=22}}};}fn i32 main(){var P p=make().child.right;p.x=21;return p.x+p.y-1;}",16);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=0}};}fn i32 main(){var P p=make().child;p.x=42;return p.x;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R id(R r){return r;}fn i32 main(){var R r=R{.child=P{.x=42}};var P p=id(r).child;p.x=0;return r.child.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn P pick(){let P p=make().child;return p;}fn i32 main(){let P p=pick();return p.x;}",4);
}

@test
fn void argument_effects_pending_names_and_early_exits() {
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var i32 n=0;let Option<i32> o=.none;let P p=make(switch(o){case .some(v):{0}case .none:{n=n+1;41}}).child;return p.x+n;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let Option<i32> o=.none;let P p=make(switch(o){case .some(v):{0}case .none:{let i32 p=42;p}}).child;return p.x;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let Option<i32> o=.none;let P p=make(switch(o){case .some(v):{0}case .none:{return 42;}}).child;return p.x;}",0);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn Option<i32> f(Option<i32> o){let P p=make(o?).child;return .some(p.x);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let i32[1] a=[0;1];var R r=R{.child=P{.x=0}};let Option<i32> o=.none;let P p=make(switch(o){case .some(v):{0}case .none:{return 42;}}).child;return p.x;}",128);
}

@test
fn void loop_reuse_transfers_and_scope_publication() {
 value(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 main(){var i32 n=0;while(n<3){let P p=make().child;if(p.x!=42){return 0;}n=n+1;continue;}return 42;}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let P p=make(switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}).child;}return n+40;}",0);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let Option<i32> o=.none;while(true){let P p=make(switch(o){case .some(v):{0}case .none:{break;}}).child;}return 42;}",0);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let i32[1] a=[0;1];{let P p=make(0).child;}let Option<i32> o=.none;var P p=make(switch(o){case .some(v):{0}case .none:{var i32 n=0;while(n<2){n=n+1;continue;}42}}).child;p.x=42;return p.x;}",128);
}

@test
fn void root_is_released_before_child_creation_and_payload_admission() {
 let ir::Program p=compiled(b"module main;struct P{i32 x;i32 y;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=20,.y=22}};}fn i32 main(){let P p=make().child;return p.x+p.y;}");
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run_with_array_limit(ref p,1000000,12)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,11)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=p.starts[p.entry];while(pc<p.ends[p.entry] && p.code[pc*8]!=45){pc+=1;}
 assert(pc>=2 && pc+1<p.ends[p.entry] && p.code[(pc-2)*8]==43 && p.code[(pc-1)*8]==43 && p.code[(pc+1)*8]==41);
 var ir::Program bad=p;bad.code[pc*8]=19;bad.code[pc*8+1]=0;
 assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void nominal_endpoint_visibility_and_unsupported_contexts_reject() {
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{Q child;}fn R make(){return R{.child=Q{.x=42}};}fn i32 main(){let P p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let P p=make().child.x;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let P p=make().missing;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let i32 make=0;let P p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 make(){return 42;}fn i32 main(){let P p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 main(){let P p=missing().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let P p=make(p.x).child;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let P p=make().child;p.x=0;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){for(let P p=make().child;false;){}return 42;}");
}
