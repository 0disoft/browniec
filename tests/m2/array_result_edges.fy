module tests::m2::array_result_edges;

import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;

fn usize built(Result<usize,errors::Error> r) {
    return switch(r) {case .ok(n):{n} case .err(_):{assert(false);0}};
}
fn void finish(ref mut ir::Program p,usize f) {
    let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;
}
fn void result(ref ir::Program p,usize limit,bool success) {
    assert(verifier::verify(p).is_ok);
    assert(switch(vm::run_with_array_limit(p,1000000,limit)) {case .ok(n):{success && n==42} case .err(e):{!success && e.kind==13}});
}
@test
fn void returned_parameter_remains_independent_of_the_original_caller_array() {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;p.arities[0]=1;
    let usize parameter=built(ir::array_parameter(ref mut p,0,1,1,0));p.array_results[0]=1;
    let usize ret=built(ir::array_return(ref mut p,parameter,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize original=built(ir::array_in(ref mut p,1,1,1,false,0));
    let usize destination=built(ir::array_in(ref mut p,1,1,1,true,0));
    let usize fill=built(ir::integer(ref mut p,42,1,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize init=built(ir::array_init(ref mut p,original,fill,0));let usize[1] args=[128+original];
    let usize called=built(ir::array_call(ref mut p,0,destination,ref args,0));
    let usize zero=built(ir::integer(ref mut p,0,1,0));let usize mutation=built(ir::array_write(ref mut p,destination,index,zero,0));
    let usize actual=built(ir::array_read(ref mut p,original,index,0));
    let usize drop_result=built(ir::array_drop(ref mut p,destination,0));let usize drop_original=built(ir::array_drop(ref mut p,original,0));
    let usize done=built(ir::emit(ref mut p,8,actual,0,0));finish(ref mut p,1);
    result(ref p,8,true);result(ref p,7,false);result(ref p,8,true);
}
@test
fn void caller_drop_reclaims_deferred_callee_holes_across_repeated_returns() {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize temporary=built(ir::array_in(ref mut p,0,1,1,false,0));
    let usize source=built(ir::array_in(ref mut p,0,1,1,false,0));p.array_results[0]=2;
    let usize fill=built(ir::integer(ref mut p,42,1,0));
    let usize first=built(ir::array_init(ref mut p,temporary,fill,0));let usize second=built(ir::array_init(ref mut p,source,fill,0));
    let usize dropped=built(ir::array_drop(ref mut p,temporary,0));let usize ret=built(ir::array_return(ref mut p,source,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize destination=built(ir::array_in(ref mut p,1,1,1,false,0));let usize[1] args=[0;1];var usize i=0;
    while(i<24) {
        let usize called=built(ir::array_call(ref mut p,0,destination,ref args[..0],0));
        let usize drop=built(ir::array_drop(ref mut p,destination,0));i+=1;
    }
    let usize answer=built(ir::integer(ref mut p,42,1,0));let usize done=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);
    result(ref p,8,true);result(ref p,7,false);result(ref p,8,true);
}
