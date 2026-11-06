module tests::m2::value_execution;
import value_ir as values;
import value_properties as properties;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import buffer_growth as growth;
import value_frame_meter as meter;
import value_roots as roots;
import value_runtime as runtime;
import slice_reborrow_ir as reborrows;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn usize built(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize measured(Result<usize,meter::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.catalog.count=5;u.catalog.nodes[0]=node(1,1,0);u.catalog.nodes[1]=node(4,0,0);
    u.catalog.nodes[2]=node(5,1,0);u.catalog.nodes[3]=node(6,0,1);u.catalog.nodes[4]=node(5,0,0);
    let usize value=built(ir::literal(ref mut u.body,42,11));return u;
}
fn usize emit(ref mut values::Program u,u8 op,usize dst,usize a,usize b){return built(ir::raw(ref mut u.body,op,dst,a,b,71));}
fn void target(ref mut values::Program u,usize pc,usize destination){
    assert(destination<256);var u8 byte=0;var usize i=0;while(i<destination){byte+=1;i+=1;}u.body.code[pc*8+4]=byte;
}
fn void finish(ref mut values::Program u){
    let usize count=u.body.count;let usize registers=u.body.registers;
    u.body.function_count=1;u.body.entry=0;u.body.starts[0]=0;u.body.ends[0]=count;
    u.body.register_starts[0]=0;u.body.register_ends[0]=registers;u.body.return_types[0]=1;
}
fn void returns(ref values::Program u,usize fuel,usize arena,growth::Limits quota,i64 expected){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,fuel,arena,quota)){case .ok(v):{v==expected}case .err(_):{false}});
}
fn void fails(ref values::Program u,usize fuel,usize arena,growth::Limits quota,u8 kind,usize offset){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,fuel,arena,quota)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==offset}});
}
fn values::Program scalar(){
    var values::Program u=base();u.types[0]=1;u.types[1]=1;u.types[2]=1;
    u.body.registers=2;u.body.types[1]=1;
    let usize a=emit(ref mut u,97,0,0,0);let usize b=emit(ref mut u,89,1,0,0);
    let usize c=emit(ref mut u,88,2,1,0);let usize d=emit(ref mut u,96,1,2,0);
    let usize e=emit(ref mut u,90,0,0,0);let usize f=emit(ref mut u,90,2,0,0);
    let usize done=emit(ref mut u,8,0,1,0);finish(ref mut u);return u;
}
@test fn void scalar_roundtrip_copy_move_drop_reuses_the_native_vm_and_keeps_legacy_admission_closed(){
    let values::Program u=scalar();returns(ref u,1000000,0,limits(),42);
    assert(switch(vm::run(ref u.body,1000000)){case .ok(_):{false}case .err(e):{e.kind==5}});
}

