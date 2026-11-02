module tests::m2::slice_derived_call_execution;
import vm_execution as execution;
import slice_reborrow_context as context;
import call_frame_vm as control;
import slice_reborrow_call_vm as handoff_vm;
import slice_reborrow_call_admission as admission;
import slice_formal_reborrow_vm as adapter;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_authority as authority;
import slice_reborrow as reborrow;
import slice_handoff as handoff;
import slice_reborrow_ir as forest;
import slice_builders as builders;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_vm as arrays;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_exclusive_vm as ordinary;
import struct_vm as records;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import vm_reborrow_execution as runner;
import std::bytes as bytes;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;p.ends[f]=n;p.register_ends[f]=r;}
fn usize at(ref ir::Program p,u8 op,usize f){var usize pc=p.starts[f];while(pc<p.ends[f]){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn forest::Sites sites(ref ir::Program p){return switch(forest::metadata(p)){case .ok(v):{v}case .err(_):{assert(false);forest::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn void fail(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn void same_view(owners::View a,owners::View b){assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);same_view(x.view,y.view);i+=1;}}
fn void same_owners(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;}
}


fn slices::Arguments arguments(Result<slices::Arguments,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::empty_arguments()}};}
fn void same_state(ref authority::State a,ref authority::State b){
    assert(a.depth==b.depth && a.frame==b.frame);var usize i=0;while(i<31){assert(a.kinds[i]==b.kinds[i] && a.frames[i]==b.frames[i] && a.counts[i]==b.counts[i] && a.reserves[i]==b.reserves[i]);let reborrow::Loan x=a.children[i];let reborrow::Loan y=b.children[i];same_view(x.parent.view,y.parent.view);same_view(x.selected,y.selected);assert(x.parent.generation==y.parent.generation && x.issued.slot==y.issued.slot && x.issued.generation==y.issued.generation && x.depth==y.depth && x.active==y.active);i+=1;}
    i=0;while(i<248){assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation && a.leases[i].generation==b.leases[i].generation);same_view(a.leases[i].view,b.leases[i].view);i+=1;}
}
fn ir::Program program(u8 tag,bool formal,usize levels,usize argc,bool mixed,bool recursive){
    var ir::Program p=ir::empty();p.function_count=3;p.entry=2;p.arities[0]=if(recursive){2}else{argc};p.return_types[0]=1;p.return_types[1]=1;p.return_types[2]=1;
    var usize[2] callee=[16;2];var usize row=0;
    while(row<argc){callee[row]=built(if(mixed && row==1){builders::parameter_typed(ref mut p,0,tag,77)}else{builders::parameter_exclusive(ref mut p,0,tag,77)});row+=1;}
    let usize counter=p.registers;
    if(recursive){p.types[counter]=1;p.registers+=1;}
    let usize index=built(ir::integer(ref mut p,0,12,77));let usize high=built(ir::integer(ref mut p,1,12,77));
    let usize cell=built(if(tag==2){ir::boolean(ref mut p,true,77)}else{ir::integer(ref mut p,expected(tag),tag,77)});
    var usize branch=256;
    if(recursive){let usize zero=built(ir::literal(ref mut p,0,77));let usize condition=built(ir::emit(ref mut p,11,counter,zero,77));branch=built(ir::raw(ref mut p,20,0,condition,0,77));}
    var usize[2] comparisons=[256;2];
    row=0;while(row<argc){if(ir::exclusive(ref p,callee[row])){let usize write=built(ir::slice_write(ref mut p,callee[row],index,cell,77));}let usize read=built(ir::slice_read(ref mut p,callee[row],index,77));if(ir::exclusive(ref p,callee[row])){let usize equal=built(ir::emit(ref mut p,11,read,cell,77));comparisons[row]=built(ir::raw(ref mut p,20,0,equal,0,77));}row+=1;}
    let usize numerator=built(ir::literal(ref mut p,1,77));let usize denominator=built(ir::literal(ref mut p,1,77));let usize quotient=built(ir::emit(ref mut p,5,numerator,denominator,77));
    row=0;while(row<argc){let usize close=built(ir::slice_close(ref mut p,callee[row],77));row+=1;}
    let usize answer=built(ir::literal(ref mut p,42,77));let usize done=built(ir::emit(ref mut p,8,answer,0,77));
    if(recursive){let usize target=p.count;let usize patched=built(ir::patch(ref mut p,branch,target,77));let usize one=built(ir::literal(ref mut p,1,77));let usize next=built(ir::emit(ref mut p,3,counter,one,77));let usize child=built(forest::derived(ref mut p,callee[0],77));let usize begin=built(forest::begin(ref mut p,child,callee[0],index,high,77));let usize[2] recursive_args=[160+child,next];let usize nested=built(ir::call(ref mut p,0,ref recursive_args,77));let usize end=built(forest::end(ref mut p,child,callee[0],77));let usize close=built(ir::slice_close(ref mut p,callee[0],77));let usize returned=built(ir::emit(ref mut p,8,nested,0,77));}
    let usize mismatch=p.count;row=0;while(row<argc){if(comparisons[row]!=256){let usize patched=built(ir::patch(ref mut p,comparisons[row],mismatch,77));}let usize close=built(ir::slice_close(ref mut p,callee[row],77));row+=1;}
    let usize failed=built(ir::literal(ref mut p,0,77));let usize failure=built(ir::emit(ref mut p,8,failed,0,77));
    finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize width=if(argc==2){2}else{1};p.arities[1]=if(formal){width}else{0};
    var usize[2] roots=[16;2];var usize[32] sites=[16;32];row=0;
    while(row<width){
        if(formal){sites[row*16]=built(if(mixed && row==1){builders::parameter_typed(ref mut p,1,tag,77)}else{builders::parameter_exclusive(ref mut p,1,tag,77)});}
        else{roots[row]=built(ir::array_in(ref mut p,1,tag,2,!(mixed && row==1),77));sites[row*16]=built(if(mixed && row==1){ir::slice(ref mut p,roots[row],77)}else{ir::exclusive_slice(ref mut p,roots[row],77)});}
        row+=1;
    }
    // Complete all formal positions before builders inspect a derived origin.
    row=0;while(row<width){var usize level=1;while(level<=if(mixed && row==1){0}else{levels}){sites[row*16+level]=built(forest::derived(ref mut p,sites[row*16+level-1],77));level+=1;}row+=1;}
    let usize lo=built(ir::integer(ref mut p,0,12,77));let usize hi=built(ir::integer(ref mut p,1,12,77));
    if(!formal){let usize fill=built(if(tag==2){ir::boolean(ref mut p,false,77)}else{ir::integer(ref mut p,0,tag,77)});row=0;while(row<width){let usize init=built(ir::array_init(ref mut p,roots[row],fill,77));let usize open=built(ir::slice_open(ref mut p,sites[row*16],lo,hi,77));row+=1;}}
    let usize condition=built(ir::boolean(ref mut p,true,77));let usize target=p.count;row=0;
    while(row<width){var usize level=1;while(level<=if(mixed && row==1){0}else{levels}){let usize begin=built(forest::begin(ref mut p,sites[row*16+level],sites[row*16+level-1],lo,hi,77));level+=1;}row+=1;}
    let usize n=built(ir::literal(ref mut p,13,77));
    let usize[2] args=[160+sites[levels],if(recursive){n}else{160+sites[if(mixed){16}else{16+levels}]}];
    var usize result=built(ir::call(ref mut p,0,ref args[..if(recursive){2}else{argc}],77));
    if(argc==2){result=built(ir::call(ref mut p,0,ref args[..2],77));}
    row=width;while(row>0){row-=1;var usize level=if(mixed && row==1){0}else{levels};while(level>0){let usize end=built(forest::end(ref mut p,sites[row*16+level],sites[row*16+level-1],77));level-=1;}}
    row=width;while(row>0){row-=1;let usize length=built(ir::slice_length(ref mut p,sites[row*16],77));let usize close=built(ir::slice_close(ref mut p,sites[row*16],77));if(!formal){let usize drop=built(ir::array_drop(ref mut p,roots[row],77));}}
    let usize returned=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);
    let usize entry=p.count;let usize end_regs=p.registers;p.starts[2]=entry;p.register_starts[2]=end_regs;
    var usize entry_result=0;
    if(formal){
        var usize[2] actual=[0;2];row=0;let usize zero=built(ir::integer(ref mut p,0,12,77));let usize high=built(ir::integer(ref mut p,1,12,77));let usize fill=built(if(tag==2){ir::boolean(ref mut p,false,77)}else{ir::integer(ref mut p,0,tag,77)});
        while(row<width){let usize root=built(ir::array_in(ref mut p,2,tag,2,!(mixed && row==1),77));let usize site=built(if(mixed && row==1){ir::slice(ref mut p,root,77)}else{ir::exclusive_slice(ref mut p,root,77)});let usize init=built(ir::array_init(ref mut p,root,fill,77));let usize opened=built(ir::slice_open(ref mut p,site,zero,high,77));actual[row]=160+site;row+=1;}
        entry_result=built(ir::call(ref mut p,1,ref actual[..width],77));row=width;while(row>0){row-=1;let usize closed=built(ir::slice_close(ref mut p,actual[row]-160,77));let usize dropped=built(ir::array_drop(ref mut p,row,77));}
    }
    if(!formal){let usize[1] no_args=[0];entry_result=built(ir::call(ref mut p,1,ref no_args[..0],77));}
    let usize entry_return=built(ir::emit(ref mut p,8,entry_result,0,77));finish(ref mut p,2);assert(verifier::inspect_reborrow_calls(ref p).is_ok);return p;
}

