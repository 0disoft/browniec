module tests::m2::slice_frame_vm;
import ir as ir;
import slice_builders as builders;
import slice_frame_vm as dispatch;
import slice_call_vm as calls;
import slice_vm as loans;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import array_layout as layouts;
import verifier as verifier;
import vm as vm;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v):{v} case .err(_):{assert(false);0} }; }
fn usize count(Result<usize,owners::Error> r) { return switch(r) { case .ok(v):{v} case .err(_):{assert(false);0} }; }
fn ir::Program program(usize length) {
    var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=1; p.return_types[0]=1; p.return_types[1]=1;
    let usize formal=built(builders::parameter(ref mut p,0,77)); let usize child=built(builders::derived(ref mut p,formal,0,77));
    let usize lo=built(ir::integer(ref mut p,0,12,77)); let usize hi=built(ir::integer(ref mut p,2,12,77));
    let usize index=built(ir::integer(ref mut p,0,12,77)); let usize sub=built(ir::slice_sub(ref mut p,child,formal,lo,hi,77));
    let usize close_formal=built(ir::slice_close(ref mut p,formal,77));
    let usize len=built(ir::slice_length(ref mut p,child,77)); let usize utf=built(ir::slice_utf8(ref mut p,child,77));
    let usize read=built(ir::slice_read(ref mut p,child,index,77)); let usize close_child=built(ir::slice_close(ref mut p,child,77));
    let usize yes=built(ir::literal(ref mut p,42,77)); let usize ret=built(ir::emit(ref mut p,8,yes,0,77));
    let usize end=p.count; let usize regs=p.registers; p.ends[0]=end; p.register_ends[0]=regs; p.starts[1]=end; p.register_starts[1]=regs;
    let usize root=built(ir::array_in(ref mut p,1,10,length,false,77)); let usize parent=built(ir::slice(ref mut p,root,77)); assert(formal==0 && child==1 && parent==2);
    let usize fill=built(ir::integer(ref mut p,65,10,77)); let usize init=built(ir::array_init(ref mut p,root,fill,77));
    let usize start=built(ir::integer(ref mut p,0,12,77)); let usize stop=built(ir::integer(ref mut p,if(length==4){4}else if(length==8){8}else{4096},12,77));
    let usize opened=built(ir::slice_open(ref mut p,parent,start,stop,77)); let usize valid=built(ir::slice_utf8(ref mut p,parent,77));
    let usize[1] args=[160+parent]; let usize answer=built(ir::call(ref mut p,0,ref args,77));
    let usize close=built(ir::slice_close(ref mut p,parent,77)); let usize drop=built(ir::array_drop(ref mut p,root,77)); let usize done=built(ir::emit(ref mut p,8,answer,0,77));
    let usize finish=p.count; let usize limit=p.registers; p.ends[1]=finish; p.register_ends[1]=limit;
    assert(verifier::inspect(ref p).is_ok && verifier::verify(ref p).is_ok); return p;
}
fn usize instruction(ref ir::Program p,u8 op,usize site,usize function) {
    var usize pc=p.starts[function]; while(pc<p.ends[function]) {
        if(p.code[pc*8]==op && (op==9 || p.code[pc*8+if(op==55 || op==57 || op==58){2}else{1}] as usize==site)) { return pc; } pc+=1;
    } assert(false); return 0;
}
fn bytes::Buffer backing(usize size) { return switch(arrays::prepare(size)) { case .ok(v):{v} case .err(_):{assert(false);bytes::empty()} }; }
fn void initialize(ref ir::Program p,ref mut calls::Frames frames,ref mut loans::State loan,ref mut arrays::State state,ref mut bytes::Buffer buffer,ref mut i64[] r) {
    var usize pc=0; while(pc<p.count) { if(p.code[pc*8]==1) { r[p.code[pc*8+1] as usize]=p.constants[p.code[pc*8+2] as usize]; } pc+=1; }
    let layouts::Array shape=switch(layouts::scalar(10,p.arrays.lengths[0])) { case .ok(v):{v} case .err(_):{assert(false);layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4}} };
    { let ref mut u8[] data=bytes::view_mut(buffer); let owners::Token created=switch(owners::create(ref shape,65,data,ref mut state.owners)) { case .ok(v):{v} case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}} }; state.tokens[0]=created; }
    assert(built(dispatch::step(p,1,instruction(p,54,2,1),0,frames,loan,state,buffer,r,65537))==0);
    let usize retained=built(calls::enter(p,instruction(p,9,0,1),0,frames,loan,state,buffer,131074)); assert(retained==0);
}
fn void same(ref calls::Frames frame,ref calls::Frames old_frame,ref loans::State loan,ref loans::State old_loan,ref arrays::State state,ref arrays::State old_state) {
    var usize i=0; while(i<256) { assert(frame.origins[i].slot==old_frame.origins[i].slot && frame.origins[i].generation==old_frame.origins[i].generation); i+=1; }
    i=0; while(i<512) { assert(loan.tickets[i].slot==old_loan.tickets[i].slot && loan.tickets[i].generation==old_loan.tickets[i].generation && state.tokens[i].slot==old_state.tokens[i].slot && state.tokens[i].generation==old_state.tokens[i].generation); i+=1; }
    assert(state.owners.depth==old_state.owners.depth && state.owners.arena.used==old_state.owners.arena.used && state.owners.arena.limit==old_state.owners.arena.limit);
    i=0; while(i<16) {
        let slices::Slot a=loan.pool.slots[i]; let slices::Slot b=old_loan.pool.slots[i];
        assert(a.live==b.live && a.generation==b.generation && a.view.root.slot==b.view.root.slot && a.view.root.generation==b.view.root.generation && a.view.element==b.view.element && a.view.length==b.view.length && a.view.start==b.view.start && a.view.end==b.view.end && a.lease.root.slot==b.lease.root.slot && a.lease.root.generation==b.lease.root.generation && a.lease.generation==b.lease.generation);
        let owners::Owner x=state.owners.slots[i]; let owners::Owner y=old_state.owners.slots[i];
        assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment && state.owners.order[i]==old_state.owners.order[i]); i+=1;
    }
}
fn void rejected(ref ir::Program p,usize function,usize pc,usize frame,ref mut calls::Frames f,ref mut loans::State l,ref mut arrays::State a,ref bytes::Buffer buffer,ref mut i64[] r,usize fuel,u8 kind) {
    let calls::Frames oldf=calls::Frames{.origins=f.origins}; let loans::State oldl=loans::State{.pool=slices::Pool{.slots=l.pool.slots},.tickets=l.tickets};
    let arrays::State olda=arrays::State{.owners=owners::Table{.slots=a.owners.slots,.order=a.owners.order,.depth=a.owners.depth,.arena=a.owners.arena},.tokens=a.tokens};
    var i64[128] oldr=[0;128]; var usize i=0; while(i<r.len) { oldr[i]=r[i]; i+=1; }
    assert(switch(dispatch::step(p,function,pc,frame,f,l,a,buffer,r,fuel)) { case .ok(_):{false} case .err(e):{e.kind==kind && e.offset==77} });
    same(f,ref oldf,l,ref oldl,a,ref olda); i=0; while(i<r.len) { assert(r[i]==oldr[i]); i+=1; }
}
fn usize step(ref ir::Program p,u8 op,usize site,ref calls::Frames f,ref mut loans::State l,ref mut arrays::State a,ref bytes::Buffer b,ref mut i64[] r,usize fuel) {
    return built(dispatch::step(p,0,instruction(p,op,site,0),1,f,l,a,b,r,fuel));
}

