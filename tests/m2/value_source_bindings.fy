module tests::m2::value_source_bindings;
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
    unit.body.function_count=1;
    unit.catalog.count=6;unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(4,0,0);
    unit.catalog.nodes[2]=node(5,1,0);unit.catalog.nodes[3]=node(6,0,1);
    unit.catalog.nodes[4]=node(5,0,0);unit.catalog.nodes[5]=node(1,2,0);
    return unit;
}
fn usize allocated(ref mut values::Program unit,ref mut bindings::State state,usize exact_type){
    return ok(bindings::allocate(unit,state,exact_type,7));
}
fn void live(ref values::Program unit,ref mut bindings::State state,usize id){let usize initialized=ok(bindings::initialize(unit,state,id,8));}
fn void emitted(ref mut values::Program unit,u8 op,usize dst,usize a,usize b){let usize pc=ok(ir::raw(ref mut unit.body,op,dst,a,b,9));}
fn void unchanged(ref values::Program unit,ref bindings::State state,usize count,usize bits,usize next,usize names){
    assert(unit.body.count==count && state.live==bits && state.next==next && state.names.count==names);
}

@test fn void names_share_locals_rules_exact_types_and_bounded_atomic_publication(){
    let ref u8[] source=b"alpha beta alpha let gamma";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize a=allocated(ref mut unit,ref mut state,1);live(ref unit,ref mut state,a);
    let usize first=ok(bindings::declare(ref unit,ref mut state,source,0,5,a,1));assert(first==0);
    assert(state.names.begins[0]==0 && state.names.ends[0]==5 && !state.names.mutable[0]);
    assert(ok(bindings::lookup(source,ref state,11,16))==first);
    // An inner scope cannot shadow an active name, matching compiler.fy.
    let usize scope=state.names.count;
    let usize b=allocated(ref mut unit,ref mut state,1);live(ref unit,ref mut state,b);
    rejected(bindings::declare(ref unit,ref mut state,source,11,16,b,1),3,11);
    rejected(bindings::declare(ref unit,ref mut state,source,6,10,b,2),3,6);
    rejected(bindings::declare(ref unit,ref mut state,source,17,20,b,1),2,17);
    rejected(bindings::declare(ref unit,ref mut state,source,25,999,b,1),2,25);
    rejected(bindings::declare(ref unit,ref mut state,source,6,10,a,1),3,6); // no second name for one owner
    unchanged(ref unit,ref state,0,3,2,scope);
    let usize ordinary=ok(locals::declare(ref mut state.names,6,10,0,false));assert(ordinary==1);
    rejected(bindings::declare(ref unit,ref mut state,source,6,10,b,1),3,6);
    rejected(bindings::lookup(source,ref state,6,10),3,6);
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,0,29));assert(cleaned==1);
    // A name can be reused after scope exit, with a different independent slot.
    let usize reused=ok(bindings::declare(ref unit,ref mut state,source,11,16,b,1));assert(reused==0);
    let usize c=allocated(ref mut unit,ref mut state,1);live(ref unit,ref mut state,c);
    state.names.count=64; // 63 ordinary hidden captures plus the typed name
    rejected(bindings::declare(ref unit,ref mut state,source,21,26,c,1),4,21);
    unchanged(ref unit,ref state,1,6,3,64);assert(state.bindings[63]==0);
    // Invalid catalog admission cannot publish a slot or cursor.
    unit.catalog.nodes[5].kind=0;
    rejected(bindings::allocate(ref mut unit,ref mut state,1,31),3,31);
    assert(unit.types[3]==0 && state.next==3);
}

