module tests::m2::value_source_propagation;
import value_source_propagation as propagation;
import value_source_bindings as bindings;
import value_source_control as branches;
import value_source_ops as ops;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import std::vec as vec;

fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn propagation::Expanded expanded(Result<propagation::Expanded,errors::Error> result){
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);propagation::Expanded{.payload=16,.exact=64}}};
}
fn void rejected(Result<propagation::Expanded,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn u8 byte(usize n){var u8 b=0;var usize i=0;while(i<n){b+=1;i+=1;}return b;}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=2;unit.body.entry=1;unit.body.return_types[1]=1;unit.catalog.count=20;
    unit.catalog.nodes[0]=node(1,1,0);unit.catalog.nodes[1]=node(1,2,0);
    unit.catalog.nodes[2]=node(1,9,0);unit.catalog.nodes[3]=node(4,0,0);
    unit.catalog.nodes[4]=node(5,0,0);unit.catalog.nodes[5]=node(5,3,0);
    unit.catalog.nodes[6]=node(5,5,0);unit.catalog.nodes[7]=node(6,0,3);
    unit.catalog.nodes[8]=node(6,3,3);unit.catalog.nodes[9]=node(6,5,3);
    unit.catalog.nodes[10]=node(5,1,0);unit.catalog.nodes[11]=node(6,1,3);
    unit.catalog.nodes[12]=node(6,0,2);unit.catalog.nodes[13]=node(6,1,2);
    unit.catalog.nodes[14]=node(6,3,5);unit.catalog.nodes[15]=node(6,1,5);
    unit.catalog.nodes[16]=node(5,2,0);unit.catalog.nodes[17]=node(6,0,1);
    unit.catalog.nodes[18]=node(6,0,4);unit.catalog.nodes[19]=node(6,1,4);return unit;
}
fn void anchor(ref mut values::Program unit,ref mut bindings::State state,usize type){
    let usize id=ok(bindings::allocate(unit,state,type,1));unit.results[0]=byte(id+1);
}
// Build only the small scalar/Buffer/wrapper DAG above. Explicitly drop copied
// constructor children, as the parent parser does for anonymous expressions.
fn usize made(ref mut values::Program unit,ref mut bindings::State state,usize type,u8 variant){
    let properties::Node n=unit.catalog.nodes[type];
    if(n.kind==4){return ok(ops::empty_buffer(unit,state,type,10));}
    if(n.kind==1){let usize r=if(n.first==2){ok(ir::boolean(ref mut unit.body,true,10))}
        else{ok(ir::integer(ref mut unit.body,42,n.first,10))};
        return ok(ops::scalar_value(unit,state,r,type,10));
    }
    let usize child=if(n.kind==5 && variant==0){16}else{
        made(unit,state,if(variant==1){n.first as usize}else{n.second as usize},1)
    };
    let usize result=ok(ops::tag(unit,state,type,child,variant,11));
    if(child!=16){let usize dropped=ok(bindings::drop(unit,state,child,12));}return result;
}
fn void ended(ref mut values::Program unit,usize f){
    let usize count=unit.body.count;let usize registers=unit.body.registers;
    unit.body.ends[f]=count;unit.body.register_ends[f]=registers;
}
// Function 0 performs propagation with a real declared result anchor. Function
// 1 CALLs it, checks the actual returned variant, drops its result and returns42.
// No parser/compiler integration is used by these primitive fixtures.
fn values::Program fixture(usize input_type,usize result_type,u8 variant){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    anchor(ref mut unit,ref mut state,result_type);
    let usize anonymous=made(ref mut unit,ref mut state,3,1);
    let usize named=made(ref mut unit,ref mut state,3,1);
    let usize name=ok(bindings::declare(ref unit,ref mut state,b"owner",0,5,named,3));
    let usize subject=made(ref mut unit,ref mut state,input_type,variant);
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    let usize outer=ok(branches::save(ref mut paths,ref state,40));let usize begin=unit.body.count;
    let propagation::Expanded success=expanded(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,result_type,50));
    assert(branches::mark(ref paths)==1 && outer==0);
    assert(success.exact==unit.catalog.nodes[input_type].first as usize);
    assert(values::type_id(ref unit,success.payload)==success.exact && state.next>success.payload+1);
    assert(state.live==(bit(anonymous)|bit(named)|bit(success.payload)));
    assert(state.names.count==1 && state.bindings[0] as usize==named+1);
    let usize continuation=unit.body.count;var usize pc=begin;var usize cases=0;var usize jumps=0;var usize returns=0;var usize fails=0;
    while(pc<continuation){let usize row=pc*8;let u8 op=unit.body.code[row];
        assert(op==92 || op==19 || op==91 || op==90 || op==94 || op==25);
        assert(unit.body.offsets[pc]==50);
        if(op==92){cases+=1;
            if(unit.body.code[row+3]==0){let usize target=unit.body.code[row+4] as usize;assert(unit.body.code[target*8]==25);}
        }
        if(op==19){jumps+=1;assert(unit.body.code[row+2] as usize==continuation);}
        if(op==94){returns+=1;}if(op==25){fails+=1;}pc+=1;
    }
    assert(cases==2 && jumps==1 && returns==1 && fails==1);
    let usize freed=ok(branches::release(ref mut paths,0,51));
    // The enclosing success payload deliberately differs from the operand's.
    let usize returned=made(ref mut unit,ref mut state,result_type,1);
    let usize cleaned=ok(propagation::finish_function(ref mut unit,ref mut state,returned,60));
    assert(state.live==0 && state.names.count==0 && state.bindings[0]==0);
    let usize terminal=ok(ir::raw(ref mut unit.body,94,0,returned,0,60));ended(ref mut unit,0);

    let usize entered=ok(bindings::enter_function(ref unit,ref mut state,1,70));
    let usize start=unit.body.count;let usize registers=unit.body.registers;
    unit.body.starts[1]=start;unit.body.register_starts[1]=registers;
    let usize result=ok(bindings::allocate(ref mut unit,ref mut state,result_type,70));
    unit.body.call_count=1;
    let usize called=ok(ir::raw(ref mut unit.body,93,result,0,0,70));
    let usize initialized=ok(bindings::initialize(ref unit,ref mut state,result,70));
    let usize test=ok(ops::tag_test(ref mut unit,ref mut state,result,variant,71));
    let usize guard=ok(ir::raw(ref mut unit.body,20,0,test,0,71));
    let usize dropped=ok(propagation::finish_function(ref mut unit,ref mut state,16,72));
    let usize answer=ok(ir::literal(ref mut unit.body,42,73));
    let usize main_return=ok(ir::raw(ref mut unit.body,8,0,answer,0,73));
    let usize failure=ok(ir::raw(ref mut unit.body,25,0,0,0,74));
    let usize patched=ok(ir::patch(ref mut unit.body,guard,failure,74));ended(ref mut unit,1);return unit;
}
fn void executes(ref values::Program unit){
    assert(verifier::inspect_values(unit).is_ok);
    let growth::Limits quota=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(unit,10000000,0,quota)){case .ok(v):{v==42}case .err(_):{false}});
}

