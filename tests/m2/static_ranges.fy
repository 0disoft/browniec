module tests::m2::static_ranges;
import program_image as programs;
import static_image as images;
import compiler as compiler;
import slice_result_ir as ir;
import ir as ordinary_ir;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import std::bytes as bytes;
import errors as errors;
import verifier as verifier;
import vm as vm;
import static_ir as statics;
import static_execution as static_vm;
import static_builders as static_builders;

import static_views as views;
fn usize built(Result<usize,errors::Error> result){
    return switch(result){case .ok(value):{value}case .err(_):{assert(false);0}};
}
fn usize fresh(ref mut ordinary_ir::Program p,u8 tag){
    let usize register=p.registers;p.types[register]=tag;p.registers+=1;return register;
}
fn usize index_zero(ref mut ordinary_ir::Program p){return built(ordinary_ir::integer(p,0,12,0));}
fn usize index_one(ref mut ordinary_ir::Program p){return built(ordinary_ir::integer(p,1,12,0));}
fn usize open_site(ref mut ordinary_ir::Program p,usize site,usize literal,u8 kind,u8 start,u8 end){
    let usize pc=built(ordinary_ir::raw(p,69,site,literal,0,0));
    p.code[pc*8+3]=kind;p.code[pc*8+4]=start;p.code[pc*8+5]=0;
    p.code[pc*8+6]=end;p.code[pc*8+7]=0;return pc;
}
fn usize close_site(ref mut ordinary_ir::Program p,usize site){return built(ordinary_ir::raw(p,70,site,0,0,0));}
fn usize read_site(ref mut ordinary_ir::Program p,usize dst,usize site,usize index){
    return built(ordinary_ir::raw(p,71,dst,site,index,0));
}
fn usize length_site(ref mut ordinary_ir::Program p,usize dst,usize site){
    return built(ordinary_ir::raw(p,72,dst,site,0,0));
}
fn usize equal_sites(ref mut ordinary_ir::Program p,usize dst,usize a,usize b){
    return built(ordinary_ir::raw(p,73,dst,a,b,0));
}
fn void function_end(ref mut ordinary_ir::Program p,usize f){
    let usize end=p.count;let usize registers=p.registers;
    p.ends[f]=end;p.register_ends[f]=registers;
    if(f+1<p.function_count){p.starts[f+1]=end;p.register_starts[f+1]=registers;}
}
fn usize returned(ref mut ordinary_ir::Program p,usize value){
    return built(ordinary_ir::emit(p,8,value,0,0));
}
fn usize choose_i32(ref mut ordinary_ir::Program p,usize condition,i64 yes,i64 no){
    let usize slot=built(ordinary_ir::slot(p,1,0));
    let usize positive=built(ordinary_ir::integer(p,yes,1,0));
    let usize branch=built(ordinary_ir::raw(p,20,0,condition,0,0));
    let usize store_yes=built(ordinary_ir::raw(p,18,slot,positive,0,0));
    let usize jump=built(ordinary_ir::raw(p,19,0,0,0,0));
    let usize zero_path=p.count;
    let usize negative=built(ordinary_ir::integer(p,no,1,0));
    let usize store_no=built(ordinary_ir::raw(p,18,slot,negative,0,0));
    let usize joined=p.count;
    let usize load=built(ordinary_ir::emit(p,17,slot,0,0));
    let usize patched=built(ordinary_ir::patch(p,branch,zero_path,0));
    let usize linked=built(ordinary_ir::patch(p,jump,joined,0));
    return load;
}
fn usize nth_opcode(ref ordinary_ir::Program p,u8 op,usize nth){
    var usize pc=0;var usize seen=0;
    while(pc<p.count){
        if(p.code[pc*8]==op){if(seen==nth){return pc;}seen+=1;}
        pc+=1;
    }
    assert(false);return 0;
}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 &&
        state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<execution::Scalar,errors::Error> run_zero(ref programs::Program p,usize function,usize fuel){
    var runtime::State state=runtime::empty(0);var u8[1] data=[0];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let Result<execution::Scalar,errors::Error> result=programs::run_scalar(p,function,
        ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data[..0],fuel);
    drained(ref state);return result;
}

