module tests::m2::value_source_functions;
import value_source_functions as metadata;
import value_source_bindings as bindings;
import value_properties as properties;
import value_ir as values;
import functions as functions;
import ir as ir;
import errors as errors;
import verifier as verifier;

fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn functions::Table scanned(ref u8[] source,ref mut properties::Catalog catalog){return switch(functions::scan_values(source,catalog)){
    case .ok(v):{v}case .err(_):{assert(false);functions::empty()}
};}
fn metadata::Plan prepared(ref properties::Catalog catalog,ref functions::Table signatures){return switch(metadata::prepare(catalog,signatures)){
    case .ok(v):{v}case .err(_):{assert(false);metadata::Plan{.results=[0;16],.parameters=[0;128]}}
};}
fn values::Program base(ref properties::Catalog catalog,ref functions::Table signatures,ref metadata::Plan plan){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=*catalog,
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=signatures.count;unit.body.entry=signatures.entry;
    var usize f=0;while(f<signatures.count){let usize encoded=plan.results[f];
        unit.body.return_types[f]=if(encoded==0){13}else if(catalog.nodes[encoded-1].kind==1){catalog.nodes[encoded-1].first}else{0};f+=1;
    }return unit;
}
fn void emit(ref mut values::Program unit,u8 op,usize dst,usize a,usize b){let usize pc=ok(ir::raw(ref mut unit.body,op,dst,a,b,0));}
fn void clean(ref mut values::Program unit,ref mut bindings::State state){let usize removed=ok(bindings::leave_scope(unit,state,0,0));}

@test fn void forward_plan_covers_six_scalars_arrays_nominal_records_and_nested_wrappers(){
    let ref u8[] source=b"module main;struct Point{i32 x;}fn i32 main(){return 42;}fn void mix(i32 a,bool b,i64 c,u8 d,u32 e,usize f,Buffer g,Option<i32> h){}fn Result<Point,u8[4]> later(Point p,u8[4] data){return .err(data);}fn i32 signed32(){return 1;}fn bool boolean(){return true;}fn i64 signed64(){return 1;}fn u8 bytevalue(){return 1;}fn u32 wordvalue(){return 1;}fn usize sizevalue(){return 1;}";
    var properties::Catalog catalog=properties::empty();let functions::Table signatures=scanned(source,ref mut catalog);
    let metadata::Plan plan=prepared(ref catalog,ref signatures);
    assert(plan.results[0]!=0 && plan.results[1]==0 && catalog.nodes[plan.results[2]-1].kind==6);
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){
        let properties::Node node=catalog.nodes[plan.parameters[8+i]-1];assert(node.kind==1 && node.first==tags[i]);
        assert(plan.results[3+i]==plan.parameters[8+i]);i+=1;
    }
    assert(catalog.nodes[plan.parameters[14]-1].kind==4 && catalog.nodes[plan.parameters[15]-1].kind==5);
    assert(catalog.nodes[plan.parameters[16]-1].kind==3 && catalog.nodes[plan.parameters[17]-1].kind==2);
    assert(catalog.nodes[plan.parameters[17]-1].extent==4 && plan.parameters[18]==0 && plan.results[9]==0);
    let properties::Node result=catalog.nodes[plan.results[2]-1];
    assert((result.first as usize)+1==plan.parameters[16] && (result.second as usize)+1==plan.parameters[17]);
}