@test
fn void dynamic_origin_lengths_exact_prices_and_children_after_formal_close_dispatch() {
    let usize[3] sizes=[4,8,4096]; var usize i=0; while(i<3) {
        let ir::Program p=program(sizes[i]); var calls::Frames f=calls::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(sizes[i]); var bytes::Buffer b=backing(sizes[i]); var i64[128] r=[0;128];
        initialize(ref p,ref mut f,ref mut l,ref mut a,ref mut b,ref mut r);
        assert(built(dispatch::step(ref p,1,instruction(ref p,55,2,1),0,ref f,ref mut l,ref mut a,ref b,ref mut r,4097+4*sizes[i]))==0);
        assert(step(ref p,59,1,ref f,ref mut l,ref mut a,ref b,ref mut r,65537)==0);
        assert(step(ref p,56,0,ref f,ref mut l,ref mut a,ref b,ref mut r,4097)==0);
        assert(step(ref p,57,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4097)==0); assert(r[p.code[instruction(ref p,57,1,0)*8+1] as usize]==2);
        assert(step(ref p,55,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4097+4*sizes[i])==0); assert(r[p.code[instruction(ref p,55,1,0)*8+1] as usize]==1);
        assert(step(ref p,58,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4131)==0); assert(r[p.code[instruction(ref p,58,1,0)*8+1] as usize]==65);
        assert(step(ref p,56,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4097)==0);
        assert(built(calls::leave(ref p,0,1,ref mut f,ref mut l,ref mut a,ref b,77))==0 && a.owners.slots[0].reading);
        assert(switch(loans::finish(ref mut l,ref mut a,ref b,.ok(42))) { case .ok(v):{v==42} case .err(_):{false} }); assert(!a.owners.slots[0].reading);
        assert(switch(vm::run_with_array_limit(ref p,0,0)) { case .err(e):{e.kind==8} case .ok(_):{false} }); i+=1;
    }
}

