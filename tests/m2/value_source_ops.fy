module tests::m2::value_source_ops;
import value_source_ops as ops;
import value_source_bindings as bindings;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=1;unit.catalog.count=11;
    unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(1,2,0);
    unit.catalog.nodes[2]=node(1,9,0);unit.catalog.nodes[3]=node(1,10,0);
    unit.catalog.nodes[4]=node(1,11,0);unit.catalog.nodes[5]=node(1,12,0);
    unit.catalog.nodes[6]=node(4,0,0);unit.catalog.nodes[7]=node(5,6,0);
    unit.catalog.nodes[8]=node(6,0,6);unit.catalog.nodes[9]=node(5,0,0);
    unit.catalog.nodes[10]=node(5,8,0);return unit;
}
fn void finish(ref mut values::Program unit,usize result){
    let usize returned=ok(ir::raw(ref mut unit.body,8,0,result,0,70));
    let usize count=unit.body.count;let usize registers=unit.body.registers;
    unit.body.ends[0]=count;unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
}
fn void executes(ref values::Program unit){
    assert(verifier::inspect_values(unit).is_ok);
    let growth::Limits quota=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(unit,4000000,0,quota)){case .ok(v):{v==42}case .err(_):{false}});
}
fn void unchanged(ref values::Program unit,ref bindings::State state,usize count,usize registers,usize next,usize bits){
    assert(unit.body.count==count && unit.body.registers==registers && state.next==next && state.live==bits);
    assert(state.names.count==0 && unit.types[next]==0 && unit.functions[next]==0);
    assert(unit.body.code[count*8]==177 && unit.body.code[count*8+7]==199 && unit.body.offsets[count]==999);
}

@test fn void all_scalar_domains_roundtrip_without_consumption_and_execute_independent_comparisons(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    unit.body.register_ends[0]=1; // Stale until finish; emission uses the live register cursor.
    let u8[12] tags=[1,1,2,2,9,9,10,10,11,11,12,12];
    let i64[12] cells=[-2147483648,2147483647,0,1,-9223372036854775808,9223372036854775807,0,255,0,4294967295,0,-1];
    var usize[24] branches=[0;24];var usize i=0;
    while(i<12){
        let usize register=if(tags[i]==2){ok(ir::boolean(ref mut unit.body,cells[i]!=0,11))}
            else{ok(ir::integer(ref mut unit.body,cells[i],tags[i],11))};
        let usize before=unit.body.count;
        let usize source=ok(ops::scalar_value(ref mut unit,ref mut state,register,i/2,12));
        let usize a=ok(ops::scalar_read(ref mut unit,ref mut state,source,13));
        let usize b=ok(ops::scalar_read(ref mut unit,ref mut state,source,14));
        assert(a!=b && unit.body.types[a]==tags[i] && unit.body.types[b]==tags[i]);
        assert(unit.body.code[before*8]==97 && unit.body.code[(before+1)*8]==96);
        assert(unit.body.offsets[before]==12 && unit.body.offsets[before+1]==13 && state.live!=0);
        let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,source,19));
        let usize equal_a=ok(ir::emit(ref mut unit.body,11,a,register,15));
        branches[i*2]=ok(ir::raw(ref mut unit.body,20,0,equal_a,0,16));
        let usize equal_b=ok(ir::emit(ref mut unit.body,11,b,register,17));
        branches[i*2+1]=ok(ir::raw(ref mut unit.body,20,0,equal_b,0,18));
        i+=1;
    }
    assert(state.next==12 && state.live==0);
    let usize result=ok(ir::literal(ref mut unit.body,42,20));finish(ref mut unit,result);
    let usize failure=unit.body.count;let usize failed=ok(ir::raw(ref mut unit.body,25,0,0,0,21));
    i=0;while(i<24){let usize patched=ok(ir::patch(ref mut unit.body,branches[i],failure,22));i+=1;}
    let usize end=unit.body.count;unit.body.ends[0]=end;executes(ref unit);
}

