module tests::m2::slice_array_arguments;
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
fn void six_readonly_array_types_open_call_and_close(){
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==2 && p[0]==42){return 42;}return 0;}fn i32 main(){let i32[2] a=[42;2];return f(ref a);}",0);
    run_source(b"module main;fn i32 f(ref bool[] p){if(p.len==2 && p[0]){return 42;}return 0;}fn i32 main(){let bool[2] a=[true;2];return f(ref a);}",0);
    run_source(b"module main;fn i32 f(ref i64[] p){if(p.len==2 && p[0]==-9223372036854775808){return 42;}return 0;}fn i32 main(){let i64[2] a=[-9223372036854775808;2];return f(ref a);}",0);
    run_source(b"module main;fn i32 f(ref u8[] p){if(p.len==2 && p[0]==255){return 42;}return 0;}fn i32 main(){let u8[2] a=[255;2];return f(ref a);}",0);
    run_source(b"module main;fn i32 f(ref u32[] p){if(p.len==2 && p[0]==4294967295){return 42;}return 0;}fn i32 main(){let u32[2] a=[4294967295;2];return f(ref a);}",0);
    run_source(b"module main;fn i32 f(ref usize[] p){if(p.len==2 && p[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){let usize[2] a=[18446744073709551615;2];return f(ref a);}",0);
}

@test
fn void six_mutable_array_types_restore_direct_owner_access(){
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){var i32[1] a=[0;1];let i32 n=f(ref mut a);if(a[0]==42){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut bool[] p){p[0]=true;return 42;}fn i32 main(){var bool[1] a=[false;1];let i32 n=f(ref mut a);if(a[0]){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut i64[] p){p[0]=-9223372036854775808;return 42;}fn i32 main(){var i64[1] a=[0;1];let i32 n=f(ref mut a);if(a[0]==-9223372036854775808){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut u8[] p){p[0]=255;return 42;}fn i32 main(){var u8[1] a=[0;1];let i32 n=f(ref mut a);if(a[0]==255){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut u32[] p){p[0]=4294967295;return 42;}fn i32 main(){var u32[1] a=[0;1];let i32 n=f(ref mut a);if(a[0]==4294967295){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut usize[] p){p[0]=18446744073709551615;return 42;}fn i32 main(){var usize[1] a=[0;1];let i32 n=f(ref mut a);if(a[0]==18446744073709551615){return n;}return 0;}",0);
}

@test
fn void nested_calls_shared_duplicates_aggregate_results_and_repeated_calls(){
    run_source(b"module main;fn i32 f(ref i32[] p,ref i32[] q){return p[0]+q[0];}fn i32 main(){var i32[1] a=[21;1];let i32 n=f(ref a,ref a);a[0]=42;return n;}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,ref i32[] q){p[0]=q[0];return 42;}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let i32 n=f(ref mut a,ref b);return a[0];}",0);
    run_source(b"module main;fn i32 g(ref i32[] p){return p[0];}fn i32 f(ref mut i32[] p,i32 n){p[0]=n;return 42;}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let i32 n=f(ref mut a,g(ref b));return a[0];}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] p){p[0]=42;return [p[0];1];}fn i32 main(){var i32[1] a=[0;1];let i32[1] r=f(ref mut a);return r[0]+a[0]-42;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p){p[0]=42;return P{.x=p[0]};}fn i32 main(){var i32[1] a=[0;1];let P r=f(ref mut a);return r.x+a[0]-42;}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=p[0]+21;return p[0];}fn i32 main(){var i32[1] a=[0;1];let i32 x=f(ref mut a);let i32 y=f(ref mut a);return a[0];}",0);
}

@test
fn void argument_early_exits_and_callee_errors_keep_existing_cleanup(){
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;return f(ref mut a,switch(o){case .some(n):{n}case .none:{return 42;}});}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;var i32 n=0;while(n<2){n=n+1;let i32 x=f(ref mut a,switch(o){case .some(v):{v}case .none:{continue;}});}a[0]=42;return a[0];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;while(true){let i32 x=f(ref mut a,switch(o){case .some(v):{v}case .none:{break;}});}a[0]=42;return a[0];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[1];}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0]/0;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a);}",7);
}

@test
fn void overlapping_arguments_and_later_root_access_reject_before_fuel(){
    conflict(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a,ref mut a);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,ref i32[] q){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a,ref a);}");
    conflict(b"module main;fn i32 f(ref i32[] p,ref mut i32[] q){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref a,ref mut a);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a,a[0]);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] q=ref mut a;return f(ref mut a);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){return 42;}fn i32 unused(){var i32[1] a=[0;1];return f(ref mut a,ref mut a);}fn i32 main(){return 42;}");
}

@test
fn void immutable_wrong_types_ranges_and_temporary_roots_stay_rejected(){
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){let i32[1] a=[0;1];return f(ref mut a);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var u32[1] a=[0;1];return f(ref mut a);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let u32[1] a=[42;1];return f(ref a);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref a);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a);}");
    run_source(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[1] a=[42;1];return f(ref a[..]);}",0);
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){return f(ref mut [0;1]);}");
    rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref make());}");
}

@test
fn void lowering_uses_one_anonymous_site_and_closes_immediately_after_call(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){var i32[1] a=[0;1];let i32 n=f(ref mut a);return a[0];}");
    assert(p.arrays.count==1);var usize opens=0;var usize closes=0;var usize calls=0;var usize pc=p.starts[p.entry];
    while(pc<p.ends[p.entry]){let u8 op=p.code[pc*8];if(op==54){opens+=1;}if(op==56){closes+=1;}if(op==9){calls+=1;assert(pc+1<p.ends[p.entry] && p.code[(pc+1)*8]==56);}pc+=1;}
    assert(opens==1 && closes==1 && calls==1 && verifier::verify(ref p).is_ok);
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
fn void caller_temporary_and_callee_failure_cleanup_release_sessions_and_preserve_writes(){
    failed(b"module main;fn i32 f(ref mut i32[] p,i32 n){p[0]=42;return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a,1/0);}",7,0);
    failed(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[1];}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a);}",14,42);
}
