module tests::m2::record_place_execution;
import ir as ir;
import record_place_ir as places;
import vm as vm;
import verifier as verifier;
import errors as errors;
import static_image as images;
import static_call_ir as calls;
import program_image as programs;
import slice_result_ir as results;
import slice_result_runtime as runtime;
import slice_result_execution as retained;
import array_owners as owners;
import array_slices as slices;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void completed(Result<i64,errors::Error> r){assert(switch(r){case .ok(v):{v==42}case .err(_):{false}});}
fn void shortage(Result<i64,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn void end(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;
    p.ends[f]=n;p.register_ends[f]=r;if(f+1<p.function_count){p.starts[f+1]=n;p.register_starts[f+1]=r;}}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};}
fn void public_retained(ref ir::Program p,usize fuel,bool exact){
    let calls::Program unit=calls::Program{.body=*p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    switch(programs::retain_reference_returns(ref unit,image(),65536)){
        case .ok(code):{if(exact){shortage(programs::run_public_references(ref code,fuel-1));}
            completed(programs::run_public_references(ref code,fuel));
            if(exact){completed(programs::run_public_references(ref code,fuel+1));}}
        case .err(_):{assert(false);}
    };
}
fn void layout(ref mut ir::Program p,u8 tag){p.records.layouts.count=2;p.records.layouts.fields[0]=1;
    p.records.layouts.kinds[0]=1;p.records.layouts.types[0]=1;p.records.layouts.fields[1]=2;
    p.records.layouts.types[16]=tag;p.records.layouts.types[17]=tag;}
fn ir::Program compound(){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;layout(ref mut p,1);
    let usize root=built(ir::record_in(ref mut p,0,0,true,0));let usize first=built(ir::literal(ref mut p,20,0));
    let usize second=built(ir::literal(ref mut p,99,0));let usize init=built(ir::record_init(ref mut p,root,first,0));
    let usize selected=built(places::select(ref mut p,0,root,0,0));let usize old=built(places::read(ref mut p,0,root,0,0));
    let usize delta=built(ir::literal(ref mut p,22,0));let usize fresh=built(ir::emit(ref mut p,2,old,delta,0));
    let usize store=built(places::store(ref mut p,0,root,0,fresh,0));let usize done=built(ir::place_end(ref mut p,0,0));
    let usize observed=built(ir::record_read(ref mut p,root,0,0));let usize drop=built(ir::record_drop(ref mut p,root,0));
    let usize ret=built(ir::emit(ref mut p,8,observed,0,0));end(ref mut p,0);return p;
}
@test fn void ordinary_and_retained_record_compounds_match_independent_exact_fuel(){
    let ir::Program p=compound();assert(verifier::verify(ref p).is_ok);
    // Body210605 + setup5077 + native backing9. Public backing adds65528.
    shortage(vm::run_with_array_limit(ref p,215690,8));completed(vm::run_with_array_limit(ref p,215691,8));
    completed(vm::run_with_array_limit(ref p,215692,8));shortage(vm::run(ref p,281218));
    completed(vm::run(ref p,281219));public_retained(ref p,625290,true);
}
fn usize scalar(ref mut ir::Program p,u8 tag,i64 n){return if(tag==2){built(ir::boolean(p,n!=0,0))}else{built(ir::integer(p,n,tag,0))};}
fn ir::Program domain(u8 tag){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;layout(ref mut p,tag);
    let usize root=built(ir::record_in(ref mut p,0,0,true,0));let usize first=scalar(ref mut p,tag,0);
    let usize second=scalar(ref mut p,tag,0);let usize init=built(ir::record_init(ref mut p,root,first,0));
    let usize selected=built(places::select(ref mut p,0,root,1,0));let usize old=built(places::read(ref mut p,0,root,1,0));
    let usize fresh=scalar(ref mut p,tag,if(tag==2){1}else{42});let usize store=built(places::store(ref mut p,0,root,1,fresh,0));
    let usize done=built(ir::place_end(ref mut p,0,0));let usize observed=built(ir::record_read(ref mut p,root,1,0));
    let usize drop=built(ir::record_drop(ref mut p,root,0));let usize eq=built(ir::emit(ref mut p,11,observed,fresh,0));
    let usize branch=built(ir::raw(ref mut p,20,0,eq,0,0));let usize yes=built(ir::literal(ref mut p,42,0));
    let usize ret=built(ir::emit(ref mut p,8,yes,0,0));let usize target=p.count;let usize patched=built(ir::patch(ref mut p,branch,target,0));
    let usize no=built(ir::literal(ref mut p,0,0));let usize bad=built(ir::emit(ref mut p,8,no,0,0));end(ref mut p,0);return p;
}
@test fn void six_scalar_domains_use_nested_ordinals_and_current_owner_bindings_in_both_drivers(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){let ir::Program p=domain(tags[i]);
        completed(vm::run_with_array_limit(ref p,1000000,16));public_retained(ref p,2000000,false);i+=1;}
}
fn ir::Program called(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;layout(ref mut p,1);
    let usize formal=built(ir::record_parameter(ref mut p,0,0,0));let usize local=built(ir::record_in(ref mut p,0,0,true,0));
    let usize copy=built(ir::record_copy(ref mut p,local,formal,0));let usize s=built(places::select(ref mut p,0,local,0,0));
    let usize old=built(places::read(ref mut p,0,local,0,0));let usize d=built(ir::literal(ref mut p,22,0));
    let usize fresh=built(ir::emit(ref mut p,2,old,d,0));let usize w=built(places::store(ref mut p,0,local,0,fresh,0));
    let usize e=built(ir::place_end(ref mut p,0,0));let usize drop=built(ir::record_drop(ref mut p,local,0));
    let usize drop_formal=built(ir::record_drop(ref mut p,formal,0));
    let usize ret=built(ir::emit(ref mut p,8,fresh,0,0));end(ref mut p,0);
    let usize root=built(ir::record_in(ref mut p,1,0,true,0));let usize argument=built(ir::record_in(ref mut p,1,0,false,0));
    let usize first=built(ir::literal(ref mut p,20,0));let usize second=built(ir::literal(ref mut p,99,0));
    let usize init=built(ir::record_init(ref mut p,root,first,0));let usize capture=built(ir::record_copy(ref mut p,argument,root,0));
    let usize select=built(places::select(ref mut p,0,root,0,0));let usize prior=built(places::read(ref mut p,0,root,0,0));
    let usize[1] args=[144+argument];let usize result=built(ir::call(ref mut p,0,ref args,0));
    let usize delta=built(ir::literal(ref mut p,22,0));let usize after=built(ir::emit(ref mut p,2,prior,delta,0));
    let usize written=built(places::store(ref mut p,0,root,0,after,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize observed=built(ir::record_read(ref mut p,root,0,0));let usize drop_arg=built(ir::record_drop(ref mut p,argument,0));
    let usize drop_root=built(ir::record_drop(ref mut p,root,0));let usize returned=built(ir::emit(ref mut p,8,observed,0,0));
    end(ref mut p,1);return p;
}
@test fn void caller_and_callee_share_place_ids_without_losing_original_record_tokens(){
    let ir::Program p=called();assert(verifier::verify(ref p).is_ok);
    completed(vm::run_with_array_limit(ref p,3000000,32));public_retained(ref p,4000000,false);
}
fn ir::Program returned_record(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[1]=1;layout(ref mut p,1);
    let usize root=built(ir::record_in(ref mut p,0,0,true,0));p.record_results[0]=1;
    let usize first=built(ir::literal(ref mut p,20,0));let usize second=built(ir::literal(ref mut p,99,0));
    let usize init=built(ir::record_init(ref mut p,root,first,0));let usize s=built(places::select(ref mut p,0,root,0,0));
    let usize answer=built(ir::literal(ref mut p,42,0));let usize w=built(places::store(ref mut p,0,root,0,answer,0));
    let usize e=built(ir::place_end(ref mut p,0,0));let usize r=built(ir::record_return(ref mut p,root,0));end(ref mut p,0);
    let usize target=built(ir::record_in(ref mut p,1,0,true,0));let usize[1] none=[0];
    let usize call=built(ir::record_call(ref mut p,0,target,ref none[..0],0));
    let usize select=built(places::select(ref mut p,0,target,0,0));let usize value=built(places::read(ref mut p,0,target,0,0));
    let usize store=built(places::store(ref mut p,0,target,0,value,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize drop=built(ir::record_drop(ref mut p,target,0));let usize ret=built(ir::emit(ref mut p,8,value,0,0));end(ref mut p,1);return p;
}
@test fn void record_result_handoff_rebinds_current_tokens_after_callee_place_cleanup(){
    let ir::Program p=returned_record();assert(verifier::verify(ref p).is_ok);
    completed(vm::run_with_array_limit(ref p,2000000,8));public_retained(ref p,3000000,false);
}
fn calls::Program guarded(){
    var ir::Program p=ir::empty();p.function_count=2;p.return_types[0]=1;layout(ref mut p,1);
    let usize array=built(ir::array_in(ref mut p,0,10,1,true,0));let usize root=built(ir::record_in(ref mut p,0,0,true,0));
    let usize byte=built(ir::integer(ref mut p,42,10,0));let usize init_a=built(ir::array_init(ref mut p,array,byte,0));
    let usize first=built(ir::literal(ref mut p,20,0));let usize second=built(ir::literal(ref mut p,99,0));
    let usize init_r=built(ir::record_init(ref mut p,root,first,0));let usize lo=built(ir::integer(ref mut p,0,12,0));
    let usize hi=built(ir::integer(ref mut p,1,12,0));let usize shared=built(ir::slice(ref mut p,array,0));
    let usize open=built(ir::slice_open(ref mut p,shared,lo,hi,0));p.call_count=1;p.call_arities[0]=1;p.call_args[0]=160;
    let usize call=built(ir::raw(ref mut p,78,3,1,0,0));let usize close=built(ir::slice_close(ref mut p,shared,0));
    let usize select=built(places::select(ref mut p,0,root,0,0));let usize old=built(places::read(ref mut p,0,root,0,0));
    let usize delta=built(ir::literal(ref mut p,22,0));let usize fresh=built(ir::emit(ref mut p,2,old,delta,0));
    let usize store=built(places::store(ref mut p,0,root,0,fresh,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize drop_r=built(ir::record_drop(ref mut p,root,0));let usize returned_close=built(ir::raw(ref mut p,70,3,0,0,0));
    let usize drop_a=built(ir::array_drop(ref mut p,array,0));let usize ret=built(ir::emit(ref mut p,8,fresh,0,0));end(ref mut p,0);
    p.arities[1]=1;let usize formal=p.registers;p.registers+=1;var u8[128] parameters=[0;128];parameters[formal]=3;
    let usize param=built(ir::raw(ref mut p,77,4,formal,3,0));let usize done=built(ir::raw(ref mut p,79,0,4,0,0));end(ref mut p,1);
    var u8[16] returns=[0;16];var u8[16] origins=[0;16];returns[1]=3;origins[1]=1;
    return calls::Program{.body=p,.parameters=parameters,.results=returns,.origins=origins};
}
@test fn void retained_array_protection_does_not_alias_same_numbered_plain_record_sites(){
    let calls::Program unit=guarded();let images::Image frozen=image();assert(verifier::inspect_reference_returns(ref unit,ref frozen).is_ok);
    switch(programs::retain_reference_returns(ref unit,image(),65536)){
        case .ok(p):{completed(programs::run_public_references(ref p,3000000));}case .err(_):{assert(false);}
    };
}
@test fn void post_store_fuel_abort_preserves_payload_drains_owners_and_allows_explicit_retry(){
    let ir::Program p=compound();let results::Program unit=results::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
    var runtime::State state=runtime::empty(8);var u8[8] data=[85;8];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    assert(switch(retained::execute_scalar(ref unit,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,321773)){
        case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(data[0]==42 && data[1]==0 && data[2]==0 && data[3]==0 && data[4]==99);
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0 && state.runtime.authority.depth==0);
    assert(switch(retained::execute_scalar(ref unit,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,559753)){
        case .ok(v):{v.value==42 && v.remaining==0}case .err(_):{false}});
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
}
@test fn void malformed_record_identity_and_missing_end_fail_before_fuel_or_backing(){
    var ir::Program p=compound();p.code[7*8+5]=1;
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
    let calls::Program unit=calls::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(!programs::retain_reference_returns(ref unit,image(),65536).is_ok);
    p.code[7*8+5]=0;p.code[8*8]=45;
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
}