fn i64 expected(u8 tag){return if(tag==2){1}else if(tag==9){-9223372036854775807-1}else if(tag==10){255}else if(tag==11){4294967295}else if(tag==12){-1}else{42};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 checked(Result<i64,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void error(Result<i64,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind}});}
fn usize opcode(ref ir::Program p,u8 op,usize f){return at(p,op,f);}
fn void clean(ref authority::State[] auth,ref calls::Bindings[] c,ref children::Bindings[] links,ref loans::State loan,ref shared::Frames frames){assert(context::ready(ref auth[0],ref c[0],ref links[0],loan,frames).is_ok);}
fn void equivalent(Result<i64,errors::Error> a,Result<i64,errors::Error> b){
    switch(a){case .ok(x):{assert(switch(b){case .ok(y):{x==y}case .err(_):{false}});}case .err(x):{assert(switch(b){case .ok(_):{false}case .err(y):{x.kind==y.kind && x.offset==y.offset}});}};
}
fn Result<i64,errors::Error> native(ref ir::Program p,usize fuel){
    var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    let Result<i64,errors::Error> result=runner::execute(p,fuel,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links);clean(ref auth,ref c,ref links,ref l,ref f);if(result.is_ok){assert(a.owners.depth==0 && a.owners.arena.used==0);}return result;
}
fn Result<i64,errors::Error> run(ref ir::Program p,usize fuel){
    let Result<i64,errors::Error> result=native(p,fuel);
    let Result<i64,errors::Error> public=vm::run_with_array_limit(p,fuel+257,256);equivalent(result,public);return public;
}

