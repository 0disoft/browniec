module tests::m2::value_source_mutation;
import value_source_bindings as bindings;
import value_ir as values;
import value_properties as properties;
import locals as locals;
import ir as ir;
import verifier as verifier;
import errors as errors;

fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=1;unit.catalog.count=3;
    unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(4,0,0);unit.catalog.nodes[2]=node(1,2,0);
    return unit;
}
fn usize allocated(ref mut values::Program unit,ref mut bindings::State state,usize exact_type){
    return ok(bindings::allocate(unit,state,exact_type,7));
}
fn void live(ref values::Program unit,ref mut bindings::State state,usize id){let usize initialized=ok(bindings::initialize(unit,state,id,8));}
fn void emitted(ref mut values::Program unit,u8 op,usize dst,usize a,usize b){let usize pc=ok(ir::raw(ref mut unit.body,op,dst,a,b,9));}
fn void same_state(ref bindings::State state,ref bindings::Snapshot before){
    let ref bindings::State prior=ref before.state;
    assert(state.next==prior.next && state.live==prior.live && state.names.count==prior.names.count);
    assert(state.names.function==prior.names.function && state.names.pending_places==prior.names.pending_places);
    var usize i=0;while(i<64){
        assert(state.bindings[i]==prior.bindings[i] && state.names.begins[i]==prior.names.begins[i]);
        assert(state.names.ends[i]==prior.names.ends[i] && state.names.registers[i]==prior.names.registers[i]);
        assert(state.names.mutable[i]==prior.names.mutable[i]);i+=1;
    }
}
fn void same_code(ref values::Program unit,ref u8[] code,ref usize[] offsets,usize count){
    assert(unit.body.count==count);var usize i=0;
    while(i<2048){assert(unit.body.code[i]==code[i]);i+=1;}
    i=0;while(i<256){assert(unit.body.offsets[i]==offsets[i]);i+=1;}
}
fn void finish(ref mut values::Program unit,usize result){
    emitted(unit,8,0,result,0);let usize end=unit.body.count;let usize registers=unit.body.registers;
    unit.body.ends[0]=end;unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
}

@test fn void mutable_buffer_replaces_reinitializes_and_keeps_fixed_name_slot(){
    let ref u8[] source=b"a b";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize destination=allocated(ref mut unit,ref mut state,1);
    let usize rhs=allocated(ref mut unit,ref mut state,1);
    let usize captured=allocated(ref mut unit,ref mut state,1);
    emitted(ref mut unit,95,destination,0,0);live(ref unit,ref mut state,destination);
    emitted(ref mut unit,95,rhs,0,0);live(ref unit,ref mut state,rhs);
    let usize name=ok(bindings::declare_mut(ref unit,ref mut state,source,0,1,destination,1));
    assert(state.names.mutable[name] && state.names.registers[name]==208);
    let usize before=unit.body.count;
    assert(ok(bindings::assign(ref mut unit,ref mut state,name,rhs,30))==destination);
    assert(unit.body.count==before+2 && unit.body.code[before*8]==90 && unit.body.code[before*8+1]==0);
    assert(unit.body.code[(before+1)*8]==88 && unit.body.code[(before+1)*8+1]==0 && unit.body.code[(before+1)*8+2]==1);
    assert(unit.body.offsets[before]==30 && unit.body.offsets[before+1]==30 && state.live==1);
    assert(ok(bindings::lookup(source,ref state,0,1))==name);
    assert(ok(bindings::assign(ref mut unit,ref mut state,name,destination,31))==destination);
    assert(unit.body.count==before+2 && state.live==1); // live self-assignment emits nothing
    let usize moved=ok(bindings::use_binding(ref mut unit,ref mut state,name,captured,32));
    assert(state.live==4 && state.names.mutable[name]);
    rejected(bindings::assign(ref mut unit,ref mut state,name,destination,33),3,33); // Dead self
    let usize reinit=unit.body.count;
    assert(ok(bindings::assign(ref mut unit,ref mut state,name,captured,34))==destination);
    assert(unit.body.count==reinit+1 && unit.body.code[reinit*8]==88 && state.live==1);
    assert(state.names.registers[name]==208 && state.bindings[name]==1 && state.next==3);
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,destination,35));
    emitted(ref mut unit,95,rhs,0,0);live(ref unit,ref mut state,rhs);
    let usize reinitialized=ok(bindings::assign(ref mut unit,ref mut state,name,rhs,36));
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,0,37))==1 && state.live==0);
    finish(ref mut unit,result);assert(verifier::inspect_values(ref unit).is_ok);
}

