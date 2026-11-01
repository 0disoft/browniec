module tests::m2::slice_exclusive_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import slice_vm as loans;
import slice_call_vm as calls;
import slice_lifecycle_vm as lifecycle;
import array_vm as arrays;
import std::bytes as bytes;

fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};}
fn void run(ref u8[] source,u8 error){
    let ir::Program p=compiled(source);assert(verifier::inspect(ref p).is_ok);
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,4000065,64)){case .ok(v):{error==0 && v==42}case .err(e):{e.kind==error && e.offset<source.len}});
    var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var calls::Frames f=calls::empty();
    var bytes::Buffer b=switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    let result=execution::execute(ref p,4000000,ref mut a,ref mut b,ref mut l,ref mut f);
    assert(switch(result){case .ok(v):{error==0 && v==42}case .err(e):{e.kind==error && e.offset<source.len}});
    assert(switch(lifecycle::finish(ref mut f,ref mut l,ref mut a,ref b,result)){case .ok(v):{error==0 && v==42}case .err(e):{e.kind==error}});
    var usize i=0;while(i<16){assert(!a.owners.slots[i].writing && !a.owners.slots[i].reading && !l.pool.slots[i].live);i+=1;}
    i=0;while(i<512){assert(l.tickets[i].generation==0);i+=1;}
}
fn void rejected(ref u8[] source){assert(switch(compiler::compile(source)){case .ok(_):{false}case .err(e):{e.kind==2 || e.kind==3}});}
fn void conflict(ref u8[] source){
    let ir::Program p=compiled(source);assert(!verifier::inspect(ref p).is_ok);
    assert(!verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});
}

@test
fn void six_scalar_tags_whole_computed_open_and_empty_ranges_lower_to_owned_exclusive_sites(){
    run(b"module main;fn i32 main(){var i32[3] a=[0;3];{let ref mut i32[] p=ref mut a[1..];p[0]=-2147483648;if(p.len!=2 || p[0]!=-2147483648){return 0;}}a[0]=42;return a[0];}",0);
    run(b"module main;fn i32 main(){var bool[2] a=[false;2];{let ref mut bool[] p=ref mut a;p[1]=true;if(!p[1]){return 0;}}if(a[1]){return 42;}return 0;}",0);
    run(b"module main;fn i32 main(){var i64[2] a=[0;2];{let ref mut i64[] p=ref mut a[..];p[0]=-9223372036854775808;if(p[0]!=-9223372036854775808){return 0;}}return 42;}",0);
    run(b"module main;fn i32 main(){var u8[3] a=[255;3];{let ref mut u8[] p=ref mut a[1+0..a.len-1];p[0]=42;if(p.len!=1 || !text::valid_utf8(p)){return 0;}}return a[1] as i32;}",0);
    run(b"module main;fn i32 main(){var u32[2] a=[0;2];{let ref mut u32[] p=ref mut a[..1];p[0]=4294967295;if(p[0]!=4294967295){return 0;}}return 42;}",0);
    run(b"module main;fn i32 main(){var usize[2] a=[0;2];{let ref mut usize[] p=ref mut a;p[0]=18446744073709551615;if(p[0]!=18446744073709551615){return 0;}}{let ref mut usize[] q=ref mut a[2..2];if(q.len!=0){return 0;}}return 42;}",0);
}

@test
fn void endpoints_and_store_operands_run_once_in_order_with_no_extra_owner_or_scalar_store(){
    run(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;var i32[2] a=[0;2];{let ref mut i32[] p=ref mut a[switch(o){case .some(v):{0}case .none:{n=n*10+1;0}}..switch(o){case .some(v):{2}case .none:{n=n*10+2;2}}];p[switch(o){case .some(v):{0}case .none:{n=n*10+3;0}}]=switch(o){case .some(v):{0}case .none:{n=n*10+4;42}};}if(n==1234){return a[0];}return 0;}",0);
    run(b"module main;fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;let i32 value=switch(o){case .some(v):{0}case .none:{let ref mut i32[] p=ref mut a;p[0]=42;p[0]}};return value;}",0);
    let ir::Program p=compiled(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[0]=42;return p[0];}");
    assert(p.arrays.count==1 && ir::exclusive(ref p,0) && p.slice_roots[0]==1);
    var usize stores=0;var usize opens=0;var usize i=0;while(i<p.count){let u8 op=p.code[i*8];if(op==60){stores+=1;}if(op==54){opens+=1;}assert(op!=18 && op!=34);i+=1;}assert(stores==1 && opens==1);
}

