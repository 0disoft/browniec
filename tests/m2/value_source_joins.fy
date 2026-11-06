module tests::m2::value_source_joins;
import value_source_bindings as bindings;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=1;unit.catalog.count=5;
    unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(4,0,0);
    unit.catalog.nodes[2]=node(6,0,0);unit.catalog.nodes[3]=node(6,0,1);
    unit.catalog.nodes[4]=node(6,0,0);return unit;
}
fn usize allocated(ref mut values::Program unit,ref mut bindings::State state,usize exact_type){
    return ok(bindings::allocate(unit,state,exact_type,7));
}
fn void live(ref values::Program unit,ref mut bindings::State state,usize id){let usize initialized=ok(bindings::initialize(unit,state,id,8));}
fn void emitted(ref mut values::Program unit,u8 op,usize dst,usize a,usize b){let usize pc=ok(ir::raw(ref mut unit.body,op,dst,a,b,9));}
fn void enable(ref values::Program unit,ref mut bindings::State state){let usize enabled=ok(bindings::enable_results(unit,state,0));}
fn void finish(ref mut values::Program unit,usize result){
    emitted(unit,8,0,result,0);let usize count=unit.body.count;let usize registers=unit.body.registers;
    unit.body.ends[0]=count;unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
}
fn void executes(ref values::Program unit){
    assert(verifier::inspect_values(unit).is_ok);
    let growth::Limits quota=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(unit,4000000,0,quota)){case .ok(v):{v==42}case .err(_):{false}});
}

@test fn void anonymous_publication_always_moves_copyable_buffer_and_result_values(){
    var values::Program unit=base();var bindings::State state=bindings::empty();enable(ref unit,ref mut state);
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize payload=allocated(ref mut unit,ref mut state,0);
    emitted(ref mut unit,97,payload,result,0);live(ref unit,ref mut state,payload);
    var usize exact_type=0;while(exact_type<4){
        let usize source=allocated(ref mut unit,ref mut state,exact_type);
        let usize destination=allocated(ref mut unit,ref mut state,exact_type);
        if(exact_type==0){emitted(ref mut unit,97,source,result,0);}
        else if(exact_type==1){emitted(ref mut unit,95,source,0,0);}
        else{emitted(ref mut unit,91,source,payload,1);}
        live(ref unit,ref mut state,source);
        // Already handling a copyable Result must not exempt its new join value.
        if(exact_type==2){let usize handled=ok(bindings::handle(ref unit,ref mut state,source,10));}
        let usize pc=unit.body.count;let usize next=state.next;
        assert(ok(bindings::move_value(ref mut unit,ref mut state,destination,source,11))==destination);
        assert(unit.body.count==pc+1 && unit.body.offsets[pc]==11 && unit.body.code[pc*8]==88);
        assert(unit.body.code[pc*8+1] as usize==destination && unit.body.code[pc*8+2] as usize==source);
        var usize byte=3;while(byte<8){assert(unit.body.code[pc*8+byte]==0);byte+=1;}
        assert(state.live==(bit(payload)|bit(destination)) && state.next==next && state.names.count==0);
        assert(unit.types[source]==unit.types[destination] && unit.functions[destination]==0);
        assert(state.pending==if(exact_type>=2){bit(destination)}else{0});
        let usize handled=ok(bindings::handle(ref unit,ref mut state,destination,12));
        let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,destination,13));
        exact_type+=1;
    }
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,payload,14));
    assert(state.live==0 && state.pending==0);finish(ref mut unit,result);executes(ref unit);
}

fn void joined(bool condition){
    var values::Program unit=base();var bindings::State state=bindings::empty();enable(ref unit,ref mut state);
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize test=ok(ir::boolean(ref mut unit.body,condition,1));
    let usize payload=allocated(ref mut unit,ref mut state,0);
    emitted(ref mut unit,97,payload,result,0);live(ref unit,ref mut state,payload);
    // The destination exists, Dead, before either alternative allocates its RHS.
    let usize destination=allocated(ref mut unit,ref mut state,2);
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize branch=ok(ir::raw(ref mut unit.body,20,0,test,0,20));
    let usize left_source=allocated(ref mut unit,ref mut state,2);
    emitted(ref mut unit,91,left_source,payload,1);live(ref unit,ref mut state,left_source);
    let usize left_pc=unit.body.count;
    let usize left_value=ok(bindings::move_value(ref mut unit,ref mut state,destination,left_source,21));
    let bindings::Snapshot left=bindings::snapshot(ref state);
    let usize jump=ok(ir::raw(ref mut unit.body,19,0,0,0,22));
    let usize right_pc=unit.body.count;let usize branch_target=ok(ir::patch(ref mut unit.body,branch,right_pc,23));
    let usize alternative=ok(bindings::begin_alternative(ref unit,ref mut state,ref entry,24));
    assert(state.live==bit(payload) && state.pending==0 && state.next==3);
    let usize right_source=allocated(ref mut unit,ref mut state,2);
    assert(right_source!=left_source && destination==1 && state.next==4);
    emitted(ref mut unit,91,right_source,payload,1);live(ref unit,ref mut state,right_source);
    let usize publication=unit.body.count;
    let usize right_value=ok(bindings::move_value(ref mut unit,ref mut state,destination,right_source,25));
    assert(state.live==left.state.live && state.pending==bit(destination));
    let usize handled_right=ok(bindings::handle(ref unit,ref mut state,destination,26));
    assert(state.pending==0);
    let usize merged=ok(bindings::merge(ref unit,ref mut state,ref left,27));
    assert(state.live==(bit(payload)|bit(destination)) && state.pending==bit(destination) && state.next==4);
    assert(unit.body.code[left_pc*8]==88 && unit.body.code[publication*8]==88);
    assert(unit.body.code[left_pc*8+1] as usize==destination && unit.body.code[publication*8+1] as usize==destination);
    let usize join=unit.body.count;let usize jump_target=ok(ir::patch(ref mut unit.body,jump,join,28));
    let usize handled=ok(bindings::handle(ref unit,ref mut state,destination,29));
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,destination,30));
    let usize payload_drop=ok(bindings::drop(ref mut unit,ref mut state,payload,31));
    assert(state.live==0 && state.pending==0 && state.names.count==0);
    finish(ref mut unit,result);executes(ref unit);
    // A fallthrough into the second publication has a Live destination and is
    // independently rejected by the real CFG verifier.
    let usize invalid_target=ok(ir::patch(ref mut unit.body,jump,right_pc,32));
    assert(!verifier::inspect_values(ref unit).is_ok);
}

