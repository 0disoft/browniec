module tests::m2::value_source_loop_effects;
import value_source_bindings as bindings;
import value_source_propagation as propagation;
import value_source_control as branches;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;
import std::vec as vec;

fn usize ok(Result<usize,errors::Error> result){
    return switch(result){case .ok(value):{value}case .err(_):{assert(false);0}};
}
fn void rejected(Result<usize,errors::Error> result,u8 kind,usize at){
    assert(switch(result){
        case .ok(_):{false}
        case .err(error):{error.kind==kind && error.offset==at}
    });
}
fn properties::Node node(u8 kind,u8 first,u8 second){
    return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};
}
fn values::Program base(){
    var values::Program unit=values::Program{
        .body=ir::empty(),.catalog=properties::empty(),.types=[0;16],
        .functions=[0;16],.parameters=[0;128],.results=[0;16]
    };
    unit.body.function_count=1;
    unit.catalog.count=5;
    unit.catalog.nodes[0]=node(1,1,0);
    unit.catalog.nodes[1]=node(4,0,0);
    unit.catalog.nodes[2]=node(6,0,0);
    unit.catalog.nodes[3]=node(6,0,1);
    unit.catalog.nodes[4]=node(5,2,0);
    return unit;
}
fn void enable(ref values::Program unit,ref mut bindings::State state){
    let usize enabled=ok(bindings::enable_results(unit,state,0));
}
fn usize initialized(ref mut values::Program unit,ref mut bindings::State state,usize exact){
    let usize id=ok(bindings::allocate(unit,state,exact,1));
    return ok(bindings::initialize(unit,state,id,2));
}
fn void handled(ref values::Program unit,ref mut bindings::State state,usize id){
    let usize value=ok(bindings::handle(unit,state,id,3));
}
fn usize effect(ref bindings::State state,usize incoming){
    return state.generated|(incoming&(65535^state.kills));
}
fn void same_state(ref bindings::State state,ref bindings::Snapshot before){
    let ref bindings::State prior=ref before.state;
    assert(state.next==prior.next && state.live==prior.live);
    assert(state.enforce_results==prior.enforce_results && state.pending==prior.pending);
    assert(state.tracking==prior.tracking && state.kills==prior.kills);
    assert(state.generated==prior.generated && state.required==prior.required);
    assert(state.names.count==prior.names.count && state.names.function==prior.names.function);
    assert(state.names.pending_places==prior.names.pending_places);
    var usize i=0;
    while(i<64){
        assert(state.bindings[i]==prior.bindings[i]);
        assert(state.names.begins[i]==prior.names.begins[i]);
        assert(state.names.ends[i]==prior.names.ends[i]);
        assert(state.names.registers[i]==prior.names.registers[i]);
        assert(state.names.mutable[i]==prior.names.mutable[i]);
        i+=1;
    }
}
fn void same_code(ref values::Program unit,ref u8[] code,ref usize[] offsets,usize count){
    assert(unit.body.count==count);
    var usize i=0;
    while(i<2048){assert(unit.body.code[i]==code[i]);i+=1;}
    i=0;
    while(i<256){assert(unit.body.offsets[i]==offsets[i]);i+=1;}
}

fn void fresh_acknowledgment(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    assert(!state.tracking && state.kills==0 && state.generated==0 && state.required==0);
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    handled(ref unit,ref mut state,a);
    assert(state.kills==0 && state.generated==0 && state.required==0);
    state.tracking=true;
    handled(ref unit,ref mut state,a);
    assert(state.pending==0 && state.live==1 && state.kills==1);
    var usize incoming=0;
    while(incoming<16){
        assert(effect(ref state,incoming)==(incoming&14));
        incoming+=1;
    }
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,a,10));
    let usize fresh=ok(bindings::initialize(ref unit,ref mut state,a,11));
    assert(state.pending==1 && state.kills==1 && state.generated==1 && state.required==0);
    incoming=0;
    while(incoming<16){
        assert(effect(ref state,incoming)==(1|(incoming&14)));
        incoming+=1;
    }
    let bindings::Snapshot before=bindings::snapshot(ref state);
    rejected(bindings::initialize(ref unit,ref mut state,a,12),3,12);
    same_state(ref state,ref before);
    handled(ref unit,ref mut state,a);
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,a,13));
    assert(state.kills==1 && state.generated==0 && state.required==0);
}

