module tests::m2::struct_parameter_signatures;
import functions as functions;
import compiler as compiler;
import lexer as lexer;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn functions::Table scanned(ref u8[] source) {
 return switch(functions::scan(source)){case .ok(t):{t}case .err(_):{assert(false);functions::empty()}};
}
fn void gated(ref u8[] source,usize slot) {
 let functions::Table t=scanned(source);assert(t.param_records[slot]!=0);
 assert(switch(compiler::compile(source)){case .err(e):{e.kind==3 && e.offset==t.param_begins[slot]}case .ok(_):{false}});
}
fn void rejected(ref u8[] source) {assert(!functions::scan(source).is_ok);}
@test
fn void nominal_records_are_disjoint_from_scalar_array_and_wrapper_tags() {
 let ref u8[] source=b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 f(P p,i32 n,Q q,i32[2] a,Option<i32> o,Result<bool,bool> r){return 42;}fn i32 main(){return 42;}";
 let functions::Table t=scanned(source);
 assert(t.count==2 && t.entry==1 && t.arities[0]==6);
 assert(t.param_records[0]==1 && t.param_records[2]==2);
 assert(t.param_types[0]==0 && t.param_types[2]==0 && t.param_lengths[0]==0 && t.param_lengths[2]==0);
 assert(t.param_types[1]==1 && t.param_records[1]==0 && t.param_lengths[1]==0);
 assert(t.param_types[3]==1 && t.param_lengths[3]==2 && t.param_records[3]==0);
 assert(t.param_types[4]==3 && t.param_types[5]==8 && t.param_records[4]==0 && t.param_records[5]==0);
 assert(lexer::equal(source[t.param_begins[2]..t.param_ends[2]],b"q"));
 assert(source[t.bodies[0]]==114 && source[t.body_ends[0]]==125);
 let functions::Table empty=functions::empty();var usize i=0;
 while(i<128){assert(empty.param_records[i]==0 && t.param_arrays[i]==0);if(i>=6){assert(t.param_records[i]==0);}i+=1;}
}
@test
fn void forward_declarations_and_mutual_signatures_keep_nominal_ids() {
 let functions::Table t=scanned(b"module main;fn i32 main(){return 42;}fn i32 f(Outer p){return g(p);}struct Outer{Inner child;}fn i32 g(Inner p){return f(p);}struct Inner{i32 x;}");
 assert(t.entry==0 && t.count==3 && t.param_records[8]==1 && t.param_records[16]==2);
 assert(t.param_types[8]==0 && t.param_types[16]==0 && t.return_types[1]==1);
 gated(b"module main;fn i32 main(){return 42;}fn i32 f(P record){return record.x;}struct P{i32 x;}",8);
}
@test
fn void last_record_function_and_parameter_use_bounded_final_slots() {
 let functions::Table t=scanned(b"module main;struct P0{u8 x;}struct P1{u8 x;}struct P2{u8 x;}struct P3{u8 x;}struct P4{u8 x;}struct P5{u8 x;}struct P6{u8 x;}struct P7{u8 x;}struct P8{u8 x;}struct P9{u8 x;}struct P10{u8 x;}struct P11{u8 x;}struct P12{u8 x;}struct P13{u8 x;}struct P14{u8 x;}struct P15{u8 x;}struct P16{u8 x;}struct P17{u8 x;}struct P18{u8 x;}struct P19{u8 x;}struct P20{u8 x;}struct P21{u8 x;}struct P22{u8 x;}struct P23{u8 x;}struct P24{u8 x;}struct P25{u8 x;}struct P26{u8 x;}struct P27{u8 x;}struct P28{u8 x;}struct P29{u8 x;}struct P30{u8 x;}struct P31{u8 x;}fn i32 main(){return 42;}fn i32 f0(){return 0;}fn i32 f1(){return 0;}fn i32 f2(){return 0;}fn i32 f3(){return 0;}fn i32 f4(){return 0;}fn i32 f5(){return 0;}fn i32 f6(){return 0;}fn i32 f7(){return 0;}fn i32 f8(){return 0;}fn i32 f9(){return 0;}fn i32 f10(){return 0;}fn i32 f11(){return 0;}fn i32 f12(){return 0;}fn i32 f13(){return 0;}fn i32 last(P31 a,P31 b,P31 c,P31 d,P31 e,P31 f,P31 g,P31 h){return 42;}");
 assert(t.count==16 && t.entry==0 && t.arities[15]==8 && t.param_records[127]==32 && t.param_types[127]==0);
 var usize i=0;while(i<120){assert(t.param_records[i]==0);i+=1;}
 rejected(b"module main;struct P{i32 x;}fn i32 f(P a,P b,P c,P d,P e,P f,P g,P h,P i){return 42;}fn i32 main(){return 42;}");
}
@test
fn void unsupported_record_shapes_names_and_signatures_are_rejected() {
 rejected(b"module main;struct P{i32 x;}fn i32 f(P[1] p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(P<P> p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(Option<P> p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(Result<P,i32> p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(ref P p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(var P p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(P p,P p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(P p,){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 f(Missing p){return 42;}fn i32 main(){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn i32 main(P p){return 42;}");
 rejected(b"module main;struct P{i32 x;}fn P f(){return P{.x=42};}fn i32 main(){return 42;}");
}
@test
fn void compilation_gate_precedes_bodies_array_catalogs_and_unused_helpers() {
 gated(b"module main;struct P{i32 x;}fn i32 f(P record){return record.x;}fn i32 main(){return missing;}",0);
 gated(b"module main;struct P{i32 x;}fn i32 main(){return missing;}fn i32 f(P record){return 42;}",8);
 gated(b"module main;struct P{i32 x;}fn i32[1] f(P record){return [42;1];}fn i32 main(){return 42;}",0);
 gated(b"module main;struct P{i32 x;}fn i32 f(P record){return 42;}fn i32 a0(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return 42;}fn i32 a1(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return 42;}fn i32 a2(i32[1] a,i32[1] b,i32[1] c,i32[1] d,i32[1] e,i32[1] f,i32[1] g,i32[1] h){return 42;}fn i32 main(){return 42;}",0);
}
@test
fn void existing_array_parameters_wrappers_and_helper_records_still_execute() {
 let ref u8[] source=b"module main;struct P{i32 x;}fn i32 f(i32[1] a){let P p=P{.x=a[0]};return p.x;}fn Option<i32> wrap(i32 n){return .some(n);}fn i32 main(){let i32[1] a=[42;1];let Option<i32> r=wrap(f(a));return switch(r){case .some(n):{n}case .none:{0}};}";
 let functions::Table t=scanned(source);var usize i=0;while(i<128){assert(t.param_records[i]==0);i+=1;}
 let ir::Program p=switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,1000000)){case .ok(n):{n==42}case .err(_):{false}});
}
