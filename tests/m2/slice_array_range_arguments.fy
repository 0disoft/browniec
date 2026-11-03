module tests::m2::slice_array_range_arguments;
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
fn void six_readonly_scalar_ranges_reach_the_selected_view(){
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==2 && p[0]==42){return 42;}return 0;}fn i32 main(){let i32[4] a=[42;4];return f(ref a[1..3]);}",0);
    run_source(b"module main;fn i32 f(ref bool[] p){if(p.len==2 && p[0]){return 42;}return 0;}fn i32 main(){let bool[4] a=[true;4];return f(ref a[1..3]);}",0);
    run_source(b"module main;fn i32 f(ref i64[] p){if(p.len==2 && p[0]==-9223372036854775808){return 42;}return 0;}fn i32 main(){let i64[4] a=[-9223372036854775808;4];return f(ref a[1..3]);}",0);
    run_source(b"module main;fn i32 f(ref u8[] p){if(p.len==2 && p[0]==255){return 42;}return 0;}fn i32 main(){let u8[4] a=[255;4];return f(ref a[1..3]);}",0);
    run_source(b"module main;fn i32 f(ref u32[] p){if(p.len==2 && p[0]==4294967295){return 42;}return 0;}fn i32 main(){let u32[4] a=[4294967295;4];return f(ref a[1..3]);}",0);
    run_source(b"module main;fn i32 f(ref usize[] p){if(p.len==2 && p[0]==18446744073709551615){return 42;}return 0;}fn i32 main(){let usize[4] a=[18446744073709551615;4];return f(ref a[1..3]);}",0);
}

@test
fn void six_mutable_scalar_ranges_restore_the_array_without_touching_neighbors(){
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){var i32[3] a=[0;3];let i32 n=f(ref mut a[1..2]);if(a[1]==42 && a[0]==0 && a[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut bool[] p){p[0]=true;return 42;}fn i32 main(){var bool[3] a=[false;3];let i32 n=f(ref mut a[1..2]);if(a[1] && a[0]==false && a[2]==false){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut i64[] p){p[0]=-9223372036854775808;return 42;}fn i32 main(){var i64[3] a=[0;3];let i32 n=f(ref mut a[1..2]);if(a[1]==-9223372036854775808 && a[0]==0 && a[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut u8[] p){p[0]=255;return 42;}fn i32 main(){var u8[3] a=[0;3];let i32 n=f(ref mut a[1..2]);if(a[1]==255 && a[0]==0 && a[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut u32[] p){p[0]=4294967295;return 42;}fn i32 main(){var u32[3] a=[0;3];let i32 n=f(ref mut a[1..2]);if(a[1]==4294967295 && a[0]==0 && a[2]==0){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut usize[] p){p[0]=18446744073709551615;return 42;}fn i32 main(){var usize[3] a=[0;3];let i32 n=f(ref mut a[1..2]);if(a[1]==18446744073709551615 && a[0]==0 && a[2]==0){return n;}return 0;}",0);
}

@test
fn void open_empty_computed_and_nested_bounds_evaluate_once_in_order(){
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==3){return p[0];}return 0;}fn i32 main(){let i32[3] a=[42;3];return f(ref a[..]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){var i32[3] a=[0;3];let i32 n=f(ref mut a[1..]);return a[1];}",0);
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==2){return p[1];}return 0;}fn i32 main(){let i32[3] a=[42;3];return f(ref a[..2]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){if(p.len==0){return 42;}return 0;}fn i32 main(){var i32[3] a=[0;3];let i32 n=f(ref mut a[3..3]);a[0]=42;return a[0];}",0);
    run_source(b"module main;fn i32 f(ref i32[] p){if(p.len==0){return 42;}return 0;}fn i32 main(){let i32[3] a=[42;3];return f(ref a[a.len..]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 order){if(order!=12 || p.len!=1){return 0;}p[0]=42;return 42;}fn i32 main(){var i32[3] a=[0;3];var i32 n=0;let Option<i32> o=.none;let i32 r=f(ref mut a[switch(o){case .some(_):{0}case .none:{n=n*10+1;1}}..switch(o){case .some(_):{1}case .none:{n=n*10+2;2}}],n);return a[1];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=p[0]+1;return 42;}fn i32 main(){var i32[2] a=[0;2];let Option<i32> o=.none;let i32 r=f(ref mut a[switch(o){case .some(_):{0}case .none:{a[0]=41;0}}..a.len-1]);return a[0];}",0);
    run_source(b"module main;fn usize bound(usize n){return n;}fn i32 f(ref i32[] p){return p[0];}fn i32 main(){let i32[3] a=[42;3];return f(ref a[bound(1)..bound(2)]);}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] p){p[0]=42;return [p[0];1];}fn i32 main(){var i32[3] a=[0;3];let i32[1] r=f(ref mut a[1..2]);return r[0]+a[1]-42;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p){p[0]=42;return P{.x=p[0]};}fn i32 main(){var i32[3] a=[0;3];let P r=f(ref mut a[1..2]);return r.x+a[1]-42;}",0);
}

@test
fn void endpoint_and_later_argument_exits_restore_the_correct_live_set(){
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;return f(ref mut a[switch(o){case .some(_):{0}case .none:{return 42;}}..1]);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;while(true){let i32 n=f(ref mut a[0..switch(o){case .some(_):{1}case .none:{break;}}]);}a[0]=42;return a[0];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;var i32 n=0;while(n<2){let i32 r=f(ref mut a[switch(o){case .some(_):{0}case .none:{n=n+1;continue;}}..1]);}a[0]=42;return a[0];}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 0;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;return f(ref mut a[..],switch(o){case .some(n):{n}case .none:{return 42;}});}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){return 0;}fn i32 main(){var i32[1] a=[0;1];var i32[1] b=[0;1];let Option<i32> o=.none;while(true){let i32 n=f(ref mut a[..],ref mut b[0..switch(o){case .some(_):{1}case .none:{break;}}]);}a[0]=42;return a[0];}",0);
}

@test
fn void runtime_bounds_and_arithmetic_failures_preserve_error_categories(){
    run_source(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];return f(ref a[0..3]);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[2] a=[0;2];return f(ref mut a[2..1]);}",14);
    run_source(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];return f(ref a[..18446744073709551615]);}",14);
    run_source(b"module main;fn i32 f(ref i32[] p){return p[0];}fn i32 main(){let i32[2] a=[42;2];return f(ref a[2..]);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[1];}fn i32 main(){var i32[3] a=[0;3];return f(ref mut a[1..2]);}",14);
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[2] a=[0;2];return f(ref mut a[0..1/0]);}",7);
}