fn void copy_move_and_assignment(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=ok(bindings::allocate(ref mut unit,ref mut state,2,20));
    let usize c=initialized(ref mut unit,ref mut state,3);
    let usize d=ok(bindings::allocate(ref mut unit,ref mut state,3,21));
    let usize ai=ok(bindings::declare_mut(ref unit,ref mut state,b"a c",0,1,a,2));
    let usize ci=ok(bindings::declare(ref unit,ref mut state,b"a c",2,3,c,3));
    handled(ref unit,ref mut state,a);
    handled(ref unit,ref mut state,c);
    state.tracking=true;
    let usize copied=ok(bindings::use_binding(ref mut unit,ref mut state,ai,b,22));
    assert(unit.body.code[0]==89 && state.live==7 && state.pending==2);
    assert(state.kills==3 && state.generated==2 && state.required==0);
    var usize incoming=0;
    while(incoming<16){
        assert(effect(ref state,incoming)==(2|(incoming&12)));
        incoming+=1;
    }
    let bindings::Snapshot blocked=bindings::snapshot(ref state);
    unit.body.count=256;
    rejected(bindings::use_binding(ref mut unit,ref mut state,ci,d,120),4,120);
    rejected(bindings::move_value(ref mut unit,ref mut state,d,c,121),4,121);
    rejected(bindings::handle(ref unit,ref mut state,d,122),3,122);
    rejected(bindings::consume(ref unit,ref mut state,d,123),3,123);
    same_state(ref state,ref blocked);
    assert(unit.body.count==256 && unit.body.code[0]==89 && unit.body.code[8]==0);
    unit.body.count=1;
    handled(ref unit,ref mut state,b);
    let usize released=ok(bindings::consume(ref unit,ref mut state,a,23));
    let usize moved=ok(bindings::move_value(ref mut unit,ref mut state,a,b,24));
    assert(state.live==5 && state.pending==1 && state.kills==3 && state.generated==1);
    let usize count=unit.body.count;
    let bindings::Snapshot before=bindings::snapshot(ref state);
    let usize unchanged=ok(bindings::assign(ref mut unit,ref mut state,ai,a,25));
    assert(unit.body.count==count);
    same_state(ref state,ref before);
    let usize fresh=ok(bindings::initialize(ref unit,ref mut state,b,26));
    handled(ref unit,ref mut state,a);
    let usize assigned=ok(bindings::assign(ref mut unit,ref mut state,ai,b,27));
    assert(state.pending==1 && state.kills==3 && state.generated==1 && state.required==0);
    let usize owned=ok(bindings::use_binding(ref mut unit,ref mut state,ci,d,28));
    assert(unit.body.code[(unit.body.count-1)*8]==88 && state.live==9);
    assert(state.kills==15 && state.generated==9 && state.pending==9);
    handled(ref unit,ref mut state,a);
    let usize call=ok(bindings::consume(ref unit,ref mut state,d,29));
    assert(state.kills==15 && state.generated==0 && state.pending==0 && state.required==0);
}

