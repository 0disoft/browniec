module tests::m2::place_ir;
import ir as ir;
import place_ir as places;
import verifier as verifier;
import vm as vm;
import errors as errors;

fn usize built(Result<usize,errors::Error> r) {
    return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn void finish(ref mut ir::Program p) {
    p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize count=p.count;let usize registers=p.registers;
    p.ends[0]=count;p.register_ends[0]=registers;
}
// Stable PCs: fill0,index1,init2,SELECT3,READ4,new5,STORE6,END7,DROP8,return-value9,RETURN10.
fn ir::Program basic(u8 tag) {
    var ir::Program p=ir::empty();
    let usize root=built(ir::array(ref mut p,tag,2,true,0));
    let usize fill=if(tag==2){built(ir::boolean(ref mut p,false,0))}else{built(ir::integer(ref mut p,0,tag,0))};
    let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize selected=built(ir::place_select(ref mut p,0,root,index,0));
    let usize old=built(ir::place_read(ref mut p,0,root,0));
    let usize fresh=if(tag==2){built(ir::boolean(ref mut p,true,0))}else{built(ir::integer(ref mut p,1,tag,0))};
    let usize stored=built(ir::place_store(ref mut p,0,root,fresh,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize result=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,result,0,0));
    finish(ref mut p);return p;
}
fn void jump(ref mut ir::Program p,usize pc,usize target) {
    p.code[pc*8]=19;p.code[pc*8+1]=0;p.code[pc*8+2]=0;p.code[pc*8+3]=0;
    let usize patched=built(ir::patch(p,pc,target,0));
}
fn void rejected_at(ref ir::Program p,usize pc) {
    assert(switch(verifier::inspect(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});
}

@test fn void six_scalar_domains_use_private_places_without_value_registers() {
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
    while(i<6){let ir::Program p=basic(tags[i]);
        assert(p.registers==5 && p.code[3*8]==83 && p.code[4*8]==84);
        assert(verifier::inspect(ref p).is_ok && places::inspect(ref p).is_ok);
        i+=1;
    }
}

@test fn void scalar_typing_mutability_definedness_and_reserved_bytes_are_independent() {
    var ir::Program p=basic(1);p.arrays.mutable[0]=false;rejected_at(ref p,3);
    p=basic(1);p.types[1]=1;rejected_at(ref p,3);
    p=basic(1);p.code[3*8+3]=3;rejected_at(ref p,3);
    p=basic(1);p.code[4*8+1]=0;rejected_at(ref p,4);
    p=basic(1);p.code[6*8+3]=1;rejected_at(ref p,6);
    p=basic(1);p.code[6*8+3]=4;rejected_at(ref p,6);
    p=basic(1);p.code[6*8+2]=16;rejected_at(ref p,6);
    p=basic(1);p.code[7*8+2]=1;rejected_at(ref p,7);
    var usize op=3;while(op<=7){if(op!=5){var usize byte=4;while(byte<8){
        p=basic(1);p.code[op*8+byte]=1;rejected_at(ref p,op);byte+=1;
    }}op+=1;}
}

@test fn void phase_use_drop_and_return_obligations_cannot_be_skipped() {
    var ir::Program p=basic(1);jump(ref mut p,3,4);rejected_at(ref p,4);
    p=basic(1);p.code[6*8+1]=1;rejected_at(ref p,6);
    p=basic(1);jump(ref mut p,7,8);rejected_at(ref p,8);
    p=basic(1);p.code[7*8]=85;p.code[7*8+2]=0;p.code[7*8+3]=3;rejected_at(ref p,7);
    p=basic(1);p.code[6*8]=83;p.code[6*8+3]=1;rejected_at(ref p,6);
    p=basic(1);p.code[6*8]=84;p.code[6*8+1]=5;p.code[6*8+2]=0;p.code[6*8+3]=0;
    p.types[5]=1;p.registers=6;p.register_ends[0]=6;rejected_at(ref p,6);
    p=basic(1);p.code[7*8]=84;p.code[7*8+1]=5;p.code[7*8+2]=0;p.code[7*8+3]=0;
    p.types[5]=1;p.registers=6;p.register_ends[0]=6;rejected_at(ref p,7);
    p=basic(1);jump(ref mut p,7,9);
    assert(switch(places::inspect(ref p)){case .ok(_):{false}case .err(e):{e.offset==10}});
}

// Shared SELECT dominates both arms. Distinct SELECT instructions in the arms
// deliberately name the same root/index/slot; their identity still cannot join.
fn ir::Program branched(bool distinct,bool end_arm) {
    var ir::Program p=ir::empty();let usize root=built(ir::array(ref mut p,1,2,true,0));
    let usize fill=built(ir::literal(ref mut p,42,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize initialized=built(ir::array_init(ref mut p,root,fill,0));
    let usize condition=built(ir::boolean(ref mut p,false,0));
    if(!distinct){let usize selected=built(ir::place_select(ref mut p,0,root,index,0));}
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    if(distinct){let usize selected=built(ir::place_select(ref mut p,0,root,index,0));}
    if(end_arm){let usize ended=built(ir::place_end(ref mut p,0,0));}
    let usize skip=built(ir::raw(ref mut p,19,0,0,0,0));let usize alternate=p.count;
    let usize patched=built(ir::patch(ref mut p,branch,alternate,0));
    if(distinct){let usize selected=built(ir::place_select(ref mut p,0,root,index,0));}
    let usize joined=p.count;let usize patched_skip=built(ir::patch(ref mut p,skip,joined,0));
    let usize old=built(ir::place_read(ref mut p,0,root,0));
    let usize stored=built(ir::place_store(ref mut p,0,root,fill,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize returned=built(ir::emit(ref mut p,8,old,0,0));finish(ref mut p);return p;
}
@test fn void joins_require_identical_selected_identity_and_phase() {
    let ir::Program shared=branched(false,false);assert(verifier::inspect(ref shared).is_ok);
    let ir::Program different=branched(true,false);assert(!verifier::inspect(ref different).is_ok);
    let ir::Program ended=branched(false,true);assert(!verifier::inspect(ref ended).is_ok);
}

fn ir::Program looped(bool hold,bool omit_end) {
    var ir::Program p=ir::empty();let usize root=built(ir::array(ref mut p,1,2,true,0));
    let usize fill=built(ir::literal(ref mut p,42,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize initialized=built(ir::array_init(ref mut p,root,fill,0));
    let usize condition=built(ir::boolean(ref mut p,false,0));
    if(hold){let usize selected=built(ir::place_select(ref mut p,0,root,index,0));}
    let usize begin=p.count;
    if(!hold){let usize selected=built(ir::place_select(ref mut p,0,root,index,0));
        let usize stored=built(ir::place_store(ref mut p,0,root,fill,0));
        if(!omit_end){let usize ended=built(ir::place_end(ref mut p,0,0));}
    }
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    let usize back=built(ir::raw(ref mut p,22,0,begin,0,0));let usize after=p.count;
    let usize patched=built(ir::patch(ref mut p,branch,after,0));
    if(hold){let usize stored=built(ir::place_store(ref mut p,0,root,fill,0));let usize ended=built(ir::place_end(ref mut p,0,0));}
    let usize dropped=built(ir::array_drop(ref mut p,root,0));let usize returned=built(ir::emit(ref mut p,8,fill,0,0));
    finish(ref mut p);return p;
}
@test fn void loops_allow_recreation_or_preservation_but_reject_changed_obligations() {
    let ir::Program reused=looped(false,false);assert(verifier::inspect(ref reused).is_ok);
    let ir::Program held=looped(true,false);assert(verifier::inspect(ref held).is_ok);
    let ir::Program leaked=looped(false,true);assert(!verifier::inspect(ref leaked).is_ok);
}

@test fn void sixteen_live_slots_and_more_than_sixteen_sequential_selections_fit() {
    var ir::Program p=basic(1);p.count=3;p.registers=2;var usize i=0;
    while(i<24){let usize selected=built(ir::place_select(ref mut p,0,0,1,0));
        let usize stored=built(ir::place_store(ref mut p,0,0,0,0));let usize ended=built(ir::place_end(ref mut p,0,0));i+=1;}
    i=0;while(i<16){let usize selected=built(ir::place_select(ref mut p,i,0,1,0));i+=1;}
    while(i>0){i-=1;let usize stored=built(ir::place_store(ref mut p,i,0,0,0));let usize ended=built(ir::place_end(ref mut p,i,0));}
    let usize dropped=built(ir::array_drop(ref mut p,0,0));let usize result=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,result,0,0));finish(ref mut p);
    assert(verifier::inspect(ref p).is_ok);
    assert(switch(places::inspect(ref p)){case .ok(n):{n==40}case .err(_):{false}});
    let usize count=p.count;assert(!ir::place_select(ref mut p,16,0,1,0).is_ok && p.count==count);
}

@test fn void final_select_pc_and_dead_instruction_metadata_are_bounded() {
    var ir::Program p=basic(1);p.count=3;p.registers=2;
    while(p.count<254){let usize target=p.count+1;let usize skipped=built(ir::raw(ref mut p,19,0,target,0,0));}
    let usize selected=built(ir::place_select(ref mut p,15,0,1,0));
    let usize trapped=built(ir::raw(ref mut p,25,0,0,0,0));finish(ref mut p);
    assert(p.count==256 && verifier::inspect(ref p).is_ok);
    var ir::Program dead=basic(1);jump(ref mut dead,3,9);dead.code[4*8+4]=1;
    assert(switch(places::inspect(ref dead)){case .ok(_):{false}case .err(e):{e.offset==4}});
    dead=basic(1);let usize unreachable=built(ir::raw(ref mut dead,84,0,0,0,0));finish(ref mut dead);
    dead.code[unreachable*8+4]=1;rejected_at(ref dead,unreachable);
}

@test fn void independent_function_frames_and_runtime_admission_stay_separate() {
    var ir::Program p=basic(1);let usize child_end=p.count;let usize child_registers=p.registers;
    p.function_count=2;p.entry=1;p.return_types[1]=1;p.starts[1]=child_end;p.register_starts[1]=child_registers;
    let usize root=built(ir::array_in(ref mut p,1,1,2,true,0));
    let usize fill=built(ir::literal(ref mut p,0,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize initialized=built(ir::array_init(ref mut p,root,fill,0));let usize selected=built(ir::place_select(ref mut p,0,root,index,0));
    let usize[1] none=[0];let usize result=built(ir::call(ref mut p,0,ref none[..0],0));
    let usize stored=built(ir::place_store(ref mut p,0,root,result,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize dropped=built(ir::array_drop(ref mut p,root,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));
    let usize count=p.count;let usize registers=p.registers;p.ends[1]=count;p.register_ends[1]=registers;
    assert(verifier::inspect(ref p).is_ok);
    assert(!verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
}