@test fn void copyable_reads_copy_but_assignment_consumes_rhs_and_immutable_names_stay_immutable(){
    let ref u8[] source=b"a b a";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize scalar=ok(ir::literal(ref mut unit.body,42,0));
    let usize destination=allocated(ref mut unit,ref mut state,0);
    let usize rhs=allocated(ref mut unit,ref mut state,0);
    emitted(ref mut unit,97,destination,scalar,0);live(ref unit,ref mut state,destination);
    let usize name=ok(bindings::declare_mut(ref unit,ref mut state,source,0,1,destination,0));
    let usize immutable=allocated(ref mut unit,ref mut state,0);
    emitted(ref mut unit,97,immutable,scalar,0);live(ref unit,ref mut state,immutable);
    let usize fixed=ok(bindings::declare(ref unit,ref mut state,source,2,3,immutable,0));
    rejected(bindings::declare_mut(ref unit,ref mut state,source,2,3,destination,0),3,2);
    assert(!state.names.mutable[fixed] && state.names.count==2);
    let usize read=unit.body.count;
    let usize copied=ok(bindings::use_binding(ref mut unit,ref mut state,name,rhs,40));
    assert(unit.body.code[read*8]==89 && state.live==7);
    let bindings::Snapshot before=bindings::snapshot(ref state);
    rejected(bindings::assign(ref mut unit,ref mut state,fixed,rhs,41),3,41);
    same_state(ref state,ref before);assert(unit.body.count==read+1);
    let usize replaced=ok(bindings::assign(ref mut unit,ref mut state,name,rhs,42));
    assert(unit.body.code[(read+1)*8]==90 && unit.body.code[(read+2)*8]==88 && state.live==5);
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,0,43))==2 && state.live==0);
    finish(ref mut unit,scalar);assert(verifier::inspect_values(ref unit).is_ok);
}

@test fn void assignment_preflights_full_budget_including_dead_and_self_destinations(){
    let ref u8[] source=b"a";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize destination=allocated(ref mut unit,ref mut state,1);
    let usize rhs=allocated(ref mut unit,ref mut state,1);
    live(ref unit,ref mut state,destination);live(ref unit,ref mut state,rhs);
    let usize name=ok(bindings::declare_mut(ref unit,ref mut state,source,0,1,destination,1));
    unit.body.count=255;unit.body.code[2040]=177;unit.body.code[2047]=178;unit.body.offsets[255]=999;
    let u8[2048] code=unit.body.code;let usize[256] offsets=unit.body.offsets;
    let bindings::Snapshot before=bindings::snapshot(ref state);
    rejected(bindings::assign(ref mut unit,ref mut state,name,rhs,50),4,50);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,255);
    unit.body.count=256;
    rejected(bindings::assign(ref mut unit,ref mut state,name,rhs,51),4,51);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,256);
    assert(ok(bindings::assign(ref mut unit,ref mut state,name,destination,52))==destination);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,256);
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,destination,53));
    let bindings::Snapshot dead=bindings::snapshot(ref state);
    rejected(bindings::assign(ref mut unit,ref mut state,name,rhs,54),4,54);
    same_state(ref state,ref dead);same_code(ref unit,ref code,ref offsets,256);
    unit.body.count=255;
    let usize reinit=ok(bindings::assign(ref mut unit,ref mut state,name,rhs,55));
    assert(unit.body.count==256 && unit.body.code[2040]==88 && state.live==1);
    // Exactly two remaining instructions admit replacement, never a partial DROP.
    live(ref unit,ref mut state,rhs);unit.body.count=254;
    let usize replaced=ok(bindings::assign(ref mut unit,ref mut state,name,rhs,56));
    assert(unit.body.count==256 && unit.body.code[2032]==90 && unit.body.code[2040]==88 && state.live==1);
}

