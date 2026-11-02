module tests::m2::slice_mutable_parameters_source;
import ir as ir;
import errors as errors;
import compiler as compiler;
import functions as functions;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import slice_mutable_call_vm as calls;
import slice_call_vm as shared;
import slice_vm as loans;
import array_vm as arrays;
import array_owners as owners;
import std::bytes as bytes;

fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn ir::Program compiled(ref u8[] s){return switch(compiler::compile(s)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};}
fn usize pc(ref ir::Program p,u8 op,usize f){var usize i=p.starts[f];while(i<p.ends[f] && p.code[i*8]!=op){i+=1;}assert(i<p.ends[f]);return i;}
fn void inspected(ref ir::Program p){assert(verifier::inspect(p).is_ok && verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,0,0)){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn void cleared(ref calls::Frame[] receipts,ref shared::Frames f,ref loans::State l,ref arrays::State a){var usize i=0;while(i<receipts.len){assert(!receipts[i].active && receipts[i].batch.count==0);i+=1;}i=0;while(i<256){assert(f.origins[i].slot==16 && f.origins[i].generation==0);i+=1;}i=0;while(i<512){assert(l.tickets[i].slot==16 && l.tickets[i].generation==0);i+=1;}i=0;while(i<16){assert(!l.pool.slots[i].live && !a.owners.slots[i].reading && !a.owners.slots[i].writing);i+=1;}}
fn void run(ref ir::Program p,usize fuel,u8 expected){
    inspected(p);var calls::Frame[32] receipts=[calls::empty();32];var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();var errors::Error failure=errors::make(0,0);var bool failed=false;
    let i64 answer=switch(execution::execute_mutable(p,fuel,ref mut a,ref mut b,ref mut l,ref mut f,ref mut receipts)){case .ok(v):{assert(expected==0 && v==42);v}case .err(e):{assert(e.kind==expected);failed=true;failure=e;0}};
    if(!failed){cleared(ref receipts,ref f,ref l,ref a);}
    let Result<i64,errors::Error> outcome=if(failed){.err(failure)}else{.ok(answer)};
    assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,outcome)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected && e.offset==failure.offset}});cleared(ref receipts,ref f,ref l,ref a);
}
fn void run_source(ref u8[] source,u8 expected){let ir::Program p=compiled(source);run(ref p,16000000,expected);assert(switch(vm::run_with_array_limit(ref p,16000000,256)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected}});}
fn void rejected(ref u8[] source){assert(!compiler::compile(source).is_ok);}
fn void conflict(ref u8[] source){let ir::Program p=compiled(source);assert(!verifier::inspect(ref p).is_ok);}

@test
fn void all_six_scalar_tags_write_through_source_calls_and_restore_selected_caller_ranges(){
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=-2147483648;return 42;}fn i32 main(){var i32[2] a=[0;2];{let ref mut i32[] p=ref mut a[1..];let i32 n=f(ref mut p);if(p[0]!=-2147483648 || p.len!=1){return 0;}}if(a[0]==0 && a[1]==-2147483648){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut bool[] p){p[0]=true;return 42;}fn i32 main(){var bool[1] a=[false;1];{let ref mut bool[] p=ref mut a;let i32 n=f(ref mut p);if(!p[0]){return 0;}}if(a[0]){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut i64[] p){p[0]=-9223372036854775808;return 42;}fn i32 main(){var i64[1] a=[0;1];let ref mut i64[] p=ref mut a;let i32 n=f(ref mut p);if(p[0]==-9223372036854775808){return n;}return 0;}",0);
    run_source(b"module main;fn i32 main(){var u8[1] a=[0;1];let ref mut u8[] p=ref mut a;let i32 n=later(ref mut p);return p[0] as i32;}fn i32 later(ref mut u8[] p){p[0]=42;if(text::valid_utf8(p)){return 42;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut u32[] p){p[0]=4294967295;return 42;}fn i32 main(){var u32[1] a=[0;1];let ref mut u32[] p=ref mut a;let i32 n=f(ref mut p);if(p[0]==4294967295){return n;}return 0;}",0);
    run_source(b"module main;fn i32 f(ref mut usize[] p){p[0]=18446744073709551615;return 42;}fn i32 main(){var usize[1] a=[0;1];let ref mut usize[] p=ref mut a;let i32 n=f(ref mut p);if(p[0]==18446744073709551615){return n;}return 0;}",0);
}

@test
fn void nested_recursive_mutual_and_reused_calls_forward_exact_mutable_formals(){
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){if(n==0){p[0]=42;return p[0];}return f(ref mut p,n-1);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p,30);}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){if(n==0){return 42;}return f(ref mut p,n-1);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p,31);}",12);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){if(n==0){p[0]=42;return p[0];}return g(ref mut p,n-1);}fn i32 g(ref mut i32[] p,i32 n){return f(ref mut p,n-1);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p,2)+f(ref mut p,2)-42;}",0);
}

