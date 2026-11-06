module tests::m2::value_source_must_use;
import value_source_bindings as bindings;
import value_source_ops as ops;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;

fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn ops::Case selected(Result<ops::Case,errors::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);ops::Case{.instruction=256,.payload=16}}
};}
fn void bad_case(Result<ops::Case,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=1;unit.catalog.count=7;
    unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(4,0,0);
    unit.catalog.nodes[2]=node(6,0,0);unit.catalog.nodes[3]=node(6,0,1);
    unit.catalog.nodes[4]=node(5,2,0);unit.catalog.nodes[5]=node(6,2,0);
    unit.catalog.nodes[6]=node(5,0,0);return unit;
}
fn usize initialized(ref mut values::Program unit,ref mut bindings::State state,usize exact_type){
    let usize id=ok(bindings::allocate(unit,state,exact_type,1));
    return ok(bindings::initialize(unit,state,id,2));
}
fn void enable(ref values::Program unit,ref mut bindings::State state){let usize enabled=ok(bindings::enable_results(unit,state,0));}
fn void legacy(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    assert(!state.enforce_results && state.pending==0);
    let usize id=initialized(ref mut unit,ref mut state,2);
    rejected(bindings::enable_results(ref unit,ref mut state,10),3,10);
    assert(!state.enforce_results && state.pending==0);
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,id,11));
    assert(state.live==0 && state.pending==0 && unit.body.code[0]==90);
}
fn void overwrite_scope(){
    let ref u8[] names=b"a b c";
    var values::Program unit=base();var bindings::State state=bindings::empty();enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=initialized(ref mut unit,ref mut state,2);
    let usize c=initialized(ref mut unit,ref mut state,1);
    let usize ai=ok(bindings::declare_mut(ref unit,ref mut state,names,0,1,a,2));
    let usize bi=ok(bindings::declare(ref unit,ref mut state,names,2,3,b,2));
    let usize ci=ok(bindings::declare(ref unit,ref mut state,names,4,5,c,1));
    unit.body.code[0]=177;unit.body.code[7]=199;unit.body.offsets[0]=999;
    rejected(bindings::assign(ref mut unit,ref mut state,ai,b,20),18,20);
    rejected(bindings::drop(ref mut unit,ref mut state,a,21),18,21);
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,22),18,22);
    assert(unit.body.count==0 && unit.body.code[0]==177 && unit.body.code[7]==199 && unit.body.offsets[0]==999);
    assert(state.live==7 && state.pending==3 && state.names.count==3 && state.bindings[2] as usize==c+1);
    assert(ok(bindings::assign(ref mut unit,ref mut state,ai,a,23))==a);
    assert(unit.body.count==0 && state.pending==3); // True self-assignment does not overwrite or handle.
    let usize handled=ok(bindings::handle(ref unit,ref mut state,a,24));
    let usize assigned=ok(bindings::assign(ref mut unit,ref mut state,ai,b,25));
    assert(state.live==5 && state.pending==1 && unit.body.count==2);
    assert(unit.body.code[0]==90 && unit.body.code[8]==88);
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,26),18,26);
    assert(unit.body.count==2 && state.live==5 && state.pending==1 && state.names.count==3);
    let usize retained=ok(bindings::require_handled(ref unit,ref state,a,27));
    rejected(bindings::require_handled(ref unit,ref state,16,28),18,28);
    let usize done=ok(bindings::handle(ref unit,ref mut state,a,29));
    let usize cleaned=ok(bindings::leave_scope(ref mut unit,ref mut state,0,30));
    assert(cleaned==2 && state.live==0 && state.pending==0 && state.names.count==0);
    assert(unit.body.code[16]==90 && unit.body.code[17] as usize==c && unit.body.code[25] as usize==a);
}

