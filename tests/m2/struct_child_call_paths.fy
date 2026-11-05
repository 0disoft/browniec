module tests::m2::struct_child_call_paths;
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
fn void forward_deep_paths_and_constructor_returns_stage_selected_leaves() {
 value(b"module main;fn i32 main(){let D d=D{.p=make().child};return d.p.x;}struct P{i32 x;}struct R{i32 pad;P child;}struct D{P p;}fn R make(){return R{.pad=0,.child=P{.x=42}};}",8);
 value(b"module main;struct P{i32 x;i32 y;}struct R{P left;P right;}struct S{R child;}struct D{u8 head;P p;u8 tail;}struct W{D d;}fn S make(){return S{.child=R{.left=P{.x=1,.y=2},.right=P{.x=20,.y=22}}};}fn i32 main(){let W w=W{.d=D{.head=17,.p=make().child.right,.tail=19}};if(w.d.head==17 && w.d.tail==19){return w.d.p.x+w.d.p.y;}return 0;}",128);
 value(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}struct D{P p;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn D wrap(){return D{.p=make().child};}fn i32 main(){var D d=wrap();return d.p.x;}",8);
}
@test
fn void later_fields_snapshots_and_root_or_child_replacements_keep_order() {
 value(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;i32 tail;}fn R id(R r){return r;}fn i32 main(){var R r=R{.child=P{.x=20}};let Option<i32> o=.none;let D d=D{.p=id(r).child,.tail=switch(o){case .some(v):{0}case .none:{r.child.x=0;22}}};return d.p.x+d.tail;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;i32 tail;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){var D d=D{.p=P{.x=22},.tail=0};d=D{.p=make(20).child,.tail=d.p.x};return d.p.x+d.tail;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}struct W{D d;i32 tail;}fn R make(){return R{.child=P{.x=20}};}fn i32 main(){var W w=W{.d=D{.p=P{.x=0}},.tail=22};w.d=D{.p=make().child};return w.d.p.x+w.tail;}",128);
 value(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(P p,i32 n){return R{.child=P{.x=p.x+n}};}fn i32 main(){var P p=P{.x=20};let Option<i32> o=.none;let D d=D{.p=make(p,switch(o){case .some(v):{0}case .none:{p.x=0;22}}).child};return d.p.x;}",128);
}
@test
fn void early_exits_release_results_and_quota_excludes_independent_child() {
 value(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;i32 tail;}fn R make(){return R{.child=P{.x=0}};}fn i32 main(){let Option<i32> o=.none;let D d=D{.p=make().child,.tail=switch(o){case .some(v):{0}case .none:{return 42;}}};return 0;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;i32 tail;}fn R make(){return R{.child=P{.x=0}};}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let D d=D{.p=make().child,.tail=switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}};}return n+40;}",4);
 value(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(i32 n){return R{.child=P{.x=n}};}fn Option<i32> f(Option<i32> o){let D d=D{.p=make(o?).child};return .some(d.p.x);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}",4);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}struct D{P p;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 main(){let D d=D{.p=make().child};return d.p.x;}");
 assert(verifier::verify(ref p).is_ok && p.records.count==4);
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=p.starts[p.entry];while(pc<p.ends[p.entry] && p.code[pc*8]!=9){pc+=1;}
 assert(pc+5<p.ends[p.entry] && p.code[(pc+1)*8]==43 && p.code[(pc+2)*8]==18 && p.code[(pc+3)*8]==45 && p.code[(pc+4)*8]==17 && p.code[(pc+5)*8]==41);
 var ir::Program bad=p;bad.code[(pc+3)*8]=19;bad.code[(pc+3)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+3,pc+4,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
 let ir::Program q=compiled(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}struct D{P p;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 main(){var D d=D{.p=P{.x=0}};d=D{.p=make().child};return d.p.x;}");
 assert(switch(vm::run_with_array_limit(ref q,1000000,12)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref q,1000000,11)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
@test
fn void wrong_nominal_scalar_pending_and_general_operands_reject() {
 rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}struct R{Q child;}struct D{P p;}fn R make(){return R{.child=Q{.x=42}};}fn i32 main(){let D d=D{.p=make().child};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let D d=D{.p=make().child.x};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let D d=D{.p=make().missing};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let i32 make=0;let D d=D{.p=make().child};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct D{P p;}fn i32 make(){return 42;}fn i32 main(){let D d=D{.p=make().child};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct D{P p;}fn i32 main(){let D d=D{.p=missing().child};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let D d=D{.p=make().child};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(i32 n){return R{.child=P{.x=n}};}fn i32 main(){let D d=D{.p=make(d.p.x).child};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let D d=D{.p=P{.x=0}};d=D{.p=make().child};return 42;}");
}

// Grouping now preserves the same complete record value in these contexts.
@test fn void grouped_record_forms_now_compile_in_existing_contexts(){
    assert(compiler::compile(b"module main;struct P{i32 x;}struct R{P child;}struct D{P p;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let D d=D{.p=(make().child)};return 42;}").is_ok);
}
