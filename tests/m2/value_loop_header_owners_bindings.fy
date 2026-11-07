module tests::m2::value_loop_header_owners_bindings;
import value_source_bindings as bindings;
import value_source_ops as ops;
import value_view_bindings as views;
import value_ir as values;
import value_properties as properties;
import errors as errors;
import ir as ir;

// Compiler metadata/helper contracts only. These fixtures are not executable CFG
// proofs. In particular, mixed() explicitly supplies the normalized possible-owner
// plane of a conditional join after allocating real Buffer slots with EMPTY95.
// Each driver calls bounded helpers; no driver keeps Program/State aggregates.
fn usize ok(Result<usize,errors::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn void rejected(Result<usize,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=1;unit.catalog.count=1;
    unit.catalog.nodes[0]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    return unit;
}
fn void planes(ref values::Program unit,ref bindings::State state,
    usize live,usize maybe,usize held,usize count){
    assert(state.live==live && state.maybe==maybe && state.loop_roots==held);
    assert(unit.body.count==count && state.pending==0 && !state.tracking);
    assert(state.kills==0 && state.generated==0 && state.required==0);
    assert(bindings::authenticate(unit,state,900).is_ok);
}
fn void canonical(ref values::Program unit,usize pc,u8 op,usize owner,usize at){
    assert(unit.body.code[pc*8]==op && unit.body.code[pc*8+1] as usize==owner);
    var usize i=2;while(i<8){assert(unit.body.code[pc*8+i]==0);i+=1;}
    assert(unit.body.offsets[pc]==at);
}
fn usize retained_seed(ref mut values::Program unit,ref mut bindings::State state,
    usize zero,usize at){
    let usize root=ok(ops::empty_buffer(unit,state,0,at));
    let usize actual=ok(views::begin(unit,ref mut state.views,root,zero,zero,at));
    // The existing trusted CALL-result metadata hook, with no native CALL proof.
    let usize result=ok(views::call_result(unit,ref mut state.views,actual,at));
    let usize closed=ok(bindings::close_view(unit,state,actual,at));
    return result;
}
fn void mixed(ref mut values::Program unit,ref mut bindings::State state,usize live){
    let usize a=ok(ops::empty_buffer(unit,state,0,1));
    let usize b=ok(ops::empty_buffer(unit,state,0,2));
    let usize c=ok(ops::empty_buffer(unit,state,0,3));
    assert(a==0 && b==1 && c==2 && (live==1 || live==5));
    state.live=live;state.maybe=7^live;
    state.views.origins[0]=25;state.views.sets[0]=7;state.views.retained=1;
    assert(bindings::authenticate(unit,state,4).is_ok);
}
fn void filtered_protection_and_definite_cleanup(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,10));
    let usize seed=retained_seed(ref mut unit,ref mut state,zero,11);
    let usize named=retained_seed(ref mut unit,ref mut state,zero,12);
    let usize name=ok(bindings::declare(ref unit,ref mut state,b"owner",0,5,1,0));
    let usize fresh=ok(ops::empty_buffer(ref mut unit,ref mut state,0,13));
    let usize raw=ok(views::begin(ref mut unit,ref mut state.views,fresh,zero,zero,14));
    let usize before=unit.body.count;
    assert(ok(bindings::protect_loop_roots(ref unit,ref mut state,15))==1);
    planes(ref unit,ref state,7,0,1,before);assert(state.names.count==1 && name==0);
    // Neither a named retained root nor an unretained anonymous root qualifies.
    assert(ok(bindings::protect_loop_roots(ref unit,ref mut state,16))==1);
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,seed,17));
    planes(ref unit,ref state,7,0,1,before+1);
    rejected(bindings::drop(ref mut unit,ref mut state,0,18),3,18);
    planes(ref unit,ref state,7,0,1,before+1);
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,19))==1);
    planes(ref unit,ref state,6,0,0,before+2);canonical(ref unit,before+1,90,0,19);
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,20))==0);
    let usize dead=ok(bindings::drop(ref mut unit,ref mut state,0,20));
    planes(ref unit,ref state,6,0,0,before+2);
    let usize named_closed=ok(bindings::close_view(ref mut unit,ref mut state,named,21));
    let usize raw_closed=ok(bindings::close_view(ref mut unit,ref mut state,raw,22));
    let usize scope=ok(bindings::leave_scope(ref mut unit,ref mut state,0,23));
    assert(state.live==0 && state.maybe==0 && state.loop_roots==0 && state.names.count==0);
}
fn void snapshots_restore_protection_without_rewinding_ir_or_ids(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    mixed(ref mut unit,ref mut state,1);
    assert(ok(bindings::protect_loop_roots(ref unit,ref mut state,30))==7);
    // One saved State in this helper; restoration selects separately reached CFG
    // metadata, never executable owner resurrection on the continuing edge.
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,0,31));
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,1,32))==6);
    let usize newer=ok(ops::empty_buffer(ref mut unit,ref mut state,0,33));
    assert(newer==3);let usize dead=ok(bindings::drop(ref mut unit,ref mut state,newer,34));
    let usize before=unit.body.count;
    planes(ref unit,ref state,1,0,1,before);
    assert(entry.state.live==1 && entry.state.maybe==6 && entry.state.loop_roots==7);
    assert(entry.state.next==3 && views::local_roots(ref entry.state.views,0)==7);
    let usize alternative=ok(bindings::begin_alternative(ref unit,ref mut state,ref entry,35));
    planes(ref unit,ref state,1,6,7,before);assert(state.next==4);
    assert(views::same(ref state.views,ref entry.state.views));
    let usize again=ok(bindings::close_view(ref mut unit,ref mut state,0,36));
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,37))==7);
    let usize terminal=unit.body.count;planes(ref unit,ref state,0,0,0,terminal);
    // A mismatched continuing mask cannot be widened by merge, even though the
    // saved view candidates and owner planes could otherwise be restored.
    rejected(bindings::merge(ref unit,ref mut state,ref entry,38),3,38);
    planes(ref unit,ref state,0,0,0,terminal);
    let usize selected=ok(bindings::select_path(ref unit,ref mut state,ref entry,39));
    planes(ref unit,ref state,1,6,7,terminal);assert(state.next==4);
    assert(views::same(ref state.views,ref entry.state.views));
    let usize merged=ok(bindings::merge(ref unit,ref mut state,ref entry,40));
    planes(ref unit,ref state,1,6,7,terminal);
    let usize final_close=ok(bindings::close_view(ref mut unit,ref mut state,0,41));
    let usize final_release=ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,42));
    assert(state.live==0 && state.maybe==0 && state.loop_roots==0 && state.next==4);
}
fn void nested_release_keeps_the_parent_mask(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    mixed(ref mut unit,ref mut state,1);
    let usize protected=ok(bindings::protect_loop_roots(ref unit,ref mut state,50));
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,0,51));
    let usize before=unit.body.count;
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,1,52))==6);
    planes(ref unit,ref state,1,0,1,before+2);
    canonical(ref unit,before,115,2,52);canonical(ref unit,before+1,115,1,52);
    rejected(bindings::drop(ref mut unit,ref mut state,0,53),3,53);
    planes(ref unit,ref state,1,0,1,before+2);
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,54))==1);
    planes(ref unit,ref state,0,0,0,before+3);canonical(ref unit,before+2,90,0,54);
}
fn void full_ir_bytes_unchanged(ref values::Program unit){
    canonical(unit,0,95,0,1);canonical(unit,1,95,1,2);canonical(unit,2,95,2,3);
    canonical(unit,3,109,0,61);
    var usize pc=4;while(pc<255){canonical(unit,pc,82,0,62);pc+=1;}
    canonical(unit,255,177,0,999);
}
fn void loan_ir_bytes_unchanged(ref values::Program unit){
    canonical(unit,0,95,0,1);canonical(unit,1,95,1,2);canonical(unit,2,95,2,3);
    canonical(unit,3,109,0,71);canonical(unit,4,177,0,999);
    var usize pc=5;while(pc<256){canonical(unit,pc,0,0,0);pc+=1;}
}
fn void full_ir_release_rejects_before_any_retirement(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    mixed(ref mut unit,ref mut state,1);
    let usize protected=ok(bindings::protect_loop_roots(ref unit,ref mut state,60));
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,0,61));
    while(unit.body.count<255){let usize pad=ok(ir::raw(ref mut unit.body,82,0,0,0,62));}
    unit.body.code[255*8]=177;unit.body.offsets[255]=999;
    // One remaining instruction is insufficient for the entire three-root sweep.
    rejected(bindings::release_loop_roots(ref mut unit,ref mut state,0,63),4,63);
    planes(ref unit,ref state,1,6,7,255);
    full_ir_bytes_unchanged(ref unit);
    unit.body.count=256;
    rejected(bindings::release_loop_roots(ref mut unit,ref mut state,0,64),4,64);
    planes(ref unit,ref state,1,6,7,256);
    full_ir_bytes_unchanged(ref unit);
    rejected(bindings::drop(ref mut unit,ref mut state,0,65),3,65);
    rejected(bindings::drop(ref mut unit,ref mut state,1,66),3,66);
    planes(ref unit,ref state,1,6,7,256);full_ir_bytes_unchanged(ref unit);
}
fn void loan_release_rejects_before_mask_or_code_publication(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    mixed(ref mut unit,ref mut state,5);
    let usize protected=ok(bindings::protect_loop_roots(ref unit,ref mut state,70));
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,0,71));
    let usize before=unit.body.count;
    unit.body.code[before*8]=177;unit.body.offsets[before]=999;
    // Lowest-ID loan would otherwise be discovered after higher IDs retired.
    state.reads=1;
    rejected(bindings::release_loop_roots(ref mut unit,ref mut state,0,72),3,72);
    planes(ref unit,ref state,5,2,7,before);assert(state.reads==1 && state.writes==0);
    loan_ir_bytes_unchanged(ref unit);
    state.reads=0;state.writes=1;
    rejected(bindings::release_loop_roots(ref mut unit,ref mut state,0,73),3,73);
    planes(ref unit,ref state,5,2,7,before);assert(state.reads==0 && state.writes==1);
    loan_ir_bytes_unchanged(ref unit);
    state.writes=0;
    rejected(bindings::release_loop_roots(ref mut unit,ref mut state,8,74),3,74);
    planes(ref unit,ref state,5,2,7,before);
    loan_ir_bytes_unchanged(ref unit);
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,75))==7);
    planes(ref unit,ref state,0,0,0,before+3);
}
fn void reverse_retirement_and_idempotence(usize live){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    mixed(ref mut unit,ref mut state,live);
    let usize protected=ok(bindings::protect_loop_roots(ref unit,ref mut state,80));
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,0,81));
    let usize before=unit.body.count;
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,82))==7);
    planes(ref unit,ref state,0,0,0,before+3);
    canonical(ref unit,before,if(live==5){90}else{115},2,82);
    canonical(ref unit,before+1,115,1,82);canonical(ref unit,before+2,90,0,82);
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,83))==0);
    var usize i=0;while(i<3){let usize dead=ok(bindings::drop(ref mut unit,ref mut state,i,84));i+=1;}
    planes(ref unit,ref state,0,0,0,before+3);
    canonical(ref unit,before,if(live==5){90}else{115},2,82);
    canonical(ref unit,before+1,115,1,82);canonical(ref unit,before+2,90,0,82);
}
fn void released_candidates_wait_for_the_actual_last_descriptor(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    mixed(ref mut unit,ref mut state,1);
    let usize protected=ok(bindings::protect_loop_roots(ref unit,ref mut state,90));
    let usize alias=ok(views::alias(ref mut unit,ref mut state.views,0,91));
    let usize before=unit.body.count;
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,92))==7);
    planes(ref unit,ref state,1,6,0,before);assert(views::count(ref state.views)==2);
    let usize first=ok(bindings::close_view(ref mut unit,ref mut state,0,93));
    planes(ref unit,ref state,1,6,0,before+1);
    let usize last=ok(bindings::close_view(ref mut unit,ref mut state,alias,94));
    planes(ref unit,ref state,0,0,0,before+5);
    canonical(ref unit,before+2,115,2,94);canonical(ref unit,before+3,115,1,94);
    canonical(ref unit,before+4,90,0,94);assert(views::count(ref state.views)==0);
    assert(ok(bindings::release_loop_roots(ref mut unit,ref mut state,0,95))==0);
    var usize i=0;while(i<3){let usize dead=ok(bindings::drop(ref mut unit,ref mut state,i,96));i+=1;}
    planes(ref unit,ref state,0,0,0,before+5);
}
@test fn void protection_snapshots_branch_selection_and_parent_masks_preserve_owner_planes(){
    filtered_protection_and_definite_cleanup();
    snapshots_restore_protection_without_rewinding_ir_or_ids();
    nested_release_keeps_the_parent_mask();
}
@test fn void protected_drop_release_atomicity_reverse_cleanup_and_last_alias_are_exact(){
    full_ir_release_rejects_before_any_retirement();
    loan_release_rejects_before_mask_or_code_publication();
    reverse_retirement_and_idempotence(1);reverse_retirement_and_idempotence(5);
    released_candidates_wait_for_the_actual_last_descriptor();
}