fn void nonresults_and_mask_bounds(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    state.tracking=true;
    let usize scalar=initialized(ref mut unit,ref mut state,0);
    let usize buffer=initialized(ref mut unit,ref mut state,1);
    let usize option=initialized(ref mut unit,ref mut state,4);
    handled(ref unit,ref mut state,scalar);
    handled(ref unit,ref mut state,option);
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,buffer,30));
    let usize checked=ok(bindings::check_exit(ref unit,ref mut state,16,31));
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,option,32));
    assert(state.kills==0 && state.generated==0 && state.required==0 && state.pending==0);
    var usize field=0;
    while(field<3){
        state.kills=0;state.generated=0;state.required=0;
        if(field==0){state.kills=65536;}
        if(field==1){state.generated=65536;}
        if(field==2){state.required=65536;}
        let bindings::Snapshot oversized=bindings::snapshot(ref state);
        rejected(bindings::handle(ref unit,ref mut state,scalar,33),3,33);
        rejected(bindings::check_exit(ref unit,ref mut state,16,34),3,34);
        same_state(ref state,ref oversized);
        state.kills=0;state.generated=0;state.required=0;
        state.tracking=false;
        if(field==0){state.kills=1;}
        if(field==1){state.generated=1;}
        if(field==2){state.required=1;}
        let bindings::Snapshot disabled=bindings::snapshot(ref state);
        rejected(bindings::handle(ref unit,ref mut state,scalar,35),3,35);
        same_state(ref state,ref disabled);
        state.tracking=true;
        field+=1;
    }
    state.kills=65535;state.generated=65535;state.required=65535;
    handled(ref unit,ref mut state,scalar);
    assert(state.kills==65535 && state.generated==65535 && state.required==65535);
    // The loop coordinator may reset trusted trace fields directly.
    state.tracking=false;state.kills=0;state.generated=0;state.required=0;
    handled(ref unit,ref mut state,scalar);
}

fn void highest_result_bit(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    var usize id=0;
    while(id<16){
        let usize value=initialized(ref mut unit,ref mut state,2);
        handled(ref unit,ref mut state,value);
        id+=1;
    }
    state.tracking=true;
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,15,36));
    let usize fresh=ok(bindings::initialize(ref unit,ref mut state,15,37));
    assert(state.kills==32768 && state.generated==32768 && state.pending==32768);
    assert(effect(ref state,65535)==65535 && effect(ref state,0)==32768);
    handled(ref unit,ref mut state,15);
    assert(effect(ref state,65535)==32767 && state.generated==0);
}

@test fn void result_transfer_and_acknowledgment_summarize_all_inputs_even_when_initially_handled(){
    fresh_acknowledgment();
    copy_move_and_assignment();
    nonresults_and_mask_bounds();
    highest_result_bit();
}

fn void implicit_cleanup(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=initialized(ref mut unit,ref mut state,2);
    let usize c=initialized(ref mut unit,ref mut state,3);
    let usize buffer=initialized(ref mut unit,ref mut state,1);
    let usize ai=ok(bindings::declare(ref unit,ref mut state,b"a b c d",0,1,a,2));
    let usize bi=ok(bindings::declare(ref unit,ref mut state,b"a b c d",2,3,b,2));
    let usize ci=ok(bindings::declare(ref unit,ref mut state,b"a b c d",4,5,c,3));
    let usize di=ok(bindings::declare(ref unit,ref mut state,b"a b c d",6,7,buffer,1));
    handled(ref unit,ref mut state,a);
    handled(ref unit,ref mut state,b);
    handled(ref unit,ref mut state,c);
    state.tracking=true;
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,a,40));
    assert(state.required==1 && state.kills==1 && state.generated==0);
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,1,41));
    assert(cleaned==3 && state.live==0 && state.names.count==1);
    assert(state.required==7 && state.kills==7 && state.generated==0);
    assert(unit.body.code[8]==90 && unit.body.code[9] as usize==buffer);
    let usize count=unit.body.count;
    let bindings::Snapshot before=bindings::snapshot(ref state);
    let usize dead=ok(bindings::drop(ref mut unit,ref mut state,a,42));
    same_state(ref state,ref before);
    assert(unit.body.count==count);
}

