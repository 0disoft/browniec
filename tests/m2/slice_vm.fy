module tests::m2::slice_vm;
import ir as ir;
import vm as vm;
import verifier as verifier;
import slice_vm as loans;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn void finish(ref mut ir::Program p) {
    let usize count=p.count; let usize registers=p.registers;
    p.function_count=1; p.entry=0; p.ends[0]=count; p.register_ends[0]=registers; p.return_types[0]=1;
}
fn void invalid(ref ir::Program p) { assert(switch(verifier::verify(p)) { case .ok(_): { false } case .err(e): { e.kind==5 } }); }
fn void kind(Result<usize,errors::Error> r,u8 expected) { assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind==expected && e.offset==77 } }); }
fn bytes::Buffer backing(usize n) { return switch(arrays::prepare(n)) { case .ok(v): { v } case .err(_): { assert(false); bytes::empty() } }; }
fn ir::Program program(i64 start,i64 end) {
    var ir::Program p=ir::empty(); let usize root=built(ir::array(ref mut p,10,4,true,0)); let usize site=built(ir::slice(ref mut p,root,0));
    let usize fill=built(ir::integer(ref mut p,65,10,0)); let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,start,12,0)); let usize hi=built(ir::integer(ref mut p,end,12,0));
    let usize open=built(ir::slice_open(ref mut p,site,lo,hi,77)); let usize valid=built(ir::slice_utf8(ref mut p,site,77));
    let usize close=built(ir::slice_close(ref mut p,site,77)); let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize yes=built(ir::literal(ref mut p,42,0)); let usize no=built(ir::literal(ref mut p,0,0));
    let usize target=p.count+2; let usize branch=built(ir::raw(ref mut p,20,0,valid,target,0));
    let usize good=built(ir::emit(ref mut p,8,yes,0,0)); let usize bad=built(ir::emit(ref mut p,8,no,0,0));
    finish(ref mut p); return p;
}
fn void run(ref ir::Program p,i64 expected) { assert(switch(vm::run_with_array_limit(p,2000000,16)) { case .ok(v): { v==expected } case .err(_): { false } }); }
fn void empty_tickets(ref loans::State state) { var usize i=0; while(i<512) { assert(state.tickets[i].generation==0); i+=1; } }

@test
fn void verified_slice_scan_runs_with_runtime_bounds_and_prepaid_fuel() {
    let ir::Program p=program(0,4); let usize checked=built(verifier::verify(ref p)); run(ref p,42);
    let ir::Program empty=program(4,4); run(ref empty,42);
    assert(switch(vm::run_with_array_limit(ref p,73870,4)) { case .ok(v): { v==42 } case .err(_): { false } });
    assert(switch(vm::run_with_array_limit(ref p,70000,4)) { case .ok(_): { false } case .err(e): { e.kind==8 && e.offset==77 } });
    let ir::Program invalid_bounds=program(-1,4);
    assert(switch(vm::run_with_array_limit(ref invalid_bounds,2000000,4)) { case .ok(_): { false } case .err(e): { e.kind==14 && e.offset==77 } });
    var arrays::State state=arrays::empty(4); var loans::State loan=loans::empty(); var bytes::Buffer data=backing(4); var i64[6] r=[65,0,4,99,0,0];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    kind(loans::step(ref p,4,0,ref mut loan,ref mut state,ref data,ref mut r[..],65536),8);
    assert(!state.owners.slots[0].reading && loan.tickets[0].generation==0);
    assert(built(loans::step(ref p,4,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537))==0);
    kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4112),8); assert(r[3]==99);
    assert(built(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4113))==0 && r[3]==1);
    kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4096),8); assert(state.owners.slots[0].reading);
    assert(built(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097))==0 && !state.owners.slots[0].reading);
}