fn Result<images::Image,images::Error> image(bool text){
    var images::Builder b=images::builder(3)?;let u8[3] data=[10,42,30];
    let usize literal=if(text){images::intern_text(ref mut b,ref data)?}else{images::intern_bytes(ref mut b,ref data)?};
    return images::freeze(ref b,8192);
}
fn Result<programs::Program,programs::Error> retained(ref ir::Program unit){
    let images::Image backing=switch(image(false)){
        case .ok(v):{v}case .err(_):{assert(false);return .err(programs::Error{.kind=.Code,.code=errors::make(5,0),.literal=.State});}
    };return programs::retain(unit,backing,8192);
}
fn void completed(ref ir::Program unit,i64 expected){
    let programs::Program p=switch(retained(unit)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref p,0,16000000)){case .ok(v):{assert(v.value==expected);}case .err(_):{assert(false);}};
}
fn statics::Sites proof(ref ir::Program unit,ref images::Image backing){
    return switch(verifier::inspect_statics(ref unit.body,backing)){
        case .ok(v):{v}case .err(_):{assert(false);statics::empty()}
    };
}
fn void rejected(ref ir::Program unit,ref images::Image backing){
    switch(verifier::inspect_statics(ref unit.body,backing)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
}
fn ir::Program program(i64 lo,i64 hi,i64 index,u8 mode){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize a=built(ordinary_ir::integer(ref mut p,lo,12,0));let usize b=built(ordinary_ir::integer(ref mut p,hi,12,0));
    let usize subscript=built(ordinary_ir::integer(ref mut p,index,12,0));
    let usize root=built(static_builders::open(ref mut p,0,1,3,0));assert(root==0);
    let usize child=built(static_builders::range(ref mut p,root,a,b,0));assert(child==1);
    let usize close_root=built(static_builders::close(ref mut p,root,0));
    let usize alias=built(static_builders::alias(ref mut p,child,0));assert(alias==2);
    let usize close_child=built(static_builders::close(ref mut p,child,0));
    var usize answer=0;
    if(mode==0){let usize byte=built(static_builders::scalar(ref mut p,alias,subscript,false,0));answer=built(ordinary_ir::widen(ref mut p,byte,1,0));}
    else if(mode==1){let usize length=built(static_builders::scalar(ref mut p,alias,0,true,0));
        let usize expected=built(ordinary_ir::integer(ref mut p,hi-lo,12,0));
        let usize same=built(ordinary_ir::emit(ref mut p,11,length,expected,0));answer=choose_i32(ref mut p,same,42,0);
    }else{let usize other=built(static_builders::open(ref mut p,0,1,3,0));
        let usize equal=built(static_builders::equal(ref mut p,alias,other,0));
        let usize close_other=built(static_builders::close(ref mut p,other,0));answer=choose_i32(ref mut p,equal,0,42);}
    let usize close_alias=built(static_builders::close(ref mut p,alias,0));let usize done=returned(ref mut p,answer);
    function_end(ref mut p,0);return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
@test fn void range_read_alias_length_and_equality_use_actual_spans_after_parent_close(){
    let ir::Program read=program(1,2,0,0);completed(ref read,42);
    let ir::Program length=program(1,2,0,1);completed(ref length,42);
    let ir::Program equal=program(1,2,0,2);completed(ref equal,42);
    let images::Image backing=switch(image(false)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let statics::Sites sites=proof(ref read,ref backing);assert(sites.dynamic==6 && sites.spans[2].end==3);
}
@test fn void range_whole_invocation_has_exact_precharged_fuel_with_zero_guest_backing(){
    let ir::Program unit=program(1,2,0,0);
    let programs::Program p=switch(retained(ref unit)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize exact=runtime::cost()+runtime::leave_cost()+188;
    switch(run_zero(ref p,0,exact-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run_zero(ref p,0,exact)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run_zero(ref p,0,exact+1)){case .ok(v):{assert(v.value==42 && v.remaining==1);}case .err(_):{assert(false);}};
}
@test fn void shortage_and_bad_endpoints_preserve_destination_words_registers_and_source(){
    let ir::Program unit=program(1,2,0,0);
    let images::Image backing=switch(image(false)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let statics::Sites sites=proof(ref unit,ref backing);let usize pc=nth_opcode(ref unit.body,76,0);
    var i64[128] registers=[99;128];registers[0]=1;registers[1]=4;registers[2]=0;
    var u32[16] words=[0;16];words[0]=3;words[1]=12345;
    let ref u8[] payload=images::payload(ref backing);
    switch(static_vm::step_frame(ref unit.body,ref sites,payload,pc,0,ref mut registers,1,126,ref mut words)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    assert(words[0]==3 && words[1]==12345 && registers[3]==99);
    switch(static_vm::step_frame(ref unit.body,ref sites,payload,pc,0,ref mut registers,1,127,ref mut words)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}};
    assert(words[0]==3 && words[1]==12345 && registers[3]==99);
    registers[1]=2;
    switch(static_vm::step_frame(ref unit.body,ref sites,payload,pc,0,ref mut registers,1,127,ref mut words)){
        case .ok(v):{assert(v.live==3 && v.remaining==0);}case .err(_):{assert(false);}};
    assert(words[0]==3 && words[1]==8193 && registers[3]==99);
    switch(static_vm::step(ref unit.body,ref sites,payload,pc,0,ref mut registers,1,1000000)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
}
@test fn void empty_and_invalid_ranges_trap_relative_to_actual_parent_not_image_capacity(){
    let ir::Program empty=program(3,3,0,1);completed(ref empty,42);
    let i64[5] lo=[1,2,-1,0,1];let i64[5] hi=[2,1,0,9223372036854775807,4];
    var usize i=0;while(i<5){let ir::Program unit=program(lo[i],hi[i],if(i==0){1}else{0},0);
        let programs::Program p=switch(retained(ref unit)){case .ok(v):{v}case .err(_):{assert(false);return;}};
        switch(run_zero(ref p,0,16000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}};i+=1;}
}
@test fn void independent_range_proof_rejects_wrong_kinds_registers_reserved_bytes_and_liveness(){
    let images::Image backing=switch(image(false)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var ir::Program p=program(1,2,0,0);let usize pc=nth_opcode(ref p.body,76,0);
    p.body.code[pc*8+5]=1;rejected(ref p,ref backing);
    p=program(1,2,0,0);p.body.code[pc*8+4]=255;rejected(ref p,ref backing);
    p=program(1,2,0,0);p.body.code[pc*8+3]=3;rejected(ref p,ref backing);
    p=program(1,2,0,0);p.body.code[pc*8+1]=0;rejected(ref p,ref backing);
    p=program(1,2,0,0);let usize close=nth_opcode(ref p.body,70,0);var usize i=0;
    while(i<8){let u8 x=p.body.code[pc*8+i];let u8 y=p.body.code[close*8+i];p.body.code[pc*8+i]=y;p.body.code[close*8+i]=x;i+=1;}
    rejected(ref p,ref backing);
    let images::Image text=switch(image(true)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    p=program(1,2,0,0);let usize open=nth_opcode(ref p.body,69,0);p.body.code[open*8+3]=2;rejected(ref p,ref text);
    switch(vm::run(ref p.body,16000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
}
fn ir::Program recursive(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=2;p.entry=0;
    p.return_types[0]=1;p.return_types[1]=1;p.arities[1]=1;
    let usize one=built(ordinary_ir::integer(ref mut p,1,12,0));let usize[1] first=[one];
    let usize called=built(ordinary_ir::call(ref mut p,1,ref first,0));let usize main_done=returned(ref mut p,called);function_end(ref mut p,0);
    let usize lo=fresh(ref mut p,12);let usize step=built(ordinary_ir::integer(ref mut p,1,12,0));
    let usize zero=built(ordinary_ir::integer(ref mut p,0,12,0));let usize hi=built(ordinary_ir::emit(ref mut p,2,lo,step,0));
    let usize root=built(static_builders::open(ref mut p,0,1,3,0));let usize child=built(static_builders::range(ref mut p,root,lo,hi,0));
    let usize close_root=built(static_builders::close(ref mut p,root,0));
    let usize condition=built(ordinary_ir::emit(ref mut p,11,lo,step,0));let usize skip=built(ordinary_ir::raw(ref mut p,20,0,condition,0,0));
    let usize[1] second=[zero];let usize nested=built(ordinary_ir::call(ref mut p,1,ref second,0));
    let usize after=p.count;let usize patched=built(ordinary_ir::patch(ref mut p,skip,after,0));
    let usize byte=built(static_builders::scalar(ref mut p,child,zero,false,0));let usize value=built(ordinary_ir::widen(ref mut p,byte,1,0));
    let usize closed=built(static_builders::close(ref mut p,child,0));let usize done=returned(ref mut p,value);function_end(ref mut p,1);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
@test fn void recursive_calls_keep_different_ranges_for_the_same_sites_in_separate_frames(){
    let ir::Program unit=recursive();completed(ref unit,42);
}
@test fn void range_builders_count_all_definitions_and_reject_a_seventeenth(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize zero=built(ordinary_ir::integer(ref mut p,0,12,0));let usize end=built(ordinary_ir::integer(ref mut p,3,12,0));
    let usize index=built(ordinary_ir::integer(ref mut p,1,12,0));let usize root=built(static_builders::open(ref mut p,0,1,3,0));
    var usize site=1;while(site<16){let usize made=built(static_builders::range(ref mut p,site-1,zero,end,0));assert(made==site);
        let usize closed=built(static_builders::close(ref mut p,site-1,0));site+=1;}
    let usize count=p.count;
    switch(static_builders::range(ref mut p,15,zero,end,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==4);}};
    assert(p.count==count);let usize byte=built(static_builders::scalar(ref mut p,15,index,false,0));
    let usize value=built(ordinary_ir::widen(ref mut p,byte,1,0));let usize closed=built(static_builders::close(ref mut p,15,0));
    let usize done=returned(ref mut p,value);function_end(ref mut p,0);
    let ir::Program unit=ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};completed(ref unit,42);
}

@test fn void nested_ranges_are_relative_to_the_actual_parent_and_cannot_reexpand_it(){
    var ir::Program p=program(1,2,0,0);let usize pc=nth_opcode(ref p.body,75,0);
    p.body.code[pc*8]=76;p.body.code[pc*8+3]=2;p.body.code[pc*8+4]=0;
    completed(ref p,42);
    p.body.code[pc*8+4]=1;
    let programs::Program kept=switch(retained(ref p)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref kept,0,16000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}};
}
fn ir::Program looping(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize initial=built(ordinary_ir::integer(ref mut p,0,12,0));let usize cursor=built(ordinary_ir::slot(ref mut p,12,0));
    let usize start=built(ordinary_ir::raw(ref mut p,18,cursor,initial,0,0));
    let usize zero=built(ordinary_ir::integer(ref mut p,0,1,0));let usize total=built(ordinary_ir::slot(ref mut p,1,0));
    let usize init=built(ordinary_ir::raw(ref mut p,18,total,zero,0,0));
    let usize limit=built(ordinary_ir::integer(ref mut p,2,12,0));let usize step=built(ordinary_ir::integer(ref mut p,1,12,0));
    let usize index=built(ordinary_ir::integer(ref mut p,0,12,0));let usize root=built(static_builders::open(ref mut p,0,1,3,0));
    let usize head=p.count;let usize lo=built(ordinary_ir::emit(ref mut p,17,cursor,0,0));
    let usize condition=built(ordinary_ir::emit(ref mut p,13,lo,limit,0));let usize exit=built(ordinary_ir::raw(ref mut p,20,0,condition,0,0));
    let usize hi=built(ordinary_ir::emit(ref mut p,2,lo,step,0));let usize child=built(static_builders::range(ref mut p,root,lo,hi,0));
    let usize byte=built(static_builders::scalar(ref mut p,child,index,false,0));let usize value=built(ordinary_ir::widen(ref mut p,byte,1,0));
    let usize old=built(ordinary_ir::emit(ref mut p,17,total,0,0));let usize sum=built(ordinary_ir::emit(ref mut p,2,old,value,0));
    let usize store=built(ordinary_ir::raw(ref mut p,18,total,sum,0,0));let usize close=built(static_builders::close(ref mut p,child,0));
    let usize advance=built(ordinary_ir::raw(ref mut p,18,cursor,hi,0,0));let usize back=built(ordinary_ir::raw(ref mut p,22,0,head,0,0));
    let usize after=p.count;let usize patched=built(ordinary_ir::patch(ref mut p,exit,after,0));
    let usize close_root=built(static_builders::close(ref mut p,root,0));let usize answer=built(ordinary_ir::emit(ref mut p,17,total,0,0));
    let usize done=returned(ref mut p,answer);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
@test fn void loop_reentry_reuses_one_site_with_new_runtime_endpoints(){
    let ir::Program p=looping();completed(ref p,52);
}
