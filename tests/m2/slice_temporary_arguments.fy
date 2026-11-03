module tests::m2::slice_temporary_arguments;
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
fn void six_scalar_literals_have_exact_call_scoped_access(){
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==2 && p[0]==42){return 42;}return 0;}fn i32 main(){return f(ref [42;3][1..]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;if(p.len==3 && p[0]==42){return 42;}return 0;}fn i32 main(){return f(ref mut [42;3]);}",0);
    run_source(b"module main;fn i32 f(ref i64[] p){if(p.len==2 && p[0]==-9223372036854775808){return 42;}return 0;}fn i32 main(){return f(ref [-9223372036854775808;3][1..]);}",0);
    run_source(b"module main;fn i32 f(ref mut i64[] p){p[0]=-9223372036854775808;if(p.len==3 && p[0]==-9223372036854775808){return 42;}return 0;}fn i32 main(){return f(ref mut [-9223372036854775808;3]);}",0);
    run_source(b"module main;fn i32 f(ref bool[] p){if(p.len==2 && p[0]==true){return 42;}return 0;}fn i32 main(){return f(ref [true;3][1..]);}",0);
    run_source(b"module main;fn i32 f(ref mut bool[] p){p[0]=true;if(p.len==3 && p[0]==true){return 42;}return 0;}fn i32 main(){return f(ref mut [true;3]);}",0);
    run_source(b"module main;fn i32 f(ref u8[] p){if(p.len==2 && p[0]==255){return 42;}return 0;}fn i32 main(){return f(ref [255;3][1..]);}",0);
    run_source(b"module main;fn i32 f(ref mut u8[] p){p[0]=255;if(p.len==3 && p[0]==255){return 42;}return 0;}fn i32 main(){return f(ref mut [255;3]);}",0);
    run_source(b"module main;fn i32 f(ref u32[] p){if(p.len==2 && p[0]==4294967295){return 42;}return 0;}fn i32 main(){return f(ref [4294967295;3][1..]);}",0);
    run_source(b"module main;fn i32 f(ref mut u32[] p){p[0]=4294967295;if(p.len==3 && p[0]==4294967295){return 42;}return 0;}fn i32 main(){return f(ref mut [4294967295;3]);}",0);
    run_source(b"module main;fn i32 f(ref usize[] p){if(p.len==2 && p[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){return f(ref [18446744073709551615;3][1..]);}",0);
    run_source(b"module main;fn i32 f(ref mut usize[] p){p[0]=18446744073709551615;if(p.len==3 && p[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){return f(ref mut [18446744073709551615;3]);}",0);
}

@test
fn void six_scalar_owned_call_results_have_exact_call_scoped_access(){
    run_source(b"module main;fn i32[3] make(){return [42;3];}fn i32 f(ref i32[] p){if(p.len==2 && p[0]==42){return 42;}return 0;}fn i32 main(){return f(ref make()[1..]);}",0);
    run_source(b"module main;fn i32[3] make(){return [42;3];}fn i32 f(ref mut i32[] p){p[0]=42;if(p.len==3 && p[0]==42){return 42;}return 0;}fn i32 main(){return f(ref mut make());}",0);
    run_source(b"module main;fn i64[3] make(){return [-9223372036854775808;3];}fn i32 f(ref i64[] p){if(p.len==2 && p[0]==-9223372036854775808){return 42;}return 0;}fn i32 main(){return f(ref make()[1..]);}",0);
    run_source(b"module main;fn i64[3] make(){return [-9223372036854775808;3];}fn i32 f(ref mut i64[] p){p[0]=-9223372036854775808;if(p.len==3 && p[0]==-9223372036854775808){return 42;}return 0;}fn i32 main(){return f(ref mut make());}",0);
    run_source(b"module main;fn bool[3] make(){return [true;3];}fn i32 f(ref bool[] p){if(p.len==2 && p[0]==true){return 42;}return 0;}fn i32 main(){return f(ref make()[1..]);}",0);
    run_source(b"module main;fn bool[3] make(){return [true;3];}fn i32 f(ref mut bool[] p){p[0]=true;if(p.len==3 && p[0]==true){return 42;}return 0;}fn i32 main(){return f(ref mut make());}",0);
    run_source(b"module main;fn u8[3] make(){return [255;3];}fn i32 f(ref u8[] p){if(p.len==2 && p[0]==255){return 42;}return 0;}fn i32 main(){return f(ref make()[1..]);}",0);
    run_source(b"module main;fn u8[3] make(){return [255;3];}fn i32 f(ref mut u8[] p){p[0]=255;if(p.len==3 && p[0]==255){return 42;}return 0;}fn i32 main(){return f(ref mut make());}",0);
    run_source(b"module main;fn u32[3] make(){return [4294967295;3];}fn i32 f(ref u32[] p){if(p.len==2 && p[0]==4294967295){return 42;}return 0;}fn i32 main(){return f(ref make()[1..]);}",0);
    run_source(b"module main;fn u32[3] make(){return [4294967295;3];}fn i32 f(ref mut u32[] p){p[0]=4294967295;if(p.len==3 && p[0]==4294967295){return 42;}return 0;}fn i32 main(){return f(ref mut make());}",0);
    run_source(b"module main;fn usize[3] make(){return [18446744073709551615;3];}fn i32 f(ref usize[] p){if(p.len==2 && p[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){return f(ref make()[1..]);}",0);
    run_source(b"module main;fn usize[3] make(){return [18446744073709551615;3];}fn i32 f(ref mut usize[] p){p[0]=18446744073709551615;if(p.len==3 && p[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){return f(ref mut make());}",0);
}

