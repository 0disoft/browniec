module tests::m2::slice_borrow_ir;
import ir as ir;
import slice_builders as builders;
import slice_parameters as parameters;
import errors as errors;
import verifier as verifier;
import vm as vm;

fn usize built(Result<usize, errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn void rejected(Result<usize, errors::Error> r, u8 kind) { assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind==kind && e.offset==77 } }); }
fn ir::Program declarations() {
    var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=1;
    let usize formal=built(builders::parameter(ref mut p,0,0));
    let usize child=built(builders::derived(ref mut p,formal,0,0));
    let usize nested=built(builders::derived(ref mut p,child,0,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0)); let usize hi=built(ir::integer(ref mut p,2,12,0));
    return p;
}
fn void unchanged(ref ir::Program p, ref ir::Program old) {
    assert(p.count==old.count && p.registers==old.registers && p.constant_count==old.constant_count && p.call_count==old.call_count);
    var usize i=0;
    while(i<2048) { assert(p.code[i]==old.code[i]); i+=1; }
    i=0; while(i<256) { assert(p.offsets[i]==old.offsets[i]); i+=1; }
    i=0; while(i<128) { assert(p.types[i]==old.types[i] && p.slice_parameters[i]==old.slice_parameters[i]); i+=1; }
    i=0; while(i<16) { assert(p.slice_roots[i]==old.slice_roots[i] && p.slice_origins[i]==old.slice_origins[i] && p.slice_functions[i]==old.slice_functions[i]); i+=1; }
}

@test
fn void rootless_formals_and_retained_children_emit_existing_typed_instructions_and_pass_public_verification() {
    var ir::Program p=declarations();
    assert(built(ir::slice_sub(ref mut p,1,0,1,2,77))==2);
    assert(built(ir::slice_close(ref mut p,0,77))==3);
    assert(built(ir::slice_utf8(ref mut p,1,77))==3 && p.types[3]==2);
    assert(built(ir::slice_length(ref mut p,1,77))==4 && p.types[4]==12);
    assert(built(ir::slice_read(ref mut p,1,1,77))==5 && p.types[5]==10);
    assert(built(ir::slice_sub(ref mut p,2,1,1,2,77))==7);
    let usize close=built(ir::slice_close(ref mut p,1,77));
    assert(built(ir::slice_read(ref mut p,2,1,77))==6 && p.types[6]==10);
    let usize closed=built(ir::slice_close(ref mut p,2,77));
    let usize answer=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,answer,0,0));
    let usize end=p.count; let usize regs=p.registers; p.ends[0]=end; p.register_ends[0]=regs; p.return_types[0]=1;
    p.starts[1]=end; p.register_starts[1]=regs; p.return_types[1]=1;
    let usize entry=built(ir::literal(ref mut p,42,0)); let usize done=built(ir::emit(ref mut p,8,entry,0,0));
    let usize finish=p.count; let usize limit=p.registers; p.ends[1]=finish; p.register_ends[1]=limit;
    assert(p.code[16]==59 && p.code[17]==1 && p.code[18]==0 && p.code[19]==1 && p.code[20]==2);
    assert(p.code[24]==56 && p.code[32]==55 && p.code[40]==57 && p.code[48]==58);
    assert(p.code[56]==59 && p.code[57]==2 && p.code[58]==1 && p.slice_origins[2]==1);
    assert(p.arrays.count==0 && built(parameters::metadata(ref p))==1);
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,0,0)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
}

@test
fn void malformed_borrow_origins_fail_all_builders_before_publication() {
    let ir::Program base=declarations(); var usize i=0;
    while(i<16) {
        var ir::Program p=base;
        if(i==0) { p.slice_origins[1]=0; } else if(i==1) { p.slice_origins[1]=17; }
        else if(i==2) { p.slice_functions[1]=0; } else if(i==3) { p.slice_functions[1]=17; }
        else if(i==4) { p.slice_roots[1]=1; } else if(i==5) { p.slice_origins[0]=2; }
        else if(i==6) { p.slice_functions[0]=2; } else if(i==7) { p.slice_parameters[0]=0; }
        else if(i==8) { p.types[0]=10; } else if(i==9) { p.slots[0]=true; }
        else if(i==10) { p.array_parameters[0]=1; } else if(i==11) { p.record_parameters[0]=1; }
        else if(i==12) { p.registers=129; } else if(i==13) { p.arities[0]=9; }
        else if(i==14) { p.register_starts[0]=4; }
        else { p.arities[0]=2; p.types[1]=0; p.slice_parameters[1]=1; }
        let ir::Program old=p;
        rejected(ir::slice_utf8(ref mut p,1,77),3); rejected(ir::slice_length(ref mut p,1,77),3);
        rejected(ir::slice_read(ref mut p,1,1,77),3); rejected(ir::slice_close(ref mut p,1,77),3);
        rejected(ir::slice_sub(ref mut p,2,1,1,2,77),3); unchanged(ref p,ref old); i+=1;
    }
}

