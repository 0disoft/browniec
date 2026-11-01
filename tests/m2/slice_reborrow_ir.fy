module tests::m2::slice_reborrow_ir;
import ir as ir;
import errors as errors;
import slice_builders as builders;
import slice_reborrow_ir as loans;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import array_vm as arrays;
import slice_vm as slices;
import slice_call_vm as calls;
import slice_mutable_call_vm as mutable;
import std::bytes as bytes;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn usize pc(ref ir::Program p,u8 op){var usize i=p.starts[0];while(i<p.ends[0] && p.code[i*8]!=op){i+=1;}assert(i<p.ends[0]);return i;}
fn void accepted(ref ir::Program p){assert(verifier::inspect(p).is_ok);assert(switch(verifier::verify(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(switch(vm::run_with_array_limit(p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});}
fn void rejected(ref ir::Program p){assert(!verifier::inspect(p).is_ok && !verifier::verify(p).is_ok);}
fn void rejected_at(ref ir::Program p,usize at){assert(switch(verifier::inspect(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==at}});rejected(p);}
fn void skip(ref mut ir::Program p,usize at){p.code[at*8]=19;p.code[at*8+1]=0;p.code[at*8+3]=0;p.code[at*8+4]=0;let usize done=built(ir::patch(p,at,at+1,77));}
fn ir::Program program(u8 tag,bool formal,usize levels,bool loop){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;
    var usize root=16;var usize parent=16;
    if(formal){p.arities[0]=1;parent=built(builders::parameter_exclusive(ref mut p,0,tag,77));}
    else{root=built(ir::array_in(ref mut p,0,tag,2,true,77));parent=built(ir::exclusive_slice(ref mut p,root,77));let usize fill=built(if(tag==2){ir::boolean(ref mut p,false,77)}else{ir::integer(ref mut p,0,tag,77)});let usize init=built(ir::array_init(ref mut p,root,fill,77));}
    let usize lo=built(ir::integer(ref mut p,0,12,77));let usize hi=built(ir::integer(ref mut p,1,12,77));
    if(!formal){let usize open=built(ir::slice_open(ref mut p,parent,lo,hi,77));}
    let usize value=built(if(tag==2){ir::boolean(ref mut p,true,77)}else{ir::integer(ref mut p,42,tag,77)});let usize condition=built(ir::boolean(ref mut p,true,77));
    var usize[16] sites=[16;16];sites[0]=parent;var usize i=1;while(i<=levels){sites[i]=built(loans::derived(ref mut p,sites[i-1],77));i+=1;}
    let usize branch=built(ir::raw(ref mut p,19,0,0,0,77));let usize next=branch+1;let usize patched=built(ir::patch(ref mut p,branch,next,77));
    let usize target=p.count;i=1;while(i<=levels){let usize begin=built(loans::begin(ref mut p,sites[i],sites[i-1],lo,hi,77));i+=1;}
    let usize write=built(ir::slice_write(ref mut p,sites[levels],lo,value,77));let usize read=built(ir::slice_read(ref mut p,sites[levels],lo,77));
    i=levels;while(i>0){let usize end=built(loans::end(ref mut p,sites[i],sites[i-1],77));i-=1;}
    if(loop){let usize branch=built(ir::raw(ref mut p,20,0,condition,0,77));let usize back=built(ir::raw(ref mut p,22,0,target,0,77));let usize end=p.count;let usize patched=built(ir::patch(ref mut p,branch,end,77));}
    let usize after=built(ir::slice_length(ref mut p,parent,77));let usize close=built(ir::slice_close(ref mut p,parent,77));if(!formal){let usize drop=built(ir::array_drop(ref mut p,root,77));}
    let usize answer=built(ir::literal(ref mut p,42,77));let usize returned=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;let usize done=built(ir::literal(ref mut p,42,77));let usize entry_return=built(ir::emit(ref mut p,8,done,0,77));finish(ref mut p,1);return p;
}
@test
fn void six_scalar_owned_and_formal_children_inspect_without_growing_program_or_scalar_positions(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){let ir::Program owned=program(tags[i],false,2,false);let ir::Program formal=program(tags[i],true,2,false);accepted(ref owned);accepted(ref formal);
        let loans::Sites mapping=switch(loans::metadata(ref formal)){case .ok(v):{v}case .err(_):{assert(false);loans::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};assert(mapping.count==2 && mapping.parents[1]==0 && mapping.parents[2]==1 && formal.slice_parameters[0]==1 && formal.slice_origins[2]==1 && formal.slice_elements[2]==(tags[i]|128));i+=1;}
    let ir::Program full=program(10,true,15,false);accepted(ref full);assert(full.slice_elements[15]==138);
}
@test
fn void suspended_parent_reads_writes_length_utf8_close_reopen_and_root_access_are_rejected(){
    let ir::Program p=program(10,false,2,false);let usize store=pc(ref p,60);let usize read=pc(ref p,58);let usize begin=pc(ref p,61);let usize lo=p.code[begin*8+3] as usize;let u8 lower=p.code[begin*8+3];let u8 upper=p.code[begin*8+4];
    var ir::Program bad=p;bad.code[store*8+1]=0;rejected_at(ref bad,store);
    bad=p;bad.code[read*8+2]=0;rejected_at(ref bad,read);
    bad=p;bad.code[read*8]=57;bad.code[read*8+2]=0;bad.code[read*8+3]=0;rejected_at(ref bad,read);
    bad=p;bad.code[read*8]=55;bad.code[read*8+2]=0;bad.code[read*8+3]=0;rejected_at(ref bad,read);
    bad=p;bad.code[store*8]=56;bad.code[store*8+1]=0;bad.code[store*8+2]=0;bad.code[store*8+3]=0;rejected_at(ref bad,store);
    bad=p;bad.code[store*8]=54;bad.code[store*8+1]=0;bad.code[store*8+2]=lower;bad.code[store*8+3]=upper;rejected_at(ref bad,store);
    bad=p;bad.code[read*8]=35;bad.code[read*8+2]=0;rejected_at(ref bad,read);
    let usize end=pc(ref p,62);bad=p;bad.code[end*8]=56;bad.code[end*8+2]=0;rejected_at(ref bad,end);
    bad=p;bad.code[end*8+2]=0;rejected_at(ref bad,end);
    bad=p;skip(ref mut bad,end);rejected(ref bad);
    let usize length=pc(ref p,57);bad=p;bad.code[length*8+2]=2;rejected_at(ref bad,length);
    accepted(ref p);
}
@test
fn void metadata_requires_a_unique_acyclic_same_mode_same_function_parent_forest(){
    let ir::Program p=program(10,true,2,false);let usize first=pc(ref p,61);let usize second=first+1;var ir::Program bad=p;
    bad.code[second*8+1]=1;rejected_at(ref bad,second);
    bad=p;bad.code[first*8+2]=2;rejected_at(ref bad,0);
    bad=p;bad.slice_elements[2]=10;rejected(ref bad);
    bad=p;bad.slice_functions[2]=2;rejected(ref bad);
    bad=p;skip(ref mut bad,second);rejected(ref bad);
    bad=p;bad.code[first*8+1]=0;rejected_at(ref bad,first);
    bad=p;bad.code[first*8+5]=1;rejected_at(ref bad,first);
    bad=p;bad.code[first*8+3]=128;rejected_at(ref bad,first);
    bad=p;bad.code[first*8+4]=0;rejected_at(ref bad,first);
    let usize end=pc(ref p,62);bad=p;bad.code[end*8+4]=1;rejected_at(ref bad,end);
    var ir::Program owned=program(10,false,1,false);let usize begin=pc(ref owned,61);let usize other=built(ir::array_in(ref mut owned,1,10,1,true,77));owned.slice_roots[1]=2;rejected_at(ref owned,begin);
}
@test
fn void balanced_loops_and_joins_preserve_both_available_and_suspended_sets(){
    let ir::Program p=program(10,true,2,true);accepted(ref p);let usize end=pc(ref p,62);var ir::Program bad=p;skip(ref mut bad,end);rejected(ref bad);
    // A forward branch skips the entire balanced child lifetime.
    var ir::Program join=program(10,false,1,false);let usize branch=pc(ref join,19);let usize join_end=pc(ref join,62);let u8 condition=join.code[(branch-1)*8+1];join.code[branch*8]=20;join.code[branch*8+2]=condition;let usize patched=built(ir::patch(ref mut join,branch,join_end+1,77));accepted(ref join);
    // Skipping begin but joining at child end has incompatible live/suspended sets.
    let usize bad_target=join_end;let usize mismatch=built(ir::patch(ref mut join,branch,bad_target,77));rejected(ref join);

}
@test
fn void public_and_internal_execution_gates_reject_before_fuel_or_state_publication(){
    let ir::Program p=program(10,false,1,false);accepted(ref p);var arrays::State a=arrays::empty(0);var slices::State l=slices::empty();var calls::Frames f=calls::empty();var bytes::Buffer b=bytes::empty();var mutable::Frame[32] receipts=[mutable::empty();32];
    assert(switch(execution::execute(ref p,0,ref mut a,ref mut b,ref mut l,ref mut f)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});
    assert(switch(execution::execute_mutable(ref p,10000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut receipts)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});
    assert(a.owners.depth==0 && a.owners.arena.used==0 && bytes::len(ref b)==0);var usize i=0;while(i<32){assert(!receipts[i].active);i+=1;}i=0;while(i<16){assert(!l.pool.slots[i].live);i+=1;}
    // A structurally valid recursive CALL is rejected only while reborrow is live.
    let usize answer_pc=p.ends[0]-2;let u8 answer=p.code[answer_pc*8+1];let usize store=pc(ref p,60);var ir::Program bad=p;bad.call_count=1;
    bad.code[store*8]=9;bad.code[store*8+1]=answer;bad.code[store*8+2]=0;bad.code[store*8+3]=0;skip(ref mut bad,answer_pc);rejected_at(ref bad,store);
    var ir::Program after=p;after.call_count=1;after.code[answer_pc*8]=9;after.code[answer_pc*8+2]=0;after.code[answer_pc*8+3]=0;accepted(ref after);
}
@test
fn void builders_reject_bad_bounds_modes_and_capacity_before_emitting_any_instruction(){
    var ir::Program p=program(10,true,1,false);let usize count=p.count;let usize regs=p.registers;let usize begin=pc(ref p,61);let usize lo=p.code[begin*8+3] as usize;let usize hi=p.code[begin*8+4] as usize;
    assert(!loans::begin(ref mut p,1,0,128,hi,77).is_ok && !loans::begin(ref mut p,0,0,lo,hi,77).is_ok && !loans::end(ref mut p,1,16,77).is_ok);assert(p.count==count && p.registers==regs);
    p.slice_elements[0]=10;assert(!loans::derived(ref mut p,0,77).is_ok);p.slice_elements[0]=138;
    p.count=256;assert(!loans::begin(ref mut p,1,0,lo,hi,77).is_ok);assert(p.count==256 && p.registers==regs);
}