@test fn void whole_types_select_copy_or_move_including_inactive_buffer_and_verify_actual_ir(){
    let ref u8[] source=b"a b c d";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize scalar=ok(ir::literal(ref mut unit.body,42,0));
    let usize a=allocated(ref mut unit,ref mut state,1);let usize ad=allocated(ref mut unit,ref mut state,1);
    let usize b=allocated(ref mut unit,ref mut state,2);let usize bd=allocated(ref mut unit,ref mut state,2);
    let usize c=allocated(ref mut unit,ref mut state,3);let usize cd=allocated(ref mut unit,ref mut state,3);
    let usize d=allocated(ref mut unit,ref mut state,4);let usize dd=allocated(ref mut unit,ref mut state,4);
    let usize payload=allocated(ref mut unit,ref mut state,0);
    emitted(ref mut unit,95,a,0,0);live(ref unit,ref mut state,a);
    emitted(ref mut unit,91,b,0,0);live(ref unit,ref mut state,b); // Option<Buffer>.none
    emitted(ref mut unit,97,payload,scalar,0);live(ref unit,ref mut state,payload);
    emitted(ref mut unit,91,c,payload,1);live(ref unit,ref mut state,c); // Result<i32,Buffer>.ok
    emitted(ref mut unit,91,d,payload,1);live(ref unit,ref mut state,d); // Option<i32>.some
    let usize ai=ok(bindings::declare(ref unit,ref mut state,source,0,1,a,1));
    let usize bi=ok(bindings::declare(ref unit,ref mut state,source,2,3,b,2));
    let usize ci=ok(bindings::declare(ref unit,ref mut state,source,4,5,c,3));
    let usize di=ok(bindings::declare(ref unit,ref mut state,source,6,7,d,4));
    let usize before=unit.body.count;let usize bits=state.live;
    unit.body.code[before*8]=177;unit.body.offsets[before]=777;
    rejected(bindings::use_binding(ref mut unit,ref mut state,ai,bd,43),3,43);
    unchanged(ref unit,ref state,before,bits,9,4);
    assert(unit.body.code[before*8]==177 && unit.body.offsets[before]==777);
    let usize moved=ok(bindings::use_binding(ref mut unit,ref mut state,ai,ad,44));
    assert(unit.body.code[before*8]==88 && unit.body.offsets[before]==44);
    let usize none=ok(bindings::use_binding(ref mut unit,ref mut state,bi,bd,45));
    let usize inactive=ok(bindings::use_binding(ref mut unit,ref mut state,ci,cd,46));
    let usize copied=ok(bindings::use_binding(ref mut unit,ref mut state,di,dd,47));
    assert(unit.body.code[(before+1)*8]==88 && unit.body.code[(before+2)*8]==88);
    assert(unit.body.code[(before+3)*8]==89 && (state.live&64)!=0);
    assert(ok(bindings::lookup(source,ref state,0,1))==ai); // moved name remains visible
    rejected(bindings::use_binding(ref mut unit,ref mut state,ai,a,48),3,48);
    rejected(bindings::use_binding(ref mut unit,ref mut state,di,dd,49),3,49); // Live destination
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,0,50));assert(cleaned==1);
    var usize i=0;while(i<state.next){let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,i,51));i+=1;}
    assert(state.live==0);
    emitted(ref mut unit,8,0,scalar,0);
    let usize end=unit.body.count;let usize registers=unit.body.registers;
    unit.body.ends[0]=end;unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
    assert(verifier::inspect_values(ref unit).is_ok);
}

@test fn void cleanup_is_reverse_live_only_and_capacity_rejection_is_atomic(){
    let ref u8[] source=b"a b c";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    var usize i=0;while(i<3){let usize id=allocated(ref mut unit,ref mut state,1);live(ref unit,ref mut state,id);
        let usize named=ok(bindings::declare(ref unit,ref mut state,source,i*2,i*2+1,id,1));i+=1;}
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,1,60)); // call/return already admitted
    rejected(bindings::consume(ref unit,ref mut state,1,61),3,61);
    let usize count=unit.body.count;
    let usize dead_drop=ok(bindings::drop(ref mut unit,ref mut state,1,62));assert(unit.body.count==count);
    unit.body.count=255;unit.body.code[2040]=177;unit.body.offsets[255]=999;
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,63),4,63);
    unchanged(ref unit,ref state,255,5,3,3);assert(unit.body.code[2040]==177 && unit.body.offsets[255]==999);
    rejected(bindings::leave_scope(ref mut unit,ref mut state,4,64),3,64);
    // A late malformed binding cannot leave the earlier live owner half-dropped.
    unit.body.count=0;state.bindings[0]=17;
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,65),3,65);
    unchanged(ref unit,ref state,0,5,3,3);state.bindings[0]=1;
    unit.body.count=256;
    rejected(bindings::use_binding(ref mut unit,ref mut state,0,1,66),4,66);
    rejected(bindings::drop(ref mut unit,ref mut state,0,67),4,67);
    unchanged(ref unit,ref state,256,5,3,3);
    unit.body.count=254;
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,0,68))==2);
    assert(unit.body.count==256 && unit.body.code[2032]==90 && unit.body.code[2033]==2);
    assert(unit.body.code[2040]==90 && unit.body.code[2041]==0 && unit.body.offsets[255]==68);
    assert(state.names.count==0 && state.live==0 && state.next==3);
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,0,69))==0);
}

