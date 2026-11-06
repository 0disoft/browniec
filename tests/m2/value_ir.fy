module tests::m2::value_ir;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import verifier as verifier;
import vm as vm;
import program_image as programs;
import errors as errors;
import static_call_ir as static_calls;
import static_image as images;
import slice_result_ir as result_ir;
import slice_result_verifier as result_verifier;

fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn void emit(ref mut values::Program unit,u8 op,usize dst,usize a,usize b){
    let usize pc=ok(ir::raw(ref mut unit.body,op,dst,a,b,0));
}
fn void target(ref mut values::Program unit,usize pc,usize destination){
    assert(destination<256);var u8 encoded=0;var usize i=0;while(i<destination){encoded+=1;i+=1;}
    unit.body.code[pc*8+4]=encoded;
}
fn void finish(ref mut values::Program unit){
    let usize count=unit.body.count;let usize registers=unit.body.registers;
    unit.body.function_count=1;unit.body.entry=0;unit.body.starts[0]=0;unit.body.ends[0]=count;
    unit.body.register_starts[0]=0;unit.body.register_ends[0]=registers;unit.body.return_types[0]=1;
}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.catalog.count=6;unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(4,0,0);
    unit.catalog.nodes[2]=node(5,1,0);unit.catalog.nodes[3]=node(6,0,1);
    unit.catalog.nodes[4]=node(5,0,0);unit.catalog.nodes[5]=node(1,2,0);
    unit.types[0]=2;unit.types[1]=2;unit.types[2]=3;unit.types[3]=3;
    unit.types[4]=1;unit.types[5]=4;unit.types[6]=4;unit.types[7]=5;unit.types[8]=5;
    let usize value=ok(ir::literal(ref mut unit.body,42,0));return unit;
}
fn void admitted(ref values::Program unit){switch(verifier::inspect_values(unit)){
    case .ok(proof):{
        // Authenticate the returned aggregate too: optimized native struct-return
        // corruption must not hide behind an intact Result discriminator.
        assert(proof.values.sites.enabled && proof.values.properties.count==unit.catalog.count);
        var usize i=0;while(i<128){assert(proof.values.sites.parameters[i]==unit.parameters[i]);i+=1;}
        i=0;while(i<16){assert(proof.values.sites.results[i]==unit.results[i]);i+=1;}
        i=0;while(i<unit.catalog.count){
            assert(proof.values.classes[i]<=i);
            if(unit.catalog.nodes[i].kind==4){let properties::Property shape=proof.values.properties.properties[i];
                assert(shape.bytes==8 && shape.alignment==8 && !shape.copyable && shape.contains_buffer);}
            i+=1;
        }
    }case .err(_):{assert(false);}
};}
fn void invalid(ref values::Program unit){assert(!verifier::inspect_values(unit).is_ok);}
fn void rejected_at(ref values::Program unit,usize pc){assert(switch(verifier::inspect_values(unit)){
    case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}
});}
fn images::Image empty_image(){
    var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);images::Builder{
        .data=[0;4096],.catalog=images::Catalog{.starts=[0;16],.ends=[0;16],.text=[false;16],.count=0,.used=0},.limit=0}}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);empty_image()}};
}
fn values::Program moved(){
    var values::Program unit=base();emit(ref mut unit,95,0,0,0);emit(ref mut unit,88,1,0,0);
    emit(ref mut unit,90,1,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);return unit;
}
@test fn void moves_consume_sources_and_reject_copy_double_drop_overwrite_and_stale_read(){
    var values::Program unit=moved();admitted(ref unit);
    unit.body.code[3*8+1]=0;rejected_at(ref unit,3); // moved original
    unit=moved();unit.body.code[2*8]=89;rejected_at(ref unit,2); // resource copy
    unit=moved();unit.body.code[3*8]=88;unit.body.code[3*8+2]=0;rejected_at(ref unit,3);
    unit=moved();unit.body.code[2*8]=95;unit.body.code[2*8+1]=0;unit.body.code[2*8+2]=0;rejected_at(ref unit,2);
    unit=moved();unit.body.code[2*8+1]=16;rejected_at(ref unit,2);
    unit=moved();unit.body.code[2*8+6]=1;rejected_at(ref unit,2);
    unit=moved();unit.body.code[3*8]=19;unit.body.code[3*8+1]=0;unit.body.code[3*8+2]=4;rejected_at(ref unit,4);
    // Reinitialize a Dead slot, but never silently replace a live owner.
    unit=base();emit(ref mut unit,95,0,0,0);emit(ref mut unit,90,0,0,0);
    emit(ref mut unit,95,0,0,0);emit(ref mut unit,90,0,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);admitted(ref unit);
}
fn values::Program scalar_arm(){
    var values::Program unit=base();unit.body.registers=2;unit.body.types[1]=1;
    emit(ref mut unit,97,4,0,0);emit(ref mut unit,91,5,4,1);emit(ref mut unit,90,4,0,0);
    emit(ref mut unit,92,4,5,1);target(ref mut unit,4,8);
    emit(ref mut unit,96,1,4,0);emit(ref mut unit,90,4,0,0);emit(ref mut unit,8,0,1,0);
    emit(ref mut unit,90,5,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);return unit;
}
@test fn void inactive_and_scalar_resource_variants_still_consume_the_complete_wrapper(){
    var values::Program unit=base();emit(ref mut unit,91,2,0,0);emit(ref mut unit,88,3,2,0);
    emit(ref mut unit,92,0,3,0);target(ref mut unit,3,5);emit(ref mut unit,8,0,0,0);
    emit(ref mut unit,90,3,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);admitted(ref unit);
    unit.body.code[2*8]=89;rejected_at(ref unit,2); // none cannot be copied
    unit=scalar_arm();admitted(ref unit); // active i32, inactive Buffer
    unit.body.code[6*8]=90;unit.body.code[6*8+1]=5;rejected_at(ref unit,6); // wrapper Dead on match
    unit=scalar_arm();unit.body.code[8*8+1]=4;rejected_at(ref unit,8); // payload absent on mismatch
    unit=scalar_arm();unit.body.code[2*8+3]=0;rejected_at(ref unit,2); // wrong err payload
    unit=scalar_arm();unit.body.code[4*8+3]=2;rejected_at(ref unit,4);
}
@test fn void copyable_tags_copy_payloads_and_equivalent_nodes_preserve_nominal_types(){
    var values::Program unit=base();emit(ref mut unit,97,4,0,0);emit(ref mut unit,91,7,4,1);
    emit(ref mut unit,89,8,7,0);emit(ref mut unit,90,4,0,0);emit(ref mut unit,90,7,0,0);
    emit(ref mut unit,90,8,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);admitted(ref unit);
    unit=base();unit.catalog.count=7;unit.catalog.nodes[6]=node(1,1,0);unit.types[9]=7;
    emit(ref mut unit,97,4,0,0);emit(ref mut unit,89,9,4,0);emit(ref mut unit,90,4,0,0);
    emit(ref mut unit,90,9,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);admitted(ref unit);
    // Equal record bytes do not erase distinct declared nominal identities.
    unit.catalog.records.count=2;unit.catalog.records.fields[0]=1;unit.catalog.records.fields[1]=1;
    unit.catalog.records.types[0]=1;unit.catalog.records.types[16]=1;
    unit.catalog.count=8;unit.catalog.nodes[6]=node(3,0,0);unit.catalog.nodes[7]=node(3,1,0);
    unit.types[4]=7;unit.types[9]=8;unit.body.code[1*8]=89;unit.body.code[1*8+2]=9;invalid(ref unit);
}
fn values::Program loop(){
    var values::Program unit=base();let usize condition=ok(ir::boolean(ref mut unit.body,true,0));
    emit(ref mut unit,95,0,0,0);emit(ref mut unit,88,1,0,0);emit(ref mut unit,88,0,1,0);
    emit(ref mut unit,20,0,condition,7);emit(ref mut unit,22,0,3,0);
    emit(ref mut unit,90,0,0,0);emit(ref mut unit,8,0,0,0);finish(ref mut unit);return unit;
}
@test fn void joins_and_backedges_require_exact_owner_state_and_allow_explicit_loop_reinitialization(){
    var values::Program unit=loop();admitted(ref unit);
    unit.body.code[4*8]=19;unit.body.code[4*8+1]=0;unit.body.code[4*8+2]=5;rejected_at(ref unit,6);
    unit=base();let usize condition=ok(ir::boolean(ref mut unit.body,true,0));emit(ref mut unit,95,0,0,0);
    emit(ref mut unit,20,0,condition,7);emit(ref mut unit,88,1,0,0);emit(ref mut unit,90,1,0,0);
    emit(ref mut unit,19,0,9,0);emit(ref mut unit,90,0,0,0);emit(ref mut unit,19,0,9,0);
    emit(ref mut unit,8,0,0,0);finish(ref mut unit);admitted(ref unit);
    unit.body.code[7*8]=19;unit.body.code[7*8+2]=8;rejected_at(ref unit,8);
}
fn values::Program call(){
    var values::Program unit=base();unit.types[2]=2;unit.functions[2]=1;
    emit(ref mut unit,95,0,0,0);emit(ref mut unit,93,1,1,0);emit(ref mut unit,90,1,0,0);emit(ref mut unit,8,0,0,0);
    finish(ref mut unit);emit(ref mut unit,94,0,2,0);
    unit.body.function_count=2;unit.body.starts[1]=5;unit.body.ends[1]=6;
    unit.body.register_starts[1]=1;unit.body.register_ends[1]=3;unit.body.registers=3;unit.body.arities[1]=2;
    unit.body.types[1]=0;unit.body.types[2]=1;unit.parameters[1]=3;unit.results[1]=3;
    unit.body.call_count=1;unit.body.call_arities[0]=2;unit.body.call_args[0]=208;unit.body.call_args[1]=0;
    return unit;
}
@test fn void mixed_calls_move_into_distinct_frames_and_returns_require_the_sole_exact_owner(){
    var values::Program unit=call();admitted(ref unit);
    unit.body.code[3*8+1]=0;rejected_at(ref unit,3);
    unit=call();unit.body.call_args[0]=210;rejected_at(ref unit,2); // callee namespace
    unit=call();unit.body.code[2*8]=9;rejected_at(ref unit,2); // ordinary CALL cannot move
    unit=call();unit.body.code[5*8]=8;rejected_at(ref unit,5);
    unit=call();unit.body.code[0]=19;unit.body.code[1]=0;unit.body.code[2]=1;rejected_at(ref unit,2); // undefined scalar actual
    unit=call();unit.body.code[2*8+1]=0;unit.body.code[3*8+1]=0;admitted(ref unit); // move back into consumed source
    unit=call();unit.body.types[2]=2;unit.body.return_types[1]=2;invalid(ref unit);
}
fn values::Program two_arguments(bool copy){
    var values::Program unit=base();unit.types[2]=if(copy){5}else{2};unit.functions[2]=1;
    unit.types[3]=if(copy){5}else{2};unit.functions[3]=1;
    if(copy){unit.types[0]=5;unit.types[1]=5;emit(ref mut unit,97,4,0,0);
        emit(ref mut unit,91,0,4,1);emit(ref mut unit,90,4,0,0);
    }else{unit.types[4]=2;emit(ref mut unit,95,0,0,0);emit(ref mut unit,95,4,0,0);}
    emit(ref mut unit,93,1,1,0);emit(ref mut unit,90,1,0,0);if(copy){emit(ref mut unit,90,0,0,0);}
    emit(ref mut unit,8,0,0,0);finish(ref mut unit);let usize end=unit.body.count;
    emit(ref mut unit,90,3,0,0);emit(ref mut unit,94,0,2,0);
    unit.body.function_count=2;unit.body.starts[1]=end;unit.body.ends[1]=end+2;
    unit.body.register_starts[1]=1;unit.body.register_ends[1]=4;unit.body.registers=4;unit.body.arities[1]=3;
    unit.body.types[1]=0;unit.body.types[2]=0;unit.body.types[3]=1;
    unit.parameters[1]=3;unit.parameters[2]=4;unit.results[1]=3;
    unit.body.call_count=1;unit.body.call_arities[0]=3;unit.body.call_args[0]=208;
    unit.body.call_args[1]=if(copy){208}else{212};unit.body.call_args[2]=0;return unit;
}
@test fn void duplicate_copyable_actuals_are_allowed_but_duplicate_moves_and_live_destinations_fail(){
    var values::Program unit=two_arguments(false);admitted(ref unit);
    unit.body.call_args[1]=208;rejected_at(ref unit,3);
    unit=two_arguments(true);admitted(ref unit);
    unit.body.code[4*8+1]=0;rejected_at(ref unit,4); // copyable source stays live
    unit=call();unit.body.call_args[7]=208;rejected_at(ref unit,2);
}
fn values::Program places(){
    var values::Program unit=base();let usize array=ok(ir::array(ref mut unit.body,1,1,true,0));
    let usize index=ok(ir::integer(ref mut unit.body,0,12,0));let usize init=ok(ir::array_init(ref mut unit.body,array,0,0));
    let usize selected=ok(ir::place_select(ref mut unit.body,0,array,index,0));
    emit(ref mut unit,95,0,0,0);emit(ref mut unit,91,2,0,1);emit(ref mut unit,92,1,2,1);target(ref mut unit,6,11);
    emit(ref mut unit,90,1,0,0);emit(ref mut unit,86,0,0,0);emit(ref mut unit,37,0,0,0);emit(ref mut unit,8,0,0,0);
    emit(ref mut unit,90,2,0,0);emit(ref mut unit,86,0,0,0);emit(ref mut unit,37,0,0,0);emit(ref mut unit,8,0,0,0);
    finish(ref mut unit);return unit;
}
@test fn void canonical_scalar_owner_and_selected_place_checks_cover_both_tag_case_edges(){
    var values::Program unit=places();admitted(ref unit);
    unit.body.code[12*8]=19;unit.body.code[12*8+2]=13;rejected_at(ref unit,13);
    unit=places();unit.body.code[13*8]=19;unit.body.code[13*8+2]=14;rejected_at(ref unit,14);
    unit=places();unit.body.code[6*8+4]=10;invalid(ref unit); // mismatched resource state at scalar return
    unit=scalar_arm();unit.body.code[0]=19;unit.body.code[1]=0;unit.body.code[2]=1;rejected_at(ref unit,1);
}
@test fn void malformed_metadata_and_all_preexisting_executable_routes_keep_their_gates(){
    var values::Program unit=moved();admitted(ref unit);
    assert(!verifier::verify(ref unit.body).is_ok && !programs::retain_public_legacy(ref unit.body).is_ok);
    assert(switch(vm::run(ref unit.body,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
    let images::Image image=empty_image();
    let static_calls::Program static_unit=static_calls::Program{.body=unit.body,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(!verifier::verify_static_calls(ref static_unit,ref image).is_ok);
    let result_ir::Program returned=result_ir::Program{.body=unit.body,.elements=[0;16],.parameters=[0;16]};
    assert(!result_verifier::inspect(ref returned).is_ok);
    unit=moved();unit.parameters[127]=1;invalid(ref unit);
    unit=moved();unit.types[15]=65;invalid(ref unit);
    unit=moved();unit.functions[15]=1;invalid(ref unit);
    unit=moved();unit.results[15]=1;invalid(ref unit);
    unit=moved();unit.body.count=257;invalid(ref unit);
    unit=moved();unit.body.code[1*8+7]=1;rejected_at(ref unit,1);
    unit=moved();unit.catalog.nodes[63].kind=4;invalid(ref unit);
    // Full positive bounds: 64 type nodes, all 16 live values, 128 ordinary
    // registers (including high word127) and a final RETURN at PC255.
    unit=base();unit.catalog.count=64;var usize i=0;
    while(i<64){unit.catalog.nodes[i]=node(4,0,0);i+=1;}
    while(unit.body.registers<128){let usize value=ok(ir::literal(ref mut unit.body,42,0));}
    i=0;while(i<16){unit.types[i]=64;emit(ref mut unit,95,i,0,0);i+=1;}
    i=0;while(i<16){emit(ref mut unit,90,i,0,0);i+=1;}
    while(unit.body.count<255){let usize next=unit.body.count+1;emit(ref mut unit,19,0,next,0);}
    emit(ref mut unit,8,0,127,0);finish(ref mut unit);admitted(ref unit);
}