@test
fn void mixed_owned_shared_and_mutable_arguments_preserve_evaluation_order_and_returns(){
    run_source(b"module main;struct P{i32 x;}fn i32 read(ref u8[] s){return s[0] as i32;}fn i32 f(i32 n,ref mut i32[] p,u8[1] a,P r,ref u8[] s){p[0]=n+a[0] as i32+r.x+read(ref s);return p[0];}fn i32 main(){var i32[1] a=[0;1];let u8[1] b=[1;1];let P r=P{.x=38};let ref mut i32[] p=ref mut a;let ref u8[] s=ref b;let Option<i32> o=.none;return f(switch(o){case .some(v):{v}case .none:{p[0]=2;p[0]}},ref mut p,b,r,ref s);}",0);
    run_source(b"module main;fn i32[1] f(ref mut i32[] p){p[0]=42;return [p[0];1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let i32[1] b=f(ref mut p);return b[0]+p[0]-42;}",0);
    run_source(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p){p[0]=42;return P{.x=p[0]};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let P b=f(ref mut p);return b.x+p[0]-42;}",0);
    run_source(b"module main;fn Option<i32> f(ref mut i32[] p,Option<i32> o){p[0]=42;let i32 n=o?;return .some(p[0]+n);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;switch(f(ref mut p,.none)){case .some(_):{return 0;}case .none:{}}return switch(f(ref mut p,.some(0))){case .some(v):{v}case .none:{0}};}",0);
    run_source(b"module main;fn i32 f(ref mut i32[] p,i32 n){return p[0]+n;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let Option<i32> o=.none;return f(ref mut p,switch(o){case .some(v):{v}case .none:{p[0]=40;2}});}",0);
}

@test
fn void exact_modes_tags_named_sources_and_non_escaping_bindings_are_required(){
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref p);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref i32[] p=ref a;return f(ref mut p);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref p);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var u32[1] a=[0;1];let ref mut u32[] p=ref mut a;return f(ref mut p);}");
    run_source(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];return f(ref mut a);}",0);
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){return f(ref mut [0;1]);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p[..]);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){let ref mut u32[] q=ref mut p;return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){let ref i32[] q=ref p;return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){p[0]=true;return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref mut Option<i32>[] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref mut i32[1] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 main(ref mut i32[] p){return 42;}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return p;}fn i32 main(){return 42;}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,ref mut i32[] q){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p,ref mut p);}");
    conflict(b"module main;fn i32 f(ref mut i32[] p,i32[1] a){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p,a);}");
}

@test
fn void source_errors_abort_all_receipts_and_preserve_prior_payload_writes(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;p[1]=0;return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");
    inspected(ref p);var calls::Frame[32] receipts=[calls::empty();32];var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();
    let Result<i64,errors::Error> outcome=execution::execute_mutable(ref p,16000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut receipts);
    assert(switch(outcome){case .ok(_):{false}case .err(e):{e.kind==14}});assert(receipts[1].active);
    assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,outcome)){case .ok(_):{false}case .err(e):{e.kind==14}});cleared(ref receipts,ref f,ref l,ref a);
    assert(cell(owners::read(ref a.owners,a.tokens[0],0,bytes::view(ref b)))==42);
    run_source(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return 1/0;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}",7);
}

@test
fn void unused_mutable_signatures_are_public_and_body_close_releases_formal_binding(){
    let ref u8[] source=b"module main;fn i32 f(ref mut u8[] p){return 42;}fn i32 main(){return 42;}";
    let functions::Table signature=switch(functions::scan(source)){case .ok(v):{v}case .err(_):{assert(false);functions::empty()}};
    assert(signature.param_slices[0] && signature.param_slice_elements[0]==138 && signature.param_types[0]==0);
    let ir::Program p=compiled(source);inspected(ref p);
    let usize site=(p.slice_parameters[p.register_starts[0]] as usize)-1;assert(p.slice_elements[site]==138 && p.slice_roots[site]==0 && p.slice_origins[site] as usize==site+1);
    let usize close=pc(ref p,56,0);assert(p.code[close*8+1] as usize==site);
    run(ref p,16000000,0);
}
