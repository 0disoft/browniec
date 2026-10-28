module tests::m2::struct_call_path_assignment;
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
fn void root_and_deep_destinations_preserve_neighbors_and_independent_values() {
 value(b"module main;fn i32 main(){var P p=P{.x=0};p=make().child;return p.x;}struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}",12);
 value(b"module main;struct P{i32 x;i32 y;}struct R{P left;P right;}struct S{u8 head;R child;u8 tail;}fn S make(){return S{.head=0,.child=R{.left=P{.x=1,.y=2},.right=P{.x=20,.y=22}},.tail=0};}fn i32 main(){var S s=S{.head=17,.child=R{.left=P{.x=7,.y=8},.right=P{.x=0,.y=0}},.tail=19};s.child.right=make().child.right;if(s.head==17 && s.tail==19 && s.child.left.x==7 && s.child.left.y==8){return s.child.right.x+s.child.right.y;}return 0;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R id(R r){return r;}fn i32 main(){var R r=R{.child=P{.x=42}};var P p=P{.x=0};p=id(r).child;r.child.x=0;return p.x;}",128);
}
@test
fn void argument_snapshots_effects_and_early_exits_preserve_destination_rules() {
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var P p=P{.x=0};let Option<i32> o=.none;p=make(switch(o){case .some(v):{0}case .none:{p.x=7;42}}).child;return p.x;}",8);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(P p,i32 n){return R{.child=P{.x=p.x+n}};}fn i32 main(){var P p=P{.x=20};let Option<i32> o=.none;p=make(p,switch(o){case .some(v):{0}case .none:{p.x=0;22}}).child;return p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var P p=P{.x=0};let Option<i32> o=.none;p=make(switch(o){case .some(v):{0}case .none:{return 42;}}).child;return p.x;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=42}};}fn Option<i32> f(Option<i32> o){var P p=P{.x=0};p=make(o?).child;return .some(p.x);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",8);
}
@test
fn void loop_cleanup_atomic_copy_and_quota_keep_only_the_destination() {
 value(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 main(){var P p=P{.x=0};var i32 n=0;while(n<3){p=make().child;if(p.x!=42){return 0;}n=n+1;continue;}return p.x;}",12);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var P p=P{.x=0};let Option<i32> o=.none;while(true){p=make(switch(o){case .some(v):{0}case .none:{p.x=42;break;}}).child;}return p.x;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var P p=P{.x=0};var i32 n=0;let Option<i32> o=.none;while(n<2){p=make(switch(o){case .some(v):{0}case .none:{p.x=42;n=n+1;continue;}}).child;}return p.x;}",4);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 main(){var P p=P{.x=0};p=make().child;return p.x;}");
 assert(verifier::verify(ref p).is_ok && p.records.count==4);
 assert(switch(vm::run_with_array_limit(ref p,1000000,12)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,11)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=p.starts[p.entry];while(pc<p.ends[p.entry] && p.code[pc*8]!=9){pc+=1;}
 assert(pc+2<p.ends[p.entry] && p.code[(pc+1)*8]==47 && p.code[(pc+2)*8]==45);
 assert(p.code[(pc+1)*8+4]==0 && p.code[(pc+1)*8+5]==1);
 assert(p.code[(pc+1)*8+2]==p.code[(pc+2)*8+1]);
 var ir::Program bad=p;bad.code[(pc+2)*8]=19;bad.code[(pc+2)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+2,pc+3,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
 bad=p;bad.code[(pc+1)*8+5]=2;assert(!verifier::verify(ref bad).is_ok);
}
@test
fn void immutable_nominal_scalar_and_unsupported_forms_reject() {
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let P p=P{.x=0};p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{Q child;}fn R make(){return R{.child=Q{.x=42}};}fn i32 main(){var P p=P{.x=0};p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){var P p=P{.x=0};p=make().child.x;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){var P p=P{.x=0};p=make().missing;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){var P p=P{.x=0};p=(make().child);return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){var P p=P{.x=0};let i32 make=0;p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 make(){return 42;}fn i32 main(){var P p=P{.x=0};p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p=missing().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var P p=P{.x=0};p=make().child;return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){var P p=P{.x=0};for(;false;p=make().child){}return 42;}");
}