@test fn void propagation_success_and_failure_preserve_plain_nested_and_buffer_ownership(){
    let usize[10] inputs=[4,5,6,7,8,9,12,14,16,18];
    let usize[10] outputs=[10,10,10,11,11,11,13,15,10,19];
    var usize i=0;while(i<inputs.len){var u8 variant=0;while(variant<2){
        let values::Program unit=fixture(inputs[i],outputs[i],variant);executes(ref unit);variant+=1;
    }i+=1;}
}

fn void refuses(usize input_type,usize result_type){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    anchor(ref mut unit,ref mut state,result_type);let usize subject=made(ref mut unit,ref mut state,input_type,1);
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    let usize count=unit.body.count;let usize next=state.next;let usize live=state.live;
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,result_type,80),3,80);
    assert(unit.body.count==count && state.next==next && state.live==live && branches::mark(ref paths)==0);
}
@test fn void propagation_rejects_wrong_families_exact_errors_contexts_and_exhausted_budgets(){
    refuses(4,11);refuses(7,10);refuses(7,13);refuses(12,11);refuses(14,11);refuses(18,15);
    refuses(0,10);refuses(4,0);
    var values::Program unit=base();var bindings::State state=bindings::empty();
    anchor(ref mut unit,ref mut state,10);let usize subject=made(ref mut unit,ref mut state,4,1);
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    let usize count=unit.body.count;
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,64,81),3,81);
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,16,10,82),3,82);
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,4,83),3,83); // Wrong real return anchor.
    unit.results[0]=0;rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,10,84),3,84);
    unit.results[0]=1;unit.body.return_types[0]=1;
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,10,85),3,85);
    unit.body.return_types[0]=0;unit.functions[subject]=1;
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,10,86),3,86);unit.functions[subject]=0;
    let usize consumed=ok(bindings::consume(ref unit,ref mut state,subject,87));
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,10,88),3,88);
    let usize initialized=ok(bindings::initialize(ref unit,ref mut state,subject,89));
    assert(unit.body.count==count && branches::mark(ref paths)==0);
    unit.body.count=256;
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,10,90),4,90);
    assert(branches::mark(ref paths)==0 && unit.body.count==256);unit.body.count=count;
    // Entry save succeeds but success save hits the bounded pool. The helper
    // must release only its own appended entry, even on this partial error.
    while(branches::mark(ref paths)<127){let usize saved=ok(branches::save(ref mut paths,ref state,91));}
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,subject,10,92),4,92);
    assert(branches::mark(ref paths)==127);let usize released=ok(branches::release(ref mut paths,0,93));
    // A separate candidate exhausts the static slot ledger before CASE payload.
    unit=base();state=bindings::empty();anchor(ref mut unit,ref mut state,10);
    let usize other=made(ref mut unit,ref mut state,4,1);
    while(state.next<16){let usize allocated=ok(bindings::allocate(ref mut unit,ref mut state,0,94));}
    rejected(propagation::lower(ref mut unit,ref mut state,ref mut paths,other,10,95),4,95);
    assert(branches::mark(ref paths)==0 && state.next==16);
}

