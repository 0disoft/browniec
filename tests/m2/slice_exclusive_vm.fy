module tests::m2::slice_exclusive_vm;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import slice_exclusive_vm as dispatch;
import slice_vm as loans;
import slice_call_vm as calls;
import slice_lifecycle_vm as lifecycle;
import array_vm as arrays;
import array_layout as layouts;
import array_owners as owners;
import array_slices as slices;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn usize pc(ref ir::Program p,u8 op){var usize i=0;while(i<p.count){if(p.code[i*8]==op){return i;}i+=1;}assert(false);return 0;}
fn usize constant(ref mut ir::Program p,u8 tag,i64 cell){return built(if(tag==2){ir::boolean(p,cell==1,77)}else{ir::integer(p,cell,tag,77)});}
fn ir::Program program(u8 tag,i64 cell,u8 mode){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array(ref mut p,tag,4,true,77));let usize site=built(ir::exclusive_slice(ref mut p,root,77));
    let usize fill=constant(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,root,fill,77));
    let usize lo=constant(ref mut p,12,1);let usize hi=constant(ref mut p,12,3);
    let usize index=constant(ref mut p,12,if(mode==1){2}else{0});let usize value=constant(ref mut p,tag,cell);
    let usize opened=built(ir::slice_open(ref mut p,site,lo,hi,77));
    let usize length=built(ir::slice_length(ref mut p,site,77));
    if(tag==10){let usize valid=built(ir::slice_utf8(ref mut p,site,77));}
    let usize written=built(ir::slice_write(ref mut p,site,index,value,77));
    let usize read=built(ir::slice_read(ref mut p,site,index,77));let usize equal=built(ir::emit(ref mut p,11,read,value,77));
    if(mode==2){let usize one=built(ir::literal(ref mut p,1,77));let usize zero=built(ir::literal(ref mut p,0,77));let usize fault=built(ir::emit(ref mut p,5,one,zero,77));}
    let usize close=built(ir::slice_close(ref mut p,site,77));let usize drop=built(ir::array_drop(ref mut p,root,77));
    let usize branch=built(ir::raw(ref mut p,20,0,equal,0,77));
    let usize answer=built(ir::literal(ref mut p,42,77));let usize ret=built(ir::emit(ref mut p,8,answer,0,77));
    let usize no=p.count;let usize zero=built(ir::literal(ref mut p,0,77));let usize bad=built(ir::emit(ref mut p,8,zero,0,77));
    let usize patch=built(ir::patch(ref mut p,branch,no,77));let usize end=p.count;let usize regs=p.registers;p.ends[0]=end;p.register_ends[0]=regs;
    assert(built(verifier::inspect(ref p))==p.count);return p;
}
fn bytes::Buffer backing(){return switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn void initialize(ref ir::Program p,ref mut arrays::State a,ref mut bytes::Buffer b,ref mut i64[] r){
    let layouts::Array shape=switch(layouts::scalar(p.arrays.elements[0],4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4}}};
    {let ref mut u8[] data=bytes::view_mut(b);let owners::Token root=switch(owners::create(ref shape,0,data,ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};a.tokens[0]=root;}
    var usize i=0;while(i<p.count){if(p.code[i*8]==1){r[p.code[i*8+1] as usize]=p.constants[p.code[i*8+2] as usize];}i+=1;}
}
fn usize step(ref ir::Program p,u8 op,ref mut loans::State l,ref mut arrays::State a,ref mut bytes::Buffer b,ref mut i64[] r,usize fuel){return built(dispatch::step(p,0,pc(p,op),0,l,a,b,r,fuel));}
fn void clear(ref mut loans::State l,ref mut arrays::State a,ref bytes::Buffer b){assert(loans::drain(l,a,b).is_ok);var usize i=0;while(i<16){assert(!l.pool.slots[i].live && !a.owners.slots[i].writing && !a.owners.slots[i].reading);i+=1;}}

@test
fn void exact_and_one_short_fuel_cover_all_opcodes_and_six_scalar_widths(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] cells=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];let usize[6] widths=[4,1,8,1,4,8];
    var usize i=0;while(i<6){
        let ir::Program p=program(tags[i],cells[i],0);var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var i64[128] r=[0;128];initialize(ref p,ref mut a,ref mut b,ref mut r);
        rejected(dispatch::step(ref p,0,pc(ref p,54),0,ref mut l,ref mut a,ref mut b,ref mut r,65536),8);assert(!a.owners.slots[0].writing && l.tickets[0].generation==0);
        assert(step(ref p,54,ref mut l,ref mut a,ref mut b,ref mut r,65537)==0 && a.owners.slots[0].writing);
        let u8[5] ops=[57,60,58,55,56];let usize[5] prices=[4097,4130+2*widths[i],4130+widths[i],4113,4097];
        var usize j=0;while(j<5){if(ops[j]!=55 || tags[i]==10){
            let usize at=pc(ref p,ops[j]);let usize dst=p.code[at*8+1] as usize;let i64 before=r[dst];let slices::Ticket ticket=l.tickets[0];let usize epoch=a.owners.slots[0].read_generation;
            var u8[64] saved=[0;64];{let ref u8[] data=bytes::view(ref b);var usize k=0;while(k<64){saved[k]=data[k];k+=1;}}
            rejected(dispatch::step(ref p,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,prices[j]-1),8);
            assert(r[dst]==before && l.tickets[0].slot==ticket.slot && l.tickets[0].generation==ticket.generation && a.owners.slots[0].writing && a.owners.slots[0].read_generation==epoch);
            {let ref u8[] data=bytes::view(ref b);var usize k=0;while(k<64){assert(data[k]==saved[k]);k+=1;}}
            assert(step(ref p,ops[j],ref mut l,ref mut a,ref mut b,ref mut r,prices[j])==0);
            if(ops[j]==58){assert(r[dst]==cells[i]);}if(ops[j]==57){assert(r[dst]==2);}if(ops[j]==55){assert(r[dst]==0);}
        }j+=1;}
        assert(!a.owners.slots[0].writing && l.tickets[0].generation==0);clear(ref mut l,ref mut a,ref b);i+=1;
    }
}