@test
fn void relative_open_empty_independent_and_aggregate_result_calls(){
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==0){return 42;}return 0;}fn i32 main(){return f(ref [42;2][2..2]);}",0);
    run_source(b"module main;fn i32[2] make(){return [42;2];}fn i32 f(ref mut i32[] p){if(p.len==0){return 42;}return 0;}fn i32 main(){return f(ref mut make()[..0]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){p[0]=21;q[0]=21;return p[0]+q[0];}fn i32 main(){return f(ref mut [0;1],ref mut [0;1][..]);}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] p){p[0]=42;return [p[0];1];}fn i32 main(){let i32[1] a=f(ref mut [0;2][..1]);return a[0];}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p){p[0]=42;return P{.x=p[0]};}fn i32 main(){let P r=f(ref mut [0;1]);return r.x;}",0);
    run_source(b"module main;fn i32[2] make(){return [0;2];}fn i32 g(ref mut i32[] p){p[0]=42;return p[0];}fn i32 f(ref mut i32[] p){return g(ref mut p[1..]);}fn i32 main(){return f(ref mut make()[..]);}",0);
    run_source(b"module main;fn i32[2] make(){return [42;2];}fn i32[1] copy(ref i32[] p){return [p[0];1];}fn i32 f(ref i32[] p){return p[0];}fn i32 main(){return f(ref copy(ref make()[1..]));}",0);
}

@test
fn void filler_and_bounds_complete_once_in_order_before_acquisition(){
    run_source(b"module main;fn i32 bump(ref mut i32[] p){p[0]=p[0]+1;return 42;}fn i32 f(ref i32[] p,i32 n){if(n==1 && p.len==3){return p[2];}return 0;}fn i32 main(){var i32[1] a=[0;1];return f(ref [bump(ref mut a);3],a[0]);}",0);
    run_source(b"module main;fn i32[2] make(ref mut i32[] p){p[0]=p[0]+1;return [42;2];}fn i32 f(ref i32[] p,i32 n){if(n==1){return p[0];}return 0;}fn i32 main(){var i32[1] a=[0;1];return f(ref make(ref mut a)[..],a[0]);}",0);
    run_source(b"module main;fn i32 f(ref i32[] p,i32 n){if(n==12 && p.len==1){return p[0];}return 0;}fn i32 main(){var i32 n=0;let Option<i32> o=.none;return f(ref [42;2][switch(o){case .some(_):{1}case .none:{n=n*10+1;0}}..switch(o){case .some(_):{2}case .none:{n=n*10+2;1}}],n);}",0);
}

