module tests::m2::struct_child_call_assignment;
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

fn void syntax_rejected(ref u8[] source) {
 assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==2}});
}

@test
fn void deep_paths_preserve_neighbors_and_all_scalar_bits() {
 value(b"module main;fn i32 main(){var R r=R{.p=P{.x=0},.tail=22};r.p=make();return r.p.x+r.tail;}fn P make(){return P{.x=20};}struct P{i32 x;}struct R{P p;i32 tail;}",128);
 value(b"module main;struct P{i32 x;}struct C{P left;P right;}struct R{u8 head;C c;usize tail;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.head=255,.c=C{.left=P{.x=7},.right=P{.x=0}},.tail=4294967295};r.c.right=make();if(r.head==255 && r.c.left.x==7 && r.tail==4294967295){return r.c.right.x;}return 0;}",128);
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{u8 head;P p;u8 tail;}fn P make(){return P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};}fn i32 main(){var R r=R{.head=17,.p=P{.a=false,.b=0,.c=0,.d=0,.e=0,.f=0},.tail=19};r.p=make();if(r.head==17 && r.tail==19 && r.p.a && r.p.b==255 && r.p.c==-2147483648 && r.p.d==-9223372036854775808 && r.p.e==4294967295 && r.p.f==18446744073709551615){return 42;}return 0;}",128);
}

@test
fn void destination_and_mutable_argument_snapshots_remain_live() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P from(R r){return r.p;}fn i32 main(){var R r=R{.p=P{.x=42}};let R before=r;r.p=from(r);r.p.x=0;return before.p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(R before,i32 n,R after,i32[1] a){return P{.x=before.p.x*10+n+after.p.x+a[0]};}fn i32 main(){var R r=R{.p=P{.x=2}};var i32[1] a=[1;1];let Option<i32> o=.none;r.p=take(r,switch(o){case .some(v):{v}case .none:{r=R{.p=P{.x=4}};17}},r,a);return r.p.x;}",128);
}

@test
fn void early_scalar_record_and_propagated_returns_do_not_publish_pending_results() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(R r,i32 n){return r.p;}fn i32 main(){var R r=R{.p=P{.x=0}};let Option<i32> o=.none;r.p=take(r,switch(o){case .some(v):{v}case .none:{return 42;}});return 0;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(R r,i32 n){return r.p;}fn P outer(R r){var R q=r;let Option<i32> o=.none;q.p=take(q,switch(o){case .some(v):{v}case .none:{return r.p;}});return q.p;}fn i32 main(){let R r=R{.p=P{.x=42}};let P p=outer(r);return p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(R r,i32 n){return r.p;}fn Option<i32> f(Option<i32> o){var R r=R{.p=P{.x=42}};r.p=take(r,o?);return .some(r.p.x);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",128);
}

@test
fn void outer_loop_transfers_drop_captures_and_inner_loops_preserve_them() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(R r,i32 n){return r.p;}fn i32 main(){var R r=R{.p=P{.x=42}};var i32 n=0;while(n<2){var R q=R{.p=P{.x=0}};let Option<i32> o=.none;q.p=take(q,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return r.p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(R r,i32 n){return r.p;}fn i32 main(){var R r=R{.p=P{.x=42}};while(true){var R q=R{.p=P{.x=0}};let Option<i32> o=.none;q.p=take(q,switch(o){case .some(v):{v}case .none:{break;}});}return r.p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(R r,i32 n){return r.p;}fn i32 main(){var R r=R{.p=P{.x=42}};let Option<i32> o=.none;r.p=take(r,switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<1){r.p.x=0;n=n+1;continue;}n}});return r.p.x;}",128);
}

@test
fn void repeated_assignment_reuses_payload_and_matches_scoped_ir() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};var i32 n=0;while(n<3){r.p=make();if(r.p.x!=42){return 0;}n=n+1;}return r.p.x;}",128);
 let ir::Program p=compiled(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=make();return r.p.x;}");
 let ir::Program named=compiled(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};{let P temporary=make();r.p=temporary;}return r.p.x;}");
 assert(p.count==named.count && p.records.count==named.records.count);
 var usize i=0;while(i<p.count*8){assert(p.code[i]==named.code[i]);i+=1;}
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
 assert(pc+2<p.count && p.code[(pc+1)*8]==47 && p.code[(pc+2)*8]==45);
 assert(p.code[pc*8+1] as usize==144+p.code[(pc+1)*8+2] as usize);
 assert(p.code[(pc+1)*8+2]==p.code[(pc+2)*8+1]);
 var ir::Program bad=p;bad.code[(pc+2)*8]=19;bad.code[(pc+2)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+2,pc+3,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
 bad=p;bad.code[(pc+1)*8+4]=1;assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void immutable_wrong_nominal_scalar_shadowed_and_unsupported_forms_fail() {
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){let R r=R{.p=P{.x=0}};r.p=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}struct Q{i32 x;}fn Q make(){return Q{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 make(){return 42;}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32[1] make(){return [42;1];}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn Option<i32> make(){return .some(42);}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=missing();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};let i32 make=0;r.p=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(i32 n){return P{.x=n};}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=(make());return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};r.p.x=make();return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};for(;false;r.p=make()){}return 42;}");
 syntax_rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};r.p=make()+0;return 42;}");
}