@test fn void begin_preserves_scalar_and_typed_formal_positions_and_dead_result_anchors(){
    let ref u8[] source=b"module main;struct Point{i32 x;}fn Option<Buffer> mix(i32 a,bool b,i64 c,u8 d,u32 e,usize f,Buffer g,Point h){return .none;}fn i32 main(){return 42;}fn u8[4] arrayvalue(u8[4] data){return data;}";
    var properties::Catalog catalog=properties::empty();let functions::Table signatures=scanned(source,ref mut catalog);
    let metadata::Plan plan=prepared(ref catalog,ref signatures);var values::Program unit=base(ref catalog,ref signatures,ref plan);
    var bindings::State state=bindings::empty();assert(ok(metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,0))==0);
    assert(unit.body.registers==8 && unit.body.arities[0]==8 && state.next==3 && state.live==3);
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<8){
        assert(!unit.body.slots[i] && !state.names.mutable[i]);
        if(i<6){assert(unit.body.types[i]==tags[i] && unit.parameters[i]==0 && state.bindings[i]==0 && state.names.registers[i]==i);}
        else{assert(unit.body.types[i]==0 && unit.parameters[i]==state.bindings[i] && state.names.registers[i]==208+i-6);}i+=1;
    }
    assert(unit.results[0]==3 && unit.types[2] as usize==plan.results[0] && state.live==3 && unit.body.count==0);
    assert(!metadata::finish(ref mut unit,ref state,0,5).is_ok); // names/live must be cleaned by parent
    clean(ref mut unit,ref mut state);assert(state.live==0 && state.names.count==0 && state.next==3);
    assert(ok(metadata::finish(ref mut unit,ref state,0,5))==0);
    assert(ok(metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,1))==1);
    assert(state.next==3 && state.live==0 && unit.results[1]==0 && unit.body.register_starts[1]==8);
    let usize scalar=ok(ir::literal(ref mut unit.body,42,0));emit(ref mut unit,8,0,scalar,0);
    let usize main_end=ok(metadata::finish(ref mut unit,ref state,1,0));
    let usize array_function=ok(metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,2));
    assert(state.next==5 && state.live==8 && unit.parameters[9]==4 && unit.results[2]==5);
    assert(unit.body.types[9]==0 && unit.body.return_types[2]==0 && unit.types[3]==unit.types[4]);
    assert(unit.functions[3]==2 && unit.functions[4]==2 && state.names.registers[0]==211);
}

@test fn void forward_mixed_call_fixture_passes_independent_value_verifier(){
    let ref u8[] source=b"module main;fn i32 main(){return 42;}fn Buffer identity(i32 before,Buffer data,i32 after){return data;}";
    var properties::Catalog catalog=properties::empty();let functions::Table signatures=scanned(source,ref mut catalog);
    let metadata::Plan plan=prepared(ref catalog,ref signatures);var values::Program unit=base(ref catalog,ref signatures,ref plan);
    var bindings::State state=bindings::empty();let usize main=ok(metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,0));
    // Callee anchors do not exist yet. Forward lowering uses Plan exclusively.
    assert(unit.results[1]==0 && unit.parameters[3]==0 && plan.results[1]==plan.parameters[9]);
    let usize first=ok(ir::literal(ref mut unit.body,42,0));let usize last=ok(ir::literal(ref mut unit.body,7,0));
    let usize actual=ok(bindings::allocate(ref mut unit,ref mut state,plan.parameters[9]-1,0));
    let usize destination=ok(bindings::allocate(ref mut unit,ref mut state,plan.results[1]-1,0));
    emit(ref mut unit,95,actual,0,0);let usize initialized=ok(bindings::initialize(ref unit,ref mut state,actual,0));
    unit.body.call_count=1;unit.body.call_arities[0]=3;unit.body.call_args[0]=0;unit.body.call_args[1]=208;unit.body.call_args[2]=1;
    emit(ref mut unit,93,destination,1,0);let usize consumed=ok(bindings::consume(ref unit,ref mut state,actual,0));
    let usize returned=ok(bindings::initialize(ref unit,ref mut state,destination,0));let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,destination,0));
    emit(ref mut unit,8,0,first,0);clean(ref mut unit,ref mut state);let usize main_end=ok(metadata::finish(ref mut unit,ref state,0,0));
    let usize callee=ok(metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,1));
    assert(unit.body.register_starts[1]==2 && unit.body.registers==5 && unit.parameters[3]==3 && unit.results[1]==4);
    assert(state.next==4 && state.live==4); // result anchor slot3 remains Dead
    emit(ref mut unit,94,0,2,0);let usize moved=ok(bindings::consume(ref unit,ref mut state,2,0));
    clean(ref mut unit,ref mut state);let usize callee_end=ok(metadata::finish(ref mut unit,ref state,1,0));
    assert(unit.body.ends[0]==unit.body.starts[1] && unit.body.register_ends[0]==unit.body.register_starts[1]);
    assert(verifier::inspect_values(ref unit).is_ok);
}

