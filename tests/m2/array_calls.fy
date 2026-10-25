module tests::m2::array_calls;

import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import array_layout as layouts;
import array_owners as owners;
import array_vm as arrays;
import array_call_vm as calls;
import std::bytes as bytes;

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
fn ir::Program mixed_count(u8 tag,i64 value,usize repeats) {
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
    var usize called=0; var usize i=0;
    while(i<repeats) {called=built(ir::call(ref mut p,0,ref arguments,0));i+=1;}
    let usize drop_capture=built(ir::array_drop(ref mut p,capture,0));
    let usize drop_original=built(ir::array_drop(ref mut p,original,0));
    let usize returned=built(ir::emit(ref mut p,8,called,0,0)); finish(ref mut p,1);
    return p;
}
fn ir::Program mixed(u8 tag,i64 value) {return mixed_count(tag,value,1);}
fn void result(ref ir::Program p,usize limit,i64 expected) {
    assert(verifier::verify(p).is_ok);
    assert(switch(vm::run_with_array_limit(p,1000000,limit)) {case .ok(n):{n==expected} case .err(_):{false}});
}
fn void failure(ref ir::Program p,usize limit,usize fuel,u8 kind) {
    assert(verifier::verify(p).is_ok);
    assert(switch(vm::run_with_array_limit(p,fuel,limit)) {case .ok(_):{false} case .err(e):{e.kind==kind}});
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
        let layouts::Array a=switch(layouts::scalar(tags[i],2)) {case .ok(a):{a} case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}};
        result(ref p,a.bytes*3,42); failure(ref p,a.bytes*3-1,1000000,13);
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
    p=good; p.code[pc*8]=36; p.code[pc*8+2]=2; p.code[pc*8+3]=1;
    assert(!verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref good,1000000,24)) {case .ok(n):{n==42} case .err(_):{false}});
}