fn void replacement_requires_old_destination(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=initialized(ref mut unit,ref mut state,2);
    let usize ai=ok(bindings::declare_mut(ref unit,ref mut state,b"a",0,1,a,2));
    handled(ref unit,ref mut state,a);
    handled(ref unit,ref mut state,b);
    state.tracking=true;
    let usize assigned=ok(bindings::assign(ref mut unit,ref mut state,ai,b,43));
    assert(state.required==1 && state.kills==3 && state.generated==1 && state.pending==1);
    assert(unit.body.count==2 && unit.body.code[0]==90 && unit.body.code[8]==88);
    handled(ref unit,ref mut state,a);
    let usize fresh=ok(bindings::initialize(ref unit,ref mut state,b,44));
    let usize again=ok(bindings::assign(ref mut unit,ref mut state,ai,b,45));
    assert(state.required==1 && state.kills==3 && state.generated==1);
}

fn void atomic_rejections(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=initialized(ref mut unit,ref mut state,2);
    let usize ai=ok(bindings::declare_mut(ref unit,ref mut state,b"a b",0,1,a,2));
    let usize bi=ok(bindings::declare(ref unit,ref mut state,b"a b",2,3,b,2));
    handled(ref unit,ref mut state,a);
    handled(ref unit,ref mut state,b);
    state.tracking=true;
    unit.body.code[0]=177;unit.body.code[2047]=199;unit.body.offsets[0]=999;
    let u8[2048] code=unit.body.code;
    let usize[256] offsets=unit.body.offsets;
    let bindings::Snapshot before=bindings::snapshot(ref state);
    unit.body.count=255;
    rejected(bindings::assign(ref mut unit,ref mut state,ai,b,50),4,50);
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,51),4,51);
    rejected(propagation::finish_function(ref mut unit,ref mut state,16,52),4,52);
    same_state(ref state,ref before);
    same_code(ref unit,ref code,ref offsets,255);
    unit.body.count=256;
    rejected(bindings::drop(ref mut unit,ref mut state,a,53),4,53);
    same_state(ref state,ref before);
    same_code(ref unit,ref code,ref offsets,256);
    unit.body.count=0;
    rejected(bindings::check_exit(ref unit,ref mut state,17,54),3,54);
    same_state(ref state,ref before);
    // Known pending values still reject; recording a requirement cannot excuse them.
    state.pending=3;
    let bindings::Snapshot pending=bindings::snapshot(ref state);
    rejected(bindings::drop(ref mut unit,ref mut state,a,55),18,55);
    rejected(bindings::assign(ref mut unit,ref mut state,ai,b,56),18,56);
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,57),18,57);
    rejected(bindings::check_exit(ref unit,ref mut state,16,58),18,58);
    rejected(propagation::finish_function(ref mut unit,ref mut state,a,59),18,59);
    same_state(ref state,ref pending);
    same_code(ref unit,ref code,ref offsets,0);
    state.pending=0;
    state.names.registers[bi]=255;
    let bindings::Snapshot malformed=bindings::snapshot(ref state);
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,60),3,60);
    rejected(bindings::assign(ref mut unit,ref mut state,ai,b,61),3,61);
    rejected(propagation::finish_function(ref mut unit,ref mut state,16,62),3,62);
    same_state(ref state,ref malformed);
    same_code(ref unit,ref code,ref offsets,0);
}

fn void return_requirements(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize keep=initialized(ref mut unit,ref mut state,2);
    let usize buffer=initialized(ref mut unit,ref mut state,1);
    let usize ai=ok(bindings::declare(ref unit,ref mut state,b"a",0,1,a,2));
    handled(ref unit,ref mut state,a);
    state.tracking=true;
    let usize immutable=ok(bindings::require_handled(ref unit,ref state,keep,63));
    assert(state.required==0 && state.kills==0);
    let usize checked=ok(bindings::check_exit(ref unit,ref mut state,keep,64));
    assert(state.required==1 && state.kills==0 && state.generated==0 && state.pending==2);
    let usize finished=ok(propagation::finish_function(ref mut unit,ref mut state,keep,65));
    assert(state.required==1 && state.kills==3 && state.generated==0);
    assert(state.live==0 && state.pending==0 && state.names.count==0 && state.bindings[ai]==0);
    assert(unit.body.count==2 && unit.body.code[1] as usize==buffer && unit.body.code[9] as usize==a);
}

