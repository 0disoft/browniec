module tests::m2::slice_element_vm;
import ir as ir;
import errors as errors;
import slice_builders as builders;
import slice_call_vm as calls;
import slice_frame_vm as dispatch;
import slice_lifecycle_vm as lifecycle;
import slice_vm as loans;
import array_vm as arrays;
import array_layout as layouts;
import array_owners as owners;
import array_slices as slices;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) {return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize counted(Result<usize,owners::Error> r) {return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,errors::Error> r,u8 kind) {assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn usize constant(ref mut ir::Program p,u8 tag,i64 value) {
    return built(if(tag==2){ir::boolean(p,value==1,77)}else{ir::integer(p,value,tag,77)});
}
fn void finish(ref mut ir::Program p,usize f) {let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn void begin(ref mut ir::Program p,usize f) {let usize pc=p.count;let usize r=p.registers;p.starts[f]=pc;p.register_starts[f]=r;}
fn usize instruction(ref ir::Program p,u8 op,usize f) {
    var usize pc=p.starts[f];while(pc<p.ends[f]){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;
}
// Full independently inspected IR: source owned-root syntax remains gated.
// mode1 faults on a selected-range read, mode2 faults with a live child,
// mode3 observes an empty retained range without reading it.
fn ir::Program program(u8 tag,i64 value,bool forward,u8 mode) {
    var ir::Program p=ir::empty();p.function_count=if(forward){3}else{2};p.entry=if(forward){2}else{1};
    p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;p.return_types[2]=1;
    let usize formal=built(builders::parameter_typed(ref mut p,0,tag,77));
    let usize child=built(builders::derived(ref mut p,formal,0,77));
    let usize lo=built(ir::integer(ref mut p,0,12,77));
    let usize hi=if(mode==3){built(ir::integer(ref mut p,0,12,77))}else{built(ir::slice_length(ref mut p,formal,77))};
    let usize sub=built(ir::slice_sub(ref mut p,child,formal,lo,hi,77));
    let usize close=built(ir::slice_close(ref mut p,formal,77));
    var usize condition=0;
    if(mode==3) {let usize length=built(ir::slice_length(ref mut p,child,77));condition=built(ir::emit(ref mut p,11,length,lo,77));}
    else {
        let usize index=if(mode==1){built(ir::integer(ref mut p,2,12,77))}else{lo};
        let usize read=built(ir::slice_read(ref mut p,child,index,77));
        let usize expected=constant(ref mut p,tag,value);condition=built(ir::emit(ref mut p,11,read,expected,77));
    }
    if(mode==2) {let usize a=built(ir::literal(ref mut p,1,77));let usize b=built(ir::literal(ref mut p,0,77));let usize fault=built(ir::emit(ref mut p,5,a,b,77));}
    let usize drop=built(ir::slice_close(ref mut p,child,77));
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,77));
    let usize yes=built(ir::literal(ref mut p,42,77));let usize ret=built(ir::emit(ref mut p,8,yes,0,77));
    let usize no_pc=p.count;let usize no=built(ir::literal(ref mut p,0,77));let usize no_ret=built(ir::emit(ref mut p,8,no,0,77));
    let usize patched=built(ir::patch(ref mut p,branch,no_pc,77));finish(ref mut p,0);
    if(forward) {
        begin(ref mut p,1);p.arities[1]=1;
        let usize parent=built(builders::parameter_typed(ref mut p,1,tag,77));let usize derived=built(builders::derived(ref mut p,parent,1,77));
        let usize start=built(ir::integer(ref mut p,0,12,77));let usize end=built(ir::slice_length(ref mut p,parent,77));
        let usize selected=built(ir::slice_sub(ref mut p,derived,parent,start,end,77));let usize closed=built(ir::slice_close(ref mut p,parent,77));
        let usize[1] args=[160+derived];let usize result=built(ir::call(ref mut p,0,ref args,77));
        let usize released=built(ir::slice_close(ref mut p,derived,77));let usize returned=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);
    }
    let usize entry=p.entry;begin(ref mut p,entry);
    let usize root=built(ir::array_in(ref mut p,entry,tag,4,false,77));let usize site=built(ir::slice(ref mut p,root,77));
    let usize fill=constant(ref mut p,tag,value);let usize init=built(ir::array_init(ref mut p,root,fill,77));
    let usize start=built(ir::integer(ref mut p,1,12,77));let usize end=built(ir::integer(ref mut p,3,12,77));
    let usize opened=built(ir::slice_open(ref mut p,site,start,end,77));let usize[1] args=[160+site];
    var usize answer=built(ir::call(ref mut p,if(forward){1}else{0},ref args,77));
    if(forward) {let usize second=built(ir::call(ref mut p,1,ref args,77));let usize sum=built(ir::emit(ref mut p,2,answer,second,77));let usize n=built(ir::literal(ref mut p,42,77));answer=built(ir::emit(ref mut p,3,sum,n,77));}
    let usize closed=built(ir::slice_close(ref mut p,site,77));let usize dropped=built(ir::array_drop(ref mut p,root,77));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,entry);
    assert(verifier::inspect(ref p).is_ok);return p;
}
fn bytes::Buffer backing() {return switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn void cleared(ref calls::Frames f,ref loans::State l,ref arrays::State a) {
    var usize i=0;while(i<256){assert(f.origins[i].slot==16 && f.origins[i].generation==0);i+=1;}
    i=0;while(i<512){assert(l.tickets[i].slot==16 && l.tickets[i].generation==0);i+=1;}
    i=0;while(i<16){assert(!l.pool.slots[i].live && !a.owners.slots[i].reading);i+=1;}
}
fn void run(ref ir::Program p,usize fuel,u8 expected) {
    var calls::Frames f=calls::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    let Result<i64,errors::Error> outcome=execution::execute(p,fuel,ref mut a,ref mut b,ref mut l,ref mut f);
    assert(switch(outcome){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected && e.offset==77}});
    if(expected==8){assert(f.origins[8].generation!=0);}
    assert(switch(lifecycle::finish(ref mut f,ref mut l,ref mut a,ref b,outcome)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected && e.offset==77}});
    cleared(ref f,ref l,ref a);
    if(p.slice_elements[0]!=10) {
        assert(switch(vm::run_with_array_limit(p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});
    }
}