@test fn void assignment_rejects_invalid_metadata_before_any_drop_or_move(){
    let ref u8[] source=b"a b";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize destination=allocated(ref mut unit,ref mut state,0);
    let usize rhs=allocated(ref mut unit,ref mut state,0);
    let usize wrong=allocated(ref mut unit,ref mut state,2);
    live(ref unit,ref mut state,destination);live(ref unit,ref mut state,rhs);live(ref unit,ref mut state,wrong);
    let usize name=ok(bindings::declare_mut(ref unit,ref mut state,source,0,1,destination,0));
    let usize late=ok(bindings::declare(ref unit,ref mut state,source,2,3,wrong,2));
    unit.body.code[0]=177;unit.body.offsets[0]=999;
    let u8[2048] code=unit.body.code;let usize[256] offsets=unit.body.offsets;
    var bindings::Snapshot before=bindings::snapshot(ref state);
    rejected(bindings::assign(ref mut unit,ref mut state,name,wrong,60),3,60);
    rejected(bindings::assign(ref mut unit,ref mut state,name,16,61),3,61);
    rejected(bindings::assign(ref mut unit,ref mut state,64,rhs,62),3,62);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,0);
    state.names.registers[late]=208;before=bindings::snapshot(ref state);
    rejected(bindings::assign(ref mut unit,ref mut state,name,rhs,63),3,63);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,0);
    state.bindings[late]=1;before=bindings::snapshot(ref state); // duplicate owner with matching register
    rejected(bindings::assign(ref mut unit,ref mut state,name,rhs,64),3,64);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,0);
    state.bindings[late]=3;state.names.registers[late]=210;unit.catalog.nodes[2].kind=0;
    before=bindings::snapshot(ref state);
    rejected(bindings::assign(ref mut unit,ref mut state,name,rhs,65),3,65);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,0);
    unit.catalog.nodes[2].kind=1;let usize consumed=ok(bindings::consume(ref unit,ref mut state,rhs,66));
    before=bindings::snapshot(ref state);
    rejected(bindings::assign(ref mut unit,ref mut state,name,rhs,67),3,67);
    same_state(ref state,ref before);same_code(ref unit,ref code,ref offsets,0);
}