@test
fn void lexical_returns_break_continue_and_pending_endpoint_exits_release_the_right_sessions(){
    run(b"module main;fn i32 main(){var i32[1] a=[0;1];var i32 n=0;while(n<2){let ref mut i32[] p=ref mut a;p[0]=p[0]+1;n=n+1;continue;}while(true){let ref mut i32[] p=ref mut a;p[0]=42;break;}return a[0];}",0);
    run(b"module main;fn i32 f(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[0]=42;return p[0];}fn i32 main(){return f();}",0);
    run(b"module main;fn Option<i32> f(Option<i32> o){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[0]=42;let i32 v=o?;return .some(p[0]);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",0);
    run(b"module main;fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;var i32 n=0;while(n<2){let ref mut i32[] p=ref mut a[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}..1];}a[0]=42;return a[0];}",0);
    run(b"module main;fn i32 main(){var i32[1] a=[0;1];let Option<i32> o=.none;while(true){let ref mut i32[] p=ref mut a[0..switch(o){case .some(v):{1}case .none:{break;}}];}a[0]=42;return a[0];}",0);
    run(b"module main;fn i32 read(ref i32[] p){return p[0];}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref i32[] q=ref b;let ref mut i32[] p=ref mut a;p[0]=read(ref q);return p[0];}",0);
}

@test
fn void independent_inspection_rejects_root_access_copies_and_conflicting_sessions(){
    conflict(b"module main;fn i32 main(){var i32[1] a=[42;1];let ref mut i32[] p=ref mut a;return a[0];}");
    conflict(b"module main;fn i32 main(){var i32[1] a=[42;1];let ref mut i32[] p=ref mut a;let i32[1] b=a;return 42;}");
    conflict(b"module main;fn i32 main(){var i32[1] a=[42;1];let ref i32[] q=ref a;let ref mut i32[] p=ref mut a;return 42;}");
    conflict(b"module main;fn i32 main(){var i32[1] a=[42;1];let ref mut i32[] p=ref mut a;let ref i32[] q=ref a;return 42;}");
    conflict(b"module main;fn i32 main(){var i32[1] a=[42;1];let ref mut i32[] p=ref mut a[0..0];let ref mut i32[] q=ref mut a;return 42;}");
    conflict(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref mut u8[] p=ref mut a;if(text::valid_utf8(a)){return 42;}return 0;}");
}

@test
fn void readonly_roots_mode_mismatches_aliases_call_coercions_and_rebinding_fail_in_source(){
    rejected(b"module main;fn i32 main(){let i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];var ref mut i32[] p=ref mut a;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref a;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref i32[] p=ref mut a;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref i32[] q=ref p;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref i32[] p=ref a;let ref mut i32[] q=ref mut p;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p[..];return 42;}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref p);}");
    rejected(b"module main;fn i32 f(ref mut i32[] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p=p;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[true]=42;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[0]=true;return 42;}");
    rejected(b"module main;fn i32 main(){var u8[1] a=[0;1];let ref mut i32[] p=ref mut a;return 42;}");
    rejected(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let i32[1] b=p;return 42;}");
}

@test
fn void actual_source_execution_checks_selected_bounds_and_cleans_after_store_or_operand_errors(){
    run(b"module main;fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a[1..2];p[1]=42;return 42;}",14);
    run(b"module main;fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a[2..];p[0]=42;return 42;}",14);
    run(b"module main;fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] p=ref mut a[..3];return 42;}",14);
    run(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[18446744073709551615]=42;return 42;}",14);
    run(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[0]=42;p[0]=1/0;return 42;}",7);
    run(b"module main;fn i32 main(){var i32[1] a=[2147483647;1];let ref mut i32[] p=ref mut a;p[0]=p[0]+1;return 42;}",6);
}
