module tests::m2::slice_reborrow_array_results;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void run_source(ref u8[] source,u8 expected){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,16000000,256)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected}});}
fn void conflict(ref u8[] source){let ir::Program p=compiled(source);assert(!verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});}

@test
fn void all_six_array_results_return_after_child_restoration(){
    run_source(b"module main;fn i32[2] f(ref mut i32[] q){q[0]=42;return [q[0];2];}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p[1..];let i32[2] b=f(ref mut q);if(b[0]!=42 || b[1]!=42 || q[0]!=42){return 0;}}return p[1];}",0);
    run_source(b"module main;fn bool[1] f(ref mut bool[] q){q[0]=true;return [q[0];1];}fn i32 main(){var bool[1] a=[false;1];let ref mut bool[] p=ref mut a;let ref mut bool[] q=ref mut p;let bool[1] b=f(ref mut q);if(b[0] && q[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn i64[1] f(ref mut i64[] q){q[0]=-9223372036854775808;return [q[0];1];}fn i32 main(){var i64[1] a=[0;1];let ref mut i64[] p=ref mut a;let ref mut i64[] q=ref mut p;let i64[1] b=f(ref mut q);if(b[0]==-9223372036854775808 && b[0]==q[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn u8[1] f(ref mut u8[] q){q[0]=42;return [q[0];1];}fn i32 main(){var u8[1] a=[0;1];let ref mut u8[] p=ref mut a;let ref mut u8[] q=ref mut p;let u8[1] b=f(ref mut q);return b[0] as i32+q[0] as i32-42;}",0);
    run_source(b"module main;fn u32[1] f(ref mut u32[] q){q[0]=4294967295;return [q[0];1];}fn i32 main(){var u32[1] a=[0;1];let ref mut u32[] p=ref mut a;let ref mut u32[] q=ref mut p;let u32[1] b=f(ref mut q);if(b[0]==4294967295 && b[0]==q[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn usize[1] f(ref mut usize[] q){q[0]=18446744073709551615;return [q[0];1];}fn i32 main(){var usize[1] a=[0;1];let ref mut usize[] p=ref mut a;let ref mut usize[] q=ref mut p;let usize[1] b=f(ref mut q);if(b[0]==18446744073709551615 && b[0]==q[0]){return 42;}return 0;}",0);
}

@test
fn void owned_arguments_shared_readers_and_multiple_writers_return_arrays(){
    run_source(b"module main;struct P{i32 x;}fn i32[1] f(ref mut i32[] q,i32[1] b,P v,ref u8[] s){q[0]=b[0]+v.x+s[0] as i32;return [q[0];1];}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[40;1];let P v=P{.x=1};let u8[1] c=[1;1];let ref u8[] s=ref c;let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] r=f(ref mut q,b,v,ref s);return r[0]+q[0]-42;}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] q,i32[1] b){q[0]=b[0];return b;}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] r=f(ref mut q,b);return r[0]+q[0]+b[0]-84;}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] q,ref mut i32[] r){q[0]=21;r[0]=21;return [q[0]+r[0];1];}fn i32 main(){var i32[1] a=[0;1];var i32[1] b=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] s=ref mut b;let ref mut i32[] q=ref mut p;let ref mut i32[] r=ref mut s;let i32[1] answer=f(ref mut q,ref mut r);return answer[0]+q[0]+r[0]-42;}",0);
}

@test
fn void formal_forwarding_recursive_results_and_assignment_restore_callers(){
    run_source(b"module main;fn i32[1] g(ref mut i32[] q,i32[1] b){q[0]=b[0];return b;}fn i32[1] f(ref mut i32[] p,i32[1] b){let ref mut i32[] q=ref mut p;return g(ref mut q,b);}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let i32[1] r=f(ref mut p,b);return r[0]+p[0]-42;}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] p,i32[1] b,i32 n){if(n==0){p[0]=b[0];return b;}let ref mut i32[] q=ref mut p;return f(ref mut q,b,n-1);}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let i32[1] r=f(ref mut p,b,2);return r[0]+p[0]-42;}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] q){q[0]=42;return [q[0];1];}fn i32 main(){var i32[1] a=[0;1];var i32[1] out=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;out=f(ref mut q);out=f(ref mut q);return out[0]+q[0]-42;}",0);
}

@test
fn void bounds_arithmetic_and_result_allocation_failures_propagate(){
    run_source(b"module main;fn i32[1] f(ref mut i32[] q){q[0]=42;return [q[1];1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] r=f(ref mut q);return r[0];}",14);
    run_source(b"module main;fn i32[1] f(ref mut i32[] q){q[0]=42;return [q[0]/0;1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] r=f(ref mut q);return r[0];}",7);
    run_source(b"module main;fn i32[64] f(ref mut i32[] q){q[0]=42;return [q[0];64];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[64] r=f(ref mut q);return r[0];}",13);
}

@test
fn void record_results_duplicate_children_and_unreachable_record_calls_reject(){
    conflict(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q){return P{.x=42};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q);return 42;}");
    conflict(b"module main;fn i32[1] f(ref mut i32[] q,ref mut i32[] r){return [42;1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] r=f(ref mut q,ref mut q);return 42;}");
    conflict(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q){return P{.x=42};}fn i32 unused(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q);return 42;}fn i32 main(){return 42;}");
}
