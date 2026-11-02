module tests::m2::slice_reborrow_source;
import compiler as compiler;
import verifier as verifier;
import ir as ir;
import vm as vm;

fn ir::Program compiled(ref u8[] source){
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void run_source(ref u8[] source,u8 expected){
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    var usize begins=0;var usize ends=0;var usize pc=0;
    while(pc<p.count){if(p.code[pc*8]==61){begins+=1;}if(p.code[pc*8]==62){ends+=1;}pc+=1;}
    assert(begins!=0 && ends>=begins);
    assert(switch(vm::run_with_array_limit(ref p,16000000,256)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected}});
}
fn void conflict(ref u8[] source){
    let ir::Program p=compiled(source);assert(!verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});
}
fn void rejected(ref u8[] source){assert(!compiler::compile(source).is_ok);}

@test
fn void all_six_scalar_tags_reborrow_and_restore_owned_ranges(){
    run_source(b"module main;fn i32 main(){var i32[2] a=[0;2];{let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p[1..];q[0]=42;}if(p[1]!=42 || p[0]!=0){return 0;}}return a[1];}",0);
    run_source(b"module main;fn i32 main(){var bool[1] a=[false;1];let ref mut bool[] p=ref mut a;{let ref mut bool[] q=ref mut p;q[0]=true;}if(p[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 main(){var i64[1] a=[0;1];let ref mut i64[] p=ref mut a;{let ref mut i64[] q=ref mut p[..];q[0]=-9223372036854775808;}if(p[0]==-9223372036854775808){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 main(){var u8[1] a=[0;1];let ref mut u8[] p=ref mut a;{let ref mut u8[] q=ref mut p[..1];q[0]=42;if(!text::valid_utf8(q)){return 0;}}return p[0] as i32;}",0);
    run_source(b"module main;fn i32 main(){var u32[1] a=[0;1];let ref mut u32[] p=ref mut a;{let ref mut u32[] q=ref mut p[0..1];q[0]=4294967295;}if(p[0]==4294967295){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 main(){var usize[1] a=[0;1];let ref mut usize[] p=ref mut a;{let ref mut usize[] q=ref mut p;q[0]=18446744073709551615;}if(p[0]==18446744073709551615){return 42;}return 0;}",0);
}

@test
fn void nested_formals_derived_calls_and_recursion_restore_callers(){
    run_source(b"module main;fn i32 f(ref mut i32[] p){let ref mut i32[] q=ref mut p[1..];{let ref mut i32[] r=ref mut q;r[0]=42;}return q[0];}fn i32 main(){var i32[3] a=[0;3];let ref mut i32[] p=ref mut a;let i32 n=f(ref mut p);return p[1]+n-42;}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p[1..];let i32 n=f(ref mut q);if(q[0]!=n){return 0;}}return p[1];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){if(n==0){p[0]=42;return p[0];}let ref mut i32[] q=ref mut p;return f(ref mut q,n-1);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let i32 n=f(ref mut p,2);return p[0]+n-42;}",0);
}

@test
fn void lexical_exits_loops_and_propagation_restore_pending_parents(){
    run_source(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;var i32 n=0;while(n<2){let ref mut i32[] q=ref mut p;q[0]=q[0]+1;n=n+1;continue;}while(true){let ref mut i32[] r=ref mut p;r[0]=42;break;}return p[0];}",0);
    run_source(b"module main;fn Option<i32> f(ref mut i32[] p,Option<i32> o){let ref mut i32[] q=ref mut p;q[0]=42;let i32 n=o?;return .some(q[0]+n);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;switch(f(ref mut p,.none)){case .some(_):{return 0;}case .none:{}}return p[0];}",0);
    run_source(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;{let ref mut i32[] q=ref mut p;if(q.len==1){let ref mut i32[] r=ref mut q;r[0]=42;return r[0];}}return 0;}",0);
}

@test
fn void aggregate_returns_end_children_before_transferring_owned_results(){
    run_source(b"module main;fn i32[1] f(ref mut i32[] p){let ref mut i32[] q=ref mut p;q[0]=42;return [q[0];1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let i32[1] b=f(ref mut p);return b[0]+p[0]-42;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p){let ref mut i32[] q=ref mut p;q[0]=42;return P{.x=q[0]};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let P b=f(ref mut p);return b.x+p[0]-42;}",0);
}

@test
fn void suspended_access_modes_and_unsupported_calls_reject_before_effects(){
    conflict(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return p[0];}");
    conflict(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;p[0]=42;return q[0];}");
    conflict(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let usize n=p.len;return 42;}");
    conflict(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let ref mut i32[] r=ref mut p;return 42;}");
    conflict(b"module main;fn i32 f(ref mut i32[] p){return p[0];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut p);}");
    conflict(b"module main;fn i32[1] f(ref mut i32[] p){return [p[0];1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] b=f(ref mut q);return 42;}");
    conflict(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p){return P{.x=p[0]};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P b=f(ref mut q);return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref i32[] p=ref a;let ref mut i32[] q=ref mut p;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref i32[] q=ref p;return 42;}");
    rejected(b"module main;fn i32 main(){{var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;}return q[0];}");
}

@test
fn void bounds_and_arithmetic_fail_after_checked_source_admission(){
    run_source(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p[..2];return 42;}",14);
    run_source(b"module main;fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p[2..1];return 42;}",14);
    run_source(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p[0..0];return q[0];}",14);
    run_source(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;q[0]=42;return q[0]/0;}",7);
}

@test
fn void computed_bounds_evaluate_once_and_exit_before_child_publication(){
    run_source(b"module main;fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;var i32 n=0;{let ref mut i32[] q=ref mut p[switch(o){case .some(_):{0}case .none:{n=n+1;0}}..switch(o){case .some(_):{1}case .none:{n=n+1;p.len}}];q[0]=40;}return p[0]+n;}",0);
    run_source(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;var i32 n=0;while(n<2){let ref mut i32[] q=ref mut p[switch(o){case .some(_):{0}case .none:{n=n+1;continue;}}..1];}p[0]=42;return p[0];}",0);
}
