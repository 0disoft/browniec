module tests::m2::aggregate_switch_expressions;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;
fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
@test fn void arrays_compose_with_locals_arguments_returns_assignment_and_projections(){
    value(b"module main;fn i32[2] make(Option<i32> o){return switch(o){case .some(v):{[v,22]}case .none:{[0;2]}};}fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){let Option<i32> o=.some(20);let a=switch(o){case .some(_):{make(o)}case .none:{[0;2]}};var i32[2] b=(switch(o){case .none:{[0,0]}case .some(_):{a}});b=switch(o){case .none:{[0;2]}case .some(_):{a}};return take(switch(o){case .some(_):{b}case .none:{make(o)}});}");
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let u8[1] a=switch(o){case .some(_):{[0]}case .none:{[42]}};let b=switch(o){case .none:{[true]}case .some(_):{[false]}};if(b[0]){return a[0] as i32;}return 0;}");
    value(b"module main;fn i32 main(){let Result<i32,bool> r=.err(true);return ((switch(r){case .ok(v):{[v;2]}case .err(_):{[20,22]}}))[0]+(switch(r){case .err(_):{[0,22]}case .ok(_):{[0,0]}})[1];}");
    value(b"module main;fn i32 main(){let Option<i32> o=.none;if(text::valid_utf8((switch(o){case .none:{[42]}case .some(_):{[0]}}))){return 42;}return 0;}");
}
@test fn void records_keep_nominal_child_paths_and_constructor_context(){
    value(b"module main;struct P{i32 x;}fn P make(Option<i32> o){return switch(o){case .some(v):{P{.x=v}}case .none:{P{.x=0}}};}fn i32 take(P p){return p.x;}fn i32 main(){let Option<i32> o=.some(42);let p=switch(o){case .none:{P{.x=0}}case .some(_):{make(o)}};var P q=switch(o){case .some(_):{p}case .none:{P{.x=0}}};q=switch(o){case .some(_):{p}case .none:{make(o)}};return take(switch(o){case .none:{P{.x=0}}case .some(_):{q}});}");
    value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){let Option<i32> o=.some(42);let r=R{.p=P{.x=42}};let p=switch(o){case .some(_):{r.p}case .none:{P{.x=0}}};return (switch(o){case .none:{P{.x=0}}case .some(_):{p}}).x;}");
    value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){let Option<i32> o=.none;var r=R{.p=P{.x=0}};r.p=switch(o){case .some(_):{P{.x=0}}case .none:{P{.x=42}}};return ((switch(o){case .none:{r}case .some(_):{R{.p=P{.x=0}}}})).p.x;}");
    value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){let Option<i32> o=.some(42);let r=R{.p=switch(o){case .some(v):{P{.x=v}}case .none:{P{.x=0}}}};return r.p.x;}");
}
@test fn void mixed_if_switch_tails_share_destinations_in_both_drivers(){
    value(b"module main;fn i32 main(){let Option<i32> o=.some(42);let a=if(true){switch(o){case .some(v):{[v]}case .none:{[0]}}}else{[0]};let b=switch(o){case .some(_):{if(false){[0]}else{a}}case .none:{[0]}};return b[0];}");
    value(b"module main;struct P{i32 x;}fn i32 main(){let ref u8[] marker=b\"*\";let Option<i32> o=.none;let p=switch(o){case .some(_):{P{.x=0}}case .none:{switch(o){case .none:{if(true){P{.x=42}}else{P{.x=0}}}case .some(_):{P{.x=0}}}}};return p.x;}");
    value(b"module main;fn void noop(){}fn i32 main(){let ref u8[] marker=b\"*\";let Option<i32> o=.some(42);let a=switch(o){case .some(v):{noop();[v]}case .none:{[0]}};return a[0];}");
}
@test fn void subject_effects_and_value_snapshots_execute_once_in_source_order(){
    value(b"module main;fn Option<i32> choose(ref mut i32[] c){c[0]=c[0]+1;return .some(40);}fn i32 main(){var c=[0];let a=switch(choose(ref mut c)){case .some(v):{let local=[v];local}case .none:{c[0]=99;[0]}};return a[0]+c[0]+1;}");
    value(b"module main;fn i32 change(ref mut i32[] a){a[0]=22;return 0;}fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){let Option<i32> o=.none;var a=[20];let n=take(switch(o){case .none:{a}case .some(_):{[0]}},change(ref mut a));return n+a[0];}");
    value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x;}fn i32 main(){let Option<i32> o=.none;var p=P{.x=20};let n=take(switch(o){case .some(_):{P{.x=0}}case .none:{p}},if(true){p.x=22;0}else{0});return n+p.x;}");
    value(b"module main;fn i32 main(){let Option<i32> o=.some(42);return (switch(o){case .some(v):{[v]}case .none:{[1/0]}})[0];}");
}
@test fn void return_propagation_and_loop_transfers_release_only_published_values(){
    value(b"module main;fn i32 take(i32[1] a,i32[1] b){return 0;}fn i32 main(){let Option<i32> o=.none;let n=take([0],switch(o){case .some(_):{[0]}case .none:{let local=[0];return 42;}});return 0;}");
    value(b"module main;fn i32 take(i32[1] a,i32[1] b){return 0;}fn i32 main(){let Option<i32> o=.some(1);var n=0;while(n<42){let a=take([0],switch(o){case .some(_):{let local=[0];n=n+1;continue;}case .none:{[0]}});}while(true){let a=switch(o){case .some(_):{break;}case .none:{[0]}};}return n;}");
    value(b"module main;fn Option<i32> work(Option<i32> o){let Option<i32> selector=.none;let a=switch(selector){case .none:{[o?]}case .some(_):{[0]}};return .some(a[0]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}");
    value(b"module main;struct P{i32 x;}fn i32 main(){let ref u8[] marker=b\"*\";let Option<i32> o=.none;let p=switch(o){case .none:{let local=[0];return 42;}case .some(_):{P{.x=0}}};return p.x;}");
    value(b"module main;fn i32 main(){let Option<i32> o=.none;return (switch(o){case .some(_):{[0]}case .none:{[0]}})[switch(o){case .some(_):{0}case .none:{return 42;}}];}");
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void one(ref u8[] source){let ir::Program p=compiled(source);
    assert(verifier::verify(ref p).is_ok && p.arrays.count+p.records.count==1);
    assert(switch(vm::run_with_array_limit(ref p,16000000,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,16000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
@test fn void branches_and_mixed_nested_tails_need_one_site_and_four_backing_bytes(){
    one(b"module main;fn i32 main(){let Option<i32> o=.some(42);let a=switch(o){case .some(v):{[v]}case .none:{[0]}};return a[0];}");
    one(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .some(_):{[0;1]}case .none:{if(true){[42;1]}else{[0;1]}}};return a[0];}");
    one(b"module main;struct P{i32 x;}fn i32 main(){let Option<i32> o=.none;let p=switch(o){case .none:{P{.x=42}}case .some(_):{P{.x=0}}};return p.x;}");
    one(b"module main;struct P{i32 x;}fn i32 main(){let Option<i32> o=.some(42);let p=if(true){switch(o){case .some(v):{P{.x=v}}case .none:{P{.x=0}}}}else{P{.x=0}};return p.x;}");
}
@test fn void mismatched_dead_arms_nonexhaustive_patterns_and_reference_joins_are_rejected(){
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42]}case .some(_):{[0,0]}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42]}case .some(_):{[true]}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42]}case .some(_):{0}};return 0;}",3);
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){let Option<i32> o=.none;let p=switch(o){case .none:{P{.x=42}}case .some(_):{Q{.x=0}}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42]}case .some(_):{let x=[0];}};return 0;}",2);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=[42];let p=switch(o){case .none:{ref a}case .some(_):{ref a}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42]}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42]}case .none:{[0]}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{return 42;}case .some(_):{return 0;}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;for(let a=switch(o){case .none:{[42]}case .some(_):{[0]}};true;){}return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .some(v):{[v]}case .none:{[v]}};return 0;}",3);
}
fn void fuel(ref u8[] source,usize exact){let ir::Program p=compiled(source);
    assert(switch(vm::run_with_array_limit(ref p,exact,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,exact-1,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
@test fn void selected_case_fuel_follows_the_existing_dispatch_and_aggregate_schedule(){
    // Array: setup 5 + INIT 68 + READ 37 + DROP 49 + 6/7 scalar units.
    fuel(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42;1]}case .some(_):{[0;1]}};return a[0];}",165);
    fuel(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .some(_):{[0;1]}case .none:{[42;1]}};return a[0];}",166);
    // Record: setup 5 + INIT 46145 + READ 41281 + DROP 65 + 7/8 scalar units.
    fuel(b"module main;struct P{i32 x;}fn i32 main(){let Option<i32> o=.none;let p=switch(o){case .none:{P{.x=42}}case .some(_):{P{.x=0}}};return p.x;}",87503);
    fuel(b"module main;struct P{i32 x;}fn i32 main(){let Option<i32> o=.none;let p=switch(o){case .some(_):{P{.x=0}}case .none:{P{.x=42}}};return p.x;}",87504);
}
@test fn void independent_cfg_proof_rejects_missing_and_duplicate_switch_result_initialization(){
    let ir::Program p=compiled(b"module main;fn i32 main(){let Option<i32> o=.none;let a=switch(o){case .none:{[42;1]}case .some(_):{[0;1]}};return a[0];}");
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=33){pc+=1;}assert(pc+1<p.count && p.code[(pc+1)*8]==19);
    var ir::Program bad=p;var usize i=0;while(i<8){bad.code[pc*8+i]=0;i+=1;}bad.code[pc*8]=19;
    let usize patched=switch(ir::patch(ref mut bad,pc,pc+1,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
    assert(!verifier::verify(ref bad).is_ok);
    bad=p;i=0;while(i<8){bad.code[(pc+1)*8+i]=p.code[pc*8+i];i+=1;}
    assert(!verifier::verify(ref bad).is_ok);
}