@test fn void copy_obligations_transfer_independently_of_owners_and_cleanup_is_atomic(){
    legacy();overwrite_scope();
    let ref u8[] names=b"a b";
    var values::Program unit=base();var bindings::State state=bindings::empty();enable(ref unit,ref mut state);
    // Formal initialization creates the same obligation as an expression producer.
    let usize a=initialized(ref mut unit,ref mut state,2);unit.parameters[0]=1;unit.body.arities[0]=1;
    let usize ai=ok(bindings::declare(ref unit,ref mut state,names,0,1,a,2));
    let usize b=ok(bindings::allocate(ref mut unit,ref mut state,2,31));
    assert(state.pending==1 && unit.body.count==0);
    let usize copied=ok(bindings::use_binding(ref mut unit,ref mut state,ai,b,32));
    assert(state.live==3 && state.pending==2 && unit.body.code[0]==89);
    let usize count=unit.body.count;
    let usize handled=ok(bindings::handle(ref unit,ref mut state,b,33));
    assert(state.pending==0 && state.live==3 && unit.body.count==count);
    let usize c=ok(bindings::allocate(ref mut unit,ref mut state,2,34));
    let usize evaluated=ok(bindings::use_binding(ref mut unit,ref mut state,ai,c,35));
    assert(state.live==7 && state.pending==4); // Reading an already handled source starts a fresh obligation.
    let usize returned=ok(bindings::require_handled(ref unit,ref state,c,36));
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,c,37));
    assert(state.live==3 && state.pending==0 && unit.body.count==count+1);
    let usize moved_source=initialized(ref mut unit,ref mut state,3);
    let usize mi=ok(bindings::declare(ref unit,ref mut state,names,2,3,moved_source,3));
    let usize moved_dest=ok(bindings::allocate(ref mut unit,ref mut state,3,38));
    let usize moved=ok(bindings::use_binding(ref mut unit,ref mut state,mi,moved_dest,39));
    assert((state.live&bit(moved_source))==0 && state.pending==bit(moved_dest));
    assert(unit.body.code[(unit.body.count-1)*8]==88);
    let usize call=ok(bindings::consume(ref unit,ref mut state,moved_dest,40));
    assert(state.pending==0);let usize exit=ok(bindings::require_handled(ref unit,ref state,16,41));
}

@test fn void path_selection_restores_obligations_and_merges_union_without_reviving_dead_slots(){
    var values::Program unit=base();var bindings::State state=bindings::empty();enable(ref unit,ref mut state);
    let usize a=initialized(ref mut unit,ref mut state,2);
    let usize b=initialized(ref mut unit,ref mut state,2);
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    assert(entry.state.enforce_results && entry.state.pending==3);
    let usize handled_a=ok(bindings::handle(ref unit,ref mut state,a,50));
    let bindings::Snapshot left=bindings::snapshot(ref state);
    let usize alternative=ok(bindings::begin_alternative(ref unit,ref mut state,ref entry,51));
    assert(state.pending==3 && state.live==3);
    let usize handled_b=ok(bindings::handle(ref unit,ref mut state,b,52));
    let usize joined=ok(bindings::merge(ref unit,ref mut state,ref left,53));
    assert(state.pending==3 && state.live==3 && unit.body.count==0);
    rejected(bindings::require_handled(ref unit,ref state,16,54),18,54);
    let usize selected_left=ok(bindings::select_path(ref unit,ref mut state,ref left,55));
    assert(state.pending==2 && state.live==3);
    let usize extra=initialized(ref mut unit,ref mut state,2);
    let usize handed=ok(bindings::consume(ref unit,ref mut state,extra,56));
    let usize restored=ok(bindings::select_path(ref unit,ref mut state,ref entry,57));
    assert(state.next==3 && state.live==3 && state.pending==3);
    let usize dead=ok(bindings::consume(ref unit,ref mut state,a,58));
    rejected(bindings::merge(ref unit,ref mut state,ref entry,59),3,59);
    assert(state.live==2 && state.pending==2 && state.next==3); // Neither revive nor mask one path.
    let usize back=ok(bindings::select_path(ref unit,ref mut state,ref entry,60));
    state.enforce_results=false;state.pending=0;
    rejected(bindings::select_path(ref unit,ref mut state,ref entry,61),3,61);
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref entry,62),3,62);
    rejected(bindings::merge(ref unit,ref mut state,ref entry,63),3,63);
    assert(!state.enforce_results && state.pending==0 && state.live==3);
    state.pending=1;rejected(bindings::require_handled(ref unit,ref state,16,64),3,64);
    rejected(ops::tag_test(ref mut unit,ref mut state,a,1,65),3,65);
    state.enforce_results=true;state.pending=4; // Pending must be a subset of live.
    rejected(bindings::handle(ref unit,ref mut state,a,66),3,66);
    state.pending=65536;rejected(bindings::require_handled(ref unit,ref state,16,67),3,67);
    state.pending=1;unit.types[a]=1; // A pending scalar is malformed metadata.
    rejected(bindings::handle(ref unit,ref mut state,a,68),3,68);
    rejected(ops::tag_test(ref mut unit,ref mut state,a,1,69),3,69);
    unit.types[a]=3;unit.body.function_count=2;unit.functions[a]=1;
    rejected(bindings::require_handled(ref unit,ref state,16,70),3,70);
    assert(unit.body.count==0 && state.next==3 && state.live==3 && state.pending==1);
}

