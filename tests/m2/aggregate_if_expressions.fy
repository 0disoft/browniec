module tests::m2::aggregate_if_expressions;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;
import std::bytes as bytes;
fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
@test fn void fixed_arrays_compose_with_locals_arguments_returns_assignment_and_projections(){
    value(b"module main;fn i32[2] make(){return if(false){[0,0]}else{[20,22]};}fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){let a=if(true){make()}else{[0;2]};var i32[2] b=(if(false){[0,0]}else{a});b=if(true){a}else{[0;2]};return take(if(true){b}else{make()});}");
    value(b"module main;fn i32 main(){let u8[1] a=if(true){[42]}else{[0]};let b=if(false){[false]}else{[true]};if((b)[0]){return (if(true){a}else{[0]})[0] as i32;}return 0;}");
    value(b"module main;fn i32 main(){return ((if(false){[0;2]}else if(true){[20,22]}else{[0,0]}))[0]+(if(true){[0,22]}else{[0,0]})[1];}");
    value(b"module main;fn i32 main(){let ref u8[] marker=b\"*\";let a=if(true){if(false){[0]}else{[42]}}else{[0]};return a[0];}");
}
@test fn void exact_nominal_records_compose_with_child_values_calls_and_scalar_paths(){
    value(b"module main;struct P{i32 x;}fn P make(){return if(false){P{.x=0}}else{P{.x=42}};}fn i32 take(P p){return p.x;}fn i32 main(){let p=if(true){make()}else{P{.x=0}};var P q=if(false){P{.x=0}}else{p};q=if(true){p}else{make()};return take(if(false){P{.x=0}}else{q});}");
    value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){let r=R{.p=P{.x=42}};let p=if(false){P{.x=0}}else{r.p};return (if(true){p}else{P{.x=0}}).x;}");
    value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){var r=R{.p=P{.x=0}};r.p=if(true){P{.x=42}}else{P{.x=0}};let ref u8[] marker=b\"*\";return ((if(false){R{.p=P{.x=0}}}else{r})).p.x;}");
    value(b"module main;struct P{i32 x;}struct R{P p;}fn i32 main(){let r=R{.p=if(false){P{.x=0}}else{P{.x=42}}};return r.p.x;}");
}
@test fn void selected_arms_snapshot_values_and_keep_condition_and_argument_effect_order(){
    value(b"module main;fn bool choose(ref mut i32[] c){c[0]=c[0]+1;return true;}fn i32 main(){var c=[0];let a=if(choose(ref mut c)){let local=[40];local}else{c[0]=99;[0]};return a[0]+c[0]+1;}");
    value(b"module main;fn i32 change(ref mut i32[] a){a[0]=22;return 0;}fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){var a=[20];let n=take(if(false){[0]}else{a},change(ref mut a));return n+a[0];}");
    value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x;}fn i32 main(){var p=P{.x=20};let n=take(if(true){p}else{P{.x=0}},if(true){p.x=22;0}else{0});return n+p.x;}");
    value(b"module main;fn i32 main(){return (if(true){[42]}else{[1/0]})[0];}");
}
@test fn void return_propagation_break_and_continue_close_only_published_values(){
    value(b"module main;fn i32 take(i32[1] a,i32[1] b){return 0;}fn i32 main(){let a=take([0],if(true){let local=[0];return 42;}else{[0]});return 0;}");
    value(b"module main;fn i32 take(i32[1] a,i32[1] b){return 0;}fn i32 main(){var n=0;while(n<42){let a=take([0],if(true){let local=[0];n=n+1;continue;}else{[0]});}while(true){let a=take([0],if(true){break;}else{[0]});}return n;}");
    value(b"module main;fn Option<i32> work(Option<i32> o){let a=if(true){[o?]}else{[0]};return .some(a[0]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}");
    value(b"module main;struct P{i32 x;}fn i32 main(){let p=if(false){P{.x=0}}else{let local=[0];return 42;};return p.x;}");
    value(b"module main;fn i32 main(){let ref u8[] marker=b\"*\";let Option<i32> o=.none;return (if(true){[0]}else{[0]})[switch(o){case .some(v):{0}case .none:{return 42;}}];}");
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void one(ref u8[] source,bool record){let ir::Program p=compiled(source);
    assert(verifier::verify(ref p).is_ok && p.arrays.count+p.records.count==1);
    assert(switch(vm::run_with_array_limit(ref p,16000000,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,16000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
@test fn void branches_and_nested_tails_initialize_one_site_at_exact_backing(){
    one(b"module main;fn i32 main(){let a=if(true){[42]}else{[0]};return a[0];}",false);
    one(b"module main;fn i32 main(){let a=if(false){[0;1]}else{if(true){[42;1]}else{[0;1]}};return a[0];}",false);
    one(b"module main;struct P{i32 x;}fn i32 main(){let p=if(true){P{.x=42}}else{P{.x=0}};return p.x;}",true);
    one(b"module main;struct P{i32 x;}fn i32 main(){let p=if(false){P{.x=0}}else{if(true){P{.x=42}}else{P{.x=0}}};return p.x;}",true);
}
@test fn void unselected_type_errors_shape_conflicts_and_reference_joins_are_rejected(){
    rejected(b"module main;fn i32 main(){let a=if(true){[42]}else{[0,0]};return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=if(true){[42]}else{[true]};return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=if(true){[42]}else{0};return 0;}",3);
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){let p=if(true){P{.x=42}}else{Q{.x=0}};return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=if(true){[42]}else{let x=[0];};return 0;}",2);
    rejected(b"module main;fn i32 main(){let a=[42];let p=if(true){ref a}else{ref a};return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=if(true){[42]};return 0;}",2);
}
fn void fuel(ref u8[] source,usize exact){let ir::Program p=compiled(source);
    assert(switch(vm::run_with_array_limit(ref p,exact,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,exact-1,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
@test fn void aggregate_branches_keep_independent_exact_fuel_and_default_prices(){
    // Repeated array: backing setup 5, selected INIT 68, READ 37, DROP 49,
    // and six scalar instructions (five on the false path).
    fuel(b"module main;fn i32 main(){let a=if(true){[42;1]}else{[0;1]};return a[0];}",165);
    fuel(b"module main;fn i32 main(){let a=if(false){[0;1]}else{[42;1]};return a[0];}",164);
    // Record: setup 5, INIT 46145, READ 41281, DROP 65, seven scalar ops.
    fuel(b"module main;struct P{i32 x;}fn i32 main(){let p=if(true){P{.x=42}}else{P{.x=0}};return p.x;}",87503);
    fuel(b"module main;struct P{i32 x;}fn i32 main(){let p=if(false){P{.x=0}}else{P{.x=42}};return p.x;}",87502);
}
