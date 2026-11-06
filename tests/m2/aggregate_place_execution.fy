module tests::m2::aggregate_place_execution;
import aggregate_place_ir as places;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import static_call_ir as calls;
import static_image as images;
import program_image as programs;
import slice_result_ir as borrowed;
import slice_result_execution as retained;
import slice_result_runtime as runtime;
import array_owners as owners;
import array_slices as slices;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void completed(Result<i64,errors::Error> r){assert(switch(r){case .ok(v):{v==42}case .err(_):{false}});}
fn void shortage(Result<i64,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn void end(ref mut ir::Program p,usize f){let usize pc=p.count;let usize r=p.registers;p.ends[f]=pc;p.register_ends[f]=r;
    if(f+1<p.function_count){p.starts[f+1]=pc;p.register_starts[f+1]=r;}}
fn images::Image image(){let images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,65536)){case .ok(v):{v}case .err(_):{assert(false);image()}};}
fn void public_retained(ref ir::Program p,usize fuel,bool exact){
    let calls::Program unit=calls::Program{.body=*p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    switch(programs::retain_reference_returns(ref unit,image(),65536)){
        case .ok(code):{
            if(exact){shortage(programs::run_public_references(ref code,fuel-1));}
            completed(programs::run_public_references(ref code,fuel));
            if(exact){completed(programs::run_public_references(ref code,fuel+1));}
        }case .err(_):{assert(false);}
    };
}
fn usize scalar(ref mut ir::Program p,u8 tag,i64 value){return if(tag==2){built(ir::boolean(p,value!=0,0))}else{built(ir::integer(p,value,tag,0))};}
fn ir::Program array(u8 tag,u8 mode,usize length){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array(ref mut p,tag,length,true,0));let usize source=built(ir::array(ref mut p,tag,length,false,0));
    let usize zero=scalar(ref mut p,tag,0);let usize value=scalar(ref mut p,tag,if(tag==2){1}else{42});
    // The maximum case uses a separately encoded 4095 index without a cast.
    let usize index=built(ir::integer(ref mut p,if(length==2){1}else{4095},12,0));
    let usize init=built(ir::array_init(ref mut p,root,zero,0));let usize init_source=built(ir::array_init(ref mut p,source,value,0));
    let usize selected=built(places::select_array(ref mut p,0,root,77));
    if(mode<2){let usize stored=built(places::store_array(ref mut p,0,root,if(mode==0){source}else{root},77));}
    else if(mode==2){let usize stored=built(places::fill_array(ref mut p,0,root,value,77));}
    else{let usize[4096] values=[1;4096];let usize stored=built(places::replace_array(ref mut p,0,root,ref values[..length],77));}
    let usize ended=built(ir::place_end(ref mut p,0,77));let usize observed=built(ir::array_read(ref mut p,root,index,0));
    let usize equal=built(ir::emit(ref mut p,11,observed,if(mode==1){zero}else{value},0));
    let usize ds=built(ir::array_drop(ref mut p,source,0));let usize dr=built(ir::array_drop(ref mut p,root,0));
    let usize branch=built(ir::raw(ref mut p,20,0,equal,0,0));let usize answer=built(ir::literal(ref mut p,42,0));
    let usize ret=built(ir::emit(ref mut p,8,answer,0,0));let usize target=p.count;let usize patched=built(ir::patch(ref mut p,branch,target,0));
    let usize no=built(ir::literal(ref mut p,0,0));let usize wrong=built(ir::emit(ref mut p,8,no,0,0));end(ref mut p,0);return p;
}
@test fn void every_array_domain_copy_self_fill_and_list_executes_at_independent_exact_fuel(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[6] widths=[4,1,8,1,4,8];var usize t=0;
    while(t<6){var u8 mode=0;while(mode<4){let ir::Program p=array(tags[t],mode,2);assert(verifier::verify(ref p).is_ok);
        let usize width=widths[t];let usize store=if(mode<2){178+2*width+if(tags[t]==2){2}else{0}}
            else if(mode==2){146+4*width}else{148+6*width};
        let usize exact=6741+13*width+store+if(mode==3){261+2*width}else{0};
        shortage(vm::run_with_array_limit(ref p,exact-1,4*width));completed(vm::run_with_array_limit(ref p,exact,4*width));
        completed(vm::run_with_array_limit(ref p,exact+1,4*width));
        public_retained(ref p,exact+409608-4*width,true);mode+=1;
    }t+=1;}
}
fn ir::Program record(u8 mode){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=2;p.records.layouts.kinds[0]=1;p.records.layouts.kinds[1]=1;
    p.records.layouts.types[0]=1;p.records.layouts.types[1]=1;p.records.layouts.fields[1]=2;
    p.records.layouts.types[16]=1;p.records.layouts.types[17]=1;
    let usize root=built(ir::record(ref mut p,0,true,0));let usize source=built(ir::record(ref mut p,0,false,0));
    let usize a=built(ir::literal(ref mut p,1,0));let usize b=built(ir::literal(ref mut p,2,0));
    let usize c=built(ir::literal(ref mut p,3,0));let usize d=built(ir::literal(ref mut p,4,0));
    let usize x=built(ir::literal(ref mut p,20,0));let usize y=built(ir::literal(ref mut p,22,0));
    let usize z=built(ir::literal(ref mut p,24,0));let usize w=built(ir::literal(ref mut p,26,0));
    let usize init=built(ir::record_init(ref mut p,root,a,0));let usize init_source=built(ir::record_init(ref mut p,source,x,0));
    let usize nominal=if(mode<2){1}else{0};let usize ordinal=if(mode<2){2}else{0};
    let usize selected=built(places::select_record(ref mut p,0,root,nominal,ordinal,77));
    if(mode==0 || mode==2){let usize stored=built(places::store_record(ref mut p,0,root,source,nominal,ordinal,0,77));}
    else{let usize stored=built(places::replace_record(ref mut p,0,root,nominal,ordinal,x,77));}
    let usize ended=built(ir::place_end(ref mut p,0,77));let usize left=built(ir::record_read(ref mut p,root,ordinal,0));
    let usize right=built(ir::record_read(ref mut p,root,ordinal+1,0));let usize answer=built(ir::emit(ref mut p,2,left,right,0));
    let usize ds=built(ir::record_drop(ref mut p,source,0));let usize dr=built(ir::record_drop(ref mut p,root,0));
    let usize ret=built(ir::emit(ref mut p,8,answer,0,0));end(ref mut p,0);return p;
}
@test fn void record_root_and_subtree_copy_and_constructors_read_actual_result_at_exact_fuel(){
    var u8 mode=0;while(mode<4){let ir::Program p=record(mode);assert(verifier::verify(ref p).is_ok);
        let usize exact=222475+if(mode==0 || mode==2){172129}else{128162};
        shortage(vm::run_with_array_limit(ref p,exact-1,32));completed(vm::run_with_array_limit(ref p,exact,32));
        completed(vm::run_with_array_limit(ref p,exact+1,32));public_retained(ref p,exact+409577,true);mode+=1;
    }
}
fn ir::Program called(bool owned,bool record){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=if(owned && record){0}else{1};p.return_types[1]=1;
    p.records.layouts.count=if(record){1}else{0};if(record){p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;}
    let usize root=if(record){built(ir::record_in(ref mut p,0,0,true,0))}else{built(ir::array_in(ref mut p,0,1,2,true,0))};
    let usize value=built(ir::literal(ref mut p,42,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    if(record){let usize init=built(ir::record_init(ref mut p,root,value,0));let usize s=built(places::select_record(ref mut p,0,root,0,0,77));
        let usize w=built(places::replace_record(ref mut p,0,root,0,0,value,77));}
    else{let usize init=built(ir::array_init(ref mut p,root,value,0));let usize s=built(places::select_array(ref mut p,0,root,77));
        let usize w=built(places::fill_array(ref mut p,0,root,value,77));}
    let usize e=built(ir::place_end(ref mut p,0,77));
    if(owned){if(record){p.record_results[0]=1;let usize ret=built(ir::record_return(ref mut p,root,0));}
        else{p.array_results[0]=1;let usize ret=built(ir::array_return(ref mut p,root,0));}}
    else{let usize observed=built(ir::array_read(ref mut p,root,index,0));let usize drop=built(ir::array_drop(ref mut p,root,0));
        let usize ret=built(ir::emit(ref mut p,8,observed,0,0));}
    end(ref mut p,0);
    let usize parent=if(record){built(ir::record_in(ref mut p,1,0,true,0))}else{built(ir::array_in(ref mut p,1,1,2,true,0))};
    let usize target=if(!owned){16}else if(record){built(ir::record_in(ref mut p,1,0,false,0))}else{built(ir::array_in(ref mut p,1,1,2,false,0))};
    let usize zero=built(ir::literal(ref mut p,0,0));let usize at=built(ir::integer(ref mut p,0,12,0));
    if(record){let usize init=built(ir::record_init(ref mut p,parent,zero,0));let usize s=built(places::select_record(ref mut p,0,parent,0,0,77));}
    else{let usize init=built(ir::array_init(ref mut p,parent,zero,0));let usize s=built(places::select_array(ref mut p,0,parent,77));}
    let usize[1] none=[0];
    if(owned){
        if(record){let usize call=built(ir::record_call(ref mut p,0,target,ref none[..0],0));
            let usize w=built(places::store_record(ref mut p,0,parent,target,0,0,0,77));}
        else{let usize call=built(ir::array_call(ref mut p,0,target,ref none[..0],0));let usize w=built(places::store_array(ref mut p,0,parent,target,77));}
    }else{let usize first=built(ir::call(ref mut p,0,ref none[..0],0));let usize second=built(ir::call(ref mut p,0,ref none[..0],0));
        let usize w=built(places::fill_array(ref mut p,0,parent,second,77));}
    let usize ended=built(ir::place_end(ref mut p,0,77));
    let usize observed=if(record){built(ir::record_read(ref mut p,parent,0,0))}else{built(ir::array_read(ref mut p,parent,at,0))};
    if(record){let usize dt=built(ir::record_drop(ref mut p,target,0));let usize dr=built(ir::record_drop(ref mut p,parent,0));}
    else{if(owned){let usize dt=built(ir::array_drop(ref mut p,target,0));}let usize dr=built(ir::array_drop(ref mut p,parent,0));}
    let usize ret=built(ir::emit(ref mut p,8,observed,0,0));end(ref mut p,1);return p;
}
@test fn void calls_reuse_child_ids_and_publish_owned_array_and_record_results_before_parent_store(){
    var usize mode=0;while(mode<3){let ir::Program p=called(mode!=0,mode==2);assert(verifier::verify(ref p).is_ok);
        completed(vm::run_with_array_limit(ref p,3000000,32));public_retained(ref p,4000000,false);mode+=1;}
}
fn Result<retained::Scalar,errors::Error> native(ref ir::Program p,ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let borrowed::Program unit=borrowed::Program{.body=*p,.elements=[0;16],.parameters=[0;16]};
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];let i64[1] values=[0];
    let owners::Token[1] inputs=[owners::Token{.slot=16,.generation=0}];
    return retained::execute_scalar(ref unit,p.entry,ref captures[..0],ref values[..0],ref inputs[..0],state,data,fuel);
}
@test fn void exact_setup_preflight_and_post_store_zero_fuel_abort_preserve_effects_and_allow_explicit_retry(){
    let ir::Program p=array(1,0,2);var runtime::State state=runtime::empty(16);var u8[16] data=[85;16];
    assert(switch(native(ref p,ref mut state,ref mut data,153822)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==0}});
    assert(data[0]==85 && data[15]==85 && state.runtime.owners.depth==0);
    // Entry147456 + setup6367 + constants3 + INIT144 + SELECT97 + STORE186
    // plus four retained aggregate dispatch units: next END starts at zero Fuel.
    assert(switch(native(ref p,ref mut state,ref mut data,154257)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});
    assert(data[0]==42 && data[4]==42 && data[8]==42 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    assert(switch(native(ref p,ref mut state,ref mut data,351034)){case .ok(v):{v.value==42 && v.remaining==0}case .err(_):{false}});
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
}
@test fn void full_dense_pool_and_32768_byte_array_run_in_both_public_drivers_at_exact_fuel(){
    let ir::Program p=array(9,3,4096);assert(p.list_used==4096 && verifier::verify(ref p).is_ok);
    shortage(vm::run(ref p,281615));completed(vm::run(ref p,281616));completed(vm::run(ref p,281617));
    public_retained(ref p,625688,true);
}
