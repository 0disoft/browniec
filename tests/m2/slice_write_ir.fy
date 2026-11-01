module tests::m2::slice_write_ir;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import slice_verifier as slices;
import register_set as registers;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(ref ir::Program p,usize pc){assert(switch(verifier::inspect(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});assert(switch(verifier::verify(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});assert(switch(vm::run_with_array_limit(p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});}
fn void admitted(ref ir::Program p){
    assert(built(verifier::inspect(p))==p.count);
    assert(built(verifier::verify(p))==p.count);
    assert(switch(vm::run_with_array_limit(p,4000000,64)){case .ok(v):{v==42}case .err(_):{false}});
}
fn ir::Program program(u8 tag,i64 cell){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array(ref mut p,tag,2,true,0));
    let usize site=built(ir::exclusive_slice(ref mut p,root,0));
    let usize fill=if(tag==2){built(ir::boolean(ref mut p,false,0))}else{built(ir::integer(ref mut p,0,tag,0))};
    let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,2,12,0));
    let usize value=if(tag==2){built(ir::boolean(ref mut p,true,0))}else{built(ir::integer(ref mut p,cell,tag,0))};
    let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize before=p.registers;let usize count=p.count;
    let usize first=built(ir::slice_write(ref mut p,site,lo,value,71));
    assert(first==6 && p.count==count+1 && p.registers==before && p.offsets[first]==71);
    let usize second=built(ir::slice_write(ref mut p,site,lo,value,72));
    let usize read=built(ir::slice_read(ref mut p,site,lo,0));assert(p.types[read]==tag);
    let usize close=built(ir::slice_close(ref mut p,site,0));let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize ret=built(ir::emit(ref mut p,8,answer,0,0));
    let usize end=p.count;let usize regs=p.registers;p.ends[0]=end;p.register_ends[0]=regs;return p;
}
fn void builder_reject(ref mut ir::Program p,usize site,usize index,usize value,u8 kind){
    let u8[2048] code=p.code;let usize[256] offsets=p.offsets;
    let usize count=p.count;let usize regs=p.registers;let usize constants=p.constant_count;
    assert(switch(ir::slice_write(p,site,index,value,99)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==99}});
    assert(p.count==count && p.registers==regs && p.constant_count==constants);
    var usize i=0;while(i<2048){assert(p.code[i]==code[i]);i+=1;}
    i=0;while(i<256){assert(p.offsets[i]==offsets[i]);i+=1;}
}

@test
fn void six_exact_scalar_tags_and_repeated_stores_preserve_definitions_and_loans(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] cells=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];
    var usize i=0;while(i<6){let ir::Program p=program(tags[i],cells[i]);admitted(ref p);i+=1;}
    let ir::Program p=program(10,42);var registers::Set defined=registers::Set{.low=15,.high=0};
    var registers::Set written=defined;let usize live=4294967297;
    assert(built(slices::step(ref p,6,0,ref mut defined,ref mut written,live))==live);
    assert(defined.low==15 && defined.high==0 && written.low==15 && written.high==0);
}

@test
fn void builder_rejects_readonly_wrong_tags_nonvalues_and_exhaustion_without_mutation(){
    let ir::Program p=program(1,42);var ir::Program bad=p;
    builder_reject(ref mut bad,16,1,3,3);builder_reject(ref mut bad,0,128,3,3);builder_reject(ref mut bad,0,1,128,3);
    bad=p;bad.slice_elements[0]=0;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.types[3]=11;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.types[1]=11;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.slots[3]=true;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.slots[1]=true;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.array_parameters[3]=1;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.record_parameters[1]=1;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.slice_parameters[3]=1;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.arrays.elements[0]=3;bad.types[3]=3;builder_reject(ref mut bad,0,1,3,3);
    bad=p;bad.count=256;builder_reject(ref mut bad,0,1,3,4);
}

@test
fn void independent_validation_rejects_wrong_or_undefined_and_foreign_registers(){
    let ir::Program p=program(1,42);var ir::Program bad=p;bad.types[3]=11;rejected(ref bad,6);
    bad=p;bad.code[50]=3;rejected(ref bad,6);
    bad=p;bad.code[51]=4;rejected(ref bad,6);
    bad=p;bad.code[50]=128;rejected(ref bad,6);
    bad=p;bad.code[51]=128;rejected(ref bad,6);
    bad=p;bad.code[50]=5;bad.types[5]=12;rejected(ref bad,6);
    bad=p;let usize start=bad.count;let usize regs=bad.registers;
    bad.function_count=2;bad.starts[1]=start;bad.register_starts[1]=regs;bad.return_types[1]=1;
    let usize foreign=built(ir::integer(ref mut bad,42,1,0));let usize ret=built(ir::emit(ref mut bad,8,foreign,0,0));
    let usize end=bad.count;let usize all_regs=bad.registers;bad.ends[1]=end;bad.register_ends[1]=all_regs;
    bad.code[51]=6;rejected(ref bad,6);
}

@test
fn void stores_require_live_exclusive_owned_sites_and_all_reserved_bytes_zero(){
    let ir::Program p=program(10,42);var ir::Program bad=p;bad.slice_elements[0]=0;rejected(ref bad,6);
    bad=p;bad.code[40]=60;bad.code[43]=3;rejected(ref bad,5);
    bad=p;bad.code[48]=56;bad.code[50]=0;bad.code[51]=0;rejected(ref bad,7);
    bad=p;bad.code[49]=16;rejected(ref bad,6);
    var usize byte=4;while(byte<8){bad=p;bad.code[48+byte]=1;rejected(ref bad,6);byte+=1;}
    bad=p;bad.code[48]=61;rejected(ref bad,6);
}

@test
fn void stores_do_not_supply_missing_cleanup_or_change_branch_join_live_sets(){
    var ir::Program p=program(10,42);
    // Branch over the first store: both paths retain exactly the same loan.
    p.code[48]=19;p.code[49]=0;p.code[50]=7;p.code[51]=0;admitted(ref p);
    var ir::Program bad=p;bad.code[72]=19;bad.code[73]=0;bad.code[74]=10;bad.code[75]=0;rejected(ref bad,10);
    // A write cannot become a definition for a later scalar read/return.
    bad=program(10,42);bad.code[64]=19;bad.code[65]=0;bad.code[66]=9;bad.code[67]=0;
    assert(switch(verifier::inspect(ref bad)){case .ok(_):{false}case .err(e):{e.kind==5}});
}
