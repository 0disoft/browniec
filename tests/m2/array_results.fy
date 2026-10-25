module tests::m2::array_results;

import ir as ir;
import errors as errors;
import verifier as verifier;

fn usize built(Result<usize,errors::Error> r) {
    return switch(r) {case .ok(n):{n} case .err(_):{assert(false);0}};
}
fn void finish(ref mut ir::Program p,usize f) {
    let usize end=p.count;let usize regs=p.registers;
    p.ends[f]=end;p.register_ends[f]=regs;
}
fn ir::Program build(u8 tag,i64 value,usize length,bool extra) {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;
    p.return_types[0]=tag;p.return_types[1]=1;
    let usize local=built(ir::array_in(ref mut p,0,tag,length,true,0));
    p.array_results[0]=1;
    let usize fill=if(tag==2){built(ir::boolean(ref mut p,value==1,0))}else{built(ir::integer(ref mut p,value,tag,0))};
    let usize init=built(ir::array_init(ref mut p,local,fill,0));
    if(extra) {
        let usize other=built(ir::array_in(ref mut p,0,tag,length,false,0));
        let usize created=built(ir::array_init(ref mut p,other,fill,0));
    }
    let usize returned=built(ir::array_return(ref mut p,local,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize destination=built(ir::array_in(ref mut p,1,tag,length,false,0));
    let usize[1] args=[0;1];
    let usize called=built(ir::array_call(ref mut p,0,destination,ref args[..0],0));
    let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize actual=built(ir::array_read(ref mut p,destination,index,0));
    let usize dropped=built(ir::array_drop(ref mut p,destination,0));
    let usize expected=if(tag==2){built(ir::boolean(ref mut p,value==1,0))}else{built(ir::integer(ref mut p,value,tag,0))};
    let usize equal=built(ir::emit(ref mut p,11,actual,expected,0));
    let usize answer=built(ir::integer(ref mut p,42,1,0));
    let usize failure=built(ir::integer(ref mut p,0,1,0));
    let usize target=p.count+2;
    let usize branch=built(ir::raw(ref mut p,20,0,equal,target,0));
    let usize ret=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);
    let usize no=built(ir::emit(ref mut p,8,failure,0,0));finish(ref mut p,1);
    return p;
}
fn ir::Program program(u8 tag,i64 value,usize length) {return build(tag,value,length,false);}
@test
fn void result_shapes_verify_for_all_six_elements_without_scalar_placeholders() {
    let u8[6] tags=[1,2,9,10,11,12];
    let i64[6] values=[-2147483648,1,-9223372036854775808,255,4294967295,-1];
    var usize i=0;
    while(i<6) {let ir::Program p=program(tags[i],values[i],4096);assert(verifier::verify(ref p).is_ok);i+=1;}
}
@test
fn void malformed_result_anchors_and_entry_results_are_rejected() {
    let ir::Program good=program(1,42,1);var ir::Program p=good;
    p.array_results[0]=3;assert(!verifier::verify(ref p).is_ok);
    p=good;p.array_results[0]=2;assert(!verifier::verify(ref p).is_ok);
    p=good;p.array_results[1]=2;assert(!verifier::verify(ref p).is_ok);
    p=good;p.array_results[15]=1;assert(!verifier::verify(ref p).is_ok);
    p=good;p.return_types[0]=2;assert(!verifier::verify(ref p).is_ok);
    p=good;p.array_results[0]=0;assert(!verifier::verify(ref p).is_ok);
}
@test
fn void array_calls_require_dead_exact_shape_caller_destinations() {
    let ir::Program good=program(1,42,1);var ir::Program p=good;let usize call=p.starts[1]*8;
    p.code[call+1]=0;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[call+1]=128;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[call+1]=143;assert(!verifier::verify(ref p).is_ok);
    p=good;p.arrays.lengths[1]=2;assert(!verifier::verify(ref p).is_ok);
    p=good;p.arrays.elements[1]=9;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[call+24]=9;p.code[call+25]=129;
    p.code[call+26]=0;p.code[call+27]=0;
    assert(!verifier::verify(ref p).is_ok);
}
@test
fn void array_returns_require_a_live_exact_shape_callee_owner_and_no_other_arrays() {
    let ir::Program good=program(1,42,1);var ir::Program p=good;
    p.code[2*8+2]=1;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[2*8+2]=16;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[2*8+1]=1;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[2*8+3]=1;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[1*8]=37;assert(!verifier::verify(ref p).is_ok);
    let ir::Program extra=build(1,42,1,true);
    assert(switch(verifier::verify(ref extra)) {case .ok(_):{false} case .err(e):{e.kind==5 && e.offset==extra.ends[0]-1}});
}
@test
fn void scalar_return_cannot_substitute_for_array_return_or_consume_an_array_destination() {
    let ir::Program good=program(1,42,1);var ir::Program p=good;
    let usize call=p.starts[1]*8;
    p.code[2*8]=8;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[call+1]=3;assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[call+24]=8;p.code[call+25]=0;
    p.code[call+26]=0;assert(!verifier::verify(ref p).is_ok);
}
@test
fn void result_lifetimes_must_be_cleaned_before_scalar_return_and_backedges() {
    let ir::Program good=program(1,42,1);var ir::Program p=good;
    let usize pc=p.starts[1]+3;
    p.code[pc*8]=19;p.code[pc*8+1]=0;p.code[pc*8+2]=7;p.code[pc*8+3]=0;
    assert(!verifier::verify(ref p).is_ok);
    p=good;p.code[pc*8]=22;p.code[pc*8+1]=0;p.code[pc*8+2]=3;p.code[pc*8+3]=0;
    assert(!verifier::verify(ref p).is_ok);
}