@test
fn void all_scalar_widths_and_signed_unsigned_edges_run_without_public_promotion() {
    let u8[12] tags=[1,1,2,2,9,9,10,10,11,11,12,12];
    let i64[12] values=[-2147483648,2147483647,0,1,-9223372036854775808,9223372036854775807,0,255,0,4294967295,0,-1];
    var usize i=0;while(i<12){let ir::Program p=program(tags[i],values[i],false,0);run(ref p,4000000,0);i+=1;}
}

@test
fn void forwarding_after_anchor_close_and_reused_frames_preserve_every_element_type() {
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
    while(i<6){let ir::Program p=program(tags[i],if(tags[i]==2){1}else{42},true,0);run(ref p,4000000,0);i+=1;}
}

@test
fn void bounds_arithmetic_empty_ranges_and_out_of_fuel_drain_all_borrowed_types() {
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
    while(i<6) {
        let i64 value=if(tags[i]==2){1}else{42};
        let ir::Program bounds=program(tags[i],value,true,1);run(ref bounds,4000000,14);
        let ir::Program zero=program(tags[i],value,true,2);run(ref zero,4000000,7);
        let ir::Program empty=program(tags[i],value,true,3);run(ref empty,4000000,0);
        let ir::Program fuel=program(tags[i],value,false,0);run(ref fuel,265000,8);i+=1;
    }
}

// Manual instruction state for exact Fuel and publication-failure assertions.
fn void initialize(ref ir::Program p,ref mut calls::Frames f,ref mut loans::State l,ref mut arrays::State a,ref mut bytes::Buffer b,ref mut i64[] r,i64 value) {
    let layouts::Array shape=switch(layouts::scalar(p.arrays.elements[0],4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4}}};
    {let ref mut u8[] data=bytes::view_mut(b);let owners::Token token=switch(owners::create(ref shape,value,data,ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};a.tokens[0]=token;}
    let owners::Token root=a.tokens[0];
    let slices::Ticket ticket=switch(slices::open(ref mut l.pool,ref mut a.owners,root,1,3,64)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};l.tickets[2]=ticket;
    assert(built(calls::enter(p,instruction(p,9,p.entry),0,f,l,a,b,131074))==0);
    let usize sub=instruction(p,59,0);r[p.code[sub*8+3] as usize]=0;r[p.code[sub*8+4] as usize]=2;
    assert(built(dispatch::step(p,0,sub,1,f,l,a,b,r,65537))==0);
    let usize close=instruction(p,56,0);assert(built(dispatch::step(p,0,close,1,f,l,a,b,r,4097))==0);
}