@test
fn void independent_verifier_rejects_forged_origins_operands_and_use_after_close() {
    let ir::Program base=program(0,4); var usize i=0;
    while(i<13) {
        var ir::Program p=base;
        if(i==0) { p.slice_roots[0]=17; } else if(i==1) { p.slice_roots[0]=0; }
        else if(i==2) { p.code[33]=16; } else if(i==3) { p.code[34]=0; }
        else if(i==4) { p.slots[1]=true; } else if(i==5) { p.code[36]=1; }
        else if(i==6) { p.code[43]=1; } else if(i==7) { p.types[3]=1; }
        else if(i==8) { p.code[48]=55; } else if(i==9) { p.code[32]=56; }
        else if(i==10) { p.array_functions[0]=1; } else if(i==11) { p.code[50]=1; }
        else { p.code[40]=57; }
        invalid(ref p); i+=1;
    }
    var ir::Program high=ir::empty(); let usize root=built(ir::array(ref mut high,10,1,false,0));
    i=0; while(i<16) { let usize site=built(ir::slice(ref mut high,root,0)); assert(site==i); i+=1; }
    let usize fill=built(ir::integer(ref mut high,65,10,0)); let usize init=built(ir::array_init(ref mut high,root,fill,0));
    let usize lo=built(ir::integer(ref mut high,0,12,0)); let usize hi=built(ir::integer(ref mut high,1,12,0));
    i=0; while(i<16) { let usize open=built(ir::slice_open(ref mut high,i,lo,hi,0)); i+=1; }
    i=16; while(i>0) { i-=1; let usize close=built(ir::slice_close(ref mut high,i,0)); }
    let usize drop=built(ir::array_drop(ref mut high,root,0)); let usize yes=built(ir::literal(ref mut high,42,0)); let usize ret=built(ir::emit(ref mut high,8,yes,0,0));
    finish(ref mut high); run(ref high,42);
}

fn ir::Program conflicts(u8 op) {
    var ir::Program p=ir::empty(); let usize root=built(ir::array(ref mut p,10,4,true,0)); let usize site=built(ir::slice(ref mut p,root,0));
    let usize fill=built(ir::integer(ref mut p,65,10,0)); let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0)); let usize hi=built(ir::integer(ref mut p,4,12,0));
    let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0));
    if(op==34) { let usize copy=built(ir::array(ref mut p,10,4,false,0)); let usize copied=built(ir::array_copy(ref mut p,copy,root,0)); let usize dropped=built(ir::array_drop(ref mut p,copy,0)); }
    else if(op==54) { let usize again=built(ir::slice_open(ref mut p,site,lo,hi,0)); }
    else { let usize bad=built(ir::raw(ref mut p,op,root,if(op==36){lo}else if(op==40){fill}else{0},if(op==36){fill}else{0},0)); }
    let usize close=built(ir::slice_close(ref mut p,site,0)); let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize yes=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,yes,0,0)); finish(ref mut p); return p;
}
@test
fn void outstanding_slices_block_mutation_release_reopen_and_return_but_allow_copies() {
    let u8[5] ops=[36,37,38,40,54]; var usize i=0; while(i<5) { let ir::Program p=conflicts(ops[i]); invalid(ref p); i+=1; }
    let ir::Program copied=conflicts(34); run(ref copied,42);
    var ir::Program returned=program(0,4); returned.code[48]=8; returned.code[49]=0; returned.code[50]=0; invalid(ref returned);
    var ir::Program escaped=program(0,4); escaped.array_results[0]=1; escaped.code[48]=39; escaped.code[49]=0; escaped.code[50]=0; invalid(ref escaped);
}