fn ir::Program recursive(i64 n) {
    var ir::Program p=ir::empty();
    p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;p.arities[0]=2;
    let usize parameter=built(ir::array_parameter(ref mut p,0,1,1,0)); p.types[1]=1;p.registers=2;
    let usize zero=cell(ref mut p,1,0);let usize index=cell(ref mut p,12,0);
    let usize child_value=built(ir::slot(ref mut p,1,0));
    let usize init=built(ir::raw(ref mut p,18,child_value,zero,0,0));
    let usize more=built(ir::emit(ref mut p,15,1,zero,0));
    let usize branch=built(ir::raw(ref mut p,20,0,more,0,0));
    let usize one=cell(ref mut p,1,1);let usize smaller=built(ir::emit(ref mut p,3,1,one,0));
    let usize[2] arguments=[128+parameter,smaller];
    let usize child=built(ir::call(ref mut p,0,ref arguments,0));
    let usize saved=built(ir::raw(ref mut p,18,child_value,child,0,0));
    let usize target=p.count;let usize patched=built(ir::patch(ref mut p,branch,target,0));
    let usize own=built(ir::array_read(ref mut p,parameter,index,0));
    let usize loaded=built(ir::emit(ref mut p,17,child_value,0,0));
    let usize total=built(ir::emit(ref mut p,2,own,loaded,0));
    let usize drop=built(ir::array_drop(ref mut p,parameter,0));
    let usize ret=built(ir::emit(ref mut p,8,total,0,0));finish(ref mut p,0);
    let usize start=p.count;let usize registers=p.registers;p.starts[1]=start;p.register_starts[1]=registers;
    let usize source=built(ir::array_in(ref mut p,1,1,1,false,0));
    let usize fill=cell(ref mut p,1,7);let usize count=cell(ref mut p,1,n);
    let usize created=built(ir::array_init(ref mut p,source,fill,0));
    let usize[2] root=[128+source,count];let usize called=built(ir::call(ref mut p,0,ref root,0));
    let usize dropped=built(ir::array_drop(ref mut p,source,0));
    let usize returned=built(ir::emit(ref mut p,8,called,0,0));finish(ref mut p,1);return p;
}
fn ir::Program eight() {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;p.arities[0]=8;
    var usize i=0;while(i<8) {let usize id=built(ir::array_parameter(ref mut p,0,1,1,0));i+=1;}
    let usize index=cell(ref mut p,12,0);
    let usize a=built(ir::array_read(ref mut p,0,index,0));let usize b=built(ir::array_read(ref mut p,7,index,0));
    let usize sum=built(ir::emit(ref mut p,2,a,b,0));i=8;
    while(i>0) {i-=1;let usize drop=built(ir::array_drop(ref mut p,i,0));}
    let usize ret=built(ir::emit(ref mut p,8,sum,0,0));finish(ref mut p,0);
    let usize start=p.count;let usize registers=p.registers;p.starts[1]=start;p.register_starts[1]=registers;
    let usize source=built(ir::array_in(ref mut p,1,1,1,false,0));let usize fill=cell(ref mut p,1,21);
    let usize init=built(ir::array_init(ref mut p,source,fill,0));let usize[8] args=[128+source;8];
    let usize called=built(ir::call(ref mut p,0,ref args,0));let usize drop=built(ir::array_drop(ref mut p,source,0));
    let usize returned=built(ir::emit(ref mut p,8,called,0,0));finish(ref mut p,1);return p;
}
@test
fn void recursive_parameters_preserve_each_frame_and_share_owner_and_payload_caps() {
    let ir::Program p=recursive(5);result(ref p,28,42);failure(ref p,27,1000000,13);
    let ir::Program full=recursive(14);result(ref full,64,105);
    let ir::Program over=recursive(15);failure(ref over,128,1000000,13);
    result(ref p,28,42);
}
@test
fn void eight_array_parameters_copy_in_argument_order_and_need_the_combined_peak() {
    let ir::Program p=eight();result(ref p,36,42);failure(ref p,35,1000000,13);
}
@test
fn void calls_precharge_exact_fuel_and_scalar_call_prices_remain_unchanged() {
    let ir::Program p=mixed(1,42);
    assert(built(calls::cost(ref p,0,0))==271);
    assert(switch(vm::run_with_array_limit(ref p,670,24)) {case .ok(n):{n==42} case .err(_):{false}});
    failure(ref p,24,669,8);failure(ref p,24,478,8);
    result(ref p,24,42);
}
@test
fn void sequential_calls_reclaim_parameters_without_losing_parent_snapshots() {
    let ir::Program p=mixed_count(1,42,24);result(ref p,24,42);
}
@test
fn void late_copy_failure_preserves_owner_payload_and_all_frame_token_bindings() {
    let ir::Program p=eight();assert(verifier::verify(ref p).is_ok);
    var arrays::State state=arrays::empty(35);
    var bytes::Buffer buffer=switch(arrays::prepare(36)) {case .ok(b):{b} case .err(_):{assert(false);bytes::empty()}};
    let layouts::Array shape=switch(layouts::scalar(1,1)) {case .ok(a):{a} case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}};
    let owners::Token source=switch(owners::create(ref shape,21,bytes::view_mut(ref mut buffer),ref mut state.owners)) {
        case .ok(t):{t} case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}
    };
    state.tokens[8]=source;
    assert(switch(calls::enter(ref p,0,0,0,ref mut state,ref mut buffer,73)) {
        case .ok(_):{false} case .err(e):{e.kind==13 && e.offset==73}
    });
    assert(state.owners.depth==1 && state.owners.arena.used==4 && state.owners.slots[1].generation==1);
    var usize i=0;
    while(i<512) {
        assert(state.tokens[i].generation==if(i==8){source.generation}else{0});i+=1;
    }
    {let ref u8[] data=bytes::view(ref buffer);i=0;while(i<data.len) {assert(data[i]==if(i==0){21}else{0});i+=1;}}
    state.owners.arena.limit=36;
    assert(calls::enter(ref p,0,0,0,ref mut state,ref mut buffer,73).is_ok);
    assert(state.owners.depth==9 && state.owners.arena.used==36);
    assert(owners::write(ref state.owners,source,0,0,bytes::view_mut(ref mut buffer)).is_ok);
    assert(switch(owners::read(ref state.owners,state.tokens[16],0,bytes::view(ref buffer))) {case .ok(n):{n==21} case .err(_):{false}});
}
