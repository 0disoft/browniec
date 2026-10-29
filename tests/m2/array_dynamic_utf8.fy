module tests::m2::array_dynamic_utf8;
import ir as ir;
import vm as vm;
import verifier as verifier;
import array_vm as arrays;
import array_range_vm as ranges;
import array_owners as owners;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p){
    let usize end=p.count;let usize registers=p.registers;
    p.function_count=1;p.entry=0;p.starts[0]=0;p.ends[0]=end;p.register_starts[0]=0;p.register_ends[0]=registers;p.return_types[0]=1;
}
fn void result(ref ir::Program p,usize fuel,usize limit,i64 expected){assert(switch(vm::run_with_array_limit(p,fuel,limit)){
    case .ok(v):{v==expected}case .err(_):{false}});}
fn void invalid(ref ir::Program p){assert(switch(verifier::verify(p)){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void failed(Result<usize,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void same(ref owners::Table a,ref owners::Table b,ref u8[] data,ref u8[] saved){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.live==y.live && x.occupied==y.occupied);
        assert(x.reading==y.reading && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.record==y.record && x.alignment==y.alignment);i+=1;}
    assert(data.len==saved.len);i=0;while(i<data.len){assert(data[i]==saved[i]);i+=1;}
}


fn ir::Program program(usize n,i64 fill,i64 start,i64 end) {
    var ir::Program p=ir::empty();let usize id=built(ir::array(ref mut p,10,n,true,0));
    let usize value=built(ir::integer(ref mut p,fill,10,0));let usize init=built(ir::array_init(ref mut p,id,value,0));
    let usize first=built(ir::integer(ref mut p,start,12,0));let usize last=built(ir::integer(ref mut p,end,12,0));
    let usize valid=built(ir::array_dynamic_utf8(ref mut p,id,first,last,77));
    let usize drop=built(ir::array_drop(ref mut p,id,0));
    let usize yes=built(ir::literal(ref mut p,42,0));let usize no=built(ir::literal(ref mut p,0,0));
    let usize target=p.count+2;let usize branch=built(ir::raw(ref mut p,20,0,valid,target,0));
    let usize good=built(ir::emit(ref mut p,8,yes,0,0));let usize bad=built(ir::emit(ref mut p,8,no,0,0));
    finish(ref mut p);return p;
}
fn bytes::Buffer backing(usize n) {return switch(arrays::prepare(n)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};}
fn void kind(Result<usize,errors::Error> r,u8 expected) {assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==expected && e.offset==77}});}

@test
fn void endpoint_cells_select_multibyte_boundaries_without_changing_the_source() {
    let ir::Program p=program(8,0,1,5);var arrays::State state=arrays::empty(8);var bytes::Buffer data=backing(8);
    var i64[6] registers=[0,1,5,99,92,93];
    let usize init=built(arrays::execute(33,0,0,0,2,ref p.arrays,ref mut state,ref mut data,ref mut registers[..],0));
    let u8[8] saved=[255,240,159,141,171,0,65,255];
    {let ref mut u8[] b=bytes::view_mut(ref mut data);var usize i=0;while(i<8){b[i]=saved[i];i+=1;}}
    let owners::Table before=state.owners;
    let i64[12] bounds=[1,5,0,8,1,4,2,5,5,7,8,8];var usize c=0;
    while(c<6){registers[1]=bounds[c*2];registers[2]=bounds[c*2+1];
        assert(built(ranges::step(ref p,4,2,ref state,ref data,ref mut registers[..],97))==0);
        assert(registers[3]==if(c==0 || c>=4){1}else{0});
        assert(registers[1]==bounds[c*2] && registers[2]==bounds[c*2+1] && registers[4]==92 && registers[5]==93);
        same(ref state.owners,ref before,bytes::view(ref data),ref saved);c+=1;
    }
}