@test
fn void complete_private_execution_and_bounds_arithmetic_fuel_errors_drain_writers(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){var u8 mode=0;while(mode<4){
        let ir::Program p=program(tags[i],if(tags[i]==2){1}else{42},if(mode==3){0}else{mode});
        var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var calls::Frames f=calls::empty();
        // All setup constants + array init + open + length precede the store.
        let usize stride=if(tags[i]==1 || tags[i]==11){4}else if(tags[i]==9 || tags[i]==12){8}else{1};
        let usize fuel=if(mode==3){5+49+2*stride+4*stride+7+65537+4097+if(tags[i]==10){4113}else{0}+4130+2*stride-1}else{1000000};
        let u8 expected=if(mode==1){14}else if(mode==2){7}else if(mode==3){8}else{0};
        let Result<i64,errors::Error> result=execution::execute(ref p,fuel,ref mut a,ref mut b,ref mut l,ref mut f);
        assert(switch(result){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected && e.offset==77}});
        if(mode!=0){assert(a.owners.slots[0].writing && l.tickets[0].generation!=0);}
        assert(switch(lifecycle::finish(ref mut f,ref mut l,ref mut a,ref b,result)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected && e.offset==77}});
        clear(ref mut l,ref mut a,ref b);
        assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});
        mode+=1;
    }i+=1;}
}

@test
fn void bounds_bad_scalar_values_and_short_backing_preserve_payload_and_ticket(){
    let u8[4] tags=[1,2,10,11];let i64[4] invalid=[2147483648,2,256,4294967296];var usize i=0;while(i<4){
        let ir::Program p=program(tags[i],if(tags[i]==2){1}else{42},0);var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var i64[128] r=[0;128];initialize(ref p,ref mut a,ref mut b,ref mut r);let usize opened=step(ref p,54,ref mut l,ref mut a,ref mut b,ref mut r,65537);
        let usize at=pc(ref p,60);let usize index=p.code[at*8+2] as usize;let usize value=p.code[at*8+3] as usize;let i64 cell=r[value];let slices::Ticket ticket=l.tickets[0];
        r[index]=2;rejected(dispatch::step(ref p,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,5000),14);r[index]=-1;rejected(dispatch::step(ref p,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,5000),14);r[index]=0;
        r[value]=invalid[i];rejected(dispatch::step(ref p,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,5000),5);r[value]=cell;
        {let ref u8[] data=bytes::view(ref b);var usize k=0;while(k<64){assert(data[k]==0);k+=1;}}
        assert(bytes::resize_zeroed(ref mut b,0).is_ok);rejected(dispatch::step(ref p,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,5000),5);assert(bytes::resize_zeroed(ref mut b,64).is_ok);
        assert(l.tickets[0].generation==ticket.generation && a.owners.slots[0].writing);assert(step(ref p,60,ref mut l,ref mut a,ref mut b,ref mut r,5000)>0);clear(ref mut l,ref mut a,ref b);i+=1;
    }
}