@test fn void buffer_tags_copy_plain_children_and_move_whole_types_with_inactive_buffer_alternatives(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize scalar=ok(ops::scalar_value(ref mut unit,ref mut state,result,0,30));
    let usize plain=ok(ops::tag(ref mut unit,ref mut state,9,scalar,1,31));
    assert(state.live==3); // Option<i32>.some copies its child.
    let usize discarded=ok(bindings::drop(ref mut unit,ref mut state,scalar,32));
    let usize none=ok(ops::tag(ref mut unit,ref mut state,7,16,0,33));
    assert(unit.body.code[(unit.body.count-1)*8+2]==0);
    let usize buffer=ok(ops::empty_buffer(ref mut unit,ref mut state,6,34));
    let usize some=ok(ops::tag(ref mut unit,ref mut state,7,buffer,1,35));
    assert((state.live&8)==0); // Buffer payload moved into Option<Buffer>.
    let usize err_buffer=ok(ops::empty_buffer(ref mut unit,ref mut state,6,36));
    let usize err=ok(ops::tag(ref mut unit,ref mut state,8,err_buffer,0,37));
    assert((state.live&32)==0);
    let usize child=ok(ops::scalar_value(ref mut unit,ref mut state,result,0,38));
    let usize tagged=ok(ops::tag(ref mut unit,ref mut state,8,child,1,39));
    assert((state.live&128)!=0); // Result<i32,Buffer>.ok still copies i32.
    let usize dropped_child=ok(bindings::drop(ref mut unit,ref mut state,child,40));
    let usize outer=ok(ops::tag(ref mut unit,ref mut state,10,tagged,1,41));
    assert((state.live&256)==0); // Entire Result moves, even with inactive Buffer.
    let usize pc=unit.body.count;
    assert(ok(bindings::drop(ref mut unit,ref mut state,buffer,42))==buffer && unit.body.count==pc);
    var usize i=0;while(i<state.next){let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,i,43));i+=1;}
    assert(state.live==0);finish(ref mut unit,result);executes(ref unit);
    let growth::Limits short=growth::Limits{.object=4096,.instance=1,.engine=1048576};
    assert(switch(vm::run_values(ref unit,4000000,0,short)){case .ok(_):{false}case .err(e):{e.kind==13}});
    executes(ref unit); // A quota rejection cannot poison a fresh invocation.
}

@test fn void invalid_operands_dead_foreign_slots_and_full_budgets_reject_before_publication(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize source=ok(ops::scalar_value(ref mut unit,ref mut state,result,0,50));
    let usize count=unit.body.count;let usize registers=unit.body.registers;
    unit.body.code[count*8]=177;unit.body.code[count*8+7]=199;unit.body.offsets[count]=999;
    rejected(ops::empty_buffer(ref mut unit,ref mut state,0,51),3,51);
    rejected(ops::scalar_value(ref mut unit,ref mut state,999,0,52),3,52);
    rejected(ops::scalar_value(ref mut unit,ref mut state,result,1,53),3,53);
    rejected(ops::tag(ref mut unit,ref mut state,7,source,1,54),3,54);
    rejected(ops::tag(ref mut unit,ref mut state,7,source,0,55),3,55);
    rejected(ops::tag(ref mut unit,ref mut state,9,16,1,56),3,56);
    rejected(ops::tag(ref mut unit,ref mut state,9,source,2,57),3,57);
    rejected(ops::scalar_read(ref mut unit,ref mut state,16,58),3,58);
    unit.body.slots[result]=true;
    rejected(ops::scalar_value(ref mut unit,ref mut state,result,0,59),3,59);unit.body.slots[result]=false;
    unit.body.array_parameters[result]=1;
    rejected(ops::scalar_value(ref mut unit,ref mut state,result,0,60),3,60);unit.body.array_parameters[result]=0;
    unit.body.registers=128;
    rejected(ops::scalar_read(ref mut unit,ref mut state,source,61),4,61);unit.body.registers=registers;
    unit.body.count=256;unit.body.code[2047]=198;unit.body.offsets[255]=998;
    rejected(ops::empty_buffer(ref mut unit,ref mut state,6,62),4,62);
    rejected(ops::scalar_value(ref mut unit,ref mut state,result,0,63),4,63);
    rejected(ops::scalar_read(ref mut unit,ref mut state,source,64),4,64);
    rejected(ops::tag(ref mut unit,ref mut state,9,source,1,65),4,65);
    assert(unit.body.count==256 && unit.body.code[2047]==198 && unit.body.offsets[255]==998);
    unit.body.count=count;unchanged(ref unit,ref state,count,registers,1,1);
    let usize dead=ok(bindings::consume(ref unit,ref mut state,source,66));
    rejected(ops::scalar_read(ref mut unit,ref mut state,source,67),3,67);
    rejected(ops::tag(ref mut unit,ref mut state,9,source,1,68),3,68);
    unit.body.function_count=2;state.names.function=1;unit.body.register_starts[1]=registers;
    rejected(ops::scalar_read(ref mut unit,ref mut state,source,69),3,69);
    rejected(ops::scalar_value(ref mut unit,ref mut state,result,0,70),3,70);
    state.names.function=0;unit.body.function_count=1;
    unchanged(ref unit,ref state,count,registers,1,0);
    while(state.next<16){let usize allocated=ok(bindings::allocate(ref mut unit,ref mut state,0,71));}
    rejected(ops::empty_buffer(ref mut unit,ref mut state,6,72),4,72);
    rejected(ops::scalar_value(ref mut unit,ref mut state,result,0,73),4,73);
    rejected(ops::tag(ref mut unit,ref mut state,7,16,0,74),4,74);
    assert(state.next==16 && state.live==0 && unit.body.count==count && unit.body.registers==registers);
    assert(unit.body.code[count*8]==177 && unit.body.code[count*8+7]==199 && unit.body.offsets[count]==999);
    let usize initialized=ok(bindings::initialize(ref unit,ref mut state,source,75));
    let usize read=ok(ops::scalar_read(ref mut unit,ref mut state,source,76));
    assert(read==registers && state.next==16 && state.live==1 && unit.body.code[count*8]==96);
    assert(unit.body.code[count*8+4]==0 && unit.body.code[count*8+7]==0);
}