@test fn void independent_cfg_proof_requires_anonymous_failure_cleanup_and_separate_success_entry(){
    var values::Program unit=fixture(14,15,0);executes(ref unit);
    // The anonymous Buffer is slot1, after the Dead result anchor. Skipping its
    // failure DROP must independently reject RETURN with that owner still live.
    var usize pc=0;while(!(unit.body.code[pc*8]==90 && unit.body.code[pc*8+1]==1 && unit.body.offsets[pc]==50)){pc+=1;}
    unit.body.code[pc*8]=19;unit.body.code[pc*8+1]=0;unit.body.code[pc*8+2]=byte(pc+1);
    assert(!verifier::inspect_values(ref unit).is_ok);
    unit=fixture(4,10,1);pc=0;while(unit.body.code[pc*8]!=92){pc+=1;}
    let usize first_case=pc;
    while(unit.body.code[pc*8]!=19){pc+=1;}
    let u8 bad_target=unit.body.code[pc*8+2];unit.body.code[first_case*8+4]=bad_target; // Mismatch skips payload definition/cleanup.
    assert(!verifier::inspect_values(ref unit).is_ok);
    unit=fixture(7,11,0);pc=0;while(unit.body.code[pc*8]!=25){pc+=1;}
    unit.body.code[pc*8+1]=1;assert(!verifier::inspect_values(ref unit).is_ok); // FAIL must remain canonical.
    let values::Program clean=fixture(8,11,0);
    let growth::Limits tiny=growth::Limits{.object=4096,.instance=1,.engine=1048576};
    assert(switch(vm::run_values(ref clean,10000000,0,tiny)){case .ok(_):{false}case .err(e):{e.kind==13}});
    assert(switch(vm::run_values(ref clean,0,0,growth::Limits{.object=4096,.instance=1048576,.engine=1048576})){
        case .ok(_):{false}case .err(e):{e.kind==8}
    });
    executes(ref clean);executes(ref clean);
}