@test
fn void conflicting_roots_are_not_split_even_for_disjoint_ranges(){
    conflict(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){return 42;}fn i32 main(){var i32[2] a=[0;2];return f(ref mut a[..1],ref mut a[1..]);}");
    conflict(b"module main;fn i32 f(ref i32[] p,ref mut i32[] q){return 42;}fn i32 main(){var i32[2] a=[0;2];return f(ref a[..1],ref mut a[1..]);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,i32 n){return 42;}fn i32 main(){var i32[2] a=[0;2];return f(ref mut a[1..2],a[0]);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[2] a=[0;2];let ref i32[] q=ref a;return f(ref mut a[1..2]);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){return 42;}fn i32 unused(){var i32[2] a=[0;2];return f(ref mut a[..1],ref mut a[1..]);}fn i32 main(){return 42;}");
}

@test
fn void range_syntax_types_and_unsupported_roots_reject(){
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){let i32[2] a=[0;2];return f(ref mut a[..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let u32[2] a=[42;2];return f(ref a[..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];let i32 lo=0;return f(ref a[lo..1]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];return f(ref a[true..1]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];return f(ref a[0..-1]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];return f(ref a[0]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];return f(ref a[0..=1]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];return f(ref a[..][..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[2] a=[42;2];let ref i32[] p=ref a;return f(ref p[..]);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [42;2][..]);}");
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
fn void endpoint_open_and_callee_failures_drain_sessions_without_replaying_writes(){
    failed(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a[0..2]);}",14,0);
    failed(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a[0..1/0]);}",7,0);
    failed(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[1];}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a[..]);}",14,42);
    failed(b"module main;fn usize bound(ref mut i32[] p){p[0]=42;return 2;}fn i32 f(ref mut i32[] p){return 0;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a[0..bound(ref mut a)]);}",14,42);
}