@test fn void exclusive_edges_reuse_one_dead_destination_and_merge_result_obligations_with_or(){
    joined(true);joined(false);
}

fn void rejects_unchanged(ref mut values::Program unit,ref mut bindings::State state,
    usize destination,usize source,u8 kind,usize at){
    let bindings::Snapshot before=bindings::snapshot(state);
    let u8[2048] code=unit.body.code;let usize[256] offsets=unit.body.offsets;
    let u8[16] types=unit.types;let u8[16] functions=unit.functions;let usize count=unit.body.count;
    assert(switch(bindings::move_value(unit,state,destination,source,at)){
        case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}
    });
    let ref bindings::State prior=ref before.state;
    assert(state.next==prior.next && state.live==prior.live && state.pending==prior.pending);
    assert(state.enforce_results==prior.enforce_results && state.names.count==prior.names.count);
    assert(state.names.function==prior.names.function && state.names.pending_places==prior.names.pending_places);
    var usize i=0;while(i<64){
        assert(state.bindings[i]==prior.bindings[i] && state.names.begins[i]==prior.names.begins[i]);
        assert(state.names.ends[i]==prior.names.ends[i] && state.names.registers[i]==prior.names.registers[i]);
        assert(state.names.mutable[i]==prior.names.mutable[i]);i+=1;
    }
    assert(unit.body.count==count);i=0;while(i<2048){assert(unit.body.code[i]==code[i]);i+=1;}
    i=0;while(i<256){assert(unit.body.offsets[i]==offsets[i]);i+=1;}
    i=0;while(i<16){assert(unit.types[i]==types[i] && unit.functions[i]==functions[i]);i+=1;}
}

@test fn void invalid_types_functions_headers_liveness_and_capacity_preserve_all_publication_state(){
    var values::Program unit=base();var bindings::State state=bindings::empty();enable(ref unit,ref mut state);
    let usize source=allocated(ref mut unit,ref mut state,2);live(ref unit,ref mut state,source);
    let usize destination=allocated(ref mut unit,ref mut state,2);
    let usize scalar=allocated(ref mut unit,ref mut state,0);
    let usize duplicate=allocated(ref mut unit,ref mut state,4);
    let usize name=ok(bindings::declare_mut(ref unit,ref mut state,b"x",0,1,source,2));
    unit.body.code[0]=177;unit.body.code[7]=199;unit.body.offsets[0]=999;
    rejects_unchanged(ref mut unit,ref mut state,source,source,3,40); // Live self.
    rejects_unchanged(ref mut unit,ref mut state,destination,destination,3,41); // Dead self.
    rejects_unchanged(ref mut unit,ref mut state,scalar,source,3,42);
    rejects_unchanged(ref mut unit,ref mut state,duplicate,source,3,43); // Equal shape is not exact type.
    rejects_unchanged(ref mut unit,ref mut state,16,source,3,44);
    rejects_unchanged(ref mut unit,ref mut state,destination,16,3,45);
    rejects_unchanged(ref mut unit,ref mut state,4,source,3,46); // Unallocated.
    state.live=0;state.pending=0;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,47);
    state.live=3;state.pending=1;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,48);
    state.live=1;unit.body.function_count=2;unit.functions[destination]=1;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,49);
    unit.functions[destination]=0;unit.functions[source]=1;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,50);
    unit.functions[source]=0;unit.body.function_count=1;unit.types[15]=1;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,51);
    unit.types[15]=0;unit.types[scalar]=0;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,52);
    unit.types[scalar]=1;state.pending=2;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,53);
    state.pending=1;state.enforce_results=false;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,54);
    state.enforce_results=true;state.next=17;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,55);
    state.next=4;state.names.count=65;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,56);
    state.names.count=1;unit.catalog.nodes[4].kind=0;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,3,57);
    unit.catalog.nodes[4].kind=6;unit.body.count=256;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,4,58);
    unit.body.count=257;
    rejects_unchanged(ref mut unit,ref mut state,destination,source,4,59);
    // One remaining instruction is sufficient; only that row is published.
    unit.body.count=255;unit.body.code[2047]=199;unit.body.offsets[255]=999;
    assert(ok(bindings::move_value(ref mut unit,ref mut state,destination,source,60))==destination);
    assert(unit.body.count==256 && unit.body.code[2040]==88 && unit.body.code[2047]==0 && unit.body.offsets[255]==60);
    assert(state.live==2 && state.pending==2 && state.next==4 && state.names.count==1);
    assert(state.bindings[name]==1 && state.names.mutable[name] && state.names.registers[name]==208);
    assert(unit.body.code[0]==177 && unit.body.code[7]==199 && unit.body.offsets[0]==999);
}
