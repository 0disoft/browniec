module tests::m2::value_source_case;
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
fn ops::Case selected(Result<ops::Case,errors::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);ops::Case{.instruction=256,.payload=16}}
};}
fn void rejected(Result<ops::Case,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn void bad_patch(Result<usize,errors::Error> result,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==3 && e.offset==at}});
}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=1;unit.catalog.count=5;
    unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(4,0,0);
    unit.catalog.nodes[2]=node(5,0,0);unit.catalog.nodes[3]=node(5,1,0);
    unit.catalog.nodes[4]=node(6,0,1);return unit;
}
fn void returned(ref mut values::Program unit,usize register){
    let usize pc=ok(ir::raw(ref mut unit.body,8,0,register,0,70));
}
fn void finish(ref mut values::Program unit){
    let usize count=unit.body.count;let usize registers=unit.body.registers;
    unit.body.ends[0]=count;unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
}
// Both alternatives terminate; their exhaustive mismatch is an explicit failure.
// Compile-time path selection preserves the monotonic allocation high-water mark.
fn values::Program exhaustive(usize exact_type,u8 variant){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize result=ok(ir::literal(ref mut unit.body,42,0));var usize input=16;
    if(variant==1 || exact_type==4){
        input=if(exact_type==3 || variant==0){ok(ops::empty_buffer(ref mut unit,ref mut state,1,10))}
            else{ok(ops::scalar_value(ref mut unit,ref mut state,result,0,10))};
    }
    let usize source=ok(ops::tag(ref mut unit,ref mut state,exact_type,input,variant,11));
    if(input!=16){let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,input,12));}
    let bindings::Snapshot entry=bindings::snapshot(ref state);let usize entry_live=state.live;
    let usize first_slot=state.next;
    let ops::Case some=selected(ops::case_value(ref mut unit,ref mut state,source,1,20));
    assert(some.payload==first_slot && state.next==first_slot+1);
    assert(values::type_id(ref unit,some.payload)==if(exact_type==3){1}else{0});
    assert(state.live==((if(exact_type==2){entry_live}else{0})|bit(some.payload)));
    let usize start=some.instruction*8;
    assert(unit.body.code[start]==92 && unit.body.code[start+1] as usize==some.payload &&
        unit.body.code[start+2] as usize==source && unit.body.code[start+3]==1 && unit.body.offsets[some.instruction]==20);
    var usize i=4;while(i<8){assert(unit.body.code[start+i]==0);i+=1;}
    let usize extracted=if(exact_type==3){result}else{ok(ops::scalar_read(ref mut unit,ref mut state,some.payload,21))};
    let usize child_drop=ok(bindings::drop(ref mut unit,ref mut state,some.payload,22));
    let usize subject_drop=ok(bindings::drop(ref mut unit,ref mut state,source,23));
    assert(state.live==0);returned(ref mut unit,extracted);
    let usize cursor=state.next;
    let usize alternative=ok(bindings::select_path(ref unit,ref mut state,ref entry,30));
    assert(state.next==cursor && state.live==entry_live);
    let usize target=unit.body.count;let usize patched=ok(ops::patch_case(ref mut unit,some.instruction,target,31));
    let ops::Case none=selected(ops::case_value(ref mut unit,ref mut state,source,0,32));
    assert(none.instruction==target && unit.body.code[start+4] as usize==target);
    if(exact_type==4){
        assert(none.payload==cursor && state.next==cursor+1 && values::type_id(ref unit,none.payload)==1);
        assert(state.live==bit(none.payload));
        let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,none.payload,33));
    }else{
        assert(none.payload==16 && state.next==cursor && unit.body.code[none.instruction*8+1]==0);
        assert(state.live==if(exact_type==2){entry_live}else{0});
    }
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,source,34));
    assert(state.live==0);returned(ref mut unit,result);
    let usize failure=unit.body.count;let usize final_patch=ok(ops::patch_case(ref mut unit,none.instruction,failure,35));
    let usize failed=ok(ir::raw(ref mut unit.body,25,0,0,0,36));finish(ref mut unit);return unit;
}

@test fn void exhaustive_cases_copy_plain_wrappers_and_move_whole_buffer_wrappers_on_both_variants(){
    let growth::Limits quota=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    var usize exact_type=2;while(exact_type<5){var u8 variant=0;while(variant<2){
        let values::Program unit=exhaustive(exact_type,variant);
        assert(verifier::inspect_values(ref unit).is_ok);
        assert(switch(vm::run_values(ref unit,4000000,0,quota)){case .ok(v):{v==42}case .err(_):{false}});
        variant+=1;
    }exact_type+=1;}
    // Independent proof must reject consuming the already moved wrapper instead
    // of its initialized scalar child, even though the Buffer arm is inactive.
    var values::Program broken=exhaustive(4,1);var usize pc=0;
    while(broken.body.code[pc*8]!=92){pc+=1;}
    let u8 moved=broken.body.code[pc*8+2];broken.body.code[(pc+2)*8+1]=moved;
    assert(!verifier::inspect_values(ref broken).is_ok);
    broken=exhaustive(2,0);pc=0;while(broken.body.code[pc*8]!=92){pc+=1;}
    // Option.none must keep canonical dst0 even when other slots exist.
    let usize mismatch=broken.body.code[pc*8+4] as usize;
    broken.body.code[mismatch*8+1]=1; // Noncanonical dst for Option.none.
    assert(!verifier::inspect_values(ref broken).is_ok);
}