@test
fn void early_exits_release_only_published_owners_and_views(){
    run_source(b"module main;fn i32 f(ref i32[] p){return 0;}fn i32 main(){let Option<i32> o=.none;return f(ref [switch(o){case .some(v):{v}case .none:{return 42;}};2]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){let Option<i32> o=.none;return f(ref mut [0;2][switch(o){case .some(_):{0}case .none:{return 42;}}..]);}",0);
    run_source(b"module main;fn i32[2] make(){return [0;2];}fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;return f(ref mut make(),switch(o){case .some(v):{v}case .none:{return 42;}});}",0);
    run_source(b"module main;fn i32 f(ref i32[] p,ref mut i32[] q){return 0;}fn i32 main(){let Option<i32> o=.none;return f(ref [42;1],ref mut [0;2][..switch(o){case .some(_):{1}case .none:{return 42;}}]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){let Option<i32> o=.none;var i32 n=0;while(n<2){let i32 x=f(ref mut [0;2][switch(o){case .some(_):{0}case .none:{n=n+1;continue;}}..]);}return 42;}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;while(true){let i32 x=f(ref mut [0;2],switch(o){case .some(v):{v}case .none:{break;}});}return 42;}",0);
}

@test
fn void temporary_bounds_errors_preserve_existing_runtime_categories(){
    run_source(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [42;1][..2]);}",14);
    run_source(b"module main;fn i32[2] make(){return [42;2];}fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){return f(ref mut make()[2..1]);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[1];}fn i32 main(){return f(ref mut [0;1]);}",14);
    run_source(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [42;1][..1/0]);}",7);
}

@test
fn void invalid_modes_elements_shapes_and_escapes_still_reject(){
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [true;1]);}");
    rejected(b"module main;fn u32[1] make(){return [42;1];}fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref make());}");
    rejected(b"module main;fn i32 make(){return 42;}fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref make());}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref mut [42;1]);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){return f(ref [42;1]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [42;0]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [42;4097]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [42;1][..][..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [42;1][0]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32 n=0;return f(ref [42;1][n..]);}");
    rejected(b"module main;fn i32[1] make(){return [42;1];}fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32 make=42;return f(ref make());}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref ( [42;1] ));}");
}

@test
fn void lowering_closes_the_temporary_view_before_its_unique_owner(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){return f(ref mut [0;2][1..]);}");
    assert(verifier::verify(ref p).is_ok && p.arrays.count==1);
    var usize initialized=0;var usize opened=0;var usize called=0;var usize pc=p.starts[p.entry];
    while(pc<p.ends[p.entry]){
        let u8 op=p.code[pc*8];assert(op!=34 && op!=38);
        if(op==33){initialized+=1;}if(op==54){opened+=1;assert(initialized==1);}
        if(op==9){called+=1;assert(opened==1 && p.code[(pc+1)*8]==56 && p.code[(pc+2)*8]==37);}
        pc+=1;
    }
    assert(initialized==1 && opened==1 && called==1);
}

fn void drained(ref u8[] source,u8 expected,i64 payload){
    let ir::Program p=compiled(source);
    var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];
    var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(256);
    var bytes::Buffer b=switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(switch(runner::execute(ref p,16000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(n):{expected==0 && n==42}case .err(e):{e.kind==expected && e.offset<source.len}});
    assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok);
    var usize i=0;while(i<16){assert(!a.owners.slots[i].reading && !a.owners.slots[i].writing);i+=1;}
    if(expected==0){assert(a.owners.depth==0);return;}
    assert(switch(owners::read(ref a.owners,a.tokens[0],0,bytes::view(ref b))){case .ok(n):{n==payload}case .err(_):{false}});
}

@test
fn void normal_and_failed_invocations_release_sessions_and_preserve_prior_writes(){
    drained(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){return f(ref mut [0;1]);}",0,0);
    drained(b"module main;fn i32[2] make(){return [0;2];}fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){return f(ref mut make()[1..]);}",0,0);
    drained(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){q[0]=42;p[0]=21;return p[1];}fn i32 main(){var i32[1] a=[0;1];return f(ref mut [0;1],ref mut a);}",14,42);
    drained(b"module main;fn usize bound(ref mut i32[] p){p[0]=42;return 2;}fn i32 f(ref i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];return f(ref [42;1][..bound(ref mut a)]);}",14,42);
    drained(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){var i32[1] a=[42;1];return f(ref mut [0;1],1/0);}",7,42);
    let ir::Program p=compiled(b"module main;fn i32 f(ref i32[] p){return p[0];}fn i32 main(){return f(ref [42;1]);}");
    assert(switch(vm::run_with_array_limit(ref p,16000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