@test fn void shared_reference_candidates_and_malformed_or_unresolved_signatures_are_distinct(){
    let ref u8[] source=b"module main;fn i32 main(){return 42;}fn void take(ref u8[] data){}";
    var properties::Catalog catalog=properties::empty();var functions::Table signatures=scanned(source,ref mut catalog);
    let metadata::Plan shared=prepared(ref catalog,ref signatures);assert(shared.parameters[8]==66);
    signatures=scanned(b"module main;fn ref u8[] same(ref u8[] data){return data;}fn i32 main(){return 42;}",ref mut catalog);
    assert(!metadata::prepare(ref catalog,ref signatures).is_ok);
    signatures.return_slice_inputs[0]=1;
    let metadata::Plan returned=prepared(ref catalog,ref signatures);
    assert(returned.results[0]==66 && returned.parameters[0]==66);
    signatures=scanned(b"module main;fn i32 main(){return 42;}",ref mut catalog);
    signatures.count=17;assert(!metadata::prepare(ref catalog,ref signatures).is_ok);signatures.count=1;
    signatures.arities[0]=9;assert(!metadata::prepare(ref catalog,ref signatures).is_ok);signatures.arities[0]=0;
    signatures.return_types[0]=9;assert(!metadata::prepare(ref catalog,ref signatures).is_ok);signatures.return_types[0]=1;
    signatures.param_types[1]=10;assert(!metadata::prepare(ref catalog,ref signatures).is_ok);signatures.param_types[1]=0;
    catalog.nodes[0].second=1;assert(!metadata::prepare(ref catalog,ref signatures).is_ok);
}

@test fn void header_capacity_failures_preserve_global_allocation_and_reject_stale_plans(){
    let ref u8[] source=b"module main;fn i32 main(){return 42;}fn void take(Buffer a,Buffer b){}";
    var properties::Catalog catalog=properties::empty();let functions::Table signatures=scanned(source,ref mut catalog);
    var metadata::Plan plan=prepared(ref catalog,ref signatures);var values::Program unit=base(ref catalog,ref signatures,ref plan);
    var bindings::State state=bindings::empty();let usize main=ok(metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,0));
    var usize i=0;while(i<15){let usize slot=ok(bindings::allocate(ref mut unit,ref mut state,plan.parameters[8]-1,0));i+=1;}
    emit(ref mut unit,82,0,0,0);let usize ended=ok(metadata::finish(ref mut unit,ref state,0,0));
    assert(!metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,1).is_ok);
    assert(state.next==15 && state.live==0 && state.names.count==0 && state.names.function==0 && unit.parameters[0]==0);
    let usize sixteenth=ok(bindings::allocate(ref mut unit,ref mut state,plan.parameters[8]-1,0));
    assert(sixteenth==15 && state.next==16);
    assert(!bindings::allocate(ref mut unit,ref mut state,plan.parameters[8]-1,0).is_ok && state.next==16);
    // Independent register limit: a valid preceding function can use 127 positions.
    state=bindings::empty();unit=base(ref catalog,ref signatures,ref plan);unit.body.count=1;
    unit.body.registers=127;unit.body.ends[0]=1;unit.body.register_ends[0]=127;
    assert(!metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,1).is_ok);
    assert(unit.body.registers==127 && state.next==0 && state.names.count==0);
    unit.body.registers=0;unit.body.register_ends[0]=0;plan.parameters[8]=0;
    assert(!metadata::begin(ref mut unit,ref mut state,source,ref signatures,ref plan,1).is_ok);
    assert(state.next==0 && state.names.function==0 && unit.body.registers==0);
}