@test
fn void subranges_require_same_origin_and_derived_destination_and_scalar_usize_bounds() {
    var ir::Program p=declarations();
    // A second, individually valid formal/derived origin in another function.
    p.function_count=3; p.entry=2; p.arities[1]=1; p.register_starts[1]=3;
    let usize foreign=built(builders::parameter(ref mut p,1,0));
    let usize child=built(builders::derived(ref mut p,foreign,1,0));
    let usize root=built(ir::array_in(ref mut p,0,10,2,false,0)); let usize owned=built(ir::slice(ref mut p,root,0));
    let ir::Program old=p;
    rejected(ir::slice_sub(ref mut p,child,0,1,2,77),3);
    rejected(ir::slice_sub(ref mut p,1,foreign,1,2,77),3);
    rejected(ir::slice_sub(ref mut p,1,owned,1,2,77),3);
    rejected(ir::slice_sub(ref mut p,owned,0,1,2,77),3);
    rejected(ir::slice_sub(ref mut p,0,1,1,2,77),3);
    rejected(ir::slice_sub(ref mut p,1,1,1,2,77),3);
    rejected(ir::slice_open(ref mut p,0,1,2,77),3);
    rejected(ir::slice_read(ref mut p,0,0,77),3); rejected(ir::slice_read(ref mut p,0,128,77),3);
    rejected(ir::slice_sub(ref mut p,1,0,0,2,77),3);
    rejected(ir::slice_sub(ref mut p,16,0,1,2,77),3); unchanged(ref p,ref old);
    var usize i=0; while(i<5) {
        var ir::Program bad=old;
        if(i==0) { bad.types[1]=1; } else if(i==1) { bad.slots[1]=true; }
        else if(i==2) { bad.array_parameters[1]=1; } else if(i==3) { bad.record_parameters[1]=1; }
        else { bad.slice_parameters[1]=4; }
        let ir::Program before=bad;
        rejected(ir::slice_read(ref mut bad,1,1,77),3);
        rejected(ir::slice_sub(ref mut bad,1,0,1,2,77),3); unchanged(ref bad,ref before); i+=1;
    }
}

@test
fn void instruction_and_register_capacity_failures_preserve_ir_and_owned_kinds_still_work() {
    var ir::Program full=declarations(); full.count=256; let ir::Program old=full;
    rejected(ir::slice_utf8(ref mut full,1,77),4); rejected(ir::slice_length(ref mut full,1,77),4);
    rejected(ir::slice_read(ref mut full,1,1,77),4); rejected(ir::slice_close(ref mut full,1,77),4);
    rejected(ir::slice_sub(ref mut full,2,1,1,2,77),4); unchanged(ref full,ref old);
    var ir::Program registers=declarations(); registers.registers=128; let ir::Program before=registers;
    rejected(ir::slice_utf8(ref mut registers,1,77),4); rejected(ir::slice_length(ref mut registers,1,77),4);
    rejected(ir::slice_read(ref mut registers,1,1,77),4); unchanged(ref registers,ref before);
    assert(built(ir::slice_sub(ref mut registers,2,1,1,2,77))==2);
    assert(built(ir::slice_close(ref mut registers,1,77))==3 && registers.registers==128);
    var ir::Program owned=ir::empty(); let usize root=built(ir::array(ref mut owned,1,2,false,0));
    let usize site=built(ir::slice(ref mut owned,root,0)); let usize index=built(ir::integer(ref mut owned,0,12,0));
    let usize value=built(ir::slice_read(ref mut owned,site,index,0)); assert(owned.types[value]==1);
    rejected(ir::slice_utf8(ref mut owned,site,77),3);
    let usize length=built(ir::slice_length(ref mut owned,site,0)); assert(owned.types[length]==12);
    let usize close=built(ir::slice_close(ref mut owned,site,0));
}
