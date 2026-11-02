module tests::m2::slice_reborrow_record_results;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void run_source(ref u8[] source,u8 expected){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,16000000,256)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected}});}
fn void conflict(ref u8[] source){let ir::Program p=compiled(source);assert(!verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void rejected(ref u8[] source){assert(!compiler::compile(source).is_ok);}

@test
fn void six_scalar_record_fields_return_after_child_restoration(){
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=q[0]};}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p[1..];let P r=f(ref mut q);if(!(r.x==42 && q[0]==42)){return 0;}}if(p[1]==42){return 42;}return 0;}",0);
    run_source(b"module main;struct P{bool x;}fn P f(ref mut bool[] q){q[0]=true;return P{.x=q[0]};}fn i32 main(){var bool[2] a=[false;2];let ref mut bool[] p=ref mut a;{let ref mut bool[] q=ref mut p[1..];let P r=f(ref mut q);if(!(r.x && q[0])){return 0;}}if(p[1]==true){return 42;}return 0;}",0);
    run_source(b"module main;struct P{i64 x;}fn P f(ref mut i64[] q){q[0]=-9223372036854775808;return P{.x=q[0]};}fn i32 main(){var i64[2] a=[0;2];let ref mut i64[] p=ref mut a;{let ref mut i64[] q=ref mut p[1..];let P r=f(ref mut q);if(!(r.x==-9223372036854775808 && r.x==q[0])){return 0;}}if(p[1]==-9223372036854775808){return 42;}return 0;}",0);
    run_source(b"module main;struct P{u8 x;}fn P f(ref mut u8[] q){q[0]=255;return P{.x=q[0]};}fn i32 main(){var u8[2] a=[0;2];let ref mut u8[] p=ref mut a;{let ref mut u8[] q=ref mut p[1..];let P r=f(ref mut q);if(!(r.x==255 && r.x==q[0])){return 0;}}if(p[1]==255){return 42;}return 0;}",0);
    run_source(b"module main;struct P{u32 x;}fn P f(ref mut u32[] q){q[0]=4294967295;return P{.x=q[0]};}fn i32 main(){var u32[2] a=[0;2];let ref mut u32[] p=ref mut a;{let ref mut u32[] q=ref mut p[1..];let P r=f(ref mut q);if(!(r.x==4294967295 && r.x==q[0])){return 0;}}if(p[1]==4294967295){return 42;}return 0;}",0);
    run_source(b"module main;struct P{usize x;}fn P f(ref mut usize[] q){q[0]=18446744073709551615;return P{.x=q[0]};}fn i32 main(){var usize[2] a=[0;2];let ref mut usize[] p=ref mut a;{let ref mut usize[] q=ref mut p[1..];let P r=f(ref mut q);if(!(r.x==18446744073709551615 && r.x==q[0])){return 0;}}if(p[1]==18446744073709551615){return 42;}return 0;}",0);
}

@test
fn void nested_owned_shared_multiple_writer_and_child_results_execute(){
    run_source(b"module main;struct I{bool ok;i32 x;}struct R{u8 lead;I inner;}fn R f(ref mut i32[] q,i32[1] b,R v,ref u8[] s){q[0]=b[0]+v.inner.x+s[0] as i32;return R{.lead=7,.inner=I{.ok=true,.x=q[0]}};}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[40;1];let R v=R{.lead=0,.inner=I{.ok=true,.x=1}};let u8[1] c=[1;1];let ref u8[] s=ref c;let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let R r=f(ref mut q,b,v,ref s);if(r.inner.ok && r.lead==7 && v.inner.x==1){return r.inner.x+q[0]-42;}return 0;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q,P v){q[0]=v.x;return v;}fn i32 main(){var i32[1] a=[0;1];let P v=P{.x=42};let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q,v);return r.x+q[0]+v.x-84;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q,ref mut i32[] r){q[0]=21;r[0]=21;return P{.x=q[0]+r[0]};}fn i32 main(){var i32[1] a=[0;1];var i32[1] b=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] s=ref mut b;let ref mut i32[] q=ref mut p;let ref mut i32[] r=ref mut s;let P answer=f(ref mut q,ref mut r);return answer.x+q[0]+r[0]-42;}",0);
    run_source(b"module main;struct P{i32 x;}struct R{P p;}fn P f(ref mut i32[] q,R v){q[0]=v.p.x;return v.p;}fn i32 main(){var i32[1] a=[0;1];let R v=R{.p=P{.x=42}};let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q,v);return r.x+q[0]-42;}",0);
}

@test
fn void formal_recursive_and_repeated_assignments_restore_callers(){
    run_source(b"module main;struct P{i32 x;}fn P g(ref mut i32[] q,P v){q[0]=v.x;return v;}fn P f(ref mut i32[] p,P v){let ref mut i32[] q=ref mut p;return g(ref mut q,v);}fn i32 main(){var i32[1] a=[0;1];let P v=P{.x=42};let ref mut i32[] p=ref mut a;let P r=f(ref mut p,v);return r.x+p[0]-42;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p,i32 n){if(n==0){p[0]=42;return P{.x=p[0]};}let ref mut i32[] q=ref mut p;return f(ref mut q,n-1);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let P r=f(ref mut p,2);return r.x+p[0]-42;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=q[0]};}fn i32 main(){var i32[1] a=[0;1];var P out=P{.x=0};let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;out=f(ref mut q);out=f(ref mut q);return out.x+q[0]-42;}",0);
    run_source(b"module main;struct P{i32 x;}struct R{P p;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=q[0]};}fn i32 main(){var i32[1] a=[0;1];var R out=R{.p=P{.x=0}};let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;out.p=f(ref mut q);return out.p.x+q[0]-42;}",0);
}

@test
fn void bounds_arithmetic_and_record_allocation_failures_propagate(){
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=q[1]};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q);return r.x;}",14);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=q[0]/0};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q);return r.x;}",7);
    run_source(b"module main;struct P{i64 x;i64 y;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=42,.y=42};}fn i32 main(){var i32[1] a=[0;1];let i32[61] keep=[0;61];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q);return 42;}",13);
}

@test
fn void duplicate_and_unreachable_aliases_and_wrong_nominal_results_reject(){
    conflict(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q,ref mut i32[] r){return P{.x=42};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q,ref mut q);return 42;}");
    conflict(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q,ref mut i32[] r){return P{.x=42};}fn i32 unused(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q,ref mut q);return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn P f(ref mut i32[] q){return Q{.x=42};}fn i32 main(){return 42;}");
}
