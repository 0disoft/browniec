module tests::m2::value_program;
import value_program as programs;
import value_ir as values;
import value_properties as properties;
import value_frame_layout as frames;
import value_codec as codec;
import slice_reborrow_ir as reborrows;
import verifier as verifier;
import ir as ir;
import errors as errors;

fn usize built(Result<usize,errors::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn usize laid(Result<usize,frames::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn properties::Node node(u8 kind,u8 first){return properties::Node{.kind=kind,.first=first,.second=0,.extent=0};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.catalog.count=2;unit.catalog.nodes[0]=node(1,1);unit.catalog.nodes[1]=node(4,0);
    unit.types[0]=2;unit.types[1]=2;
    let usize scalar=built(ir::literal(ref mut unit.body,42,0));return unit;
}
fn void emit(ref mut values::Program unit,u8 op,usize dst,usize a,usize b){
    let usize pc=built(ir::raw(ref mut unit.body,op,dst,a,b,0));
}
fn void finish(ref mut values::Program unit){
    let usize count=unit.body.count;let usize registers=unit.body.registers;
    unit.body.function_count=1;unit.body.entry=0;unit.body.starts[0]=0;
    unit.body.ends[0]=count;unit.body.register_starts[0]=0;
    unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
}
fn values::Program moved(){
    var values::Program unit=base();emit(ref mut unit,95,0,0,0);emit(ref mut unit,88,1,0,0);
    emit(ref mut unit,90,1,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);return unit;
}
// Fixture replacement finishes its large IR temporaries before admission runs.
fn void reset(ref mut values::Program unit){*unit=moved();}
fn programs::Program retained(ref values::Program unit){return switch(programs::retain(unit)){
    case .ok(v):{v}case .err(_):{assert(false);retained(unit)}
};}
fn void invalid(ref values::Program unit){switch(programs::retain(unit)){
    case .ok(_):{assert(false);}case .err(e):{assert(!e.layout && e.code.kind==5);}
};}
fn void rejected_at(ref values::Program unit,usize pc){switch(programs::retain(unit)){
    case .ok(_):{assert(false);}case .err(e):{assert(!e.layout && e.code.kind==5 && e.code.offset==pc);}
};}
fn values::Program borrowed(){
    var values::Program unit=base();
    let usize array=built(ir::array(ref mut unit.body,1,1,true,0));
    let usize init=built(ir::array_init(ref mut unit.body,array,0,0));
    let usize lo=built(ir::integer(ref mut unit.body,0,12,0));
    let usize hi=built(ir::integer(ref mut unit.body,1,12,0));
    let usize parent=built(ir::exclusive_slice(ref mut unit.body,array,0));
    let usize child=built(reborrows::derived(ref mut unit.body,parent,0));
    let usize grandchild=built(reborrows::derived(ref mut unit.body,child,0));
    let usize open=built(ir::slice_open(ref mut unit.body,parent,lo,hi,0));
    let usize first=built(reborrows::begin(ref mut unit.body,child,parent,lo,hi,0));
    let usize second=built(reborrows::begin(ref mut unit.body,grandchild,child,lo,hi,0));
    let usize end_second=built(reborrows::end(ref mut unit.body,grandchild,child,0));
    let usize end_first=built(reborrows::end(ref mut unit.body,child,parent,0));
    let usize close=built(ir::slice_close(ref mut unit.body,parent,0));
    let usize drop=built(ir::array_drop(ref mut unit.body,array,0));
    emit(ref mut unit,95,0,0,0);emit(ref mut unit,88,1,0,0);
    emit(ref mut unit,90,1,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);return unit;
}
fn programs::Program escaped(){let values::Program unit=borrowed();return retained(ref unit);}
@test fn void retained_code_layout_and_nonempty_loans_outlive_and_isolate_the_candidate(){
    let programs::Program out=escaped();
    let ref values::Program outside=programs::code(ref out);
    let ref ir::Program outside_body=ref outside.body;
    assert(outside_body.constants[0]==42 && programs::loans(ref out).count==2);
    var values::Program unit=borrowed();
    let verifier::ValueProof proof=switch(verifier::inspect_values(ref unit)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let programs::Program p=retained(ref unit);
    unit.body.constants[0]=99;unit.body.code[0]=255;unit.body.slice_roots[1]=0;
    unit.catalog.nodes[1]=node(1,2);unit.types[0]=1;unit.functions[1]=1;
    let ref values::Program code=programs::code(ref p);
    let ref ir::Program body=ref code.body;
    let ref properties::Catalog catalog=ref code.catalog;
    assert(body.constants[0]==42 && body.code[0]==1 && body.slice_roots[1]==1);
    assert(catalog.nodes[1].kind==4 && code.types[0]==2 && code.functions[1]==0);
    let ref frames::Plan plan=programs::layout(ref p);
    assert(frames::functions(plan)==1 && frames::largest(plan)==8 && laid(frames::width(plan,0))==16);
    assert(laid(frames::type_id(plan,0,0))==1 && laid(frames::offset(plan,1))==8);
    let ref reborrows::Sites loans=programs::loans(ref p);
    assert(loans.count==2 && loans.count==proof.loans.count && loans.parents[1]==0 && loans.parents[2]==1);
    var usize i=0;while(i<16){
        assert(loans.parents[i]==proof.loans.parents[i] && loans.newer[i]==proof.loans.newer[i]);i+=1;
    }
    assert(loans.newer[1]==4 && loans.newer[2]==0);
    invalid(ref unit);
}
fn values::Program nominal(){
    var values::Program unit=base();unit.catalog.count=3;
    unit.catalog.records.count=2;unit.catalog.records.fields[0]=1;unit.catalog.records.fields[1]=1;
    unit.catalog.records.types[0]=1;unit.catalog.records.types[16]=1;
    unit.catalog.nodes[1]=node(3,0);unit.catalog.nodes[2]=node(3,1);
    unit.functions[0]=1;unit.functions[1]=1;
    emit(ref mut unit,8,0,0,0);finish(ref mut unit);
    emit(ref mut unit,88,1,0,0);emit(ref mut unit,94,0,1,0);
    unit.body.function_count=2;unit.body.starts[1]=2;unit.body.ends[1]=4;
    unit.body.register_starts[1]=1;unit.body.register_ends[1]=2;unit.body.registers=2;
    unit.body.arities[1]=1;unit.body.types[1]=0;unit.parameters[1]=1;unit.results[1]=2;return unit;
}
fn void reset_nominal(ref mut values::Program unit){*unit=nominal();}
@test fn void native_resource_moves_and_nominal_returns_admit_with_exact_dead_and_type_checks(){
    var values::Program unit=moved();let programs::Program p=retained(ref unit);
    let ref values::Program code=programs::code(ref p);let ref ir::Program body=ref code.body;
    assert(body.code[16]==88);
    unit.body.code[3*8+1]=0;rejected_at(ref unit,3); // moved source is Dead
    reset(ref mut unit);unit.body.code[2*8]=89;rejected_at(ref unit,2); // Buffer cannot COPY
    reset_nominal(ref mut unit);let programs::Program records=retained(ref unit);
    let ref frames::Plan plan=programs::layout(ref records);
    assert(frames::functions(plan)==2 && laid(frames::width(plan,0))==0 && laid(frames::width(plan,1))==8);
    assert(switch(codec::same(frames::layout(plan),1,2)){case .ok(v):{!v}case .err(_):{false}});
    unit.types[1]=3;invalid(ref unit); // same bytes, different declared record
}
@test fn void every_retention_rechecks_cfg_scalar_definitions_and_reserved_metadata(){
    var values::Program unit=moved();let programs::Program p=retained(ref unit);
    // Typed owner flow remains valid, but scalar RETURN now reads an undefined register.
    unit.body.code[0]=19;unit.body.code[1]=0;unit.body.code[2]=1;invalid(ref unit);
    reset(ref mut unit);unit.body.code[2*8]=19;unit.body.code[2*8+1]=0;unit.body.code[2*8+2]=4;
    invalid(ref unit); // malformed CFG skips a reachable instruction and leaks the owner
    reset(ref mut unit);unit.parameters[127]=1;invalid(ref unit);
    reset(ref mut unit);unit.body.ends[0]-=1;invalid(ref unit);
    reset(ref mut unit);unit.body.code[2*8+7]=1;rejected_at(ref unit,2);
    reset(ref mut unit);unit.catalog.nodes[63]=node(4,0);invalid(ref unit);
    let ref values::Program code=programs::code(ref p);let ref ir::Program body=ref code.body;
    assert(code.parameters[127]==0 && body.code[0]==1);
}