@test
fn void element_width_read_prices_bounds_and_invalid_bool_bytes_precede_publication() {
    let u8[6] tags=[1,2,9,10,11,12];let usize[6] costs=[4134,4131,4138,4131,4134,4138];var usize i=0;
    while(i<6) {
        let i64 value=if(tags[i]==2){1}else{42};let ir::Program p=program(tags[i],value,false,0);
        var calls::Frames f=calls::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var i64[128] r=[0;128];
        initialize(ref p,ref mut f,ref mut l,ref mut a,ref mut b,ref mut r,value);
        let usize pc=instruction(ref p,58,0);let usize dst=p.code[pc*8+1] as usize;let usize index=p.code[pc*8+3] as usize;r[dst]=99;
        rejected(dispatch::step(ref p,0,pc,1,ref f,ref mut l,ref mut a,ref b,ref mut r,costs[i]-1),8);assert(r[dst]==99);
        assert(built(dispatch::step(ref p,0,pc,1,ref f,ref mut l,ref mut a,ref b,ref mut r,costs[i]))==0 && r[dst]==value);
        r[index]=2;r[dst]=99;rejected(dispatch::step(ref p,0,pc,1,ref f,ref mut l,ref mut a,ref b,ref mut r,costs[i]),14);assert(r[dst]==99);r[index]=0;
        if(tags[i]==2) {{let ref mut u8[] data=bytes::view_mut(ref mut b);data[1]=2;}rejected(dispatch::step(ref p,0,pc,1,ref f,ref mut l,ref mut a,ref b,ref mut r,costs[i]),5);assert(r[dst]==99);}
        assert(switch(lifecycle::finish(ref mut f,ref mut l,ref mut a,ref b,.ok(42))){case .ok(v):{v==42}case .err(_):{false}});cleared(ref f,ref l,ref a);i+=1;
    }
}

@test
fn void mismatched_call_types_stale_roots_utf8_and_failed_cleanup_keep_original_state() {
    let ir::Program p=program(1,42,false,0);var calls::Frames f=calls::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var i64[128] r=[0;128];
    initialize(ref p,ref mut f,ref mut l,ref mut a,ref mut b,ref mut r,42);
    let usize pc=instruction(ref p,58,0);let usize dst=p.code[pc*8+1] as usize;r[dst]=99;
    f.origins[8].generation+=1;rejected(dispatch::step(ref p,0,pc,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4134),5);assert(r[dst]==99);f.origins[8].generation-=1;
    var ir::Program wrong=p;wrong.code[pc*8]=55;wrong.code[pc*8+3]=0;rejected(dispatch::step(ref wrong,0,pc,1,ref f,ref mut l,ref mut a,ref b,ref mut r,0),5);
    wrong=p;wrong.slice_elements[0]=11;wrong.slice_elements[1]=11;
    let usize child=l.tickets[17].slot;let usize root_generation=f.origins[8].generation;
    rejected(calls::leave(ref wrong,0,1,ref mut f,ref mut l,ref mut a,ref b,77),5);
    assert(l.pool.slots[child].live && f.origins[8].generation==root_generation && a.owners.slots[0].reading);
    // A target-type mismatch must not retain any ticket in a fresh child frame.
    let usize left=built(calls::leave(ref p,0,1,ref mut f,ref mut l,ref mut a,ref b,77));assert(left==1);
    rejected(calls::enter(ref wrong,instruction(ref wrong,9,wrong.entry),0,ref mut f,ref mut l,ref a,ref b,131074),5);
    assert(l.tickets[16].slot==16 && f.origins[8].generation==0 && l.pool.slots[l.tickets[2].slot].live);
    assert(switch(lifecycle::finish(ref mut f,ref mut l,ref mut a,ref b,.err(errors::make(7,77)))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==77}});cleared(ref f,ref l,ref a);
}