@test fn void branch_merge_cannot_revive_owners_and_static_slots_are_global_across_functions(){
    let ref u8[] source=b"a b";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    unit.body.function_count=2;
    let usize a=allocated(ref mut unit,ref mut state,1);live(ref unit,ref mut state,a);
    let usize named=ok(bindings::declare(ref unit,ref mut state,source,0,1,a,1));
    let bindings::Snapshot before=bindings::snapshot(ref state);
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,a,70));
    rejected(bindings::merge(ref unit,ref mut state,ref before,71),3,71);
    unchanged(ref unit,ref state,0,0,1,1); // never overwritten with saved Live
    let bindings::Snapshot dead=bindings::snapshot(ref state);
    assert(ok(bindings::merge(ref unit,ref mut state,ref dead,72))==0);
    // A branch-local independent slot remains allocated after its scope ends.
    let usize b=allocated(ref mut unit,ref mut state,1);live(ref unit,ref mut state,b);
    let usize local=ok(bindings::declare(ref unit,ref mut state,source,2,3,b,1));
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,1,73))==1);
    assert(ok(bindings::merge(ref unit,ref mut state,ref dead,74))==0 && state.next==2);
    rejected(bindings::enter_function(ref unit,ref mut state,1,75),3,75); // names must leave first
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,0,76));
    let usize entered=ok(bindings::enter_function(ref unit,ref mut state,1,77));
    let usize foreign=allocated(ref mut unit,ref mut state,1);assert(foreign==2 && unit.functions[2]==1);
    rejected(bindings::initialize(ref unit,ref mut state,a,78),3,78);
    // Even restoring an old small State cannot rewind the Program's slot ledger.
    var bindings::State stale=before.state;
    rejected(bindings::allocate(ref mut unit,ref mut stale,1,79),3,79);
    while(state.next<16){let usize id=allocated(ref mut unit,ref mut state,1);assert(unit.functions[id]==1);}
    rejected(bindings::allocate(ref mut unit,ref mut state,1,80),4,80);
    assert(state.next==16 && unit.types[15]==2 && unit.functions[15]==1);
    assert(unit.types[0]==2 && unit.functions[0]==0 && unit.types[1]==2 && unit.functions[1]==0);
}

@test fn void alternatives_restore_entry_liveness_keep_distinct_slots_and_verify_exclusive_cfg_moves(){
    let ref u8[] source=b"parent";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize condition=ok(ir::boolean(ref mut unit.body,true,1));
    let usize parent=allocated(ref mut unit,ref mut state,1);
    emitted(ref mut unit,95,parent,0,0);live(ref unit,ref mut state,parent);
    let usize name=ok(bindings::declare(ref unit,ref mut state,source,0,6,parent,1));
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize branch=ok(ir::raw(ref mut unit.body,20,0,condition,0,81));
    let usize then_slot=allocated(ref mut unit,ref mut state,1);
    let usize then_pc=unit.body.count;
    let usize then_move=ok(bindings::use_binding(ref mut unit,ref mut state,name,then_slot,82));
    let usize then_drop=ok(bindings::drop(ref mut unit,ref mut state,then_slot,83));
    let bindings::Snapshot then_exit=bindings::snapshot(ref state);
    let usize jump=ok(ir::raw(ref mut unit.body,19,0,0,0,84));
    let usize else_pc=unit.body.count;
    let usize branch_target=ok(ir::patch(ref mut unit.body,branch,else_pc,85));

    // Reject malformed entries before changing any metadata or emitted code.
    var bindings::Snapshot bad=bindings::snapshot(ref state);
    bad.state.names.function=1;
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref bad,86),3,86);
    bad=bindings::snapshot(ref state);bad.state.next=1;bad.state.live=2;
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref bad,87),3,87); // live outside entry prefix
    bad=bindings::snapshot(ref state);bad.state.next=1;bad.state.bindings[0]=2;bad.state.names.registers[0]=209;
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref bad,88),3,88); // changed surviving name/ID
    unchanged(ref unit,ref state,else_pc,0,2,1);

    assert(ok(bindings::begin_alternative(ref unit,ref mut state,ref entry,89))==1);
    unchanged(ref unit,ref state,else_pc,1,2,1);
    assert(unit.types[then_slot]==2 && unit.functions[then_slot]==0);
    rejected(bindings::merge(ref unit,ref mut state,ref then_exit,90),3,90); // Live entry != Dead exit
    let usize else_slot=allocated(ref mut unit,ref mut state,1);
    assert(then_slot==1 && else_slot==2 && state.next==3);
    let usize else_move=ok(bindings::use_binding(ref mut unit,ref mut state,name,else_slot,91));
    let usize else_drop=ok(bindings::drop(ref mut unit,ref mut state,else_slot,92));
    assert(ok(bindings::merge(ref unit,ref mut state,ref then_exit,93))==0);
    let usize join=unit.body.count;
    let usize jump_target=ok(ir::patch(ref mut unit.body,jump,join,94));
    // A merged continuation cannot use the consumed parent again.
    rejected(bindings::use_binding(ref mut unit,ref mut state,name,then_slot,95),3,95);
    unchanged(ref unit,ref state,join,0,3,1);
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,0,96));assert(cleaned==0);
    emitted(ref mut unit,8,0,result,0);
    let usize end=unit.body.count;let usize registers=unit.body.registers;
    unit.body.ends[0]=end;unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
    assert(unit.body.code[then_pc*8]==88 && unit.body.code[then_pc*8+1]==1);
    assert(unit.body.code[else_pc*8]==88 && unit.body.code[else_pc*8+1]==2);
    assert(verifier::inspect_values(ref unit).is_ok);
    // Without the jump, both MOVE instructions execute on one path. The actual
    // independent CFG proof rejects that source reuse; no Program copy is used.
    let usize invalid_target=ok(ir::patch(ref mut unit.body,jump,else_pc,97));
    assert(!verifier::inspect_values(ref unit).is_ok);
    let usize restored=ok(ir::patch(ref mut unit.body,jump,join,98));
}
