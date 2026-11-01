module tests::m2::slice_mutable_public;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import ir as ir;
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void error(ref ir::Program p,usize fuel,usize limit,u8 kind){assert(switch(vm::run_with_array_limit(p,fuel,limit)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
@test
fn void complete_proof_precedes_fuel_and_backing_and_repeated_invocations_are_independent(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");
    assert(verifier::verify(ref p).is_ok);error(ref p,0,4,8);error(ref p,2000000,3,13);error(ref p,0,65537,13);
    var ir::Program bad=p;bad.slice_elements[0]=255;error(ref bad,0,65537,5);
    var usize i=0;while(i<3){assert(switch(vm::run_with_array_limit(ref p,2000000,4)){case .ok(v):{v==42}case .err(_):{false}});i+=1;}
}
@test
fn void public_exact_fuel_and_one_short_preserve_admission_and_subsequent_invocations(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut i32[] p){p[0]=42;return p[0];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");
    var usize lo=0;var usize hi=2000000;
    while(lo<hi){let usize mid=lo+(hi-lo)/2;let bool ok=switch(vm::run_with_array_limit(ref p,mid,4)){case .ok(v):{assert(v==42);true}case .err(e):{assert(e.kind==8);false}};if(ok){hi=mid;}else{lo=mid+1;}}
    assert(lo>0 && lo<2000000);error(ref p,lo-1,4,8);assert(switch(vm::run_with_array_limit(ref p,lo,4)){case .ok(v):{v==42}case .err(_):{false}});
}
@test
fn void two_exclusive_roots_and_shared_helpers_return_authority_to_their_callers(){
    let ir::Program p=compiled(b"module main;fn i32 read(ref i32[] s){return s[0];}fn i32 f(ref mut i32[] p,ref mut i32[] q,ref i32[] s){p[0]=20;q[0]=read(ref s);return p[0]+q[0];}fn i32 main(){var i32[1] a=[0;1];var i32[1] b=[0;1];let i32[1] c=[22;1];{let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut b;let ref i32[] s=ref c;let i32 n=f(ref mut p,ref mut q,ref s);if(n!=p[0]+q[0]){return 0;}}return a[0]+b[0];}");
    assert(switch(vm::run_with_array_limit(ref p,4000000,12)){case .ok(v):{v==42}case .err(_):{false}});
}