fn ir::Program branches(bool balanced) {
    var ir::Program p=ir::empty(); let usize root=built(ir::array(ref mut p,10,1,false,0)); let usize site=built(ir::slice(ref mut p,root,0));
    let usize fill=built(ir::integer(ref mut p,65,10,0)); let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0)); let usize hi=built(ir::integer(ref mut p,1,12,0)); let usize cond=built(ir::boolean(ref mut p,true,0));
    let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0)); let usize branch=built(ir::raw(ref mut p,20,0,cond,9,0));
    let usize close=built(ir::slice_close(ref mut p,site,0)); let usize jump=built(ir::raw(ref mut p,19,0,10,0,0));
    if(balanced) { let usize other=built(ir::slice_close(ref mut p,site,0)); } else { let usize other=built(ir::literal(ref mut p,0,0)); }
    let usize drop=built(ir::array_drop(ref mut p,root,0)); let usize yes=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,yes,0,0)); finish(ref mut p); return p;
}
@test
fn void branch_merges_and_backedges_preserve_exact_slice_live_sets() {
    let ir::Program bad=branches(false); invalid(ref bad); let ir::Program good=branches(true); run(ref good,42);
    var ir::Program loop=branches(true); loop.code[64]=22; loop.code[66]=5; let usize verified=built(verifier::verify(ref loop));
    // Jump to the earlier open while still holding that same slice is rejected.
    loop=branches(true); loop.code[56]=22; loop.code[57]=0; loop.code[58]=5; invalid(ref loop);
}

@test
fn void runtime_rechecks_shape_ticket_frame_padding_and_never_writes_on_failure() {
    let ir::Program p=program(0,4); var arrays::State state=arrays::empty(8); var loans::State loan=loans::empty(); var bytes::Buffer data=backing(8); var i64[6] r=[65,0,4,99,0,0];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    let usize open=built(loans::step(ref p,4,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    kind(loans::step(ref p,4,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537),5);
    kind(loans::step(ref p,5,1,ref mut loan,ref mut state,ref data,ref mut r[..],4113),5);
    kind(loans::step(ref p,5,32,ref mut loan,ref mut state,ref data,ref mut r[..],4113),5);
    var ir::Program bad=p; bad.arrays.lengths[0]=3; kind(loans::step(ref bad,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4113),5);
    bad=p; bad.code[44]=1; kind(loans::step(ref bad,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4113),5);
    let bytes::Buffer missing=bytes::empty(); kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref missing,ref mut r[..],4113),5);
    let slices::Ticket ticket=loan.tickets[0]; let slices::Slot saved=loan.pool.slots[ticket.slot]; var slices::Slot corrupt=saved; corrupt.generation+=1; loan.pool.slots[ticket.slot]=corrupt;
    kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4113),5); loan.pool.slots[ticket.slot]=saved;
    assert(r[3]==99 && state.owners.slots[0].reading && loan.tickets[0].generation==ticket.generation);
    let usize close=built(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097));
    kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4113),5);
}

