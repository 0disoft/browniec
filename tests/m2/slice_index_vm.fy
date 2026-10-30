module tests::m2::slice_index_vm;
import ir as ir;
import verifier as verifier;
import vm as vm;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import cells as cells;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn void kind(Result<usize,errors::Error> r,u8 expected) { assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind==expected && e.offset==77 } }); }
fn ir::Program program(u8 tag,i64 filler) {
    var ir::Program p=ir::empty(); let usize root=built(ir::array(ref mut p,tag,4,false,0)); let usize site=built(ir::slice(ref mut p,root,0));
    let usize fill=built(if(tag==2) { ir::boolean(ref mut p,true,0) } else { ir::integer(ref mut p,filler,tag,0) }); let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,1,12,0)); let usize hi=built(ir::integer(ref mut p,3,12,0));
    let usize index=built(ir::integer(ref mut p,0,12,0)); let usize open=built(ir::slice_open(ref mut p,site,lo,hi,77));
    let usize read=built(ir::slice_read(ref mut p,site,index,77)); let usize close=built(ir::slice_close(ref mut p,site,77));
    let usize drop=built(ir::array_drop(ref mut p,root,0)); let usize yes=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,yes,0,0));
    let usize end=p.count; let usize registers=p.registers;
    p.function_count=1; p.ends[0]=end; p.register_ends[0]=registers; p.return_types[0]=1; return p;
}

@test
fn void independent_verifier_requires_live_origins_and_fresh_typed_local_registers() {
    let ir::Program p=program(10,65); assert(verifier::verify(ref p).is_ok);
    var usize i=0; while(i<13) {
        var ir::Program bad=p;
        if(i==0) { bad.types[4]=12; } else if(i==1) { bad.slots[4]=true; }
        else if(i==2) { bad.code[50]=16; } else if(i==3) { bad.code[51]=127; }
        else if(i==4) { bad.code[52]=1; } else if(i==5) { bad.code[49]=0; }
        else if(i==6) { bad.code[51]=4; } else if(i==7) { bad.types[3]=1; }
        else if(i==8) { bad.slots[3]=true; } else if(i==9) { bad.array_functions[0]=1; }
        else if(i==10) { bad.code[48]=56; bad.code[49]=0; bad.code[50]=0; bad.code[51]=0; bad.code[56]=58; bad.code[57]=4; bad.code[59]=3; }
        else if(i==11) { bad.slice_roots[0]=0; } else { bad.code[50]=1; }
        assert(!verifier::verify(ref bad).is_ok); i+=1;
    }
}

@test
fn void checked_reads_prepay_fuel_and_preserve_output_and_loan_on_every_failure() {
    let ir::Program p=program(10,65); var arrays::State state=arrays::empty(4); var loans::State loan=loans::empty();
    var bytes::Buffer data=switch(arrays::prepare(4)) { case .ok(v): { v } case .err(_): { assert(false); bytes::empty() } };
    var i64[6] r=[65,1,3,0,99,42];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),5);
    let usize open=built(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4130),8); assert(r[4]==99);
    assert(built(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131))==0 && r[4]==65);
    r[4]=99; r[3]=2; kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),14);
    r[3]=-1; kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),14); r[3]=0;
    kind(loans::step(ref p,6,1,ref mut loan,ref mut state,ref data,ref mut r[..],4131),5);
    let bytes::Buffer missing=bytes::empty(); kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref missing,ref mut r[..],4131),5);
    let slices::Ticket ticket=loan.tickets[0]; let slices::Slot saved=loan.pool.slots[ticket.slot];
    var slices::Slot corrupt=saved; corrupt.generation+=1; loan.pool.slots[ticket.slot]=corrupt;
    kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),5); loan.pool.slots[ticket.slot]=saved;
    let usize generation=state.owners.slots[0].read_generation; state.owners.slots[0].read_generation+=1;
    kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),5); state.owners.slots[0].read_generation=generation;
    var ir::Program bad=p; bad.arrays.lengths[0]=3; kind(loans::step(ref bad,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),5);
    assert(r[4]==99 && r[5]==42 && state.owners.slots[0].reading && loan.tickets[0].generation==ticket.generation);
    let usize close=built(loans::step(ref p,7,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097));
    kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),5);
    r[1]=3; let usize empty=built(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    kind(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4131),14);
    let i64 done=switch(loans::finish(ref mut loan,ref mut state,ref data,.ok(42))) { case .ok(v): { v } case .err(_): { 0 } };
    assert(done==42 && !state.owners.slots[0].reading && r[4]==99);
}

@test
fn void element_types_builder_limits_and_error_cleanup_use_existing_paths() {
    let u8[6] tags=[1,2,9,10,11,12]; var usize i=0;
    while(i<tags.len) {
        let ir::Program p=program(tags[i],1); assert(verifier::verify(ref p).is_ok);
        assert(switch(vm::run_with_array_limit(ref p,1000000,64)) { case .ok(v): { v==42 } case .err(_): { false } });
        i+=1;
    }
    var ir::Program p=program(10,65); p.constants[3]=2;
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)) { case .ok(_): { false } case .err(e): { e.kind==14 && e.offset==77 } });
    assert(!ir::slice_read(ref mut p,16,3,0).is_ok && !ir::slice_read(ref mut p,0,128,0).is_ok);
    p.types[3]=1; assert(!ir::slice_read(ref mut p,0,3,0).is_ok); p.types[3]=12;
    let usize count=p.count; p.registers=128; assert(!ir::slice_read(ref mut p,0,3,0).is_ok && p.count==count);
    p=program(10,65); p.slice_roots[0]=255; p.arrays.count=255; assert(!ir::slice_read(ref mut p,0,3,0).is_ok);
}
