module tests::m2::array_calls;

import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;

fn usize built(Result<usize,errors::Error> r) {
    return switch(r) {case .ok(n):{n} case .err(_):{assert(false);0}};
}
fn void finish(ref mut ir::Program p,usize f) {
    let usize end=p.count; let usize registers=p.registers;
    p.ends[f]=end; p.register_ends[f]=registers;
}
fn usize cell(ref mut ir::Program p,u8 tag,i64 value) {
    if(tag==2) {return built(ir::boolean(p,value==1,0));}
    return built(ir::integer(p,value,tag,0));
}
fn ir::Program mixed(u8 tag,i64 value) {
    var ir::Program p=ir::empty();
    p.function_count=2; p.entry=1; p.return_types[0]=1; p.return_types[1]=1;
    p.arities[0]=2;
    let usize parameter=built(ir::array_parameter(ref mut p,0,tag,2,0));
    p.types[1]=tag; p.registers=2;
    let usize index=cell(ref mut p,12,0);
    let usize actual=built(ir::array_read(ref mut p,parameter,index,0));
    let usize equal=built(ir::emit(ref mut p,11,actual,1,0));
    let usize drop=built(ir::array_drop(ref mut p,parameter,0));
    let usize answer=cell(ref mut p,1,42); let usize failure=cell(ref mut p,1,0);
    let usize target=p.count+2;
    let usize branch=built(ir::raw(ref mut p,20,0,equal,target,0));
    let usize yes=built(ir::emit(ref mut p,8,answer,0,0));
    let usize no=built(ir::emit(ref mut p,8,failure,0,0)); finish(ref mut p,0);
    let usize start=p.count; let usize registers=p.registers;
    p.starts[1]=start; p.register_starts[1]=registers;
    let usize original=built(ir::array_in(ref mut p,1,tag,2,true,0));
    let usize capture=built(ir::array_in(ref mut p,1,tag,2,false,0));
    let usize fill=cell(ref mut p,tag,value); let usize zero=cell(ref mut p,tag,0);
    let usize parent_index=cell(ref mut p,12,0);
    let usize init=built(ir::array_init(ref mut p,original,fill,0));
    let usize snapshot=built(ir::array_copy(ref mut p,capture,original,0));
    let usize mutation=built(ir::array_write(ref mut p,original,parent_index,zero,0));
    let usize[2] arguments=[128+capture,fill];
    let usize called=built(ir::call(ref mut p,0,ref arguments,0));
    let usize drop_capture=built(ir::array_drop(ref mut p,capture,0));
    let usize drop_original=built(ir::array_drop(ref mut p,original,0));
    let usize returned=built(ir::emit(ref mut p,8,called,0,0)); finish(ref mut p,1);
    return p;
}
fn usize call_pc(ref ir::Program p) {
    var usize pc=p.starts[1];
    while(pc<p.ends[1] && p.code[pc*8]!=9) {pc+=1;}
    assert(pc<p.ends[1]); return pc;
}
@test
fn void mixed_scalar_array_shapes_verify_for_all_six_elements() {
    let u8[6] tags=[1,2,9,10,11,12];
    let i64[6] values=[-2147483648,1,-9223372036854775808,255,4294967295,-1];
    var usize i=0;
    while(i<6) {
        let ir::Program p=mixed(tags[i],values[i]);
        assert(verifier::verify(ref p).is_ok && p.array_parameters[0]==1 && p.array_parameters[1]==0);
        i+=1;
    }
}
@test
fn void malformed_parameter_catalog_and_placeholder_metadata_are_rejected() {
    let ir::Program good=mixed(1,42); var ir::Program p=good;
    p.array_parameters[0]=16; assert(!verifier::verify(ref p).is_ok);
    p=good; p.array_parameters[127]=1; assert(!verifier::verify(ref p).is_ok);
    p=good; p.array_parameters[1]=1; assert(!verifier::verify(ref p).is_ok);
    p=good; p.array_parameters[2]=1; p.array_parameters[0]=0; assert(!verifier::verify(ref p).is_ok);
    p=good; p.array_parameters[0]=0; assert(!verifier::verify(ref p).is_ok);
    p=good; p.array_functions[0]=1; assert(!verifier::verify(ref p).is_ok);
    p=good; p.arrays.mutable[0]=true; assert(!verifier::verify(ref p).is_ok);
    p=good; p.types[0]=2; assert(!verifier::verify(ref p).is_ok);
    p=good; p.slots[0]=true; assert(!verifier::verify(ref p).is_ok);
}
@test
fn void call_arguments_require_live_immutable_exact_shape_owned_by_caller() {
    let ir::Program good=mixed(1,42); var ir::Program p=good;
    p.call_args[0]=1; assert(!verifier::verify(ref p).is_ok);
    p=good; p.call_args[1]=130; assert(!verifier::verify(ref p).is_ok);
    p=good; p.call_args[2]=1; assert(!verifier::verify(ref p).is_ok);
    p=good; p.call_args[0]=128; assert(!verifier::verify(ref p).is_ok);
    p=good; p.call_args[0]=143; assert(!verifier::verify(ref p).is_ok);
    p=good; p.arrays.mutable[2]=true; assert(!verifier::verify(ref p).is_ok);
    p=good; p.arrays.lengths[0]=1; assert(!verifier::verify(ref p).is_ok);
    p=good; p.arrays.elements[0]=9; p.types[0]=9; assert(!verifier::verify(ref p).is_ok);
    p=good; let usize before=call_pc(ref p)-1;
    p.code[before*8]=37; p.code[before*8+1]=2; p.code[before*8+2]=0; p.code[before*8+3]=0;
    assert(!verifier::verify(ref p).is_ok);
}
@test
fn void parameters_cannot_be_scalar_operands_reinitialized_or_left_live_on_return() {
    let ir::Program good=mixed(1,42); var ir::Program p=good;
    var usize pc=0; while(p.code[pc*8]!=37) {pc+=1;}
    p.code[pc*8]=19; assert(ir::patch(ref mut p,pc,pc+1,0).is_ok);
    assert(!verifier::verify(ref p).is_ok);
    p=good; p.code[(pc+1)*8]=33; p.code[(pc+1)*8+1]=0; p.code[(pc+1)*8+2]=1; p.code[(pc+1)*8+3]=0;
    assert(!verifier::verify(ref p).is_ok);
    p=good; p.code[2*8+2]=0;
    assert(!verifier::verify(ref p).is_ok);
    // This stage verifies shapes but must not execute array CALLs yet.
    assert(!vm::run_with_array_limit(ref good,1000000,24).is_ok);
}