fn ir::Program mixed_owned(bool derived){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=2;p.return_types[0]=1;p.return_types[1]=1;
    let usize formal=built(builders::parameter_exclusive(ref mut p,0,10,77));let usize copied=built(ir::array_parameter(ref mut p,0,10,1,77));let usize dropped=built(ir::array_drop(ref mut p,copied,77));let usize close=built(ir::slice_close(ref mut p,formal,77));let usize answer=built(ir::literal(ref mut p,42,77));let usize returned=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize root=built(ir::array_in(ref mut p,1,10,1,true,77));let usize copy=built(ir::array_in(ref mut p,1,10,1,false,77));let usize other=built(ir::array_in(ref mut p,1,10,1,true,77));let usize parent=built(ir::exclusive_slice(ref mut p,root,77));let usize child=built(forest::derived(ref mut p,parent,77));let usize available=built(ir::exclusive_slice(ref mut p,other,77));let usize zero=built(ir::integer(ref mut p,0,12,77));let usize one=built(ir::integer(ref mut p,1,12,77));let usize fill=built(ir::integer(ref mut p,0,10,77));let usize init1=built(ir::array_init(ref mut p,root,fill,77));let usize init2=built(ir::array_init(ref mut p,copy,fill,77));let usize init3=built(ir::array_init(ref mut p,other,fill,77));let usize open1=built(ir::slice_open(ref mut p,parent,zero,one,77));let usize open2=built(ir::slice_open(ref mut p,available,zero,one,77));let usize begin=built(forest::begin(ref mut p,child,parent,zero,one,77));let usize[2] args=[160+if(derived){child}else{available},128+copy];let usize result=built(ir::call(ref mut p,0,ref args,77));let usize end=built(forest::end(ref mut p,child,parent,77));let usize close1=built(ir::slice_close(ref mut p,available,77));let usize close2=built(ir::slice_close(ref mut p,parent,77));let usize drop3=built(ir::array_drop(ref mut p,other,77));let usize drop2=built(ir::array_drop(ref mut p,copy,77));let usize drop1=built(ir::array_drop(ref mut p,root,77));let usize ret=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);assert(verifier::inspect_reborrow_calls(ref p).is_ok);return p;
}
@test
fn void all_six_owned_and_formal_derived_calls_execute_complete_programs(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){let ir::Program owned=program(tags[i],false,2,1,false,false);let ir::Program formal=program(tags[i],true,2,1,false,false);assert(runner::inspect(ref owned).is_ok && runner::inspect(ref formal).is_ok);assert(checked(run(ref owned,16000000))==42 && checked(run(ref formal,16000000))==42);i+=1;}
}
@test
fn void recursive_scalar_counters_and_combined_depth_are_executed_by_the_shared_loop(){
    let ir::Program p=program(10,true,2,1,false,true);assert(checked(run(ref p,16000000))==42);var ir::Program deep=p;var usize i=0;while(i<deep.constant_count){if(deep.constants[i]==13){deep.constants[i]=14;}i+=1;}error(run(ref deep,16000000),12);
}
@test
fn void mixed_shared_and_multiple_writers_reuse_call_frames_and_keep_normal_owned_calls(){
    let ir::Program shared=program(10,true,1,2,true,false);let ir::Program writers=program(10,false,2,2,false,false);assert(checked(run(ref shared,16000000))==42 && checked(run(ref writers,16000000))==42);let ir::Program ordinary=mixed_owned(false);assert(checked(run(ref ordinary,16000000))==42);
}
@test
fn void bounds_arithmetic_and_fuel_failures_drain_loans_and_preserve_prior_writes(){
    var usize variant=0;while(variant<2){let ir::Program p=program(10,variant==1,2,1,false,false);var ir::Program bad=p;let usize read=opcode(ref bad,58,0);bad.code[read*8+3]+=1;
        var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
        error(runner::execute(ref bad,16000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links),14);clean(ref auth,ref c,ref links,ref l,ref f);assert(a.owners.depth==1);let usize owner=if(variant==1){0}else{16};assert(cell(owners::read(ref a.owners,a.tokens[owner],0,bytes::view(ref b)))==255);
        bad=p;let usize division=opcode(ref bad,5,0);let u8 denominator=bad.code[division*8+3];var usize pc=bad.starts[0];while(pc<bad.ends[0]){if(bad.code[pc*8]==1 && bad.code[pc*8+1]==denominator){let usize id=bad.code[pc*8+2] as usize;bad.constants[id]=0;}pc+=1;}error(run(ref bad,16000000),7);error(run(ref p,0),8);variant+=1;}
}
@test
fn void exact_execution_fuel_and_one_short_budget_keep_cleanup_deterministic(){
    let ir::Program p=program(10,true,1,1,false,false);var usize lo=0;var usize hi=4000000;assert(run(ref p,hi).is_ok);while(lo<hi){let usize mid=lo+(hi-lo)/2;if(run(ref p,mid).is_ok){hi=mid;}else{lo=mid+1;}}assert(checked(run(ref p,lo))==42);error(run(ref p,lo-1),8);
}
@test
fn void scalar_and_control_preflight_publish_nothing_until_derived_handoff_succeeds(){
    let ir::Program p=program(10,false,1,1,false,true);let forest::Sites map=switch(runner::inspect(ref p)){case .ok(v):{v}case .err(_):{assert(false);forest::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};
    var arrays::State a=arrays::empty(256);var records::State record_state=records::empty();var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();var children::Bindings links=children::empty();var bytes::Buffer b=backing();
    let layouts::Array shape=switch(layouts::scalar(10,2)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=2,.stride=1,.alignment=1,.bytes=2}}};let owners::Token root=switch(owners::create(ref shape,0,bytes::view_mut(ref mut b),ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};a.tokens[0]=root;
    var i64[256] r=[99;256];var usize i=0;while(i<p.count){if(p.code[i*8]==1){r[p.code[i*8+1] as usize]=p.constants[p.code[i*8+2] as usize];}i+=1;}let usize opened=built(ordinary::step(ref p,1,opcode(ref p,54,1),0,ref mut l,ref mut a,ref mut b,ref mut r[..128],65537));let usize begun=built(adapter::step(ref p,ref map,1,opcode(ref p,61,1),0,ref mut links,ref c,ref mut auth,ref f,ref mut l,ref a,ref b,ref r[..128],65537));
    let usize pc=opcode(ref p,9,1);let usize args=p.code[pc*8+3] as usize;let usize scalar=p.call_args[args*8+1] as usize;let usize charge=built(calls::cost(ref p,pc,77));var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];let i64[256] before=r;let slices::Pool pool=l.pool;let authority::State receipts=auth;
    var usize mode=0;while(mode<3){let usize span=if(mode==1){128}else{256};let usize controls=if(mode==2){1}else{32};let usize fuel=if(mode==0){charge-1}else{charge};fail(control::step_canonical_derived(ref p,ref map,pc,0,ref links,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut record_state,ref mut a,ref mut b,ref mut r[..span],ref mut pcs[..controls],ref mut dsts,fuel),if(mode==0){8}else{5});same_pool(ref pool,ref l.pool);same_state(ref receipts,ref auth);i=0;while(i<256){assert(r[i]==before[i]);i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}mode+=1;}
    assert(built(control::step_canonical_derived(ref p,ref map,pc,0,ref links,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut record_state,ref mut a,ref mut b,ref mut r,ref mut pcs,ref mut dsts,charge))==0);assert(r[129]==r[scalar] && r[128]==before[128] && pcs[1]==pc+1 && dsts[1]==p.code[pc*8+1] as usize);assert(checked(context::finish(ref mut links,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref b,.ok(42)))==42);
}
@test
fn void raw_core_failure_keeps_maps_until_cleanup_and_failed_cleanup_is_retryable(){
    var ir::Program p=program(10,true,2,1,false,false);let usize read=opcode(ref p,58,0);p.code[read*8+3]+=1;let forest::Sites map=switch(runner::inspect(ref p)){case .ok(v):{v}case .err(_):{assert(false);forest::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    let Result<i64,errors::Error> outcome=execution::execute_canonical(ref p,ref map,16000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links);error(outcome,14);assert(auth[0].depth==4 && auth[0].frame==2 && c[0].pcs[3]!=256 && links[0].children[1]!=16 && links[0].children[2]!=16);
    let usize epoch=a.owners.slots[0].read_generation;a.owners.slots[0].read_generation+=1;let slices::Pool before=l.pool;let authority::State receipts=auth[0];assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,outcome)){case .ok(_):{false}case .err(e):{e.kind==5}});same_pool(ref before,ref l.pool);same_state(ref receipts,ref auth[0]);assert(c[0].pcs[3]!=256);a.owners.slots[0].read_generation=epoch;error(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,outcome),14);clean(ref auth,ref c,ref links,ref l,ref f);assert(cell(owners::read(ref a.owners,a.tokens[0],0,bytes::view(ref b)))==255);
}
@test
fn void owned_derived_calls_admit_but_dirty_contexts_reject_before_execution(){
    var ir::Program owned=mixed_owned(true);var usize variant=0;
    while(variant<2){
        assert(verifier::inspect_reborrow_calls(ref owned).is_ok);
        assert(runner::inspect(ref owned).is_ok && runner::inspect_derived(ref owned).is_ok && verifier::verify(ref owned).is_ok);
        error(vm::run_with_array_limit(ref owned,0,65537),13);error(run(ref owned,0),8);assert(checked(run(ref owned,16000000))==42);
        if(variant==0){
            // Valid owned arguments also admit in an unreachable function.
            owned.function_count=3;owned.entry=2;owned.return_types[2]=1;
            let usize start=owned.count;let usize regs=owned.registers;owned.starts[2]=start;owned.register_starts[2]=regs;
            let usize answer=built(ir::literal(ref mut owned,42,0));let usize ret=built(ir::emit(ref mut owned,8,answer,0,0));finish(ref mut owned,2);
        }
        variant+=1;
    }
    let ir::Program p=program(10,true,1,1,false,false);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    assert(runner::inspect(ref p).is_ok && runner::inspect_derived(ref p).is_ok && !verifier::inspect(ref p).is_ok && verifier::verify(ref p).is_ok);
    error(vm::run_with_array_limit(ref p,0,0),8);error(vm::run_with_array_limit(ref p,0,65537),13);
    error(execution::execute(ref p,16000000,ref mut a,ref mut b,ref mut l,ref mut f),5);clean(ref auth,ref c,ref links,ref l,ref f);assert(a.owners.depth==0 && a.owners.arena.used==0);
    dirty(ref mut links[0],0);error(runner::execute(ref p,0,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links),5);
    assert(links[0].children[30]==0 && a.owners.depth==0 && a.owners.arena.used==0);dirty(ref mut links[0],16);clean(ref auth,ref c,ref links,ref l,ref f);
    error(runner::execute(ref p,0,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links),8);clean(ref auth,ref c,ref links,ref l,ref f);
    assert(checked(runner::execute_derived(ref p,16000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);clean(ref auth,ref c,ref links,ref l,ref f);assert(a.owners.depth==0 && a.owners.arena.used==0);
}

fn void dirty(ref mut children::Bindings sites,usize value){sites.children[30]=value;}
