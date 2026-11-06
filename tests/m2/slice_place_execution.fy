module tests::m2::slice_place_execution;
import ir as ir;
import slice_place_ir as places;
import slice_builders as builders;
import slice_reborrow_ir as children;
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
        case .ok(p):{if(exact){shortage(programs::run_public_references(ref p,fuel-1));}
            completed(programs::run_public_references(ref p,fuel));}
        case .err(_):{assert(false);}
    };
}
fn ir::Program compound(){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array_in(ref mut p,0,1,2,true,0));
    let usize fill=built(ir::literal(ref mut p,20,0));let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,2,12,0));
    let usize site=built(ir::exclusive_slice(ref mut p,root,0));let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize select=built(places::select(ref mut p,0,site,lo,0));let usize old=built(places::read(ref mut p,0,site,0));
    let usize delta=built(ir::literal(ref mut p,22,0));let usize fresh=built(ir::emit(ref mut p,2,old,delta,0));
    let usize store=built(places::store(ref mut p,0,site,fresh,0));let usize done=built(ir::place_end(ref mut p,0,0));
    let usize observed=built(ir::slice_read(ref mut p,site,lo,0));let usize close=built(ir::slice_close(ref mut p,site,0));
    let usize drop=built(ir::array_drop(ref mut p,root,0));let usize ret=built(ir::emit(ref mut p,8,observed,0,0));
    end(ref mut p,0);return p;
}
@test fn void ordinary_and_retained_slice_compounds_have_independent_exact_fuel(){
    let ir::Program p=compound();assert(verifier::verify(ref p).is_ok);
    // Body86382 +5067 snapshot +9 native backing. Public backing adds65528.
    shortage(vm::run_with_array_limit(ref p,91457,8));completed(vm::run_with_array_limit(ref p,91458,8));
    completed(vm::run_with_array_limit(ref p,91459,8));shortage(vm::run(ref p,156985));
    completed(vm::run(ref p,156986));public_retained(ref p,501059,true);
}
fn ir::Program scalar(u8 tag){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array_in(ref mut p,0,tag,2,true,0));
    let usize fill=if(tag==2){built(ir::boolean(ref mut p,false,0))}else{built(ir::integer(ref mut p,0,tag,0))};
    let usize init=built(ir::array_init(ref mut p,root,fill,0));let usize lo=built(ir::integer(ref mut p,0,12,0));
    let usize hi=built(ir::integer(ref mut p,2,12,0));let usize index=built(ir::integer(ref mut p,1,12,0));
    let usize site=built(ir::exclusive_slice(ref mut p,root,0));let usize open=built(ir::slice_open(ref mut p,site,lo,hi,0));
    let usize selected=built(places::select(ref mut p,0,site,index,0));let usize old=built(places::read(ref mut p,0,site,0));
    let usize fresh=if(tag==2){built(ir::boolean(ref mut p,true,0))}else{built(ir::integer(ref mut p,42,tag,0))};
    let usize store=built(places::store(ref mut p,0,site,fresh,0));let usize done=built(ir::place_end(ref mut p,0,0));
    let usize observed=built(ir::slice_read(ref mut p,site,index,0));let usize close=built(ir::slice_close(ref mut p,site,0));
    let usize drop=built(ir::array_drop(ref mut p,root,0));let usize equal=built(ir::emit(ref mut p,11,observed,fresh,0));
    let usize branch=built(ir::raw(ref mut p,20,0,equal,0,0));let usize yes=built(ir::literal(ref mut p,42,0));
    let usize ret=built(ir::emit(ref mut p,8,yes,0,0));let usize target=p.count;let usize patch=built(ir::patch(ref mut p,branch,target,0));
    let usize no=built(ir::literal(ref mut p,0,0));let usize bad=built(ir::emit(ref mut p,8,no,0,0));end(ref mut p,0);return p;
}
@test fn void both_drivers_execute_all_six_scalar_widths_through_authoritative_bindings(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){let ir::Program p=scalar(tags[i]);
        completed(vm::run_with_array_limit(ref p,300000,16));public_retained(ref p,1000000,false);i+=1;}
}
fn ir::Program called(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize parent=built(builders::parameter_exclusive(ref mut p,0,1,0));let usize child=built(children::derived(ref mut p,parent,0));
    let usize zero=built(ir::integer(ref mut p,0,12,0));let usize one=built(ir::integer(ref mut p,1,12,0));
    let usize select=built(places::select(ref mut p,0,parent,one,0));let usize old=built(places::read(ref mut p,0,parent,0));
    let usize begin=built(children::begin(ref mut p,child,parent,zero,one,0));
    let usize seven=built(ir::literal(ref mut p,7,0));let usize changed=built(ir::slice_write(ref mut p,child,zero,seven,0));
    let usize restore=built(children::end(ref mut p,child,parent,0));let usize delta=built(ir::literal(ref mut p,22,0));
    let usize fresh=built(ir::emit(ref mut p,2,old,delta,0));let usize store=built(places::store(ref mut p,0,parent,fresh,0));
    let usize done=built(ir::place_end(ref mut p,0,0));let usize close=built(ir::slice_close(ref mut p,parent,0));
    let usize ret=built(ir::emit(ref mut p,8,fresh,0,0));end(ref mut p,0);
    let usize root=built(ir::array_in(ref mut p,1,1,2,true,0));let usize fill=built(ir::literal(ref mut p,20,0));
    let usize init=built(ir::array_init(ref mut p,root,fill,0));let usize lo=built(ir::integer(ref mut p,0,12,0));
    let usize hi=built(ir::integer(ref mut p,2,12,0));let usize index=built(ir::integer(ref mut p,1,12,0));
    let usize source=built(ir::exclusive_slice(ref mut p,root,0));let usize opened=built(ir::slice_open(ref mut p,source,lo,hi,0));
    let usize before=built(places::select(ref mut p,0,source,index,0));let usize prior=built(places::read(ref mut p,0,source,0));
    let usize[1] args=[160+source];let usize result=built(ir::call(ref mut p,0,ref args,0));
    let usize increment=built(ir::literal(ref mut p,22,0));let usize after=built(ir::emit(ref mut p,2,prior,increment,0));
    let usize written=built(places::store(ref mut p,0,source,after,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize observed=built(ir::slice_read(ref mut p,source,index,0));let usize side=built(ir::slice_read(ref mut p,source,lo,0));
    let usize closed=built(ir::slice_close(ref mut p,source,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize expected=built(ir::literal(ref mut p,7,0));let usize equal=built(ir::emit(ref mut p,11,side,expected,0));
    let usize branch=built(ir::raw(ref mut p,20,0,equal,0,0));let usize returned=built(ir::emit(ref mut p,8,observed,0,0));
    let usize fail=p.count;let usize patched=built(ir::patch(ref mut p,branch,fail,0));let usize no=built(ir::literal(ref mut p,0,0));
    let usize bad=built(ir::emit(ref mut p,8,no,0,0));end(ref mut p,1);return p;
}
@test fn void caller_and_formal_places_share_ids_and_restore_call_and_lexical_tickets(){
    let ir::Program p=called();assert(verifier::verify(ref p).is_ok);
    completed(vm::run_with_array_limit(ref p,3000000,8));public_retained(ref p,4000000,false);
}
@test fn void fuel_abort_after_store_keeps_payload_and_drains_before_explicit_retry(){
    let ir::Program p=compound();let results::Program unit=results::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
    var runtime::State state=runtime::empty(8);var u8[8] data=[85;8];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    assert(switch(retained::execute_scalar(ref unit,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,230607)){
        case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(data[0]==42 && data[1]==0 && data[2]==0 && data[3]==0);
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0 && state.runtime.authority.depth==0);
    assert(switch(retained::execute_scalar(ref unit,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,435522)){
        case .ok(v):{v.value==42 && v.remaining==0}case .err(_):{false}});
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
}
fn usize find(ref ir::Program p,u8 op){var usize pc=0;while(pc<p.count){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
@test fn void malformed_places_reject_before_backing_fuel_or_retained_admission(){
    var ir::Program p=compound();let usize selected=find(ref p,83);p.code[selected*8+4]=2;
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
    let calls::Program unit=calls::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(!programs::retain_reference_returns(ref unit,image(),65536).is_ok);
    p.code[selected*8+4]=1;let usize ended=find(ref p,86);p.code[ended*8]=56;p.code[ended*8+1]=0;
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
}

fn calls::Program guarded(bool blocked){
    var ir::Program p=ir::empty();p.function_count=2;p.return_types[0]=1;
    let usize first=built(ir::array_in(ref mut p,0,10,1,true,0));let usize second=built(ir::array_in(ref mut p,0,10,2,true,0));
    let usize byte=built(ir::integer(ref mut p,42,10,0));let usize fill=built(ir::integer(ref mut p,20,10,0));
    let usize init0=built(ir::array_init(ref mut p,first,byte,0));let usize init1=built(ir::array_init(ref mut p,second,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize exclusive=built(ir::exclusive_slice(ref mut p,if(blocked){first}else{second},0));
    let usize shared=built(ir::slice(ref mut p,first,0));assert(exclusive==0 && shared==1);
    let usize opened=built(ir::slice_open(ref mut p,shared,lo,hi,0));
    p.call_count=1;p.call_arities[0]=1;p.call_args[0]=161;
    let usize call=built(ir::raw(ref mut p,78,3,1,0,0));let usize released=built(ir::slice_close(ref mut p,shared,0));
    let usize opened_write=built(ir::slice_open(ref mut p,exclusive,lo,hi,0));
    let usize selected=built(places::select(ref mut p,0,exclusive,lo,0));let usize old=built(places::read(ref mut p,0,exclusive,0));
    let usize delta=built(ir::integer(ref mut p,22,10,0));let usize fresh=built(ir::emit(ref mut p,2,old,delta,0));
    let usize stored=built(places::store(ref mut p,0,exclusive,fresh,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize observed=built(ir::slice_read(ref mut p,exclusive,lo,0));let usize closed=built(ir::slice_close(ref mut p,exclusive,0));
    let usize returned_closed=built(ir::raw(ref mut p,70,3,0,0,0));
    let usize drop1=built(ir::array_drop(ref mut p,second,0));let usize drop0=built(ir::array_drop(ref mut p,first,0));
    let usize wide=built(ir::widen(ref mut p,observed,1,0));let usize ret=built(ir::emit(ref mut p,8,wide,0,0));end(ref mut p,0);
    p.arities[1]=1;let usize formal=p.registers;p.registers+=1;var u8[128] parameters=[0;128];parameters[formal]=3;
    let usize param=built(ir::raw(ref mut p,77,4,formal,3,0));let usize done=built(ir::raw(ref mut p,79,0,4,0,0));end(ref mut p,1);
    var u8[16] returns=[0;16];var u8[16] origins=[0;16];returns[1]=3;origins[1]=1;
    return calls::Program{.body=p,.parameters=parameters,.results=returns,.origins=origins};
}
@test fn void retained_owner_guard_maps_slice_site_to_its_actual_root(){
    let calls::Program unit=guarded(false);
    switch(programs::retain_reference_returns(ref unit,image(),65536)){
        case .ok(p):{completed(programs::run_public_references(ref p,2000000));}
        case .err(_):{assert(false);}
    };
    let calls::Program blocked=guarded(true);
    assert(!programs::retain_reference_returns(ref blocked,image(),65536).is_ok);
}