@test
fn void vm_prepays_root_length_for_empty_partial_invalid_and_maximum_ranges() {
    let usize[3] lengths=[1,4,4096];let i64[3] ends=[1,4,4096];var usize i=0;
    while(i<3){let usize n=lengths[i];let usize fuel=180+6*n;
        let ir::Program full=program(n,65,0,ends[i]);let ir::Program empty=program(n,255,ends[i],ends[i]);
        assert(verifier::verify(ref full).is_ok && verifier::verify(ref empty).is_ok);
        result(ref full,fuel,n,42);result(ref empty,fuel,n,42);
        assert(switch(vm::run_with_array_limit(ref full,fuel-1,n)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(vm::run_with_array_limit(ref empty,126+6*n,n)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});
        i+=1;
    }
    let ir::Program partial=program(4,255,1,3);result(ref partial,204,4,0);
    let ir::Program reversed=program(4,65,3,1);let ir::Program outside=program(4,65,0,5);let ir::Program maximum=program(4,65,0,-1);
    assert(verifier::verify(ref reversed).is_ok && verifier::verify(ref outside).is_ok && verifier::verify(ref maximum).is_ok);
    assert(switch(vm::run_with_array_limit(ref reversed,204,4)){case .ok(_):{false}case .err(e):{e.kind==14 && e.offset==77}});
    assert(switch(vm::run_with_array_limit(ref outside,204,4)){case .ok(_):{false}case .err(e):{e.kind==14 && e.offset==77}});
    assert(switch(vm::run_with_array_limit(ref maximum,204,4)){case .ok(_):{false}case .err(e):{e.kind==14 && e.offset==77}});
}

@test
fn void independent_verifier_checks_defined_usize_inputs_bool_destination_and_live_root() {
    let ir::Program baseline=program(4,65,1,3);var usize i=0;
    while(i<14){var ir::Program p=baseline;
        if(i==0){p.types[1]=1;}else if(i==1){p.types[2]=10;}else if(i==2){p.types[3]=1;}
        else if(i==3){p.slots[1]=true;}else if(i==4){p.slots[2]=true;}else if(i==5){p.slots[3]=true;}
        else if(i==6){p.code[35]=128;}else if(i==7){p.code[36]=128;}else if(i==8){p.code[37]=1;}
        else if(i==9){p.code[38]=1;}else if(i==10){p.code[39]=1;}else if(i==11){p.code[33]=1;}
        else if(i==12){p.code[34]=16;}else{p.code[32]=54;}
        invalid(ref p);i+=1;
    }
    var ir::Program undefined=baseline;undefined.registers=7;undefined.register_ends[0]=7;undefined.types[6]=12;undefined.code[35]=6;invalid(ref undefined);
    var ir::Program dead=baseline;dead.code[32]=37;dead.code[33]=0;dead.code[34]=0;dead.code[35]=0;dead.code[36]=0;
    dead.code[40]=53;dead.code[41]=3;dead.code[42]=0;dead.code[43]=1;dead.code[44]=2;invalid(ref dead);
}

@test
fn void runtime_errors_and_fuel_gate_leave_destination_owners_and_payload_untouched() {
    let ir::Program p=program(4,65,1,3);var arrays::State state=arrays::empty(4);var bytes::Buffer data=backing(4);
    var i64[6] registers=[65,3,1,99,92,93];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut registers[..],0));
    let owners::Table before=state.owners;let u8[4] saved=[65;4];
    kind(ranges::step(ref p,4,0,ref state,ref data,ref mut registers[..],80),8);
    kind(ranges::step(ref p,4,0,ref state,ref data,ref mut registers[..],81),14);
    registers[1]=-1;registers[2]=4;kind(ranges::step(ref p,4,0,ref state,ref data,ref mut registers[..],81),14);
    registers[1]=0;registers[2]=-9223372036854775808;kind(ranges::step(ref p,4,0,ref state,ref data,ref mut registers[..],81),14);
    registers[1]=1;registers[2]=3;
    var ir::Program bad=p;bad.code[35]=6;kind(ranges::step(ref bad,4,0,ref state,ref data,ref mut registers[..],81),5);
    bad=p;bad.code[37]=1;kind(ranges::step(ref bad,4,0,ref state,ref data,ref mut registers[..],81),5);
    kind(ranges::step(ref p,4,32,ref state,ref data,ref mut registers[..],81),5);
    kind(ranges::step(ref p,4,1,ref state,ref data,ref mut registers[..],81),5);
    let bytes::Buffer missing=bytes::empty();kind(ranges::step(ref p,4,0,ref state,ref missing,ref mut registers[..],81),5);
    state.owners.arena.used=3;kind(ranges::step(ref p,4,0,ref state,ref data,ref mut registers[..],81),5);state.owners=before;
    assert(registers[3]==99 && registers[4]==92 && registers[5]==93);same(ref state.owners,ref before,bytes::view(ref data),ref saved);
    let usize drop=built(arrays::execute(37,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut registers[..],0));
    kind(ranges::step(ref p,4,0,ref state,ref data,ref mut registers[..],81),5);assert(registers[3]==99);
}

@test
fn void builder_rejects_non_usize_or_slot_operands_without_partial_publication() {
    var ir::Program p=ir::empty();let usize id=built(ir::array(ref mut p,10,1,false,0));
    let usize start=built(ir::integer(ref mut p,0,12,0));let usize end=built(ir::integer(ref mut p,1,12,0));
    let usize other=built(ir::integer(ref mut p,1,1,0));let usize slot=built(ir::slot(ref mut p,12,0));
    assert(!ir::array_dynamic_utf8(ref mut p,id,other,end,0).is_ok);
    assert(!ir::array_dynamic_utf8(ref mut p,id,start,slot,0).is_ok);
    assert(!ir::array_dynamic_utf8(ref mut p,16,start,end,0).is_ok);
    assert(!ir::array_dynamic_utf8(ref mut p,id,128,end,0).is_ok);
    assert(p.count==3 && p.registers==4);
    let usize result=built(ir::array_dynamic_utf8(ref mut p,id,start,end,77));
    assert(result==4 && p.count==4 && p.registers==5 && p.types[4]==2);
    assert(p.code[24]==53 && p.code[25]==4 && p.code[26]==0 && p.code[27]==0 && p.code[28]==1 && p.code[29]==0 && p.code[30]==0 && p.code[31]==0);
}
