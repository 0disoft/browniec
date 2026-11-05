module tests::m2::struct_child_calls;
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
fn void forward_nested_fields_and_scalar_extrema() {
 value(b"module main;fn i32 main(){let R r=R{.p=make(),.tail=22};return r.p.x+r.tail;}fn P make(){return P{.x=20};}struct P{i32 x;}struct R{P p;i32 tail;}",128);
 value(b"module main;struct P{i32 x;}struct C{u8 head;P p;}struct R{C c;usize tail;}fn P make(){return P{.x=42};}fn i32 main(){let R r=R{.c=C{.head=255,.p=make()},.tail=4294967295};if(r.c.head==255 && r.tail==4294967295){return r.c.p.x;}return 0;}",128);
 value(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}struct R{u8 head;P p;u8 tail;}fn P make(){return P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};}fn i32 main(){let R r=R{.head=17,.p=make(),.tail=19};if(r.head==17 && r.tail==19 && r.p.a && r.p.b==255 && r.p.c==-2147483648 && r.p.d==-9223372036854775808 && r.p.e==4294967295 && r.p.f==18446744073709551615){return 42;}return 0;}",128);
}

@test
fn void field_snapshots_and_mutable_arguments_evaluate_left_to_right() {
 value(b"module main;struct P{i32 x;}struct R{P a;i32 n;P b;}fn P pick(P p){return p;}fn i32 main(){var P p=P{.x=20};let Option<i32> o=.none;let R r=R{.a=pick(p),.n=switch(o){case .some(v):{v}case .none:{p.x=0;22}},.b=pick(p)};return r.a.x+r.n+r.b.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(P p,i32 n){return P{.x=p.x*10+n};}fn i32 main(){var P p=P{.x=2};let Option<i32> o=.none;let R r=R{.p=take(p,switch(o){case .some(v):{v}case .none:{p.x=0;22}})};return r.p.x;}",128);
}

@test
fn void replacement_and_record_return_use_the_same_child_staging() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){var R r=R{.p=P{.x=0}};r=R{.p=make()};return r.p.x;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}struct W{R r;i32 tail;}fn P make(){return P{.x=20};}fn i32 main(){var W w=W{.r=R{.p=P{.x=0}},.tail=22};w.r=R{.p=make()};return w.r.p.x+w.tail;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn R wrap(){return R{.p=make()};}fn i32 main(){let R r=wrap();return r.p.x;}",128);
}

@test
fn void argument_and_later_field_transfers_leave_no_pending_owner() {
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(P p,i32 n){return p;}fn i32 main(){var P p=P{.x=0};let Option<i32> o=.none;let R r=R{.p=take(p,switch(o){case .some(v):{v}case .none:{return 42;}})};return 0;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;i32 tail;}fn P make(){return P{.x=42};}fn i32 main(){let Option<i32> o=.none;let R r=R{.p=make(),.tail=switch(o){case .some(v):{v}case .none:{return 42;}}};return 0;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;}fn P take(P p,i32 n){return p;}fn Option<i32> f(Option<i32> o){var P p=P{.x=42};let R r=R{.p=take(p,o?)};return .some(r.p.x);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;i32 tail;}fn P make(){return P{.x=42};}fn R wrap(){let Option<i32> o=.none;return R{.p=make(),.tail=switch(o){case .some(v):{v}case .none:{return R{.p=make(),.tail=0};}}};}fn i32 main(){let R r=wrap();return r.p.x;}",128);
}

@test
fn void later_loop_transfers_and_repeated_fields_release_results() {
 value(b"module main;struct P{i32 x;}struct R{P p;i32 tail;}fn P make(){return P{.x=0};}fn i32 main(){let Option<i32> o=.none;var i32 n=0;while(n<2){let R r=R{.p=make(),.tail=switch(o){case .some(v):{v}case .none:{n=n+1;continue;}}};}return n+40;}",128);
 value(b"module main;struct P{i32 x;}struct R{P p;i32 tail;}fn P make(){return P{.x=0};}fn i32 main(){let Option<i32> o=.none;while(true){let R r=R{.p=make(),.tail=switch(o){case .some(v):{v}case .none:{break;}}};}return 42;}",128);
 value(b"module main;struct P{i32 x;}struct R{P a;P b;}fn P make(i32 n){return P{.x=n};}fn i32 main(){var i32 n=0;while(n<2){let R r=R{.a=make(20),.b=make(22)};if(r.a.x+r.b.x!=42){return 0;}n=n+1;}return 42;}",128);
}

@test
fn void nominal_rejections_and_early_drop_before_parent_publication() {
 rejected(b"module main;struct P{i32 x;}struct R{P p;}struct Q{i32 x;}fn Q make(){return Q{.x=42};}fn i32 main(){let R r=R{.p=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 make(){return 42;}fn i32 main(){let R r=R{.p=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32[1] make(){return [42;1];}fn i32 main(){let R r=R{.p=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn Option<i32> make(){return .some(42);}fn i32 main(){let R r=R{.p=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){let R r=R{.p=missing()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){let i32 make=0;let R r=R{.p=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(i32 n){return P{.x=n};}fn i32 main(){let R r=R{.p=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){let P p=P{.x=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn R make(){return R{.p=P{.x=42}};}fn i32 main(){let R r=R{.p=make()};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){let R r=R{.p=make(r)};return 42;}");
 rejected(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){for(let R r=R{.p=make()};false;){}return 42;}");
 let ir::Program p=compiled(b"module main;struct P{i32 x;}struct R{P p;}fn P make(){return P{.x=42};}fn i32 main(){let R r=R{.p=make()};return r.p.x;}");
 assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
 var usize pc=0;while(pc<p.count && p.code[pc*8]!=9){pc+=1;}
 assert(pc+5<p.count && p.code[(pc+1)*8]==43 && p.code[(pc+2)*8]==18);
 assert(p.code[(pc+3)*8]==45 && p.code[(pc+4)*8]==17 && p.code[(pc+5)*8]==41);
 assert(p.code[pc*8+1] as usize==144+p.code[(pc+3)*8+1] as usize);
 var ir::Program bad=p;bad.code[(pc+3)*8]=19;bad.code[(pc+3)*8+1]=0;
 assert(ir::patch(ref mut bad,pc+3,pc+4,0).is_ok);assert(!verifier::verify(ref bad).is_ok);
}