@test fn void implicit_cleanup_records_entry_requirements_only_after_complete_atomic_preflight(){
    implicit_cleanup();
    replacement_requires_old_destination();
    atomic_rejections();
    return_requirements();
}

fn void cfg_restore_and_merge(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=initialized(ref mut unit,ref mut state,2);
    let usize c=initialized(ref mut unit,ref mut state,2);
    let usize d=initialized(ref mut unit,ref mut state,2);
    handled(ref unit,ref mut state,a);
    handled(ref unit,ref mut state,b);
    handled(ref unit,ref mut state,c);
    handled(ref unit,ref mut state,d);
    state.tracking=true;
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize drop_a=ok(bindings::drop(ref mut unit,ref mut state,a,70));
    let usize fresh_a=ok(bindings::initialize(ref unit,ref mut state,a,71));
    handled(ref unit,ref mut state,b);
    let bindings::Snapshot left=bindings::snapshot(ref state);
    assert(left.state.kills==3 && left.state.generated==1 && left.state.required==1);
    let usize alternative=ok(bindings::begin_alternative(ref unit,ref mut state,ref entry,72));
    assert(state.kills==0 && state.generated==0 && state.required==1 && state.pending==0);
    let usize drop_c=ok(bindings::drop(ref mut unit,ref mut state,c,73));
    let usize fresh_c=ok(bindings::initialize(ref unit,ref mut state,c,74));
    handled(ref unit,ref mut state,b);
    assert(state.kills==6 && state.generated==4 && state.required==5);
    let usize merged=ok(bindings::merge(ref unit,ref mut state,ref left,75));
    assert(state.kills==2 && state.generated==5 && state.required==5 && state.pending==5);
    var usize incoming=0;
    while(incoming<16){
        assert(effect(ref state,incoming)==(5|(incoming&8)));
        incoming+=1;
    }
    let usize restored=ok(bindings::select_path(ref unit,ref mut state,ref entry,76));
    assert(state.live==15 && state.kills==0 && state.generated==0 && state.required==5);
    let usize terminal=ok(propagation::finish_function(ref mut unit,ref mut state,b,77));
    assert(state.live==0 && state.kills==15 && state.required==13);
    let usize continuing=ok(bindings::select_path(ref unit,ref mut state,ref entry,78));
    assert(state.live==15 && state.kills==0 && state.generated==0 && state.required==13);
    let usize extra=initialized(ref mut unit,ref mut state,2);
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,extra,79));
    let usize rebased=ok(bindings::select_path(ref unit,ref mut state,ref entry,80));
    assert(state.next==5 && state.live==15 && state.kills==0 && state.generated==0 && state.required==13);
    var bindings::Snapshot incompatible=bindings::snapshot(ref state);
    incompatible.state.tracking=false;
    incompatible.state.required=0;
    let bindings::Snapshot before=bindings::snapshot(ref state);
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref incompatible,81),3,81);
    rejected(bindings::select_path(ref unit,ref mut state,ref incompatible,82),3,82);
    rejected(bindings::merge(ref unit,ref mut state,ref incompatible,83),3,83);
    same_state(ref state,ref before);
    incompatible.state.tracking=true;
    incompatible.state.generated=65536;
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref incompatible,84),3,84);
    rejected(bindings::select_path(ref unit,ref mut state,ref incompatible,85),3,85);
    rejected(bindings::merge(ref unit,ref mut state,ref incompatible,86),3,86);
    same_state(ref state,ref before);
}

