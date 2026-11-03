module tests::m2::slice_result_signatures;
import functions as functions;
import compiler as compiler;
import lexer as lexer;

fn functions::Table scanned(ref u8[] source){
    return switch(functions::scan(source)){case .ok(t):{t}case .err(_):{assert(false);functions::empty()}};
}
fn void closed(ref u8[] source){
    let functions::Table t=scanned(source);var usize f=0;
    while(f<t.count && t.return_slice_elements[f]==0){f+=1;}
    assert(f<t.count);
    assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==3 && e.offset==t.begins[f]}});
}
fn void described(ref u8[] source,usize f,u8 element,u8 candidates){
    let functions::Table t=scanned(source);
    assert(t.return_slice_elements[f]==element && t.return_slice_candidates[f]==candidates);
    assert(t.return_types[f]==0 && t.return_lengths[f]==0 && t.return_records[f]==0);
    assert(t.begins[f]<t.ends[f] && t.bodies[f]<=t.body_ends[f] && t.body_ends[f]<source.len);
    closed(source);
}
fn void rejected(ref u8[] source){assert(!functions::scan(source).is_ok);}
@test
fn void six_scalar_results_preserve_exact_shared_and_exclusive_modes(){
    described(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}",0,1,1);
    described(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 42;}",0,129,1);
    described(b"module main;fn ref bool[] f(ref bool[] p){return ref p;}fn i32 main(){return 42;}",0,2,1);
    described(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p;}fn i32 main(){return 42;}",0,130,1);
    described(b"module main;fn ref i64[] f(ref i64[] p){return ref p;}fn i32 main(){return 42;}",0,9,1);
    described(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p;}fn i32 main(){return 42;}",0,137,1);
    described(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){return 42;}",0,10,1);
    described(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){return 42;}",0,138,1);
    described(b"module main;fn ref u32[] f(ref u32[] p){return ref p;}fn i32 main(){return 42;}",0,11,1);
    described(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p;}fn i32 main(){return 42;}",0,139,1);
    described(b"module main;fn ref usize[] f(ref usize[] p){return ref p;}fn i32 main(){return 42;}",0,12,1);
    described(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p;}fn i32 main(){return 42;}",0,140,1);
}

@test
fn void candidate_bits_use_argument_positions_and_exact_types_and_modes(){
    described(b"module main;fn ref i32[] f(ref mut i32[] w,ref u32[] q,i32[1] a,Option<i32> o,ref i32[] p,i32 n,ref i32[] r,bool b){return ref p;}fn i32 main(){return 42;}",0,1,80);
    described(b"module main;fn ref mut u8[] f(i32 a,bool b,u8[1] c,ref u8[] d,ref mut i32[] e,u32 f,usize g,ref mut u8[] h){return ref mut h;}fn i32 main(){return 42;}",0,138,128);
}

@test
fn void candidate_sets_do_not_prove_which_input_or_local_body_returns(){
    described(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q,bool b){if(b){return ref p;}return ref q;}fn i32 main(){return 42;}",0,1,3);
    described(b"module main;fn ref i32[] f(ref i32[] p){let i32[1] local=[42;1];return ref local;}fn i32 main(){return 42;}",0,1,1);
    described(b"module main;fn ref i32[] f(ref i32[] p){return ref [42;1];}fn i32 main(){return 42;}",0,1,1);
}

@test
fn void owned_local_static_and_incompatible_origins_are_not_candidates(){
    rejected(b"module main;fn ref i32[] f(){return ref [42;1];}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(i32[1] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(i32 p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref u32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref mut i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref mut i32[] f(ref i32[] p){return ref mut p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref bool[] f(ref u8[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] main(){return ref [42;1];}");
    rejected(b"module main;fn ref mut i32[] main(ref mut i32[] p){return ref mut p;}");
}

@test
fn void malformed_wrapped_nominal_and_overwide_signatures_reject(){
    rejected(b"module main;fn ref i32[1] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[][] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref Option<i32>[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref Result<i32,i32>[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}fn ref P[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref mut mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[ f(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,i32 h){return ref p;}fn i32 main(){return 42;}");
}

@test
fn void final_function_and_eighth_parameter_bits_remain_bounded(){
    described(b"module main;fn i32 main(){return 42;}fn i32 a(){return 0;}fn i32 b(){return 0;}fn i32 c(){return 0;}fn i32 d(){return 0;}fn i32 e(){return 0;}fn i32 f(){return 0;}fn i32 g(){return 0;}fn i32 h(){return 0;}fn i32 i(){return 0;}fn i32 j(){return 0;}fn i32 k(){return 0;}fn i32 l(){return 0;}fn i32 m(){return 0;}fn i32 n(){return 0;}fn ref usize[] last(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,ref usize[] h){return ref h;}",15,12,128);
    rejected(b"module main;fn i32 main(){return 42;}fn i32 a(){return 0;}fn i32 b(){return 0;}fn i32 c(){return 0;}fn i32 d(){return 0;}fn i32 e(){return 0;}fn i32 f(){return 0;}fn i32 g(){return 0;}fn i32 h(){return 0;}fn i32 i(){return 0;}fn i32 j(){return 0;}fn i32 k(){return 0;}fn i32 l(){return 0;}fn i32 m(){return 0;}fn i32 n(){return 0;}fn ref usize[] last(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,ref usize[] h){return ref h;}fn i32 extra(){return 0;}");
}

@test
fn void old_result_kinds_and_unused_signature_slots_keep_zero_sentinels(){
    let functions::Table t=scanned(b"module main;struct P{i32 x;}fn i32 scalar(){return 42;}fn i32[1] array(){return [42;1];}fn P record(){return P{.x=42};}fn Option<i32> wrapped(){return .none;}fn i32 main(){return 42;}");
    let functions::Table empty=functions::empty();var usize i=0;
    while(i<16){assert(t.return_slice_elements[i]==0 && t.return_slice_candidates[i]==0 && empty.return_slice_elements[i]==0 && empty.return_slice_candidates[i]==0);i+=1;}
    assert(t.return_types[0]==1 && t.return_lengths[1]==1 && t.return_records[2]==1 && t.return_types[3]==3);
}

@test
fn void unreachable_forward_recursive_and_invalid_bodies_cannot_bypass_gate(){
    closed(b"module main;fn i32 main(){return 42;}fn ref i32[] f(ref i32[] p){return ref p;}");
    closed(b"module main;fn ref i32[] f(ref i32[] p){return g(ref p);}fn ref i32[] g(ref i32[] p){return f(ref p);}fn i32 main(){return 42;}");
    closed(b"module main;fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref f(ref a);return p[0];}fn ref i32[] f(ref i32[] p){return ref p;}");
    closed(b"module main;fn ref i32[] f(ref i32[] p){return unknown;}fn i32 main(){return 42;}");
}
