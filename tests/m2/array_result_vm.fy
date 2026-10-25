module tests::m2::array_result_vm;

import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import array_result_vm as results;
import array_vm as arrays;
import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) {
    return switch(r) {case .ok(n):{n} case .err(_):{assert(false);0}};
}
fn void finish(ref mut ir::Program p,usize f) {
    let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;
}
fn layouts::Array shape(u8 tag,usize length) {
    return switch(layouts::scalar(tag,length)) {
        case .ok(a):{a} case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}
    };
}
fn bytes::Buffer buffer(usize capacity) {
    return switch(arrays::prepare(capacity)) {case .ok(b):{b} case .err(_):{assert(false);bytes::empty()}};
}
fn owners::Token create(ref mut arrays::State state,ref mut bytes::Buffer data,u8 tag,usize length,i64 fill) {
    let layouts::Array a=shape(tag,length);
    return switch(owners::create(ref a,fill,bytes::view_mut(data),ref mut state.owners)) {
        case .ok(t):{t} case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}
    };
}
fn ir::Program program(u8 tag,i64 fill,usize length,usize repetitions) {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=tag;p.return_types[1]=1;
    let usize source=built(ir::array_in(ref mut p,0,tag,length,true,0));p.array_results[0]=1;
    let usize value=if(tag==2){built(ir::boolean(ref mut p,fill==1,0))}else{built(ir::integer(ref mut p,fill,tag,0))};
    let usize init=built(ir::array_init(ref mut p,source,value,0));
    let usize ret=built(ir::array_return(ref mut p,source,73));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize destination=built(ir::array_in(ref mut p,1,tag,length,false,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize expected=if(tag==2){built(ir::boolean(ref mut p,fill==1,0))}else{built(ir::integer(ref mut p,fill,tag,0))};
    var usize i=0;
    while(i<repetitions) {
        let usize[1] args=[0;1];let usize called=built(ir::array_call(ref mut p,0,destination,ref args[..0],0));
        let usize actual=built(ir::array_read(ref mut p,destination,index,0));
        let usize equal=built(ir::emit(ref mut p,11,actual,expected,0));
        let usize jump=built(ir::raw(ref mut p,21,0,equal,0,0));
        let usize fail=built(ir::raw(ref mut p,25,0,0,0,0));
        let usize after=p.count;let usize patched=built(ir::patch(ref mut p,jump,after,0));
        let usize dropped=built(ir::array_drop(ref mut p,destination,0));i+=1;
    }
    let usize answer=built(ir::integer(ref mut p,42,1,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);return p;
}
fn void value(ref ir::Program p,usize limit,usize fuel) {
    assert(verifier::verify(p).is_ok);
    assert(switch(vm::run_with_array_limit(p,fuel,limit)) {case .ok(n):{n==42} case .err(_):{false}});
}
fn void failure(ref ir::Program p,usize limit,usize fuel,u8 kind) {
    assert(verifier::verify(p).is_ok);
    assert(switch(vm::run_with_array_limit(p,fuel,limit)) {case .ok(_):{false} case .err(e):{e.kind==kind}});
}
@test
fn void returns_rehome_all_six_elements_at_one_extent_peak() {
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] fills=[-2147483648,1,-9223372036854775808,255,4294967295,-1];
    var usize i=0;
    while(i<6) {
        let layouts::Array small=shape(tags[i],1);let ir::Program p=program(tags[i],fills[i],1,1);
        value(ref p,small.bytes,1000000);failure(ref p,small.bytes-1,1000000,13);
        let layouts::Array maximum=shape(tags[i],4096);let ir::Program large=program(tags[i],fills[i],4096,1);
        value(ref large,maximum.bytes,1000000);i+=1;
    }
}
@test
fn void repeated_returns_reclaim_the_same_extent_and_owner_slot() {
    let ir::Program p=program(1,42,1,24);value(ref p,4,1000000);value(ref p,4,1000000);
}
fn ir::Program recursive(i64 n) {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;p.arities[0]=1;
    p.types[0]=1;p.registers=1;
    let usize local=built(ir::array_in(ref mut p,0,1,1,false,0));p.array_results[0]=1;
    let usize result=built(ir::array_in(ref mut p,0,1,1,false,0));
    let usize zero=built(ir::integer(ref mut p,0,1,0));let usize more=built(ir::emit(ref mut p,15,0,zero,0));
    let usize branch=built(ir::raw(ref mut p,20,0,more,0,0));
    let usize one=built(ir::integer(ref mut p,1,1,0));let usize less=built(ir::emit(ref mut p,3,0,one,0));
    let usize[1] child=[less];let usize called=built(ir::array_call(ref mut p,0,result,ref child,0));
    let usize returned=built(ir::array_return(ref mut p,result,0));
    let usize base=p.count;let usize patched=built(ir::patch(ref mut p,branch,base,0));
    let usize fill=built(ir::integer(ref mut p,42,1,0));let usize init=built(ir::array_init(ref mut p,local,fill,0));
    let usize terminal=built(ir::array_return(ref mut p,local,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize destination=built(ir::array_in(ref mut p,1,1,1,false,0));
    let usize count=built(ir::integer(ref mut p,n,1,0));let usize[1] args=[count];
    let usize entered=built(ir::array_call(ref mut p,0,destination,ref args,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize actual=built(ir::array_read(ref mut p,destination,index,0));
    let usize drop=built(ir::array_drop(ref mut p,destination,0));let usize done=built(ir::emit(ref mut p,8,actual,0,0));
    finish(ref mut p,1);return p;
}
@test
fn void recursive_returns_keep_one_owner_across_all_32_frames() {
    let ir::Program p=recursive(30);value(ref p,4,1000000);failure(ref p,3,1000000,13);
    let ir::Program over=recursive(31);failure(ref over,4,1000000,12);value(ref p,4,1000000);
}
fn void unchanged(ref arrays::State state,ref arrays::State prior) {
    assert(state.owners.depth==prior.owners.depth && state.owners.arena.used==prior.owners.arena.used && state.owners.arena.limit==prior.owners.arena.limit);
    var usize i=0;
    while(i<512) {assert(state.tokens[i].slot==prior.tokens[i].slot && state.tokens[i].generation==prior.tokens[i].generation);i+=1;}
    i=0;while(i<16) {
        assert(state.owners.order[i]==prior.owners.order[i]);
        let owners::Owner a=state.owners.slots[i];let owners::Owner b=prior.owners.slots[i];
        assert(a.generation==b.generation && a.occupied==b.occupied && a.live==b.live && a.mark==b.mark && a.base==b.base && a.end==b.end && a.element==b.element && a.length==b.length);i+=1;
    }
}
@test
fn void failed_return_preflight_preserves_all_owner_tokens_and_payload_bytes() {
    let ir::Program p=program(2,1,4,1);var usize variant=0;
    while(variant<6) {
        var arrays::State state=arrays::empty(4);var bytes::Buffer data=buffer(4);
        let owners::Token token=create(ref mut state,ref mut data,2,4,1);state.tokens[16]=token;
        if(variant==0) {state.tokens[16]=owners::Token{.slot=token.slot,.generation=token.generation+1};}
        if(variant==1) {state.tokens[1]=token;}
        if(variant==2) {state.tokens[17]=token;}
        if(variant==3) {let ref mut u8[] view=bytes::view_mut(ref mut data);view[3]=2;}
        if(variant==4) {state.owners.slots[0].length=2;}
        let arrays::State prior=state;
        let usize frame=if(variant==5){0}else{1};
        assert(switch(results::leave(ref p,0,0,1,frame,ref mut state,ref data,73)) {case .ok(_):{false} case .err(e):{e.kind==5 && e.offset==73}});
        unchanged(ref state,ref prior);
        {let ref u8[] view=bytes::view(ref data);var usize i=0;while(i<4) {assert(view[i]==if(variant==3 && i==3){2}else{1});i+=1;}}
        variant+=1;
    }
}
@test
fn void successful_return_preserves_descriptor_generation_and_bytes_then_drops_cleanly() {
    let ir::Program p=program(1,42,1,1);var arrays::State state=arrays::empty(4);var bytes::Buffer data=buffer(4);
    let owners::Token token=create(ref mut state,ref mut data,1,1,42);state.tokens[16]=token;
    assert(built(results::leave(ref p,0,0,1,1,ref mut state,ref data,73))==4);
    assert(state.tokens[16].generation==0 && state.tokens[1].slot==token.slot && state.tokens[1].generation==token.generation);
    assert(state.owners.depth==1 && state.owners.arena.used==4 && state.owners.slots[0].generation==token.generation);
    assert(switch(owners::read(ref state.owners,state.tokens[1],0,bytes::view(ref data))) {case .ok(n):{n==42} case .err(_):{false}});
    let owners::Token received=state.tokens[1];
    assert(owners::release(ref mut state.owners,received,4).is_ok);
    assert(state.owners.depth==0 && state.owners.arena.used==0);
}
@test
fn void return_work_is_prepaid_and_scalar_call_prices_are_unchanged() {
    let ir::Program p=program(1,42,1,1);assert(built(results::cost(ref p,0,0))==65);
    // Preparation 5, entry constants 2, CALL 1, callee constant/init 69,
    // ARET 65, read/equality/branch/drop 88, final constant/RET 2 = 232.
    value(ref p,4,232);failure(ref p,4,231,8);
    assert(switch(vm::run_with_array_limit(ref p,141,4)) {case .ok(_):{false} case .err(e):{e.kind==8 && e.offset==73}});
    let ir::Program flags=program(2,1,4,1);assert(built(results::cost(ref flags,0,0))==69);
}
