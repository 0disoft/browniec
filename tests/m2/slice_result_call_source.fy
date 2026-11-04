module tests::m2::slice_result_call_source;
import compiler as compiler;
import slice_result_ir as results;
import slice_result_verifier as verifier;
import ir as ir;
import render as render;

@effects(console)
fn results::Program lowered(ref u8[] source){
    assert(!compiler::compile(source).is_ok);
    return switch(compiler::inspect_slice_result_ir(source)){case .ok(v):{v}case .err(e):{let i32 printed=render::outcome(true,false,true,0,e);assert(false);results::Program{.body=ir::empty(),.elements=[0;16],.parameters=[0;16]}}};
}
@effects(console)
fn void accepted(ref u8[] source){let results::Program p=lowered(source);assert(verifier::inspect(ref p).is_ok);var usize pc=0;var bool found=false;
    while(pc<p.body.count){if(p.body.code[pc*8]==66){found=true;}pc+=1;}assert(found);
}
fn void rejected(ref u8[] source){assert(!compiler::inspect_slice_result_ir(source).is_ok);assert(!compiler::compile(source).is_ok);}
fn usize opcode(ref results::Program p,u8 op){var usize pc=0;while(pc<p.body.count){if(p.body.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}

@effects(console)
@test
fn void source_bindings_keep_exact_six_scalar_access_modes(){
    accepted(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){let i32[2] a=[42;2];let ref i32[] r=f(ref a);return 0;}");
    accepted(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){var i32[2] a=[42;2];let ref mut i32[] r=f(ref mut a);return 0;}");
    accepted(b"module main;fn ref bool[] f(ref bool[] p){return ref p;}fn i32 main(){let bool[2] a=[true;2];let ref bool[] r=f(ref a);return 0;}");
    accepted(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p;}fn i32 main(){var bool[2] a=[true;2];let ref mut bool[] r=f(ref mut a);return 0;}");
    accepted(b"module main;fn ref i64[] f(ref i64[] p){return ref p;}fn i32 main(){let i64[2] a=[42;2];let ref i64[] r=f(ref a);return 0;}");
    accepted(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p;}fn i32 main(){var i64[2] a=[42;2];let ref mut i64[] r=f(ref mut a);return 0;}");
    accepted(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] r=f(ref a);return 0;}");
    accepted(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){var u8[2] a=[42;2];let ref mut u8[] r=f(ref mut a);return 0;}");
    accepted(b"module main;fn ref u32[] f(ref u32[] p){return ref p;}fn i32 main(){let u32[2] a=[42;2];let ref u32[] r=f(ref a);return 0;}");
    accepted(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p;}fn i32 main(){var u32[2] a=[42;2];let ref mut u32[] r=f(ref mut a);return 0;}");
    accepted(b"module main;fn ref usize[] f(ref usize[] p){return ref p;}fn i32 main(){let usize[2] a=[42;2];let ref usize[] r=f(ref a);return 0;}");
    accepted(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p;}fn i32 main(){var usize[2] a=[42;2];let ref mut usize[] r=f(ref mut a);return 0;}");
}
@effects(console)
@test
fn void named_range_results_close_before_restored_parents_are_reused(){
    accepted(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){let i32[3] a=[42;3];let ref i32[] p=ref a;{let ref i32[] r=f(ref p[1..]);let i32 x=r[0];}return p[0];}");
    accepted(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){var i32[3] a=[0;3];let ref mut i32[] p=ref mut a;{let ref mut i32[] r=f(ref mut p[1..]);r[0]=42;}return p[1];}");
    accepted(b"module main;fn ref mut i32[] f(ref mut i32[] a,ref mut i32[] b){return ref mut b;}fn i32 main(){var i32[2] a=[0;2];var i32[2] b=[0;2];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut b;{let ref mut i32[] r=f(ref mut p[..],ref mut q[1..]);r[0]=42;}return q[1];}");
}
@effects(console)
@test
fn void selected_temporary_literal_and_owned_call_inputs_outlive_the_call(){
    accepted(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){return ref q;}fn i32 main(){let ref i32[] r=f(ref [1;2],ref [42;2]);return r[0];}");
    accepted(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){let ref mut i32[] r=f(ref mut [0;2]);r[0]=42;return r[0];}");
    accepted(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32[3] make(){return [42;3];}fn i32 main(){let ref i32[] r=f(ref make()[1..]);return r[0];}");
}
@effects(console)
@test
fn void result_bindings_support_aliases_forward_origins_and_grounded_recursion(){
    let results::Program p=lowered(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){let ref i32[] r=g(ref q,ref p);let ref i32[] s=ref r;return ref s;}fn ref i32[] g(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){return 42;}");
    assert(p.parameters[0]==1 && p.parameters[1]==2);
    accepted(b"module main;fn ref i32[] f(ref i32[] p,i32 n){if(n==0){return ref p;}let ref i32[] r=f(ref p,n-1);return ref r;}fn i32 main(){return 42;}");
    accepted(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32 n){if(n==0){return ref mut p;}let ref mut i32[] r=f(ref mut p,n-1);return ref mut r;}fn i32 main(){return 42;}");
}
@effects(console)
@test
fn void mixed_value_arguments_and_end_masks_keep_source_argument_order(){
    let results::Program p=lowered(b"module main;fn ref mut i32[] f(i32 n,ref mut i32[] a,ref mut i32[] b){return ref mut b;}fn i32 main(){var i32[2] a=[0;2];var i32[2] b=[0;2];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut b;let ref mut i32[] r=f(3,ref mut p[..],ref mut q[..]);return r[0];}");
    let usize at=opcode(ref p,66);assert(p.body.code[at*8+4]==6);
    accepted(b"module main;struct P{i32 x;}fn ref i32[] f(P p,i32[2] a,ref i32[] b){return ref b;}fn i32 main(){let ref i32[] r=f(P{.x=1},[2;2],ref [42;2]);return r[0];}");
}
@effects(console)
@test
fn void unsafe_bindings_fail_independent_lifetime_origin_and_exact_type_checks(){
    rejected(b"module main;fn ref i32[] f(ref i32[] p){let ref i32[] r=f(ref p);return ref r;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q,i32 n){if(n==0){return ref p;}let ref i32[] r=f(ref q,ref p,n-1);return ref r;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn ref i32[] bad(ref i32[] p){let ref i32[] r=f(ref [42;2]);return ref r;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;let ref mut i32[] r=f(ref mut p);return p[0]+r[0];}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){let i32[2] a=[42;2];let ref bool[] r=f(ref a);return 0;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){var i32[2] a=[42;2];let ref mut i32[] r=f(ref a);return 0;}");
}
