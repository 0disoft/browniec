module tests::m2::slice_place_ir;

import ir as ir;
import errors as errors;
import slice_place_ir as places;
import slice_builders as builders;
import slice_reborrow_ir as loans;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import place_vm as place_vm;
import array_vm as arrays;
import slice_vm as slices;
import slice_call_vm as calls;
import slice_mutable_call_vm as mutable;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void error(Result<usize,errors::Error> r,u8 kind,usize at){
    assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn void finish(ref mut ir::Program p,usize f){
    let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;
}
fn usize pc(ref ir::Program p,u8 op,usize from){
    var usize i=from;while(i<p.count){if(p.code[i*8]==op){return i;}i+=1;}
    assert(false);return 0;
}
fn usize scalar(ref mut ir::Program p,u8 tag,i64 cell){
    if(tag==2){return built(ir::boolean(p,cell!=0,0));}
    return built(ir::integer(p,cell,tag,0));
}
fn void analysis(ref ir::Program p){
    assert(switch(verifier::inspect_slice_places(p)){case .ok(n):{n==p.count}case .err(_):{false}});
}
fn void rejected(ref ir::Program p){
    assert(!verifier::inspect_slice_places(p).is_ok);
}
fn void rejected_at(ref ir::Program p,usize at){
    assert(switch(verifier::inspect_slice_places(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==at}});
}

// A rooted exclusive site is opened before the place is selected. The common
// END must precede the ordinary slice close.
fn ir::Program rooted(u8 tag,u8 mode){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize root=built(ir::array_in(ref mut p,0,tag,2,true,0));
    let usize fill=scalar(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize site=built(ir::exclusive_slice(ref mut p,root,0));
    let usize opened=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize cell=scalar(ref mut p,tag,42);
    let usize selected=built(places::select(ref mut p,0,site,index,0));
    if(mode==0){
        let usize old=built(places::read(ref mut p,0,site,0));
        let usize stored=built(places::store(ref mut p,0,site,cell,0));
    }else if(mode==1){
        let usize first=built(places::read(ref mut p,0,site,0));
        let usize second=built(places::read(ref mut p,0,site,0));
    }else if(mode==2){
        let usize first=built(places::store(ref mut p,0,site,cell,0));
        let usize second=built(places::store(ref mut p,0,site,cell,0));
    }else{
        let usize stored=built(places::store(ref mut p,0,site,cell,0));
        let usize old=built(places::read(ref mut p,0,site,0));
    }
    let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize closed=built(ir::slice_close(ref mut p,site,0));
    let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize answer=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}

fn ir::Program formal_parent(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize site=built(builders::parameter_exclusive(ref mut p,0,1,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize cell=built(ir::integer(ref mut p,42,1,0));
    let usize selected=built(places::select(ref mut p,0,site,index,0));
    let usize old=built(places::read(ref mut p,0,site,0));let usize stored=built(places::store(ref mut p,0,site,cell,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize closed=built(ir::slice_close(ref mut p,site,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize entry=built(ir::literal(ref mut p,42,0));let usize done=built(ir::emit(ref mut p,8,entry,0,0));finish(ref mut p,1);return p;
}

// Rootless exclusive formals use their child ticket for the place. A derived
// child is valid only after BEGIN, and its END follows the common place END.
fn ir::Program formal_child(bool guard_end){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize parent=built(builders::parameter_exclusive(ref mut p,0,10,0));
    let usize child=built(loans::derived(ref mut p,parent,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize began=built(loans::begin(ref mut p,child,parent,lo,hi,0));
    let usize index=built(ir::integer(ref mut p,99,12,0));let usize value=built(ir::integer(ref mut p,42,10,0));
    let usize selected=built(places::select(ref mut p,0,child,index,0));
    let usize old=built(places::read(ref mut p,0,child,0));let usize stored=built(places::store(ref mut p,0,child,value,0));
    if(guard_end){let usize ended_child=built(loans::end(ref mut p,child,parent,0));let usize ended=built(ir::place_end(ref mut p,0,0));}
    else{let usize ended=built(ir::place_end(ref mut p,0,0));let usize ended_child=built(loans::end(ref mut p,child,parent,0));}
    let usize closed=built(ir::slice_close(ref mut p,parent,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize entry=built(ir::literal(ref mut p,42,0));let usize done=built(ir::emit(ref mut p,8,entry,0,0));finish(ref mut p,1);return p;
}

// The parent place stays pending while the child is live. It is usable after
// the child is restored, but never while the parent is suspended.
fn ir::Program formal_pending(bool suspended,bool store_child){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize parent=built(builders::parameter_exclusive(ref mut p,0,10,0));let usize child=built(loans::derived(ref mut p,parent,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=built(ir::integer(ref mut p,7,10,0));
    let usize selected=built(places::select(ref mut p,0,parent,index,0));let usize began=built(loans::begin(ref mut p,child,parent,lo,hi,0));
    if(suspended){if(store_child){let usize stored=built(places::store(ref mut p,0,parent,value,0));}
        else{let usize old=built(places::read(ref mut p,0,parent,0));}}
    else{let usize ended_child=built(loans::end(ref mut p,child,parent,0));
        let usize old=built(places::read(ref mut p,0,parent,0));let usize stored=built(places::store(ref mut p,0,parent,value,0));}
    let usize ended=built(ir::place_end(ref mut p,0,0));
    if(suspended){let usize ended_child=built(loans::end(ref mut p,child,parent,0));}
    let usize closed=built(ir::slice_close(ref mut p,parent,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize entry=built(ir::literal(ref mut p,42,0));let usize done=built(ir::emit(ref mut p,8,entry,0,0));finish(ref mut p,1);return p;
}

fn ir::Program formal_pending_call(){
    var ir::Program p=ir::empty();p.function_count=3;p.entry=2;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;p.return_types[2]=1;
    let usize parent=built(builders::parameter_exclusive(ref mut p,0,1,0));let usize child=built(loans::derived(ref mut p,parent,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=built(ir::integer(ref mut p,7,1,0));
    let usize selected=built(places::select(ref mut p,0,parent,index,0));let usize began=built(loans::begin(ref mut p,child,parent,lo,hi,0));
    let usize[1] none=[0];let usize called=built(ir::call(ref mut p,1,ref none[..0],0));
    let usize ended_child=built(loans::end(ref mut p,child,parent,0));
    let usize old=built(places::read(ref mut p,0,parent,0));let usize stored=built(places::store(ref mut p,0,parent,value,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize closed=built(ir::slice_close(ref mut p,parent,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);
    let usize callee_start=p.count;let usize callee_regs=p.registers;p.starts[1]=callee_start;p.register_starts[1]=callee_regs;
    let usize callee_value=built(ir::literal(ref mut p,42,0));let usize callee_done=built(ir::emit(ref mut p,8,callee_value,0,0));finish(ref mut p,1);
    let usize entry_start=p.count;let usize entry_regs=p.registers;p.starts[2]=entry_start;p.register_starts[2]=entry_regs;
    let usize entry_value=built(ir::literal(ref mut p,42,0));let usize entry_done=built(ir::emit(ref mut p,8,entry_value,0,0));finish(ref mut p,2);return p;
}

fn ir::Program two_sites(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize root0=built(ir::array_in(ref mut p,0,1,2,true,0));let usize root1=built(ir::array_in(ref mut p,0,1,2,true,0));
    let usize fill=built(ir::integer(ref mut p,0,1,0));let usize init0=built(ir::array_init(ref mut p,root0,fill,0));let usize init1=built(ir::array_init(ref mut p,root1,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize site0=built(ir::exclusive_slice(ref mut p,root0,0));let usize site1=built(ir::exclusive_slice(ref mut p,root1,0));
    let usize open0=built(ir::slice_open(ref mut p,site0,lo,hi,0));let usize open1=built(ir::slice_open(ref mut p,site1,lo,hi,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=built(ir::integer(ref mut p,42,1,0));
    let usize selected=built(places::select(ref mut p,0,site0,index,0));let usize old=built(places::read(ref mut p,0,site0,0));let usize stored=built(places::store(ref mut p,0,site0,value,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize close0=built(ir::slice_close(ref mut p,site0,0));let usize close1=built(ir::slice_close(ref mut p,site1,0));
    let usize drop0=built(ir::array_drop(ref mut p,root0,0));let usize drop1=built(ir::array_drop(ref mut p,root1,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}

// Root 0 is deliberately unborrowed while site 0 borrows root 1. Both places
// therefore use ordinal 0, so the common graph must compare kind as well as ID.
fn ir::Program mixed(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize root0=built(ir::array_in(ref mut p,0,1,2,true,0));let usize root1=built(ir::array_in(ref mut p,0,1,2,true,0));
    let usize fill=built(ir::integer(ref mut p,0,1,0));let usize init0=built(ir::array_init(ref mut p,root0,fill,0));let usize init1=built(ir::array_init(ref mut p,root1,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));let usize site=built(ir::exclusive_slice(ref mut p,root1,0));let usize opened=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize condition=built(ir::boolean(ref mut p,false,0));
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    let usize new_select=built(places::select(ref mut p,0,site,index,0));let usize skip=built(ir::raw(ref mut p,19,0,0,0,0));
    let usize old_select=built(ir::place_select(ref mut p,0,root0,index,0));let usize join=p.count;
    let usize target_old=built(ir::patch(ref mut p,branch,old_select,0));let usize target_join=built(ir::patch(ref mut p,skip,join,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize closed=built(ir::slice_close(ref mut p,site,0));let usize drop0=built(ir::array_drop(ref mut p,root0,0));let usize drop1=built(ir::array_drop(ref mut p,root1,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}

fn ir::Program looped(bool omit_end){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize root=built(ir::array_in(ref mut p,0,1,2,true,0));let usize fill=built(ir::integer(ref mut p,0,1,0));let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));let usize site=built(ir::exclusive_slice(ref mut p,root,0));let usize opened=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=built(ir::integer(ref mut p,42,1,0));let usize begin=p.count;
    let usize selected=built(places::select(ref mut p,0,site,index,0));let usize old=built(places::read(ref mut p,0,site,0));let usize stored=built(places::store(ref mut p,0,site,value,0));
    if(!omit_end){let usize ended=built(ir::place_end(ref mut p,0,0));}
    let usize condition=built(ir::boolean(ref mut p,false,0));let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));let usize back=built(ir::raw(ref mut p,22,0,begin,0,0));let usize after=p.count;let usize target=built(ir::patch(ref mut p,branch,after,0));
    let usize closed=built(ir::slice_close(ref mut p,site,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}

// Both kind/ordinal pairs are canonically live and have the same element type.
// A mistagged use must fail the independent SELECT identity comparison alone.
fn ir::Program mixed_uses(bool wrong_read,bool wrong_store){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize array=built(ir::array_in(ref mut p,0,1,2,true,0));
    let usize borrowed=built(ir::array_in(ref mut p,0,1,2,true,0));
    let usize fill=built(ir::literal(ref mut p,42,0));
    let usize first=built(ir::array_init(ref mut p,array,fill,0));
    let usize second=built(ir::array_init(ref mut p,borrowed,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize site=built(ir::exclusive_slice(ref mut p,borrowed,0));
    let usize opened=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize selected=built(places::select(ref mut p,0,site,lo,0));
    let usize read_pc=p.count;let usize old=built(places::read(ref mut p,0,site,0));
    if(wrong_read){p.code[read_pc*8+4]=0;}
    let usize store_pc=built(places::store(ref mut p,0,site,fill,0));
    if(wrong_store){p.code[store_pc*8+4]=0;}
    let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize array_place=built(ir::place_select(ref mut p,0,array,lo,0));
    // Closing site zero must not end an unrelated selected array zero.
    let usize closed=built(ir::slice_close(ref mut p,site,0));
    let usize stored=built(ir::place_store(ref mut p,0,array,fill,0));
    let usize array_end=built(ir::place_end(ref mut p,0,0));
    let usize drop_first=built(ir::array_drop(ref mut p,array,0));
    let usize drop_second=built(ir::array_drop(ref mut p,borrowed,0));
    let usize returned=built(ir::emit(ref mut p,8,fill,0,0));finish(ref mut p,0);return p;
}

@test
fn void repeated_operand_kind_is_checked_even_when_both_same_ordinals_are_live(){
    let ir::Program good=mixed_uses(false,false);analysis(ref good);
    let ir::Program read=mixed_uses(true,false);rejected_at(ref read,pc(ref read,84,0));
    let ir::Program store=mixed_uses(false,true);rejected_at(ref store,pc(ref store,85,0));
}

@test
fn void six_scalar_domains_rooted_places_use_the_shared_end_and_analysis_only_admission(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
    while(i<6){let ir::Program p=rooted(tags[i],0);analysis(ref p);
        let usize selected=pc(ref p,83,0);let usize read=pc(ref p,84,0);let usize stored=pc(ref p,85,0);let usize ended=pc(ref p,86,0);
        assert(p.code[selected*8+4]==1 && p.code[selected*8+5]==0 && p.code[selected*8+6]==0 && p.code[selected*8+7]==0);
        assert(p.code[read*8+4]==1 && p.code[read*8+5]==0 && p.code[stored*8+4]==1 && p.code[stored*8+5]==0);
        assert(p.code[ended*8+4]==0 && p.code[ended*8+5]==0);i+=1;
    }
}

@test
fn void rootless_exclusive_formals_and_derived_children_prove_exact_elements_and_ir_ranges(){
    let ir::Program parent=formal_parent();analysis(ref parent);
    let ir::Program child=formal_child(false);analysis(ref child);
    let usize selected=pc(ref child,83,0);assert(child.code[selected*8+4]==1);
    assert(child.slice_elements[1]==138 && child.slice_roots[0]==0 && child.slice_origins[1]==1);
    // The 99 index and the full-range child are legal analysis facts; no native
    // backing is present, so bounds belong to a later runtime check.
    let ir::Program guarded=formal_child(true);rejected_at(ref guarded,pc(ref guarded,62,0));
}

@test
fn void parent_place_survives_child_lifetimes_and_call_but_not_suspended_access(){
    let ir::Program available=formal_pending(false,false);analysis(ref available);
    let ir::Program called=formal_pending_call();analysis(ref called);
    let ir::Program blocked=formal_pending(true,false);let usize read=pc(ref blocked,84,0);rejected_at(ref blocked,read);
    let ir::Program blocked_store=formal_pending(true,true);let usize store=pc(ref blocked_store,85,0);rejected_at(ref blocked_store,store);
}

@test
fn void phase_proof_rejects_second_read_double_store_and_read_after_store(){
    let ir::Program twice_read=rooted(1,1);let usize first=pc(ref twice_read,84,0);let usize second=pc(ref twice_read,84,first+1);rejected_at(ref twice_read,second);
    let ir::Program twice_store=rooted(1,2);let usize first_store=pc(ref twice_store,85,0);let usize second_store=pc(ref twice_store,85,first_store+1);rejected_at(ref twice_store,second_store);
    let ir::Program after_store=rooted(1,3);let usize store=pc(ref after_store,85,0);let usize read=pc(ref after_store,84,store+1);rejected_at(ref after_store,read);
}

@test
fn void close_and_derived_end_guards_use_the_common_place_graph_not_dead_cleanup(){
    var ir::Program closed=rooted(1,0);let usize end=pc(ref closed,86,0);let usize close=pc(ref closed,56,0);
    let u8 place=closed.code[end*8+1];let u8 site=closed.code[close*8+1];
    closed.code[end*8]=56;closed.code[end*8+1]=site;closed.code[end*8+2]=0;closed.code[end*8+3]=0;closed.code[end*8+4]=0;closed.code[end*8+5]=0;closed.code[end*8+6]=0;closed.code[end*8+7]=0;
    closed.code[close*8]=86;closed.code[close*8+1]=place;closed.code[close*8+2]=0;closed.code[close*8+3]=0;closed.code[close*8+4]=0;closed.code[close*8+5]=0;closed.code[close*8+6]=0;closed.code[close*8+7]=0;rejected_at(ref closed,end);
    var ir::Program child=formal_child(false);let usize place_end=pc(ref child,86,0);let usize child_end=pc(ref child,62,0);
    let u8 child_place=child.code[place_end*8+1];let u8 child_site=child.code[child_end*8+1];
    child.code[place_end*8]=62;child.code[place_end*8+1]=child_site;child.code[place_end*8+2]=0;child.code[place_end*8+3]=0;child.code[place_end*8+4]=0;child.code[place_end*8+5]=0;child.code[place_end*8+6]=0;child.code[place_end*8+7]=0;
    child.code[child_end*8]=86;child.code[child_end*8+1]=child_place;child.code[child_end*8+2]=0;child.code[child_end*8+3]=0;child.code[child_end*8+4]=0;child.code[child_end*8+5]=0;child.code[child_end*8+6]=0;child.code[child_end*8+7]=0;rejected_at(ref child,place_end);
}

@test
fn void complete_proof_rejects_kind_site_type_definedness_slots_and_placeholders(){
    var ir::Program p=rooted(1,0);let usize selected=pc(ref p,83,0);let usize read=pc(ref p,84,0);let usize store=pc(ref p,85,0);let usize index=p.code[selected*8+3] as usize;let usize value=p.code[store*8+3] as usize;
    p.code[selected*8+4]=0;rejected_at(ref p,selected);p.code[selected*8+4]=1;
    p.code[read*8+4]=0;rejected_at(ref p,read);p.code[read*8+4]=1;
    let usize read_value=p.code[read*8+1] as usize;
    p.types[read_value]=2;rejected_at(ref p,read);p.types[read_value]=1;
    p.slots[index]=true;rejected(ref p);p.slots[index]=false;
    p.array_parameters[index]=1;rejected(ref p);p.array_parameters[index]=0;
    p.record_parameters[index]=1;rejected(ref p);p.record_parameters[index]=0;
    p.slice_parameters[index]=1;rejected(ref p);p.slice_parameters[index]=0;
    p.slots[value]=true;rejected(ref p);p.slots[value]=false;
    p.array_parameters[value]=1;rejected(ref p);p.array_parameters[value]=0;
    p.types[value]=12;rejected_at(ref p,store);p.types[value]=1;
    let u8 answer=p.code[(p.ends[0]-1)*8+2];let u8 original_value=p.code[store*8+3];
    p.code[store*8+3]=answer;rejected_at(ref p,store);p.code[store*8+3]=original_value;
    // Move the index definition past SELECT without changing its scalar type.
    let usize definition=pc(ref p,54,0)+1;var usize byte=0;
    while(byte<8){let u8 saved=p.code[definition*8+byte];let u8 other=p.code[selected*8+byte];
        p.code[definition*8+byte]=other;p.code[selected*8+byte]=saved;byte+=1;}
    rejected_at(ref p,definition);
    let ir::Program q=two_sites();analysis(ref q);let usize qread=pc(ref q,84,0);let usize qstore=pc(ref q,85,0);var ir::Program bad=q;bad.code[qread*8+3]=1;rejected_at(ref bad,qread);
    var ir::Program bad_store=q;bad_store.code[qstore*8+2]=1;rejected_at(ref bad_store,qstore);
}

@test
fn void malformed_tags_builder_atomic_limits_and_legacy_array_adapter_rejection_remain(){
    var ir::Program p=rooted(1,0);let usize selected=pc(ref p,83,0);let usize read=pc(ref p,84,0);let usize store=pc(ref p,85,0);let usize ended=pc(ref p,86,0);
    p.code[selected*8+4]=2;rejected_at(ref p,selected);p.code[selected*8+4]=1;
    p.code[read*8+5]=1;rejected_at(ref p,read);p.code[read*8+5]=0;
    p.code[ended*8+4]=1;rejected_at(ref p,ended);p.code[ended*8+4]=0;
    let usize count=p.count;let usize regs=p.registers;let usize constants=p.constant_count;let u8 first=p.code[selected*8];let u8 marker=p.code[selected*8+4];let usize site=p.code[selected*8+2] as usize;let usize index=p.code[selected*8+3] as usize;let usize value=p.code[store*8+3] as usize;
    error(places::select(ref mut p,16,site,index,77),3,77);assert(p.count==count && p.registers==regs && p.constant_count==constants && p.code[selected*8]==first && p.code[selected*8+4]==marker);
    error(places::select(ref mut p,0,16,index,77),3,77);error(places::select(ref mut p,0,site,128,77),3,77);
    error(places::read(ref mut p,16,site,77),3,77);error(places::store(ref mut p,0,site,index,77),3,77);error(ir::place_end(ref mut p,16,77),3,77);
    var ir::Program full=rooted(1,0);full.count=256;let usize full_count=full.count;let usize full_regs=full.registers;
    error(places::select(ref mut full,0,0,index,77),4,77);error(places::read(ref mut full,0,0,77),4,77);error(places::store(ref mut full,0,0,value,77),4,77);assert(full.count==full_count && full.registers==full_regs);
    var ir::Program narrow=rooted(1,0);narrow.registers=128;let usize original_count=narrow.count;error(places::read(ref mut narrow,0,0,77),4,77);assert(narrow.count==original_count && narrow.registers==128);
    let ir::Program gate=rooted(1,0);let usize gate_select=pc(ref gate,83,0);
    assert(switch(place_vm::requirement(ref gate)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==gate_select}});
    assert(switch(place_vm::cost(ref gate,gate_select)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==gate_select}});
    assert(switch(vm::run(ref gate,0)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run(ref gate,1000000)){case .ok(v):{v==42}case .err(_):{false}});
    var arrays::State a=arrays::empty(0);var bytes::Buffer b=bytes::empty();var slices::State l=slices::empty();var calls::Frames f=calls::empty();var mutable::Frame[32] receipts=[mutable::empty();32];
    assert(switch(execution::execute(ref gate,0,ref mut a,ref mut b,ref mut l,ref mut f)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(execution::execute_mutable(ref gate,0,ref mut a,ref mut b,ref mut l,ref mut f,ref mut receipts)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(a.owners.depth==0 && a.owners.arena.used==0 && bytes::len(ref b)==0 && !l.pool.slots[0].live);
}

@test
fn void mixed_kind_ordinal_identity_joins_and_backedges_require_same_selected_pc_phase(){
    let ir::Program mixed_kind=mixed();let usize new_select=pc(ref mixed_kind,83,0);let usize old_select=pc(ref mixed_kind,83,new_select+1);
    assert(mixed_kind.code[new_select*8+4]==1 && mixed_kind.code[old_select*8+4]==0);rejected(ref mixed_kind);
    let ir::Program valid_loop=looped(false);analysis(ref valid_loop);
    let ir::Program invalid_loop=looped(true);let usize back=pc(ref invalid_loop,22,0);rejected_at(ref invalid_loop,back);
}

