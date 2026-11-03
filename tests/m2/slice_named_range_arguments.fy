module tests::m2::slice_named_range_arguments;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import errors as errors;
import array_vm as arrays;
import array_owners as owners;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_context as context;
import slice_vm as loans;
import slice_call_vm as shared;
import vm_reborrow_execution as runner;
import std::bytes as bytes;
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void run_source(ref u8[] source,u8 expected){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,16000000,256)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected}});}
fn void conflict(ref u8[] source){let ir::Program p=compiled(source);assert(!verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void rejected(ref u8[] source){assert(!compiler::compile(source).is_ok);}

@test
fn void six_scalar_modes_select_relative_ranges_and_restore_parents(){
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==1 && p[0]==42){return 42;}return 0;}fn i32 main(){let i32[4] a=[42;4];let ref i32[] p=ref a[1..4];return f(ref p[1..2]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){var i32[4] a=[0;4];let ref mut i32[] p=ref mut a[1..4];let i32 n=f(ref mut p[1..2]);if(p[1]==42 && p[0]==0 && p[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref bool[] p){if(p.len==1 && p[0]){return 42;}return 0;}fn i32 main(){let bool[4] a=[true;4];let ref bool[] p=ref a[1..4];return f(ref p[1..2]);}",0);
    run_source(b"module main;fn i32 f(ref mut bool[] p){p[0]=true;return 42;}fn i32 main(){var bool[4] a=[false;4];let ref mut bool[] p=ref mut a[1..4];let i32 n=f(ref mut p[1..2]);if(p[1] && p[0]==false && p[2]==false){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref i64[] p){if(p.len==1 && p[0]==-9223372036854775808){return 42;}return 0;}fn i32 main(){let i64[4] a=[-9223372036854775808;4];let ref i64[] p=ref a[1..4];return f(ref p[1..2]);}",0);
    run_source(b"module main;fn i32 f(ref mut i64[] p){p[0]=-9223372036854775808;return 42;}fn i32 main(){var i64[4] a=[0;4];let ref mut i64[] p=ref mut a[1..4];let i32 n=f(ref mut p[1..2]);if(p[1]==-9223372036854775808 && p[0]==0 && p[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref u8[] p){if(p.len==1 && p[0]==255){return 42;}return 0;}fn i32 main(){let u8[4] a=[255;4];let ref u8[] p=ref a[1..4];return f(ref p[1..2]);}",0);
    run_source(b"module main;fn i32 f(ref mut u8[] p){p[0]=255;return 42;}fn i32 main(){var u8[4] a=[0;4];let ref mut u8[] p=ref mut a[1..4];let i32 n=f(ref mut p[1..2]);if(p[1]==255 && p[0]==0 && p[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref u32[] p){if(p.len==1 && p[0]==4294967295){return 42;}return 0;}fn i32 main(){let u32[4] a=[4294967295;4];let ref u32[] p=ref a[1..4];return f(ref p[1..2]);}",0);
    run_source(b"module main;fn i32 f(ref mut u32[] p){p[0]=4294967295;return 42;}fn i32 main(){var u32[4] a=[0;4];let ref mut u32[] p=ref mut a[1..4];let i32 n=f(ref mut p[1..2]);if(p[1]==4294967295 && p[0]==0 && p[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref usize[] p){if(p.len==1 && p[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){let usize[4] a=[18446744073709551615;4];let ref usize[] p=ref a[1..4];return f(ref p[1..2]);}",0);
    run_source(b"module main;fn i32 f(ref mut usize[] p){p[0]=18446744073709551615;return 42;}fn i32 main(){var usize[4] a=[0;4];let ref mut usize[] p=ref mut a[1..4];let i32 n=f(ref mut p[1..2]);if(p[1]==18446744073709551615 && p[0]==0 && p[2]==0){return n;}return 0;}",0);
}

@test
fn void formals_nested_children_and_recursion_keep_canonical_restoration(){
    run_source(b"module main;fn i32 g(ref mut i32[] p){p[0]=42;return 42;}fn i32 f(ref mut i32[] p){let i32 n=g(ref mut p[1..]);return p[1];}fn i32 main(){var i32[2] a=[0;2];return f(ref mut a);}",0);
    run_source(b"module main;fn i32 g(ref i32[] p){return p[0];}fn i32 f(ref i32[] p){return g(ref p[1..]);}fn i32 main(){let i32[2] a=[42;2];return f(ref a);}",0);
    run_source(b"module main;fn i32 g(ref mut i32[] p){p[0]=42;return 42;}fn i32 f(ref mut i32[] p){let ref mut i32[] q=ref mut p;let i32 n=g(ref mut q[..]);return q[0];}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){if(n==0){p[0]=42;return 42;}let i32 v=f(ref mut p[..],n-1);return p[0];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p,2);}",0);
}

@test
fn void open_empty_shared_duplicate_and_aggregate_results_use_existing_paths(){
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==0){return 42;}return 0;}fn i32 main(){let i32[3] a=[42;3];let ref i32[] p=ref a[1..];return f(ref p[p.len..]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){if(p.len==0){return 42;}return 0;}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;let i32 n=f(ref mut p[2..2]);p[0]=42;return p[0];}",0);
    run_source(b"module main;fn i32 f(ref i32[] p,ref i32[] q){return p[0]+q[0];}fn i32 main(){let i32[3] a=[21;3];let ref i32[] p=ref a;return f(ref p[..1],ref p[1..2]);}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] p){p[0]=42;return [p[0];1];}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;let i32[1] r=f(ref mut p[1..]);return r[0]+p[1]-42;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p,P v){p[0]=v.x;return v;}fn i32 main(){var i32[2] a=[0;2];let P v=P{.x=42};let ref mut i32[] p=ref mut a;let P r=f(ref mut p[..1],v);return r.x+p[0]-42;}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=p[0]+21;return p[0];}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;let i32 a1=f(ref mut p[..1]);let i32 a2=f(ref mut p[..1]);return p[0];}",0);
}

@test
fn void endpoints_evaluate_before_suspension_and_exit_without_a_pending_child(){
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){if(n!=12){return 0;}p[0]=42;return 42;}fn i32 main(){var i32[3] a=[0;3];let ref mut i32[] p=ref mut a;var i32 n=0;let Option<i32> o=.none;let i32 r=f(ref mut p[switch(o){case .some(_):{0}case .none:{n=n*10+1;1}}..switch(o){case .some(_):{1}case .none:{n=n*10+2;2}}],n);return p[1];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=p[0]+1;return 42;}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;let i32 n=f(ref mut p[switch(o){case .some(_):{0}case .none:{p[0]=41;0}}..p.len-1]);return p[0];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;return f(ref mut p[switch(o){case .some(_):{0}case .none:{return 42;}}..1]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;while(true){let i32 n=f(ref mut p[0..switch(o){case .some(_):{1}case .none:{break;}}]);}p[0]=42;return p[0];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;var i32 n=0;while(n<2){let i32 r=f(ref mut p[switch(o){case .some(_):{0}case .none:{n=n+1;continue;}}..1]);}p[0]=42;return p[0];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;return f(ref mut p[..],switch(o){case .some(v):{v}case .none:{return 42;}});}",0);
}

