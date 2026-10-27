module tests::m2::struct_result_signatures;
import functions as functions;
import compiler as compiler;
import lexer as lexer;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn functions::Table scanned(ref u8[] source) {
 return switch(functions::scan(source)){case .ok(t):{t}case .err(_):{assert(false);functions::empty()}};
}
fn void gated(ref u8[] source,usize f) {
 let functions::Table t=scanned(source);assert(t.return_records[f]!=0);
 assert(switch(compiler::compile(source)){case .err(e):{e.kind==3 && e.offset==t.begins[f]}case .ok(_):{false}});
}
fn void rejected(ref u8[] source){assert(!functions::scan(source).is_ok);}
fn void value(ref u8[] source) {
 let ir::Program p=switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,1000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void nominal_result_ids_are_disjoint_from_scalar_array_and_wrapper_metadata() {
 let functions::Table t=scanned(b"module main;struct P{i32 x;}struct Q{i32 x;}fn P a(){return 0;}fn Q b(){return 0;}fn i32 c(){return 0;}fn bool d(){return true;}fn u8 e(){return 0;}fn i64 f(){return 0;}fn u32 g(){return 0;}fn usize h(){return 0;}fn bool[2] i(){return 0;}fn Option<i32> j(){return .none;}fn Result<bool,bool> k(){return .ok(true);}fn i32 main(){return 42;}");
 assert(t.count==12 && t.entry==11 && t.return_records[0]==1 && t.return_records[1]==2);
 assert(t.return_types[0]==0 && t.return_types[1]==0 && t.return_lengths[0]==0 && t.return_lengths[1]==0);
 assert(t.return_types[2]==1 && t.return_types[3]==2 && t.return_types[4]==10);
 assert(t.return_types[5]==9 && t.return_types[6]==11 && t.return_types[7]==12);
 assert(t.return_types[8]==2 && t.return_lengths[8]==2 && t.return_types[9]==3 && t.return_types[10]==8);
 let functions::Table empty=functions::empty();var usize i=0;
 while(i<16){assert(empty.return_records[i]==0);if(i>=2){assert(t.return_records[i]==0);}i+=1;}
}
@test
fn void forward_nested_and_mutual_names_preserve_function_and_parameter_spans() {
 let ref u8[] source=b"module main;fn Outer f(Inner p){return g(p);}fn i32 main(){return 42;}struct Outer{Inner child;}fn Inner g(Outer p){return f(p);}struct Inner{i32 x;}";
 let functions::Table t=scanned(source);
 assert(t.count==3 && t.entry==1 && t.return_records[0]==1 && t.return_records[2]==2);
 assert(t.param_records[0]==2 && t.param_records[16]==1 && t.arities[0]==1 && t.arities[2]==1);
 assert(t.return_lengths[0]==0 && t.return_types[0]==0 && t.param_types[0]==0);
 assert(lexer::equal(source[t.begins[0]..t.ends[0]],b"f") && lexer::equal(source[t.param_begins[16]..t.param_ends[16]],b"p"));
 assert(source[t.bodies[0]]==114 && source[t.body_ends[0]]==125);
 gated(b"module main;fn i32 main(){return 42;}fn P make(P p){return p;}struct P{i32 x;}",1);
}
@test
fn void final_result_slot_keeps_the_largest_nominal_id_and_function_limit() {
 let functions::Table t=scanned(b"module main;struct P0{u8 x;}struct P1{u8 x;}struct P2{u8 x;}struct P3{u8 x;}struct P4{u8 x;}struct P5{u8 x;}struct P6{u8 x;}struct P7{u8 x;}struct P8{u8 x;}struct P9{u8 x;}struct P10{u8 x;}struct P11{u8 x;}struct P12{u8 x;}struct P13{u8 x;}struct P14{u8 x;}struct P15{u8 x;}struct P16{u8 x;}struct P17{u8 x;}struct P18{u8 x;}struct P19{u8 x;}struct P20{u8 x;}struct P21{u8 x;}struct P22{u8 x;}struct P23{u8 x;}struct P24{u8 x;}struct P25{u8 x;}struct P26{u8 x;}struct P27{u8 x;}struct P28{u8 x;}struct P29{u8 x;}struct P30{u8 x;}struct P31{u8 x;}fn i32 main(){return 42;}fn i32 f0(){return 0;}fn i32 f1(){return 0;}fn i32 f2(){return 0;}fn i32 f3(){return 0;}fn i32 f4(){return 0;}fn i32 f5(){return 0;}fn i32 f6(){return 0;}fn i32 f7(){return 0;}fn i32 f8(){return 0;}fn i32 f9(){return 0;}fn i32 f10(){return 0;}fn i32 f11(){return 0;}fn i32 f12(){return 0;}fn i32 f13(){return 0;}fn P31 last(){return 0;}");
 assert(t.count==16 && t.return_records[15]==32 && t.return_types[15]==0 && t.return_lengths[15]==0);
 var usize i=0;while(i<15){assert(t.return_records[i]==0);i+=1;}
 rejected(b"module main;struct P0{u8 x;}struct P1{u8 x;}struct P2{u8 x;}struct P3{u8 x;}struct P4{u8 x;}struct P5{u8 x;}struct P6{u8 x;}struct P7{u8 x;}struct P8{u8 x;}struct P9{u8 x;}struct P10{u8 x;}struct P11{u8 x;}struct P12{u8 x;}struct P13{u8 x;}struct P14{u8 x;}struct P15{u8 x;}struct P16{u8 x;}struct P17{u8 x;}struct P18{u8 x;}struct P19{u8 x;}struct P20{u8 x;}struct P21{u8 x;}struct P22{u8 x;}struct P23{u8 x;}struct P24{u8 x;}struct P25{u8 x;}struct P26{u8 x;}struct P27{u8 x;}struct P28{u8 x;}struct P29{u8 x;}struct P30{u8 x;}struct P31{u8 x;}fn i32 main(){return 42;}fn i32 f0(){return 0;}fn i32 f1(){return 0;}fn i32 f2(){return 0;}fn i32 f3(){return 0;}fn i32 f4(){return 0;}fn i32 f5(){return 0;}fn i32 f6(){return 0;}fn i32 f7(){return 0;}fn i32 f8(){return 0;}fn i32 f9(){return 0;}fn i32 f10(){return 0;}fn i32 f11(){return 0;}fn i32 f12(){return 0;}fn i32 f13(){return 0;}fn P31 last(){return 0;}fn i32 extra(){return 0;}");
}
@test
fn void unknown_borrowed_wrapped_array_and_entry_record_results_are_rejected() {
 rejected(b"module main;fn Unknown make(){return 0;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P[1] make(){return 0;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P<P> make(){return 0;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn Option<P> make(){return .none;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn Result<i32,P> make(){return .ok(0);}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn ref P make(){return 0;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn var P make(){return 0;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P main(){return 0;}");
}
@test
fn void compilation_gate_precedes_bodies_calls_and_aggregate_catalogs() {
 gated(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){return missing;}",0);
 gated(b"module main;struct P{i32 x;}fn i32 main(){return missing;}fn P make(){return P{.x=42};}",1);
 gated(b"module main;struct P{i32 x;}fn P make(P p){return p;}fn i32 main(){let P p=P{.x=42};return make(p);}",0);
 gated(b"module main;struct P{i32 x;}fn P make(){return 0;}fn i32 a(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return 0;}fn i32 b(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return 0;}fn i32 c(i32[1] a){return 0;}fn i32 main(){return 42;}",0);
 gated(b"module main;struct P{i32 x;}fn P make(){return 0;}fn i32 a(P a,P b,P c,P d,P e,P f,P g,P h){return 0;}fn i32 b(P a,P b,P c,P d,P e,P f,P g,P h){return 0;}fn i32 c(P a){return 0;}fn i32 main(){return 42;}",0);
}
@test
fn void existing_record_parameters_array_results_and_scalar_wrappers_still_execute() {
 value(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let P p=P{.x=42};return take(p);}");
 value(b"module main;fn i32[1] make(){return [42;1];}fn i32 main(){let i32[1] a=make();return a[0];}");
 value(b"module main;fn Option<i32> f(){return .some(42);}fn i32 main(){switch(f()){case .some(v):{return v;}case .none:{return 0;}}}");
}