@test fn void select_surviving_exit_after_terminal_cleanup_preserves_global_allocations_and_cfg_proof(){
    let ref u8[] source=b"parent local";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize condition=ok(ir::boolean(ref mut unit.body,true,1));
    let usize parent=allocated(ref mut unit,ref mut state,1);
    emitted(ref mut unit,95,parent,0,0);live(ref unit,ref mut state,parent);
    let usize name=ok(bindings::declare_mut(ref unit,ref mut state,source,0,6,parent,1));
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize branch=ok(ir::raw(ref mut unit.body,20,0,condition,0,70));
    let usize then_slot=allocated(ref mut unit,ref mut state,1);
    let usize moved=ok(bindings::use_binding(ref mut unit,ref mut state,name,then_slot,71));
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,then_slot,72));
    let bindings::Snapshot surviving=bindings::snapshot(ref state);
    let usize jump=ok(ir::raw(ref mut unit.body,19,0,0,0,73));
    let usize else_pc=unit.body.count;
    let usize branch_target=ok(ir::patch(ref mut unit.body,branch,else_pc,74));
    assert(ok(bindings::select_path(ref unit,ref mut state,ref entry,75))==1 && state.next==2);
    let usize local_slot=allocated(ref mut unit,ref mut state,1);assert(local_slot==2);
    emitted(ref mut unit,95,local_slot,0,0);live(ref unit,ref mut state,local_slot);
    let usize local_name=ok(bindings::declare_mut(ref unit,ref mut state,source,7,12,local_slot,1));
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,0,76))==2);
    emitted(ref mut unit,8,0,result,0); // terminal path has no surviving names/owners
    let usize join=unit.body.count;let u8[2048] code=unit.body.code;let usize[256] offsets=unit.body.offsets;
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref surviving,77),3,77);
    assert(ok(bindings::select_path(ref unit,ref mut state,ref surviving,78))==0);
    assert(state.names.count==1 && state.names.mutable[0] && state.next==3);
    assert(unit.types[then_slot]==2 && unit.types[local_slot]==2 && unit.functions[local_slot]==0);
    same_code(ref unit,ref code,ref offsets,join);
    assert(ok(bindings::merge(ref unit,ref mut state,ref surviving,79))==0);
    let usize patched=ok(ir::patch(ref mut unit.body,jump,join,80));
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,0,81));
    finish(ref mut unit,result);assert(verifier::inspect_values(ref unit).is_ok);
    // Selecting compiler metadata cannot make sequential use of the dead parent valid.
    let usize invalid_target=ok(ir::patch(ref mut unit.body,jump,else_pc,82));
    assert(!verifier::inspect_values(ref unit).is_ok);
    let usize restored=ok(ir::patch(ref mut unit.body,jump,join,83));
    let usize next=allocated(ref mut unit,ref mut state,0);assert(next==3 && state.next==4);
}

@test fn void path_selection_rejects_invalid_snapshots_atomically_and_can_restore_live_after_terminal(){
    let ref u8[] source=b"a b";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    unit.body.function_count=2;
    let usize owner=allocated(ref mut unit,ref mut state,1);live(ref unit,ref mut state,owner);
    let usize name=ok(bindings::declare_mut(ref unit,ref mut state,source,0,1,owner,1));
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize branch_slot=allocated(ref mut unit,ref mut state,1);
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,0,90));
    let bindings::Snapshot terminal=bindings::snapshot(ref state);
    let u8[2048] code=unit.body.code;let usize[256] offsets=unit.body.offsets;let usize count=unit.body.count;
    var bindings::Snapshot bad=entry;bad.state.next=3;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,91),3,91);
    bad=entry;bad.state.live=2; // later slot cannot be revived by an earlier snapshot
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,92),3,92);
    bad=entry;bad.state.bindings[0]=2;bad.state.names.registers[0]=209;bad.state.live=0;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,93),3,93); // even Dead binding must predate snapshot
    bad=entry;bad.state.names.registers[0]=209;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,94),3,94);
    bad=entry;bad.state.names.count=2;bad.state.bindings[1]=1;bad.state.names.registers[1]=208;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,95),3,95);
    bad=entry;bad.state.names.begins[0]=2;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,96),3,96);
    bad=entry;bad.state.names.count=65;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,97),3,97);
    bad=entry;bad.state.names.function=1;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,98),3,98);
    bad=entry;bad.state.live=65536;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,99),3,99);
    same_state(ref state,ref terminal);same_code(ref unit,ref code,ref offsets,count);
    state.next=1;let bindings::Snapshot stale=bindings::snapshot(ref state);
    rejected(bindings::select_path(ref unit,ref mut state,ref entry,100),3,100);
    same_state(ref state,ref stale);state.next=2;
    // Different current names need not match the independently checked entry.
    let usize ordinary=ok(locals::declare(ref mut state.names,2,3,0,false));
    assert(ok(bindings::select_path(ref unit,ref mut state,ref entry,101))==1);
    assert(state.next==2 && state.names.count==1 && state.names.mutable[name] && state.bindings[name]==1);
    same_code(ref unit,ref code,ref offsets,count);
    let usize next=allocated(ref mut unit,ref mut state,1);assert(next==2 && unit.types[branch_slot]==2);
}