@test
fn void prepaid_abort_cleanup_drains_all_frames_and_preserves_the_original_error() {
    let ir::Program p=program(0,4); var arrays::State state=arrays::empty(8); var loans::State loan=loans::empty(); var bytes::Buffer data=backing(8); var i64[6] r=[65,0,4,99,0,0];
    var usize frame=0; while(frame<2) { let usize init=built(arrays::execute(33,0,0,0,frame,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0)); let usize open=built(loans::step(ref p,4,frame,ref mut loan,ref mut state,ref data,ref mut r[..],65537)); frame+=1; }
    assert(state.owners.depth==2 && state.owners.slots[0].reading && state.owners.slots[1].reading);
    assert(switch(loans::finish(ref mut loan,ref mut state,ref data,.err(errors::make(7,123)))) { case .ok(_): { false } case .err(e): { e.kind==7 && e.offset==123 } });
    assert(!state.owners.slots[0].reading && !state.owners.slots[1].reading && state.owners.depth==2 && state.owners.arena.used==8); empty_tickets(ref loan);
    assert(owners::write(ref state.owners,state.tokens[0],0,255,bytes::view_mut(ref mut data)).is_ok);
    assert(switch(loans::finish(ref mut loan,ref mut state,ref data,.ok(42))) { case .ok(v): { v==42 } case .err(_): { false } });
    let usize open=built(loans::step(ref p,4,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    let slices::Ticket ticket=loan.tickets[0]; let slices::Slot saved=loan.pool.slots[ticket.slot]; var slices::Slot corrupt=saved; corrupt.view.end=5; loan.pool.slots[ticket.slot]=corrupt;
    assert(switch(loans::finish(ref mut loan,ref mut state,ref data,.err(errors::make(8,77)))) { case .ok(_): { false } case .err(e): { e.kind==14 && e.offset==0 } });
    assert(state.owners.slots[0].reading && loan.tickets[0].generation==ticket.generation); loan.pool.slots[ticket.slot]=saved;
    assert(switch(loans::finish(ref mut loan,ref mut state,ref data,.ok(42))) { case .ok(v): { v==42 } case .err(_): { false } }); empty_tickets(ref loan);
}

@test
fn void native_vm_calls_keep_origins_and_register_partitions_function_local() {
    var ir::Program p=ir::empty(); p.function_count=2; p.return_types[1]=1;
    let usize[1] arguments=[0]; let usize call=built(ir::call(ref mut p,1,ref arguments[..0],0)); let usize ret=built(ir::emit(ref mut p,8,call,0,0));
    let usize main_end=p.count; let usize main_registers=p.registers;
    p.ends[0]=main_end; p.register_ends[0]=main_registers; p.return_types[0]=1;
    p.starts[1]=main_end; p.register_starts[1]=main_registers;
    let usize root=built(ir::array_in(ref mut p,1,10,1,false,0)); let usize site=built(ir::slice(ref mut p,root,0));
    let usize fill=built(ir::integer(ref mut p,65,10,0)); let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0)); let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0)); let usize valid=built(ir::slice_utf8(ref mut p,site,0));
    let usize close=built(ir::slice_close(ref mut p,site,0)); let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize yes=built(ir::literal(ref mut p,42,0)); let usize returned=built(ir::emit(ref mut p,8,yes,0,0));
    let usize helper_end=p.count; let usize helper_registers=p.registers;
    p.ends[1]=helper_end; p.register_ends[1]=helper_registers; p.return_types[1]=1; run(ref p,42);
    p.code[open*8+2]=0; invalid(ref p);
}

@test
fn void builders_and_global_slice_quota_fail_before_publishing_any_new_lease() {
    var ir::Program p=program(0,4); let usize count=p.count; let usize registers=p.registers;
    assert(!ir::slice(ref mut p,16,0).is_ok && !ir::slice_open(ref mut p,16,1,2,0).is_ok && !ir::slice_open(ref mut p,0,0,2,0).is_ok);
    assert(!ir::slice_utf8(ref mut p,16,0).is_ok && !ir::slice_close(ref mut p,16,0).is_ok && p.count==count && p.registers==registers);
    var ir::Program forged=p; forged.registers=200;
    assert(!ir::slice_open(ref mut forged,0,128,2,0).is_ok);
    forged=p; forged.slice_roots[0]=255; forged.arrays.count=255;
    assert(!ir::slice_open(ref mut forged,0,1,2,0).is_ok && !ir::slice_utf8(ref mut forged,0,0).is_ok);
    var usize i=1; while(i<16) { let usize site=built(ir::slice(ref mut p,0,0)); i+=1; } assert(!ir::slice(ref mut p,0,0).is_ok);
    var arrays::State state=arrays::empty(8); var loans::State loan=loans::empty(); var bytes::Buffer data=backing(8); var i64[6] r=[65,0,4,99,0,0];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    let usize other=built(arrays::execute(33,0,0,0,1,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    let u8[16] ids=[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];
    i=0; while(i<16) { p.code[33]=ids[i]; let usize open=built(loans::step(ref p,4,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537)); i+=1; }
    p.code[33]=0; kind(loans::step(ref p,4,1,ref mut loan,ref mut state,ref data,ref mut r[..],65537),13);
    assert(!state.owners.slots[1].reading && loan.tickets[16].generation==0);
    assert(switch(loans::finish(ref mut loan,ref mut state,ref data,.ok(42))) { case .ok(v): { v==42 } case .err(_): { false } }); empty_tickets(ref loan);
}
