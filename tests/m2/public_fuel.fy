module tests::m2::public_fuel;
import compiler as compiler;
import ir as ir;
import vm as vm;
import errors as errors;
import fuel as meter;

fn ir::Program compiled(ref u8[] source){
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void completed(Result<i64,errors::Error> result){
    assert(switch(result){case .ok(v):{v==42}case .err(_):{false}});
}
fn void shortage(Result<i64,errors::Error> result){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==8}});
}
// Independent numeric oracle for these straight-line i32-array fixtures only:
// every instruction executes exactly once and their sole helper is called once.
fn usize required(ref ir::Program p,usize backing){
    var usize total=1+backing;var usize pc=0;
    while(pc<p.count){
        let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;
        var usize cost=1;
        if(op==9){cost=1+8+17*65537;}
        else if(op==33){cost=49+8+4*p.arrays.lengths[dst]+7;}
        else if(op==35){cost=37;}else if(op==37){cost=49;}
        else if(op==54 || op==59 || op==61 || op==62){cost=65537;}
        else if(op==55){cost=4097+4*p.arrays.lengths[(p.slice_roots[a] as usize)-1];}
        else if(op==56 || op==57){cost=4097;}
        else if(op==58){cost=4134;}else if(op==60){cost=4138;}
        else{assert(op<33 && !(op>=19 && op<=22));}
        total+=cost;pc+=1;
    }return total;
}
fn void exact(ref ir::Program p,usize backing){
    let usize price=required(p,backing);
    shortage(vm::run_with_array_limit(p,price-1,backing));
    completed(vm::run_with_array_limit(p,price,backing));
    completed(vm::run_with_array_limit(p,price+1,backing));
    completed(vm::run_with_array_limit(p,meter::cli_limit(),backing));
}
@test fn void eight_writer_call_is_executable_under_the_public_ceiling(){
    let ir::Program p=compiled(b"module main;fn i32 touch(ref mut i32[] a,ref mut i32[] b,ref mut i32[] c,ref mut i32[] d,ref mut i32[] e,ref mut i32[] f,ref mut i32[] g,ref mut i32[] h){a[0]=42;return a[0];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] pa=ref mut a;var i32[1] b=[0;1];let ref mut i32[] pb=ref mut b;var i32[1] c=[0;1];let ref mut i32[] pc=ref mut c;var i32[1] d=[0;1];let ref mut i32[] pd=ref mut d;var i32[1] e=[0;1];let ref mut i32[] pe=ref mut e;var i32[1] f=[0;1];let ref mut i32[] pf=ref mut f;var i32[1] g=[0;1];let ref mut i32[] pg=ref mut g;var i32[1] h=[0;1];let ref mut i32[] ph=ref mut h;return touch(ref mut pa,ref mut pb,ref mut pc,ref mut pd,ref mut pe,ref mut pf,ref mut pg,ref mut ph);}");
    assert(required(ref p,32)>1000000 && required(ref p,32)<16000000);
    shortage(vm::run_with_array_limit(ref p,1000000,32));exact(ref p,32);
    // The same source and schedule work with the public default 64KiB backing.
    shortage(vm::run(ref p,required(ref p,65536)-1));
    completed(vm::run(ref p,required(ref p,65536)));
}
@test fn void rooted_shared_and_exclusive_operations_keep_their_exact_prices(){
    let ir::Program shared=compiled(b"module main;fn i32 main(){let i32[2] a=[42;2];let ref i32[] s=ref a;return s[0];}");
    exact(ref shared,8);
    let ir::Program writer=compiled(b"module main;fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] s=ref mut a;s[0]=42;return s[0];}");
    exact(ref writer,8);
}
@test fn void scalar_defaults_and_native_host_budgets_remain_independent(){
    let ir::Program scalar=compiled(b"module main;fn i32 main(){return 42;}");
    assert(meter::cli_default()==256 && meter::cli_limit()==16000000);
    shortage(vm::run(ref scalar,1));completed(vm::run(ref scalar,2));
    completed(vm::run(ref scalar,meter::cli_default()));
    // The CLI ceiling is a policy for parsing CLI arguments, not native vm::run.
    completed(vm::run(ref scalar,16000001));
}
@test fn void admission_still_precedes_runtime_fuel_and_backing_limits(){
    var ir::Program p=compiled(b"module main;fn i32 main(){let i32[1] a=[42;1];return a[0];}");
    p.code[0]=255;
    assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .err(e):{e.kind==5}case .ok(_):{false}});
}
