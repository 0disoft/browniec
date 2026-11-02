module tests::m2::slice_reborrow_owned_calls;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void run_source(ref u8[] source,u8 expected){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,16000000,256)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected}});}
fn void conflict(ref u8[] source){let ir::Program p=compiled(source);assert(!verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});}

@test
fn void all_six_owned_scalar_arrays_copy_with_live_derived_arguments(){
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32[1] b){p[0]=b[0];return p[0];}fn i32 main(){var i32[2] a=[0;2];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p[1..];let i32 n=f(ref mut q,b);if(q[0]!=n){return 0;}}return p[1]+b[0]-42;}",0);
    run_source(b"module main;fn i32 f(ref mut bool[] p,bool[1] b){p[0]=b[0];return 42;}fn i32 main(){var bool[1] a=[false;1];let bool[1] b=[true;1];let ref mut bool[] p=ref mut a;{let ref mut bool[] q=ref mut p;let i32 n=f(ref mut q,b);}if(p[0] && b[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut i64[] p,i64[1] b){p[0]=b[0];return 42;}fn i32 main(){var i64[1] a=[0;1];let i64[1] b=[-9223372036854775808;1];let ref mut i64[] p=ref mut a;{let ref mut i64[] q=ref mut p;let i32 n=f(ref mut q,b);}if(p[0]==b[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut u8[] p,u8[1] b){p[0]=b[0];return p[0] as i32;}fn i32 main(){var u8[1] a=[0;1];let u8[1] b=[42;1];let ref mut u8[] p=ref mut a;{let ref mut u8[] q=ref mut p;let i32 n=f(ref mut q,b);}return p[0] as i32;}",0);
    run_source(b"module main;fn i32 f(ref mut u32[] p,u32[1] b){p[0]=b[0];return 42;}fn i32 main(){var u32[1] a=[0;1];let u32[1] b=[4294967295;1];let ref mut u32[] p=ref mut a;{let ref mut u32[] q=ref mut p;let i32 n=f(ref mut q,b);}if(p[0]==b[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut usize[] p,usize[1] b){p[0]=b[0];return 42;}fn i32 main(){var usize[1] a=[0;1];let usize[1] b=[18446744073709551615;1];let ref mut usize[] p=ref mut a;{let ref mut usize[] q=ref mut p;let i32 n=f(ref mut q,b);}if(p[0]==b[0]){return 42;}return 0;}",0);
}

@test
fn void mixed_record_array_reader_scalar_and_writer_arguments_preserve_order(){
    run_source(b"module main;struct P{bool flag;i64 wide;i32 n;}fn i32 f(P v,ref mut i32[] q,i32[1] b,ref u8[] s,i32 n){if(v.flag && v.wide==-9223372036854775808){q[0]=v.n+b[0]+s[0] as i32+n;return q[0];}return 0;}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[1;1];let u8[1] c=[1;1];let P v=P{.flag=true,.wide=-9223372036854775808,.n=38};let ref u8[] s=ref c;let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p;let i32 n=f(v,ref mut q,b,ref s,2);}return p[0];}",0);
    run_source(b"module main;struct P{i32 x;}fn i32 f(ref mut i32[] q,P v,P w){q[0]=v.x+w.x;return q[0];}fn i32 main(){var i32[1] a=[0;1];let P v=P{.x=21};let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut q,v,v);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] q,ref mut i32[] r,i32[1] b){q[0]=b[0];r[0]=b[0];return q[0]+r[0];}fn i32 main(){var i32[1] a=[0;1];var i32[1] c=[0;1];let i32[1] b=[21;1];let ref mut i32[] p=ref mut a;let ref mut i32[] s=ref mut c;let ref mut i32[] q=ref mut p;let ref mut i32[] r=ref mut s;return f(ref mut q,ref mut r,b);}",0);
}

@test
fn void formal_descendants_recursive_forwarding_and_early_exits_restore_sources(){
    run_source(b"module main;struct P{i32 x;}fn i32 g(ref mut i32[] q,P v){q[0]=v.x;return q[0];}fn i32 f(ref mut i32[] p,P v){let ref mut i32[] q=ref mut p;return g(ref mut q,v);}fn i32 main(){var i32[1] a=[0;1];let P v=P{.x=42};let ref mut i32[] p=ref mut a;return f(ref mut p,v);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32[1] b,i32 n){if(n==0){p[0]=b[0];return p[0];}let ref mut i32[] q=ref mut p;return f(ref mut q,b,n-1);}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;return f(ref mut p,b,2);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] q,i32[1] b){q[0]=b[0];return q[0];}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[21;1];let ref mut i32[] p=ref mut a;var i32 n=0;while(n<2){let ref mut i32[] q=ref mut p;n=n+1;let i32 x=f(ref mut q,b);continue;}return p[0]+b[0];}",0);
}

@test
fn void owned_copy_quota_and_callee_errors_fail_without_replay(){
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32[1] b){p[0]=b[0];return p[1];}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut q,b);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32[1] b){p[0]=b[0];return p[0]/0;}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut q,b);}",7);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32[32] b){return 42;}fn i32 main(){var i32[1] a=[0;1];let i32[32] b=[0;32];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut q,b);}",13);
}

@test
fn void aggregate_results_aliases_and_unreachable_invalid_calls_keep_their_gates(){
    conflict(b"module main;fn i32[1] f(ref mut i32[] q,i32[1] b){return b;}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] c=f(ref mut q,b);return 42;}");
    conflict(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q,P v){return v;}fn i32 main(){var i32[1] a=[0;1];let P v=P{.x=42};let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P w=f(ref mut q,v);return 42;}");
    conflict(b"module main;fn i32 f(ref mut i32[] q,ref mut i32[] r,i32[1] b){return 42;}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut q,ref mut q,b);}");
    conflict(b"module main;fn i32[1] f(ref mut i32[] q){return [42;1];}fn i32 unused(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] b=f(ref mut q);return 42;}fn i32 main(){return 42;}");
}
