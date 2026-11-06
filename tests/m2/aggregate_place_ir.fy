module tests::m2::aggregate_place_ir;
import aggregate_place_ir as places;
import place_ir as graph;
import ir as ir;
import verifier as verifier;
import errors as errors;
import array_list_ir as lists;
import place_vm as array_vm;
import slice_place_vm as slice_vm;
import record_place_vm as record_vm;
import static_image as images;
import static_call_ir as recipes;
import vm as vm;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p,usize f){let usize pc=p.count;let usize n=p.registers;p.ends[f]=pc;p.register_ends[f]=n;}
fn usize cell(ref mut ir::Program p,u8 tag){return if(tag==2){built(ir::boolean(p,true,0))}else{built(ir::integer(p,42,tag,0))};}
fn void accepted(ref ir::Program p){assert(switch(verifier::inspect_aggregate_places(p)){case .ok(n):{n==p.count}case .err(_):{false}});}
fn void rejected(ref ir::Program p){assert(!verifier::inspect_aggregate_places(p).is_ok);}
fn void at(ref ir::Program p,usize pc){assert(switch(verifier::inspect_aggregate_places(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});}
fn usize find(ref ir::Program p,u8 op){var usize pc=0;while(pc<p.count){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void jump(ref mut ir::Program p,usize pc,usize target){var usize i=0;while(i<8){p.code[pc*8+i]=0;i+=1;}p.code[pc*8]=19;let usize patched=built(ir::patch(p,pc,target,0));}

// constant0, INIT1/2, SELECT3, STORE/REPLACE4, END5, DROP6/7, constant8, RETURN9.
fn ir::Program array(u8 tag,u8 mode){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array(ref mut p,tag,2,true,0));let usize source=built(ir::array(ref mut p,tag,2,false,0));
    let usize v=cell(ref mut p,tag);let usize init=built(ir::array_init(ref mut p,root,v,0));
    let usize init_source=built(ir::array_init(ref mut p,source,v,0));let usize selected=built(places::select_array(ref mut p,0,root,0));
    if(mode==0 || mode==1){let usize stored=built(places::store_array(ref mut p,0,root,if(mode==0){source}else{root},0));}
    else if(mode==2){let usize stored=built(places::fill_array(ref mut p,0,root,v,0));}
    else{let usize[2] values=[v,v];let usize stored=built(places::replace_array(ref mut p,0,root,ref values,0));}
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize drop_source=built(ir::array_drop(ref mut p,source,0));
    let usize drop=built(ir::array_drop(ref mut p,root,0));let usize answer=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}
// constants0..3, INIT4/5, SELECT6, STORE/REPLACE7, END8, DROP9/10, constant11, RETURN12.
fn ir::Program record(u8 mode){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=2;
    p.records.layouts.kinds[0]=1;p.records.layouts.kinds[1]=1;p.records.layouts.types[0]=1;p.records.layouts.types[1]=1;
    p.records.layouts.fields[1]=2;p.records.layouts.types[16]=1;p.records.layouts.types[17]=2;
    let usize root=built(ir::record(ref mut p,0,true,0));let usize source=built(ir::record(ref mut p,0,false,0));
    let usize a=cell(ref mut p,1);let usize b=cell(ref mut p,2);let usize c=cell(ref mut p,1);let usize d=cell(ref mut p,2);
    let usize init=built(ir::record_init(ref mut p,root,a,0));let usize init_source=built(ir::record_init(ref mut p,source,a,0));
    let usize nominal=if(mode>=3 && mode<=4){0}else{1};let usize leaf=if(nominal==0){0}else{2};
    let usize selected=built(places::select_record(ref mut p,0,root,nominal,leaf,0));
    if(mode==2 || mode==3){let usize stored=built(places::replace_record(ref mut p,0,root,nominal,leaf,a,0));}
    else{let usize stored=built(places::store_record(ref mut p,0,root,if(mode==1 || mode==5){root}else{source},
        nominal,leaf,if(mode==5){leaf}else{0},0));}
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize drop_source=built(ir::record_drop(ref mut p,source,0));
    let usize drop=built(ir::record_drop(ref mut p,root,0));let usize answer=built(ir::literal(ref mut p,42,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}
@test fn void all_array_scalar_domains_prove_copy_identity_fill_and_list_without_new_registers(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){var u8 mode=0;while(mode<4){
        let ir::Program p=array(tags[i],mode);accepted(ref p);assert(p.registers==2 && p.count==10);
        assert(p.code[3*8+4]==3 && p.code[4*8]==if(mode<2){85}else{87});
        assert(built(graph::inspect(ref p))==1);mode+=1;
    }i+=1;}
}
@test fn void record_root_subtree_copy_identity_and_constructor_values_keep_nominal_identity(){
    var u8 mode=0;while(mode<6){let ir::Program p=record(mode);accepted(ref p);
        assert(p.registers==5 && p.code[6*8+4]==4 && built(graph::inspect(ref p))==1);mode+=1;}
    var ir::Program p=record(0);p.code[7*8+5]=0;at(ref p,7);
    p=record(0);p.code[7*8+2]=1;p.records.mutable[1]=true;at(ref p,7);
    p=record(2);p.code[7*8+3]=5;p.registers=7;p.register_ends[0]=7;p.types[5]=1;p.types[6]=2;at(ref p,7);
    p=record(2);p.code[7*8+3]=1;at(ref p,7);
    // Root wrapper and child have identical bytes but distinct nominal IDs.
    p=record(0);p.records.layouts.fields[0]=1;p.records.layouts.kinds[1]=0;p.records.layouts.types[1]=0;
    p.code[6*8+5]=0;p.code[7*8+5]=0;accepted(ref p);
    p.code[7*8+6]=0;at(ref p,7);
}
@test fn void common_phases_reject_reselection_double_store_dead_use_and_owner_drop_until_end(){
    var ir::Program p=array(1,0);p.code[4*8]=83;p.code[4*8+3]=0;at(ref p,4);
    p=array(1,0);p.code[5*8]=85;p.code[5*8+2]=0;p.code[5*8+3]=1;p.code[5*8+4]=3;at(ref p,5);
    p=array(1,0);var usize i=0;while(i<8){let u8 saved=p.code[5*8+i];let u8 moved=p.code[7*8+i];p.code[5*8+i]=moved;p.code[7*8+i]=saved;i+=1;}at(ref p,5);
    p=array(1,0);jump(ref mut p,3,4);at(ref p,4);
    p=array(1,0);p.code[4*8]=86;p.code[4*8+2]=0;p.code[4*8+3]=0;p.code[4*8+4]=0;at(ref p,5);
    p=array(1,0);p.code[4*8]=86;p.code[4*8+2]=0;p.code[4*8+3]=0;p.code[4*8+4]=0;jump(ref mut p,5,6);accepted(ref p);
    p=array(1,0);p.count=4;p.registers=1;p.types[1]=0;i=32;while(i<2048){p.code[i]=0;i+=1;}let usize trap=built(ir::raw(ref mut p,25,0,0,0,0));finish(ref mut p,0);accepted(ref p);
    p=record(0);p.records.mutable[0]=false;at(ref p,6);
    mixed();
}
fn void mixed(){
    var ir::Program p=record(0);p.count=6;p.registers=4;var usize i=48;while(i<2048){p.code[i]=0;i+=1;}
    let usize a=built(ir::array(ref mut p,1,2,true,0));let usize init=built(ir::array_init(ref mut p,a,0,0));
    let usize first=built(places::select_array(ref mut p,0,a,0));let usize second=built(places::select_record(ref mut p,1,0,1,0,0));
    let usize r=built(places::store_record(ref mut p,1,0,1,1,0,2,0));let usize v=built(places::store_array(ref mut p,0,a,a,0));
    let usize end1=built(ir::place_end(ref mut p,1,0));let usize end0=built(ir::place_end(ref mut p,0,0));
    let usize da=built(ir::array_drop(ref mut p,a,0));let usize d1=built(ir::record_drop(ref mut p,1,0));let usize d0=built(ir::record_drop(ref mut p,0,0));
    let usize answer=cell(ref mut p,1);let usize ret=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);accepted(ref p);
    p.code[second*8+1]=0;at(ref p,second);
}
fn ir::Program branch(bool same){
    var ir::Program p=array(1,0);p.count=3;p.registers=1;var usize i=24;while(i<2048){p.code[i]=0;i+=1;}
    let usize condition=cell(ref mut p,2);if(same){let usize selected=built(places::select_array(ref mut p,0,0,0));}
    let usize fork=built(ir::raw(ref mut p,20,0,condition,0,0));if(!same){let usize selected=built(places::select_array(ref mut p,0,0,0));}
    let usize left=built(ir::raw(ref mut p,19,0,0,0,0));let usize right=p.count;
    if(!same){let usize selected=built(places::select_array(ref mut p,0,0,0));}
    let usize join=p.count;let usize patch1=built(ir::patch(ref mut p,fork,right,0));let usize patch2=built(ir::patch(ref mut p,left,join,0));
    let usize stored=built(places::store_array(ref mut p,0,0,1,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize d1=built(ir::array_drop(ref mut p,1,0));let usize d0=built(ir::array_drop(ref mut p,0,0));
    let usize returned=built(ir::emit(ref mut p,8,0,0,0));finish(ref mut p,0);return p;
}
fn ir::Program looped(bool leak){
    var ir::Program p=array(1,0);p.count=3;p.registers=1;var usize i=24;while(i<2048){p.code[i]=0;i+=1;}
    let usize condition=cell(ref mut p,2);let usize start=p.count;let usize selected=built(places::select_array(ref mut p,0,0,0));
    let usize stored=built(places::store_array(ref mut p,0,0,1,0));if(!leak){let usize ended=built(ir::place_end(ref mut p,0,0));}
    let usize fork=built(ir::raw(ref mut p,20,0,condition,0,0));let usize back=built(ir::raw(ref mut p,22,0,start,0,0));
    let usize after=p.count;let usize patch=built(ir::patch(ref mut p,fork,after,0));if(leak){let usize ended=built(ir::place_end(ref mut p,0,0));}
    let usize d1=built(ir::array_drop(ref mut p,1,0));let usize d0=built(ir::array_drop(ref mut p,0,0));
    let usize returned=built(ir::emit(ref mut p,8,0,0,0));finish(ref mut p,0);return p;
}
@test fn void joins_and_backedges_compare_exact_selecting_pcs_and_phases(){
    let ir::Program common=branch(true);accepted(ref common);let ir::Program separate=branch(false);rejected(ref separate);
    let ir::Program loop=looped(false);accepted(ref loop);let ir::Program leaked=looped(true);rejected(ref leaked);
}
fn ir::Program loan(u8 mode){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array(ref mut p,10,2,true,0));let usize source=built(ir::array(ref mut p,10,2,true,0));
    let usize v=cell(ref mut p,10);let usize zero=built(ir::integer(ref mut p,0,12,0));let usize two=built(ir::integer(ref mut p,2,12,0));
    let usize init=built(ir::array_init(ref mut p,root,v,0));let usize init2=built(ir::array_init(ref mut p,source,v,0));
    p.slice_roots[0]=if(mode==3){2}else{1};
    if(mode==0 || mode==3){let usize open=built(ir::raw(ref mut p,54,0,zero,two,0));}
    let usize selected=built(places::select_array(ref mut p,0,root,0));
    if(mode==1 || mode==2){let usize open=built(ir::raw(ref mut p,54,0,zero,two,0));}
    if(mode==2){let usize close=built(ir::raw(ref mut p,56,0,0,0,0));}
    let usize stored=built(places::store_array(ref mut p,0,root,source,0));
    if(mode!=2){let usize close=built(ir::raw(ref mut p,56,0,0,0,0));}
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize d1=built(ir::array_drop(ref mut p,source,0));let usize d0=built(ir::array_drop(ref mut p,root,0));
    let usize answer=cell(ref mut p,1);let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);return p;
}
fn void calls(){
    var ir::Program p=array(1,0);let usize start=p.count;let usize regs=p.registers;
    p.function_count=2;p.entry=1;p.starts[1]=start;p.register_starts[1]=regs;p.return_types[1]=1;
    let usize root=built(ir::array_in(ref mut p,1,1,2,true,0));let usize v=cell(ref mut p,1);
    let usize init=built(ir::array_init(ref mut p,root,v,0));let usize selected=built(places::select_array(ref mut p,0,root,0));
    let usize[1] none=[0];let usize result=built(ir::call(ref mut p,0,ref none[..0],0));
    let usize stored=built(places::fill_array(ref mut p,0,root,result,0));let usize ended=built(ir::place_end(ref mut p,0,0));
    let usize dropped=built(ir::array_drop(ref mut p,root,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));finish(ref mut p,1);accepted(ref p);
    p.code[selected*8+2]=0;rejected(ref p);
}
@test fn void available_destination_and_source_lifetimes_hold_across_loans_and_separate_call_frames(){
    let ir::Program before=loan(0);rejected(ref before);let ir::Program during=loan(1);rejected(ref during);
    let ir::Program closed=loan(2);accepted(ref closed);let ir::Program shared_source=loan(3);accepted(ref shared_source);
    var ir::Program p=array(1,2);p.code[4*8+3]=1;at(ref p,4);
    p=array(1,0);p.code[2*8]=19;p.code[2*8+1]=0;p.code[2*8+2]=3;p.code[2*8+3]=0;at(ref p,4);
    calls();
}
@test fn void exact_encoding_scalar_roles_nominals_and_builder_failures_are_checked_independently(){
    var ir::Program p=array(1,0);var usize byte=5;while(byte<8){p=array(1,0);p.code[3*8+byte]=1;at(ref p,3);byte+=1;}
    p=array(1,0);p.code[4*8+3]=16;at(ref p,4);
    p=array(1,0);p.code[4*8]=84;rejected(ref p);
    p=array(1,2);p.code[4*8+5]=2;at(ref p,4);
    p=array(1,2);p.code[4*8+4]=0;at(ref p,4);
    p=array(1,0);p.code[4*8+2]=1;p.arrays.mutable[1]=true;at(ref p,4);
    p=record(0);p.code[7*8+7]=128;at(ref p,7);
    p=record(0);p.code[6*8+6]=1;at(ref p,6);
    p=record(2);p.code[7*8+7]=1;at(ref p,7);
    p=array(1,3);p.list_operands[0]=1;at(ref p,4);
    p=array(1,3);p.code[4*8+6]=1;rejected(ref p);
    p=array(1,3);p.list_used=4097;rejected(ref p);
    p=array(1,0);let usize count=p.count;let usize pool=p.list_used;
    assert(!places::select_array(ref mut p,16,0,77).is_ok && !places::select_array(ref mut p,0,16,77).is_ok);
    let usize[2] values=[0,0];assert(!places::replace_array(ref mut p,16,0,ref values,77).is_ok);
    assert(p.count==count && p.list_used==pool && p.registers==2);
}
fn void limits(){
    var ir::Program p=array(1,0);p.count=3;p.registers=1;var usize i=24;while(i<2048){p.code[i]=0;i+=1;}
    i=0;while(i<16){let usize selected=built(places::select_array(ref mut p,i,0,0));i+=1;}
    while(i>0){i-=1;let usize stored=built(places::store_array(ref mut p,i,0,1,0));let usize ended=built(ir::place_end(ref mut p,i,0));}
    let usize d1=built(ir::array_drop(ref mut p,1,0));let usize d0=built(ir::array_drop(ref mut p,0,0));
    let usize returned=built(ir::emit(ref mut p,8,0,0,0));finish(ref mut p,0);accepted(ref p);
    p=array(1,0);p.count=3;p.registers=1;i=24;while(i<2048){p.code[i]=0;i+=1;}
    while(p.count<254){let usize next=p.count+1;let usize step=built(ir::raw(ref mut p,19,0,next,0,0));}
    let usize selected=built(places::select_array(ref mut p,15,0,0));let usize trap=built(ir::raw(ref mut p,25,0,0,0,0));finish(ref mut p,0);
    assert(selected==254 && p.count==256);accepted(ref p);
}
fn void maximum_pool(){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize big=built(ir::array(ref mut p,12,4094,true,0));let usize small=built(ir::array(ref mut p,12,2,true,0));
    let usize v=cell(ref mut p,12);let usize[4094] values=[0;4094];let usize init=built(ir::array_values(ref mut p,big,ref values,0));
    let usize init2=built(ir::array_init(ref mut p,small,v,0));let usize selected=built(places::select_array(ref mut p,0,small,0));
    let usize[2] pair=[v,v];let usize replaced=built(places::replace_array(ref mut p,0,small,ref pair,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize d1=built(ir::array_drop(ref mut p,small,0));let usize d0=built(ir::array_drop(ref mut p,big,0));
    let usize answer=cell(ref mut p,1);let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);
    assert(p.list_used==4096 && lists::start(ref p,replaced)==4094 && p.code[replaced*8+6]==15);accepted(ref p);
    let usize count=p.count;assert(!places::replace_array(ref mut p,0,small,ref pair,0).is_ok && p.count==count && p.list_used==4096);
    p.code[replaced*8+6]=0;rejected(ref p);
}
fn void maximum_record(){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=8;p.records.layouts.fields[1]=16;var usize i=0;
    while(i<16){if(i<8){p.records.layouts.kinds[i]=1;p.records.layouts.types[i]=1;}p.records.layouts.types[16+i]=10;i+=1;}
    let usize root=built(ir::record(ref mut p,0,true,0));i=0;while(i<128){let usize v=cell(ref mut p,10);i+=1;}
    let usize init=built(ir::record_init(ref mut p,root,0,0));let usize selected=built(places::select_record(ref mut p,15,root,0,0,0));
    let usize replaced=built(places::replace_record(ref mut p,15,root,0,0,0,0));let usize ended=built(ir::place_end(ref mut p,15,0));
    let usize drop=built(ir::record_drop(ref mut p,root,0));let usize trap=built(ir::raw(ref mut p,25,0,0,0,0));finish(ref mut p,0);
    assert(p.registers==128);accepted(ref p);
}
@test fn void sixteen_ids_last_select_pc_full_dense_pool_and_full_constructor_registers_remain_bounded(){limits();maximum_pool();maximum_record();}

@test fn void complete_admission_accepts_aggregates_while_legacy_only_adapters_keep_their_gates(){
    let ir::Program p=array(1,3);accepted(ref p);assert(verifier::inspect(ref p).is_ok && verifier::verify(ref p).is_ok);
    assert(!array_vm::requirement(ref p).is_ok && !slice_vm::requirement(ref p).is_ok && !record_vm::requirement(ref p).is_ok);
    let images::Builder builder=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let images::Image image=switch(images::freeze(ref builder,65536)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(verifier::inspect_statics(ref p,ref image).is_ok && verifier::verify_statics(ref p,ref image).is_ok);
    let recipes::Program unit=recipes::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(verifier::inspect_reference_calls(ref unit,ref image).is_ok && verifier::inspect_reference_returns(ref unit,ref image).is_ok);
    assert(switch(vm::run(ref p,0)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