@test fn void wrappers_cases_predicates_and_formal_producers_preserve_result_obligations(){
    var values::Program unit=base();var bindings::State state=bindings::empty();enable(ref unit,ref mut state);
    let usize register=ok(ir::literal(ref mut unit.body,42,0));
    let usize scalar=ok(ops::scalar_value(ref mut unit,ref mut state,register,0,80));
    let usize inner=ok(ops::tag(ref mut unit,ref mut state,2,scalar,1,81));
    assert(state.pending==bit(inner));
    let usize wrapped=ok(ops::tag(ref mut unit,ref mut state,4,inner,1,82));
    assert(state.pending==0 && (state.live&bit(inner))!=0); // Copy child is transferred; Option itself is not Result.
    let ops::Case some=selected(ops::case_value(ref mut unit,ref mut state,wrapped,1,83));
    assert(state.pending==bit(some.payload) && (state.live&bit(wrapped))!=0);
    let usize outer=ok(ops::tag(ref mut unit,ref mut state,5,some.payload,1,84));
    assert(state.pending==bit(outer) && (state.live&bit(some.payload))!=0);
    let usize count=unit.body.count;let usize registers=unit.body.registers;let usize bits=state.live;
    unit.body.code[count*8]=177;unit.body.code[count*8+7]=199;unit.body.offsets[count]=999;
    rejected(ops::tag(ref mut unit,ref mut state,4,outer,1,85),3,85);
    rejected(ops::tag_test(ref mut unit,ref mut state,outer,2,86),3,86);
    bad_case(ops::case_value(ref mut unit,ref mut state,outer,2,87),3,87);
    unit.body.registers=128;
    rejected(ops::tag_test(ref mut unit,ref mut state,outer,1,88),4,88);unit.body.registers=registers;
    unit.body.count=256;
    rejected(ops::tag(ref mut unit,ref mut state,4,inner,1,89),4,89);
    bad_case(ops::case_value(ref mut unit,ref mut state,outer,1,90),4,90);unit.body.count=count;
    assert(state.live==bits && state.pending==bit(outer) && unit.body.registers==registers);
    assert(unit.body.code[count*8]==177 && unit.body.code[count*8+7]==199 && unit.body.offsets[count]==999);
    let usize predicate=ok(ops::tag_test(ref mut unit,ref mut state,outer,0,91));
    assert(state.pending==0 && state.live==bits && unit.body.registers==registers+1);
    assert(unit.body.code[count*8]==98 && unit.body.count==count+1);
    let ops::Case nested=selected(ops::case_value(ref mut unit,ref mut state,outer,1,92));
    assert(state.pending==bit(nested.payload)); // Matching payload creates a fresh direct Result.
    let usize discarded=ok(bindings::handle(ref unit,ref mut state,nested.payload,93));
    let usize buffer=ok(ops::empty_buffer(ref mut unit,ref mut state,1,94));
    let usize owned=ok(ops::tag(ref mut unit,ref mut state,3,buffer,0,95));
    assert(state.pending==bit(owned) && (state.live&bit(buffer))==0);
    let ops::Case err=selected(ops::case_value(ref mut unit,ref mut state,owned,0,96));
    assert(state.pending==0 && (state.live&bit(owned))==0 && values::type_id(ref unit,err.payload)==1);
    // A parameter/returned-call hook uses initialize, not an executable constructor.
    let usize formal=initialized(ref mut unit,ref mut state,2);
    assert(state.pending==bit(formal));
    let usize before=unit.body.count;let usize owners=state.live;
    unit.body.count=256;
    rejected(ops::tag(ref mut unit,ref mut state,4,formal,1,99),4,99);
    bad_case(ops::case_value(ref mut unit,ref mut state,formal,1,100),4,100);
    rejected(ops::tag_test(ref mut unit,ref mut state,formal,1,101),4,101);
    unit.body.count=before;
    while(state.next<16){let usize dead=ok(bindings::allocate(ref mut unit,ref mut state,0,102));}
    rejected(ops::tag(ref mut unit,ref mut state,4,formal,1,103),4,103);
    bad_case(ops::case_value(ref mut unit,ref mut state,formal,1,104),4,104);
    assert(state.pending==bit(formal) && state.live==owners && unit.body.count==before);
    let usize inspected=ok(ops::tag_test(ref mut unit,ref mut state,formal,1,97));
    assert(state.pending==0 && state.live==owners && unit.body.count==before+1);
    let usize exit=ok(bindings::require_handled(ref unit,ref state,16,98));
}