@test fn void none_needs_no_free_child_slot_and_patch_defers_final_target_admission(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize source=ok(ops::tag(ref mut unit,ref mut state,3,16,0,40));
    while(state.next<16){let usize allocated=ok(bindings::allocate(ref mut unit,ref mut state,0,41));}
    let usize count=unit.body.count;
    // Reserved bytes must be cleared even when destination zero is also source.
    var usize i=0;while(i<8){unit.body.code[count*8+i]=199;i+=1;}
    let ops::Case none=selected(ops::case_value(ref mut unit,ref mut state,source,0,42));
    assert(none.payload==16 && none.instruction==count && state.next==16 && state.live==0);
    assert(unit.body.count==count+1 && unit.body.code[count*8+1]==0 && unit.body.code[count*8+2]==0);
    i=3;while(i<8){assert(unit.body.code[count*8+i]==0);i+=1;}
    let usize target=unit.body.count;
    assert(ok(ops::patch_case(ref mut unit,none.instruction,target,43))==none.instruction);
    assert(unit.body.code[count*8+4] as usize==target && unit.body.offsets[count]==42);
    bad_patch(ops::patch_case(ref mut unit,none.instruction,none.instruction,44),44);
    bad_patch(ops::patch_case(ref mut unit,none.instruction,256,45),45);
    bad_patch(ops::patch_case(ref mut unit,target,target+1,46),46);
    bad_patch(ops::patch_case(ref mut unit,0,target,47),47); // TAG_BUILD, not CASE.
    assert(unit.body.count==target && unit.body.code[count*8+4] as usize==target);
    let usize result=ok(ir::literal(ref mut unit.body,42,48));returned(ref mut unit,result);
    let usize failure=unit.body.count;let usize final_patch=ok(ops::patch_case(ref mut unit,none.instruction,failure,48));
    let usize failed=ok(ir::raw(ref mut unit.body,25,0,0,0,48));finish(ref mut unit);
    assert(verifier::inspect_values(ref unit).is_ok);
    // Patching itself admits a byte-sized forward placeholder, not a final CFG.
    let usize patched=ok(ops::patch_case(ref mut unit,none.instruction,255,49));
    assert(!verifier::inspect_values(ref unit).is_ok);
}

fn void unchanged(ref values::Program unit,ref bindings::State state,usize count,usize next,usize live){
    assert(unit.body.count==count && unit.body.registers==1 && state.next==next && state.live==live);
    assert(state.names.count==0);var usize i=0;while(i<8){assert(unit.body.code[count*8+i]==199);i+=1;}
    assert(unit.body.offsets[count]==999);i=next;while(i<16){assert(unit.types[i]==0 && unit.functions[i]==0);i+=1;}
}
@test fn void invalid_cases_and_full_instruction_or_child_budgets_reject_atomically(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize result=ok(ir::literal(ref mut unit.body,42,0));
    let usize scalar=ok(ops::scalar_value(ref mut unit,ref mut state,result,0,50));
    let usize source=ok(ops::tag(ref mut unit,ref mut state,4,scalar,1,51));
    let usize count=unit.body.count;let usize next=state.next;let usize bits=state.live;
    var usize i=0;while(i<8){unit.body.code[count*8+i]=199;i+=1;}unit.body.offsets[count]=999;
    rejected(ops::case_value(ref mut unit,ref mut state,source,2,52),3,52);
    rejected(ops::case_value(ref mut unit,ref mut state,scalar,1,53),3,53);
    rejected(ops::case_value(ref mut unit,ref mut state,16,1,54),3,54);
    unchanged(ref unit,ref state,count,next,bits);
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,source,55));
    rejected(ops::case_value(ref mut unit,ref mut state,source,1,56),3,56);
    unchanged(ref unit,ref state,count,next,1);
    let usize initialized=ok(bindings::initialize(ref unit,ref mut state,source,57));
    unit.catalog.nodes[4].second=4; // Invalid property plan, before allocation.
    rejected(ops::case_value(ref mut unit,ref mut state,source,1,58),3,58);
    unchanged(ref unit,ref state,count,next,bits);unit.catalog.nodes[4].second=1;
    unit.functions[source]=1;
    rejected(ops::case_value(ref mut unit,ref mut state,source,1,59),3,59);
    unchanged(ref unit,ref state,count,next,bits);unit.functions[source]=0;
    unit.body.count=256;unit.body.code[2047]=198;unit.body.offsets[255]=998;
    rejected(ops::case_value(ref mut unit,ref mut state,source,1,60),4,60);
    rejected(ops::case_value(ref mut unit,ref mut state,source,0,61),4,61);
    assert(unit.body.count==256 && unit.body.code[2047]==198 && unit.body.offsets[255]==998);
    unit.body.count=count;unchanged(ref unit,ref state,count,next,bits);
    while(state.next<16){let usize allocated=ok(bindings::allocate(ref mut unit,ref mut state,0,62));}
    rejected(ops::case_value(ref mut unit,ref mut state,source,1,63),4,63);
    rejected(ops::case_value(ref mut unit,ref mut state,source,0,64),4,64); // err still needs Buffer.
    unchanged(ref unit,ref state,count,16,bits);
    // The final instruction slot is usable when no child allocation is needed.
    unit.types[source]=4;unit.body.count=255;
    let ops::Case none=selected(ops::case_value(ref mut unit,ref mut state,source,0,65));
    assert(none.instruction==255 && none.payload==16 && unit.body.count==256 && state.next==16 && state.live==1);
}