fn values::Program tagged(bool active,bool matching){
    var values::Program u=base();u.types[0]=2;u.types[1]=2;u.types[2]=3;u.types[3]=3;
    if(active){let usize source=emit(ref mut u,95,0,0,0);}
    let usize build=emit(ref mut u,91,2,0,if(active){1}else{0});
    let usize moved=emit(ref mut u,88,3,2,0);
    let usize selected=emit(ref mut u,92,if(matching && active){1}else{0},3,if(matching && active){1}else{0});
    if(matching && active){let usize drop=emit(ref mut u,90,1,0,0);}
    let usize done=emit(ref mut u,8,0,0,0);let usize mismatch=u.body.count;
    let usize released=emit(ref mut u,90,3,0,0);let usize end=emit(ref mut u,8,0,0,0);
    target(ref mut u,selected,mismatch);finish(ref mut u);return u;
}
fn values::Program scalar_tag(){
    var values::Program u=base();u.types[0]=1;u.types[1]=4;u.body.registers=2;u.body.types[1]=1;
    let usize a=emit(ref mut u,97,0,0,0);let usize b=emit(ref mut u,91,1,0,1);let usize c=emit(ref mut u,90,0,0,0);
    let usize selected=emit(ref mut u,92,0,1,1);let usize read=emit(ref mut u,96,1,0,0);
    let usize drop=emit(ref mut u,90,0,0,0);let usize done=emit(ref mut u,8,0,1,0);let usize mismatch=u.body.count;
    let usize released=emit(ref mut u,90,1,0,0);let usize end=emit(ref mut u,8,0,0,0);
    target(ref mut u,selected,mismatch);finish(ref mut u);return u;
}
@test fn void active_inactive_and_mismatched_buffer_tags_clean_up_and_scalar_payloads_roundtrip(){
    let values::Program none=tagged(false,true);returns(ref none,1000000,0,limits(),42);
    let values::Program some=tagged(true,true);returns(ref some,1000000,0,limits(),42);
    // Exhaust Fuel at CASE after EMPTY_BUFFER, TAG_BUILD and MOVE have left a
    // real root in the wrapper. Failure must drain native owners, not guest DROP.
    let usize setup=runtime::context_charge()+roots::setup_cost()+measured(meter::setup_cost(16))+measured(meter::enter_cost(48));
    let usize root_creation=switch(roots::create_cost(0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize before_case=setup+1+measured(meter::operation_cost(8))+root_creation+2*measured(meter::operation_cost(16));
    fails(ref some,before_case+measured(meter::operation_cost(16))-1,0,limits(),8,71);
    returns(ref some,1000000,0,limits(),42);
    let values::Program mismatch=tagged(true,false);returns(ref mismatch,1000000,0,limits(),42);
    let values::Program scalar_payload=scalar_tag();returns(ref scalar_payload,1000000,0,limits(),42);
}

fn values::Program called(bool copying){
    var values::Program u=base();let u8 encoded=if(copying){1}else{2};
    u.types[0]=encoded;u.types[1]=encoded;u.types[2]=encoded;u.types[3]=encoded;u.functions[2]=1;u.functions[3]=1;
    if(copying){let usize source=emit(ref mut u,97,0,0,0);}else{let usize source=emit(ref mut u,95,0,0,0);}
    let usize call=emit(ref mut u,93,if(copying){1}else{0},1,0);
    if(copying){let usize drop_source=emit(ref mut u,90,0,0,0);}
    let usize drop_result=emit(ref mut u,90,if(copying){1}else{0},0,0);
    let usize done=emit(ref mut u,8,0,0,0);finish(ref mut u);let usize start=u.body.count;
    if(copying){let usize drop_extra=emit(ref mut u,90,3,0,0);}
    let usize returned=emit(ref mut u,94,0,2,0);let usize end=u.body.count;
    u.body.function_count=2;u.body.starts[1]=start;u.body.ends[1]=end;
    let usize registers=if(copying){4}else{3};
    u.body.registers=registers;u.body.register_starts[1]=1;u.body.register_ends[1]=registers;
    u.body.arities[1]=if(copying){3}else{2};u.parameters[1]=3;u.results[1]=3;
    u.body.call_count=1;u.body.call_arities[0]=if(copying){3}else{2};u.body.call_args[0]=208;
    if(copying){u.parameters[2]=4;u.body.call_args[1]=208;u.body.types[3]=1;u.body.call_args[2]=0;}
    else{u.body.types[2]=1;u.body.call_args[1]=0;}return u;
}
@test fn void typed_calls_return_into_consumed_actuals_and_allow_repeated_copyable_arguments(){
    let values::Program moved=called(false);returns(ref moved,1000000,0,limits(),42);
    let values::Program copied=called(true);returns(ref copied,1000000,0,limits(),42);
}

fn values::Program nested(){
    var values::Program u=base();u.types[0]=2;u.types[1]=2;u.types[2]=2;u.functions[2]=1;
    u.body.registers=2;u.body.types[1]=1;
    let usize source=emit(ref mut u,95,0,0,0);let usize outer=emit(ref mut u,93,1,1,0);
    let usize done=emit(ref mut u,8,0,1,0);finish(ref mut u);
    let usize first=u.body.count;let usize inner=emit(ref mut u,9,4,2,1);
    let usize drop=emit(ref mut u,90,2,0,0);let usize returned=emit(ref mut u,8,0,4,0);
    let usize second=u.body.count;let usize scalar_return=emit(ref mut u,8,0,5,0);let usize end=u.body.count;
    u.body.function_count=3;u.body.starts[1]=first;u.body.ends[1]=second;u.body.starts[2]=second;u.body.ends[2]=end;
    u.body.registers=6;u.body.register_starts[1]=2;u.body.register_ends[1]=5;u.body.register_starts[2]=5;u.body.register_ends[2]=6;
    u.body.arities[1]=2;u.body.arities[2]=1;u.parameters[2]=3;
    u.body.types[3]=1;u.body.types[4]=1;u.body.types[5]=1;u.body.return_types[1]=1;u.body.return_types[2]=1;
    u.body.call_count=2;u.body.call_arities[0]=2;u.body.call_args[0]=208;u.body.call_args[1]=0;
    u.body.call_arities[1]=1;u.body.call_args[8]=3;return u;
}
@test fn void ordinary_call_and_scalar_return_inside_typed_activation_preserve_the_live_buffer(){
    let values::Program u=nested();returns(ref u,1000000,0,limits(),42);
}

fn values::Program aggregates(){
    var values::Program u=base();u.types[0]=2;u.types[1]=2;
    u.body.records.layouts.count=1;u.body.records.layouts.fields[0]=1;u.body.records.layouts.types[0]=1;
    let usize record=built(ir::record(ref mut u.body,0,false,71));
    let usize record_init=built(ir::record_init(ref mut u.body,record,0,71));
    let usize array=built(ir::array(ref mut u.body,1,1,true,71));
    let usize array_init=built(ir::array_init(ref mut u.body,array,0,71));
    let usize lo=built(ir::integer(ref mut u.body,0,12,71));let usize hi=built(ir::integer(ref mut u.body,1,12,71));
    let usize parent=built(ir::exclusive_slice(ref mut u.body,array,71));
    let usize child=built(reborrows::derived(ref mut u.body,parent,71));
    let usize open=built(ir::slice_open(ref mut u.body,parent,lo,hi,71));
    let usize root=emit(ref mut u,95,0,0,0);let usize moved=emit(ref mut u,88,1,0,0);
    let usize begin=built(reborrows::begin(ref mut u.body,child,parent,lo,hi,71));
    let usize element=built(ir::slice_read(ref mut u.body,child,lo,71));
    let usize end=built(reborrows::end(ref mut u.body,child,parent,71));
    let usize close=built(ir::slice_close(ref mut u.body,parent,71));
    let usize field=built(ir::record_read(ref mut u.body,record,0,71));
    let usize sum=built(ir::emit(ref mut u.body,2,element,field,71));
    let usize record_drop=built(ir::record_drop(ref mut u.body,record,71));
    let usize array_drop=built(ir::array_drop(ref mut u.body,array,71));
    let usize drop=emit(ref mut u,90,1,0,0);let usize done=emit(ref mut u,8,0,sum,0);
    finish(ref mut u);return u;
}
@test fn void ordinary_array_record_and_derived_borrow_share_execution_with_a_live_typed_buffer(){
    let values::Program u=aggregates();returns(ref u,4000000,64,limits(),84);
    fails(ref u,4000000,0,limits(),13,71);returns(ref u,4000000,64,limits(),84);
}

@test fn void exact_fuel_and_combined_quota_boundaries_reject_one_short_and_allow_fresh_retry(){
    let values::Program u=scalar();
    // Numeric oracle independent of production pricing helpers: setup147568,
    // two ordinary dispatches, two 2080 scalar operations, four 2064 transfers/
    // drops. Quota counts context65536 + root4096 + frame12288 + scratch128 +
    // entry128. An accidental double charge must not adjust its own expected.
    let usize price=159986;let usize quota=82176;
    let growth::Limits exact=growth::Limits{.object=4096,.instance=quota,.engine=quota};
    fails(ref u,price-1,0,exact,8,71);returns(ref u,price,0,exact,42);returns(ref u,price+1,0,exact,42);
    fails(ref u,0,0,exact,8,0);
    let growth::Limits instance_short=growth::Limits{.object=4096,.instance=quota-1,.engine=quota};
    let growth::Limits engine_short=growth::Limits{.object=4096,.instance=quota,.engine=quota-1};
    fails(ref u,price,0,instance_short,13,0);fails(ref u,price,0,engine_short,13,0);returns(ref u,price,0,exact,42);
}