@test
fn void stale_roots_tickets_modes_and_failed_cleanup_keep_metadata_for_diagnosis(){
    let ir::Program p=program(10,42,0);var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var i64[128] r=[0;128];initialize(ref p,ref mut a,ref mut b,ref mut r);let usize open=step(ref p,54,ref mut l,ref mut a,ref mut b,ref mut r,65537);
    let slices::Ticket old=l.tickets[0];let usize closed=step(ref p,56,ref mut l,ref mut a,ref mut b,ref mut r,4097);let usize again=step(ref p,54,ref mut l,ref mut a,ref mut b,ref mut r,65537);let slices::Ticket now=l.tickets[0];assert(now.generation!=old.generation);
    l.tickets[0]=old;rejected(dispatch::step(ref p,0,pc(ref p,60),0,ref mut l,ref mut a,ref mut b,ref mut r,5000),5);l.tickets[0]=now;
    let owners::Token token=a.tokens[0];a.tokens[0].generation+=1;rejected(dispatch::step(ref p,0,pc(ref p,58),0,ref mut l,ref mut a,ref mut b,ref mut r,5000),5);a.tokens[0]=token;
    l.pool.slots[now.slot].exclusive=false;rejected(dispatch::step(ref p,0,pc(ref p,60),0,ref mut l,ref mut a,ref mut b,ref mut r,5000),5);l.pool.slots[now.slot].exclusive=true;
    let usize epoch=a.owners.slots[0].read_generation;a.owners.slots[0].read_generation+=1;
    rejected(dispatch::step(ref p,0,pc(ref p,56),0,ref mut l,ref mut a,ref mut b,ref mut r,4097),5);
    var calls::Frames f=calls::empty();assert(!lifecycle::finish(ref mut f,ref mut l,ref mut a,ref b,.ok(42)).is_ok);assert(l.tickets[0].generation==now.generation && a.owners.slots[0].writing);
    a.owners.slots[0].read_generation=epoch;clear(ref mut l,ref mut a,ref b);
}

@test
fn void selected_utf8_empty_ranges_and_failed_mutation_preserve_scan_results(){
    let ir::Program p=program(10,42,0);var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var i64[128] r=[0;128];initialize(ref p,ref mut a,ref mut b,ref mut r);
    {let ref mut u8[] data=bytes::view_mut(ref mut b);data[0]=255;data[1]=194;data[2]=162;data[3]=255;}
    let usize open=step(ref p,54,ref mut l,ref mut a,ref mut b,ref mut r,65537);let usize valid=step(ref p,55,ref mut l,ref mut a,ref mut b,ref mut r,4113);let usize result=p.code[pc(ref p,55)*8+1] as usize;assert(r[result]==1);
    let usize store=pc(ref p,60);r[p.code[store*8+3] as usize]=255;let usize written=step(ref p,60,ref mut l,ref mut a,ref mut b,ref mut r,4132);let usize invalid=step(ref p,55,ref mut l,ref mut a,ref mut b,ref mut r,4113);assert(r[result]==0);
    let usize close=step(ref p,56,ref mut l,ref mut a,ref mut b,ref mut r,4097);let usize start=p.code[pc(ref p,54)*8+2] as usize;let usize end=p.code[pc(ref p,54)*8+3] as usize;r[end]=r[start];
    let usize empty=step(ref p,54,ref mut l,ref mut a,ref mut b,ref mut r,65537);let usize scan=step(ref p,55,ref mut l,ref mut a,ref mut b,ref mut r,4113);assert(r[result]==1);
    rejected(dispatch::step(ref p,0,store,0,ref mut l,ref mut a,ref mut b,ref mut r,4132),14);clear(ref mut l,ref mut a,ref b);
}

@test
fn void malformed_instructions_readonly_adapters_and_frame_mismatches_fail_closed(){
    let ir::Program p=program(10,42,0);var ir::Program bad=p;var loans::State l=loans::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();var i64[128] r=[0;128];initialize(ref p,ref mut a,ref mut b,ref mut r);let usize at=pc(ref p,54);
    bad.arrays.mutable[0]=false;rejected(dispatch::step(ref bad,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,65537),5);
    bad=p;bad.array_functions[0]=1;rejected(dispatch::step(ref bad,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,65537),5);
    bad=p;bad.slice_roots[0]=0;rejected(dispatch::step(ref bad,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,65537),5);
    bad=p;bad.code[at*8]=59;rejected(dispatch::step(ref bad,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,65537),5);
    var usize reserved=4;while(reserved<8){bad=p;bad.code[at*8+reserved]=1;rejected(dispatch::step(ref bad,0,at,0,ref mut l,ref mut a,ref mut b,ref mut r,65537),5);reserved+=1;}
    rejected(dispatch::step(ref p,0,at,32,ref mut l,ref mut a,ref mut b,ref mut r,65537),5);
    let usize opened=step(ref p,54,ref mut l,ref mut a,ref mut b,ref mut r,65537);
    rejected(loans::step(ref p,pc(ref p,58),0,ref mut l,ref mut a,ref b,ref mut r,5000),5);
    bad=p;bad.slice_elements[0]=0;rejected(dispatch::step(ref bad,0,pc(ref p,60),0,ref mut l,ref mut a,ref mut b,ref mut r,5000),5);
    rejected(dispatch::step(ref p,0,pc(ref p,60),1,ref mut l,ref mut a,ref mut b,ref mut r,5000),5);
    clear(ref mut l,ref mut a,ref b);
}