@test
fn void fuel_bounds_backing_and_stale_provenance_fail_without_ticket_or_register_publication() {
    let ir::Program p=program(4); var calls::Frames f=calls::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(4); var bytes::Buffer b=backing(4); var i64[128] r=[99;128]; initialize(ref p,ref mut f,ref mut l,ref mut a,ref mut b,ref mut r);
    let usize sub=instruction(ref p,59,1,0); let usize read=instruction(ref p,58,1,0); let usize scan=instruction(ref p,55,1,0); let usize len=instruction(ref p,57,1,0);
    rejected(ref p,0,sub,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,65536,8);
    r[p.code[sub*8+4] as usize]=5; rejected(ref p,0,sub,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,65537,14); r[p.code[sub*8+4] as usize]=2;
    assert(step(ref p,59,1,ref f,ref mut l,ref mut a,ref b,ref mut r,65537)==0);
    rejected(ref p,0,sub,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,65537,5);
    rejected(ref p,0,read,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4130,8);
    r[p.code[read*8+3] as usize]=-1; rejected(ref p,0,read,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4131,14); r[p.code[read*8+3] as usize]=0;
    let bytes::Buffer missing=bytes::empty(); rejected(ref p,0,len,1,ref mut f,ref mut l,ref mut a,ref missing,ref mut r,4096,8); rejected(ref p,0,len,1,ref mut f,ref mut l,ref mut a,ref missing,ref mut r,4097,5);
    // After base admission, scan Fuel precedes ticket resolution and any bytes.
    l.tickets[17].generation+=1; rejected(ref p,0,scan,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4112,8); rejected(ref p,0,scan,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4113,5); l.tickets[17].generation-=1;
    f.origins[8].generation+=1; rejected(ref p,0,len,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4097,5); f.origins[8].generation-=1;
    a.owners.slots[0].read_generation+=1; rejected(ref p,0,len,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4097,5); a.owners.slots[0].read_generation-=1;
    rejected(ref p,1,len,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4097,5); rejected(ref p,0,len,32,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4097,5);
}

@test
fn void empty_subranges_utf8_values_and_root_shape_mismatches_use_actual_backing() {
    let ir::Program p=program(4); var calls::Frames f=calls::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(4); var bytes::Buffer b=backing(4); var i64[128] r=[0;128]; initialize(ref p,ref mut f,ref mut l,ref mut a,ref mut b,ref mut r);
    let usize sub=instruction(ref p,59,1,0); let usize read=instruction(ref p,58,1,0); let usize utf=instruction(ref p,55,1,0); let usize len=instruction(ref p,57,1,0);
    r[p.code[sub*8+3] as usize]=4; r[p.code[sub*8+4] as usize]=4;
    assert(step(ref p,59,1,ref f,ref mut l,ref mut a,ref b,ref mut r,65537)==0); assert(step(ref p,57,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4097)==0 && r[p.code[len*8+1] as usize]==0);
    assert(step(ref p,55,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4113)==0 && r[p.code[utf*8+1] as usize]==1);
    rejected(ref p,0,read,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4131,14);
    assert(step(ref p,56,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4097)==0);
    r[p.code[sub*8+3] as usize]=0; r[p.code[sub*8+4] as usize]=2;
    assert(step(ref p,59,1,ref f,ref mut l,ref mut a,ref b,ref mut r,65537)==0);
    { let ref mut u8[] data=bytes::view_mut(ref mut b); data[0]=255; }
    assert(step(ref p,55,1,ref f,ref mut l,ref mut a,ref b,ref mut r,4113)==0 && r[p.code[utf*8+1] as usize]==0);
    let usize slot=l.tickets[17].slot; l.pool.slots[slot].view.length=3; rejected(ref p,0,len,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4097,5); l.pool.slots[slot].view.length=4;
    // A valid but different runtime owner cannot authenticate the old ticket.
    let owners::Token old=f.origins[8]; f.origins[8]=owners::Token{.slot=1,.generation=1}; rejected(ref p,0,len,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,4097,5); f.origins[8]=old;
}

@test
fn void malformed_rootless_operands_and_partial_pool_capacity_preserve_existing_sessions() {
    let ir::Program p=program(4); var calls::Frames f=calls::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(4); var bytes::Buffer b=backing(4); var i64[128] r=[0;128]; initialize(ref p,ref mut f,ref mut l,ref mut a,ref mut b,ref mut r);
    let usize sub=instruction(ref p,59,1,0); var usize i=0; while(i<8) {
        var ir::Program bad=p;
        if(i==0) { bad.code[sub*8]=54; } else if(i==1) { bad.code[sub*8+2]=2; }
        else if(i==2) { bad.code[sub*8+4]=128; } else if(i==3) { bad.code[sub*8+5]=1; }
        else if(i==4) { bad.slice_functions[1]=2; } else if(i==5) { bad.slice_origins[1]=0; }
        else if(i==6) { bad.code[sub*8+1]=0; } else { bad.code[sub*8+3]=128; }
        rejected(ref bad,0,sub,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,65537,5); i+=1;
    }
    let slices::Ticket parent=l.tickets[16]; i=2; while(i<16) {
        let slices::Ticket extra=switch(slices::subslice(ref mut l.pool,parent,ref a.owners,0,0,4)) { case .ok(v):{v} case .err(_):{assert(false);parent} }; i+=1;
    }
    rejected(ref p,0,sub,1,ref mut f,ref mut l,ref mut a,ref b,ref mut r,65537,13);
}
