module tests::m2::slice_public_canonical;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import array_vm as arrays;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_mutable_call_vm as legacy;
import vm_execution as execution;
import std::bytes as bytes;

fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn i64 value(Result<i64,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
// Frozen pre-migration public mutable transaction, used only as a compatibility
// oracle for results, error offsets and exact logical Fuel. All fixtures below
// contain aggregates and exclusive formals; ordinary dispatch is not modeled.
fn Result<i64,errors::Error> old(ref ir::Program p,usize fuel,usize limit){
    let usize checked=verifier::verify(p)?;
    if(limit>65536){return .err(errors::make(13,0));}
    if(fuel<1+limit){return .err(errors::make(8,0));}
    var arrays::State a=arrays::empty(limit);var bytes::Buffer b=arrays::prepare(limit)?;
    var loans::State l=loans::empty();var shared::Frames f=shared::empty();
    var legacy::Frame[32] receipts=[legacy::empty();32];
    let Result<i64,errors::Error> result=execution::execute_mutable(p,fuel-1-limit,ref mut a,ref mut b,ref mut l,ref mut f,ref mut receipts);
    return legacy::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,result);
}
fn void same(Result<i64,errors::Error> a,Result<i64,errors::Error> b){
    switch(a){case .ok(x):{assert(switch(b){case .ok(y):{x==y}case .err(_):{false}});}case .err(x):{assert(switch(b){case .ok(_):{false}case .err(y):{x.kind==y.kind && x.offset==y.offset}});}};
}
fn void run(ref u8[] source){
    let ir::Program p=compiled(source);assert(value(old(ref p,16000000,256))==42);
    assert(value(vm::run_with_array_limit(ref p,16000000,256))==42);
}
@test
fn void public_canonical_calls_match_legacy_shared_owned_results_and_scalar_frames(){
    run(b"module main;struct R{i32 x;}fn i32[1] f(R r,i32[1] a,ref i32[] q,ref mut i32[] p){p[0]=r.x+a[0]+q[0];return [p[0];1];}fn i32 main(){let R r=R{.x=20};let i32[1] a=[21;1];let i32[1] b=[1;1];var i32[1] out=[0;1];let ref i32[] q=ref b;let ref mut i32[] p=ref mut out;let i32[1] result=f(r,a,ref q,ref mut p);return result[0];}");
    run(b"module main;struct I{bool ok;i32 x;}struct R{u8 lead;I inner;}fn R f(R r,i32[1] a,ref i32[] q,ref mut i32[] p){p[0]=r.inner.x+a[0]+q[0];return R{.lead=7,.inner=I{.ok=true,.x=p[0]}};}fn i32 main(){let R r=R{.lead=0,.inner=I{.ok=true,.x=20}};let i32[1] a=[21;1];let i32[1] b=[1;1];var i32[1] out=[0;1];let ref i32[] q=ref b;let ref mut i32[] p=ref mut out;let R result=f(r,a,ref q,ref mut p);if(result.inner.ok){return result.inner.x;}return 0;}");
    run(b"module main;fn i32 add(i32 x){return x;}fn i32 f(ref mut i32[] p,ref i32[] q,ref i32[] r){p[0]=add(q[0]+r[0]);return p[0];}fn i32 main(){let i32[1] a=[21;1];var i32[1] b=[0;1];let ref i32[] q=ref a;let ref mut i32[] p=ref mut b;return f(ref mut p,ref q,ref q);}");
    run(b"module main;fn Option<i32> f(ref mut i32[] p,bool yes){p[0]=42;if(yes){return .some(p[0]);}return .none;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return switch(f(ref mut p,true)){case .some(v):{v}case .none:{0}};}");
    run(b"module main;fn i32 write(ref mut i32[] p){p[0]=42;return p[0];}fn i32 recurse(i32 n){if(n==0){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return write(ref mut p);}return recurse(n-1);}fn i32 main(){return recurse(29);}");
}
@test
fn void public_canonical_fuel_quotas_and_error_offsets_match_legacy(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut i32[] p,i32 n){p[0]=n;return p[0];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p,42);}");
    var usize lo=0;var usize hi=2000000;assert(value(old(ref p,hi,4))==42);
    while(lo<hi){let usize mid=lo+(hi-lo)/2;if(old(ref p,mid,4).is_ok){hi=mid;}else{lo=mid+1;}}
    assert(value(vm::run_with_array_limit(ref p,lo,4))==42);same(old(ref p,lo-1,4),vm::run_with_array_limit(ref p,lo-1,4));
    same(old(ref p,0,65537),vm::run_with_array_limit(ref p,0,65537));same(old(ref p,2000000,3),vm::run_with_array_limit(ref p,2000000,3));
    let ir::Program bounds=compiled(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");
    same(old(ref bounds,2000000,4),vm::run_with_array_limit(ref bounds,2000000,4));
    let ir::Program division=compiled(b"module main;fn i32 fail(i32 z){return 1/z;}fn i32 f(ref mut i32[] p){p[0]=42;return fail(0);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");
    same(old(ref division,2000000,4),vm::run_with_array_limit(ref division,2000000,4));
    let ir::Program deep=compiled(b"module main;fn i32 write(ref mut i32[] p){return 42;}fn i32 recurse(i32 n){if(n==0){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return write(ref mut p);}return recurse(n-1);}fn i32 main(){return recurse(30);}");
    same(old(ref deep,16000000,4),vm::run_with_array_limit(ref deep,16000000,4));
    assert(value(vm::run_with_array_limit(ref p,lo,4))==42);
}