@test
fn void relative_bounds_and_endpoint_arithmetic_fail_with_existing_errors(){
    run_source(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[4] a=[42;4];let ref i32[] p=ref a[2..3];return f(ref p[..2]);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[3] a=[0;3];let ref mut i32[] p=ref mut a;return f(ref mut p[2..1]);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return p[0];}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;return f(ref mut p[2..]);}",14);
    run_source(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];let ref i32[] p=ref a;return f(ref p[..18446744073709551615]);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[0..1/0]);}",7);
}

@test
fn void suspended_parent_access_duplicate_children_and_unreachable_conflicts_reject(){
    conflict(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[..],p[0]);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){return 42;}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a;return f(ref mut p[..1],ref mut p[1..]);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut p[..]);}");
    conflict(b"module main;fn i32 g(ref mut i32[] p){return p[0];}fn i32 f(ref mut i32[] p,i32 n){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[..],g(ref mut p));}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 42;}fn i32 unused(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[..],p[0]);}fn i32 main(){return 42;}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[..],a[0]);}");
}

@test
fn void mode_type_syntax_and_temporary_root_errors_remain_source_errors(){
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return f(ref mut p[..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref p[..]);}");
    rejected(b"module main;fn i32 f(ref u32[] p){return 42;}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return f(ref p[..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;let i32 n=0;return f(ref p[n..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return f(ref p[..][..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [true;1][..]);}");
}

fn void failed(ref u8[] source,u8 expected,i64 payload){
    let ir::Program p=compiled(source);
    var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];
    var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(256);
    var bytes::Buffer b=switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(switch(runner::execute(ref p,16000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{false}case .err(e):{e.kind==expected && e.offset<source.len}});
    assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok && a.owners.depth==1);
    var usize i=0;while(i<16){assert(!a.owners.slots[i].reading && !a.owners.slots[i].writing);i+=1;}
    assert(switch(owners::read(ref a.owners,a.tokens[0],0,bytes::view(ref b))){case .ok(n):{n==payload}case .err(_):{false}});
}

@test
fn void failed_child_and_call_cleanup_drain_canonical_maps_and_preserve_writes(){
    failed(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[..2]);}",14,0);
    failed(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[0..1/0]);}",7,0);
    failed(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[..]);}",14,42);
    failed(b"module main;fn usize bound(ref mut i32[] p){p[0]=42;return 2;}fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[0..bound(ref mut p)]);}",14,42);
}

@test
fn void mutable_range_calls_end_the_child_before_resuming_the_named_parent(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let i32 n=f(ref mut p[..]);return p[0];}");
    assert(verifier::verify(ref p).is_ok && p.arrays.count==1);var usize begins=0;var usize ends=0;var usize pc=p.starts[p.entry];
    while(pc<p.ends[p.entry]){if(p.code[pc*8]==61){begins+=1;}if(p.code[pc*8]==62){ends+=1;}if(p.code[pc*8]==9){assert(p.code[(pc+1)*8]==62);}pc+=1;}
    assert(begins==1 && ends==1);
}