fn bool joined(Result<bool,errors::Error> result){
    return switch(result){case .ok(value):{value}case .err(_):{assert(false);true}};
}
fn branches::Exit captured(Result<branches::Exit,errors::Error> result){
    return switch(result){
        case .ok(value):{value}
        case .err(_):{assert(false);branches::Exit{.path=128,.terminal=true,.jump=256}}
    };
}
fn void terminal_joins(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=initialized(ref mut unit,ref mut state,2);
    let usize ai=ok(bindings::declare(ref unit,ref mut state,b"a b",0,1,a,2));
    let usize bi=ok(bindings::declare(ref unit,ref mut state,b"a b",2,3,b,2));
    handled(ref unit,ref mut state,a);
    handled(ref unit,ref mut state,b);
    state.tracking=true;
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    let usize entry=ok(branches::save(ref mut paths,ref state,90));
    let usize returned=ok(propagation::finish_function(ref mut unit,ref mut state,b,91));
    let branches::Exit terminal=captured(branches::capture(ref mut paths,ref state,true,256,92));
    assert(state.required==1 && state.names.count==0);
    let usize restored=ok(branches::select(ref unit,ref mut state,ref paths,entry,93));
    handled(ref unit,ref mut state,a);
    let usize jump=ok(ir::raw(ref mut unit.body,19,0,0,0,94));
    let branches::Exit continuing=captured(branches::capture(ref mut paths,ref state,false,jump,95));
    assert(!joined(branches::join(ref mut unit,ref mut state,ref mut paths,ref terminal,ref continuing,96)));
    assert(state.required==1 && state.kills==1 && state.live==3 && state.names.count==2);
    let usize other_return=ok(propagation::finish_function(ref mut unit,ref mut state,a,97));
    assert(state.required==3 && state.live==0);
    assert(!joined(branches::join(ref mut unit,ref mut state,ref mut paths,ref continuing,ref terminal,98)));
    assert(state.required==3 && state.kills==1 && state.live==3 && state.names.count==2);
    let usize both_return=ok(propagation::finish_function(ref mut unit,ref mut state,a,99));
    let bindings::Snapshot before=bindings::snapshot(ref state);
    assert(joined(branches::join(ref mut unit,ref mut state,ref mut paths,ref terminal,ref terminal,100)));
    same_state(ref state,ref before);
    let usize released=ok(branches::release(ref mut paths,0,101));
}

fn void propagation_keeps_terminal_requirements(){
    var values::Program unit=base();
    var bindings::State state=bindings::empty();
    enable(ref unit,ref mut state);
    let usize anchor=ok(bindings::allocate(ref mut unit,ref mut state,2,110));
    unit.results[0]=1;
    let usize earlier=initialized(ref mut unit,ref mut state,2);
    handled(ref unit,ref mut state,earlier);
    let usize subject=initialized(ref mut unit,ref mut state,2);
    state.tracking=true;
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    let propagation::Expanded success=switch(propagation::lower(
        ref mut unit,ref mut state,ref mut paths,subject,2,111)){
        case .ok(value):{value}
        case .err(_):{assert(false);propagation::Expanded{.payload=16,.exact=64}}
    };
    // The failure return implicitly cleans earlier, while success keeps it live.
    // Restoring the continuing edge must retain the failure edge's requirement.
    assert(anchor==0 && earlier==1 && subject==2 && success.payload==3 && success.exact==0);
    assert(state.required==2 && state.kills==4 && state.generated==0 && state.pending==0);
    assert(state.live==10 && state.next==6 && branches::mark(ref paths)==0);
    let usize finished=ok(propagation::finish_function(ref mut unit,ref mut state,16,112));
    assert(state.required==2 && state.kills==6 && state.generated==0 && state.live==0);
}

@test fn void cfg_restore_join_and_propagation_retain_requirements_from_terminal_alternatives(){
    cfg_restore_and_merge();
    terminal_joins();
    propagation_keeps_terminal_requirements();
}
