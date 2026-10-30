module tests::m2::slice_sub_vm;
import ir as ir;
import verifier as verifier;
import vm as vm;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn void kind(Result<usize,errors::Error> r,u8 expected) { assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind==expected && e.offset==77 } }); }
fn ir::Program program() {
    var ir::Program p=ir::empty(); let usize root=built(ir::array(ref mut p,10,4,false,0));
    let usize parent=built(ir::slice(ref mut p,root,0)); let usize child=built(ir::slice(ref mut p,root,0));
    let usize fill=built(ir::integer(ref mut p,42,10,0)); let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,1,12,0)); let usize hi=built(ir::integer(ref mut p,4,12,0));
    let usize start=built(ir::integer(ref mut p,0,12,0)); let usize end=built(ir::integer(ref mut p,2,12,0));
    let usize index=built(ir::integer(ref mut p,0,12,0)); let usize open=built(ir::slice_open(ref mut p,parent,lo,hi,77));
    let usize sub=built(ir::slice_sub(ref mut p,child,parent,start,end,77));
    let usize close_parent=built(ir::slice_close(ref mut p,parent,77)); let usize read=built(ir::slice_read(ref mut p,child,index,77));
    let usize close=built(ir::slice_close(ref mut p,child,77)); let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize yes=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,yes,0,0));
    let usize count=p.count; let usize registers=p.registers;
    p.function_count=1; p.ends[0]=count; p.register_ends[0]=registers; p.return_types[0]=1; return p;
}

@test
fn void verifier_checks_parent_liveness_origin_bounds_registers_and_canonical_operands() {
    let ir::Program p=program(); assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)) { case .ok(v): { v==42 } case .err(_): { false } });
    var usize i=0; while(i<12) {
        var ir::Program bad=p;
        if(i==0) { bad.code[66]=16; } else if(i==1) { bad.code[65]=0; }
        else if(i==2) { bad.code[67]=127; } else if(i==3) { bad.code[68]=127; }
        else if(i==4) { bad.code[69]=1; } else if(i==5) { bad.types[3]=1; }
        else if(i==6) { bad.slots[4]=true; } else if(i==7) { bad.code[67]=6; }
        else if(i==8) { bad.code[66]=1; } else if(i==9) { bad.slice_roots[1]=2; }
        else if(i==10) { bad.code[56]=56; bad.code[58]=0; bad.code[59]=0; }
        else { bad.code[72]=37; }
        assert(!verifier::verify(ref bad).is_ok); i+=1;
    }
    var ir::Program bad=p; assert(!ir::slice_sub(ref mut bad,0,0,3,4,0).is_ok);
    assert(!ir::slice_sub(ref mut bad,1,16,3,4,0).is_ok && !ir::slice_sub(ref mut bad,1,0,128,4,0).is_ok);
    bad.count=256; assert(!ir::slice_sub(ref mut bad,1,0,3,4,0).is_ok);
}

@test
fn void publication_is_prepaid_and_atomic_with_relative_bounds_and_stale_state() {
    let ir::Program p=program(); var arrays::State state=arrays::empty(4); var loans::State loan=loans::empty();
    var bytes::Buffer data=switch(arrays::prepare(4)) { case .ok(v): { v } case .err(_): { assert(false); bytes::empty() } };
    var i64[8] r=[42,1,4,0,2,0,99,42];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),5);
    let usize open=built(loans::step(ref p,7,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    let slices::Ticket parent=loan.tickets[0];
    kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65536),8);
    r[4]=4; kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),14);
    r[4]=-1; kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),14);
    r[3]=2; r[4]=1; kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),14); r[3]=0; r[4]=2;
    kind(loans::step(ref p,8,1,ref mut loan,ref mut state,ref data,ref mut r[..],65537),5);
    let bytes::Buffer missing=bytes::empty(); kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref missing,ref mut r[..],65537),5);
    let slices::Slot saved=loan.pool.slots[parent.slot]; var slices::Slot bad=saved; bad.generation+=1; loan.pool.slots[parent.slot]=bad;
    kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),5); loan.pool.slots[parent.slot]=saved;
    let usize generation=state.owners.slots[0].read_generation; state.owners.slots[0].read_generation+=1;
    kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),5); state.owners.slots[0].read_generation=generation;
    assert(loan.tickets[1].generation==0 && !loan.pool.slots[1].live && r[6]==99 && state.owners.slots[0].reading);
    assert(built(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537))==0);
    assert(loan.pool.slots[1].view.start==1 && loan.pool.slots[1].view.end==3);
    kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),5);
    let usize close_parent=built(loans::step(ref p,9,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097));
    assert(state.owners.slots[0].reading);
    let usize read=built(loans::step(ref p,10,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131)); assert(r[6]==42);
    let usize close=built(loans::step(ref p,11,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097)); assert(!state.owners.slots[0].reading);
}

@test
fn void empty_children_capacity_and_abort_cleanup_preserve_shared_sessions() {
    let ir::Program p=program(); var arrays::State state=arrays::empty(4); var loans::State loan=loans::empty();
    var bytes::Buffer data=switch(arrays::prepare(4)) { case .ok(v): { v } case .err(_): { assert(false); bytes::empty() } };
    var i64[8] r=[42,1,4,3,3,0,99,42];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    let usize open=built(loans::step(ref p,7,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    let usize sub=built(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    kind(loans::step(ref p,10,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),14);
    let usize close=built(loans::step(ref p,11,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097));
    let slices::Ticket parent=loan.tickets[0]; var usize i=1;
    while(i<16) { let slices::Ticket child=switch(slices::subslice(ref mut loan.pool,parent,ref state.owners,0,0,4)) { case .ok(v): { v } case .err(_): { assert(false); parent } }; i+=1; }
    kind(loans::step(ref p,8,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),13);
    assert(loan.tickets[1].generation==0 && state.owners.slots[0].reading && r[6]==99);
    assert(switch(loans::finish(ref mut loan,ref mut state,ref data,.err(errors::make(14,77)))) { case .ok(_): { false } case .err(e): { e.kind==14 && e.offset==77 } });
    assert(!state.owners.slots[0].reading && loan.tickets[0].generation==0);
}
