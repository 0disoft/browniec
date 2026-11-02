module tests::m2::slice_reborrow_execution;
import vm_reborrow_execution as runner;
import vm_execution as execution;
import slice_reborrow_context as context;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow as reborrow;
import slice_reborrow_ir as proof;
import slice_builders as builders;
import slice_exclusive_vm as ordinary;
import slice_call_vm as shared;
import slice_vm as loans;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import array_layout as layouts;
import struct_vm as records;
import call_frame_vm as control;
import slice_mutable_call_vm as legacy;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import std::bytes as bytes;
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn usize size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token create(ref mut owners::Table table,u8 tag,usize n,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(tag,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    return switch(owners::create(ref shape,0,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
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

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void fail(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn usize at(ref ir::Program p,u8 op,usize occurrence){var usize i=0;var usize n=0;while(i<p.count){if(p.code[i*8]==op){if(n==occurrence){return i;}n+=1;}i+=1;}assert(false);return 0;}
fn usize constant(ref mut ir::Program p,u8 tag,i64 n){return built(if(tag==2){ir::boolean(p,n==1,77)}else{ir::integer(p,n,tag,77)});}
fn void end_function(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;p.ends[f]=n;p.register_ends[f]=r;}
fn ir::Program program(u8 tag,i64 value,usize levels,bool empty,bool formal,u8 failure){
    var ir::Program p=ir::empty();p.function_count=if(formal){2}else{1};p.entry=if(formal){1}else{0};p.return_types[0]=1;p.return_types[1]=if(formal){1}else{0};var usize root=16;var usize parent=16;
    if(formal){p.arities[0]=1;parent=built(builders::parameter_exclusive(ref mut p,0,tag,77));}
    else{root=built(ir::array(ref mut p,tag,4,true,77));parent=built(ir::exclusive_slice(ref mut p,root,77));let usize fill=constant(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,root,fill,77));}
    let usize one=constant(ref mut p,12,1);let usize high=constant(ref mut p,12,4);let usize zero=constant(ref mut p,12,0);let usize two=constant(ref mut p,12,2);let usize cell=constant(ref mut p,tag,value);
    if(!formal){let usize opened=built(ir::slice_open(ref mut p,parent,one,high,77));}
    var usize[16] sites=[16;16];sites[0]=parent;var usize i=1;while(i<=levels){sites[i]=built(proof::derived(ref mut p,sites[i-1],77));let usize begin=built(proof::begin(ref mut p,sites[i],sites[i-1],if(i==1){one}else{zero},if(empty){if(i==1){one}else{zero}}else{if(i==1){two}else{one}},77));i+=1;}
    let usize length=built(ir::slice_length(ref mut p,sites[levels],77));if(tag==10){let usize utf=built(ir::slice_utf8(ref mut p,sites[levels],77));}let usize write=built(ir::slice_write(ref mut p,sites[levels],zero,cell,77));let usize read=built(ir::slice_read(ref mut p,sites[levels],zero,77));
    if(failure==1){let usize index=constant(ref mut p,12,99);let usize bad=built(ir::slice_write(ref mut p,sites[levels],index,cell,77));}
    if(failure==2){let usize x=constant(ref mut p,1,1);let usize z=constant(ref mut p,1,0);let usize bad=built(ir::emit(ref mut p,5,x,z,77));}
    i=levels;while(i>0){let usize done=built(proof::end(ref mut p,sites[i],sites[i-1],77));i-=1;}
    let usize closed=built(ir::slice_close(ref mut p,parent,77));if(!formal){let usize drop=built(ir::array_drop(ref mut p,root,77));}let usize equal=built(ir::emit(ref mut p,11,read,cell,77));let usize branch=built(ir::raw(ref mut p,20,0,equal,0,77));let usize answer=built(ir::literal(ref mut p,42,77));let usize returned=built(ir::emit(ref mut p,8,answer,0,77));let usize target=p.count;let usize jump=built(ir::patch(ref mut p,branch,target,77));let usize wrong=built(ir::literal(ref mut p,43,77));let usize bad=built(ir::emit(ref mut p,8,wrong,0,77));end_function(ref mut p,0);
    if(formal){let usize n=p.count;let usize r=p.registers;p.starts[1]=n;p.register_starts[1]=r;
        let usize id=built(ir::array_in(ref mut p,1,tag,4,true,77));let usize source=built(ir::exclusive_slice(ref mut p,id,77));let usize fill=constant(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,id,fill,77));
        let usize lo=constant(ref mut p,12,1);let usize hi=constant(ref mut p,12,4);let usize opened=built(ir::slice_open(ref mut p,source,lo,hi,77));let usize[1] args=[160+source];let usize result=built(ir::call(ref mut p,0,ref args,77));
        let usize at=constant(ref mut p,12,1);let usize observed=built(ir::slice_read(ref mut p,source,at,77));let usize wanted=constant(ref mut p,tag,value);let usize equal=built(ir::emit(ref mut p,11,observed,wanted,77));let usize closed=built(ir::slice_close(ref mut p,source,77));let usize drop=built(ir::array_drop(ref mut p,id,77));let usize branch=built(ir::raw(ref mut p,20,0,equal,0,77));let usize ret=built(ir::emit(ref mut p,8,result,0,77));let usize target=p.count;let usize jump=built(ir::patch(ref mut p,branch,target,77));let usize wrong=built(ir::literal(ref mut p,43,77));let usize bad=built(ir::emit(ref mut p,8,wrong,0,77));end_function(ref mut p,1);}
    assert(verifier::inspect(ref p).is_ok);return p;
}
fn bytes::Buffer backing(){return switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};}
fn void clean(ref authority::State[] receipts,ref calls::Bindings[] c,ref children::Bindings[] links,ref loans::State l,ref shared::Frames f){
    assert(receipts.len==1 && c.len==1 && links.len==1 && context::ready(ref receipts[0],ref c[0],ref links[0],l,f).is_ok);
}
fn void dirty(ref mut children::Bindings bindings,usize value){bindings.children[30]=value;}
fn i64 checked(Result<i64,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void failure(Result<i64,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}

@test
fn void six_scalar_formals_execute_nested_reborrow_and_return_visible_writes_through_one_core(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];var usize i=0;while(i<6){let ir::Program p=program(tags[i],values[i],2,false,true,0);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
        assert(checked(runner::execute(ref p,3000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);clean(ref auth,ref c,ref links,ref l,ref f);assert(a.owners.depth==0 && a.owners.arena.used==0);i+=1;
    }
    let ir::Program p=program(10,42,2,false,false,0);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    assert(checked(runner::execute(ref p,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);clean(ref auth,ref c,ref links,ref l,ref f);
}
@test
fn void runtime_bounds_arithmetic_and_fuel_failures_drain_and_preserve_earlier_writes(){
    var usize mode=0;while(mode<4){let ir::Program p=program(10,42,2,mode==3,true,if(mode==1){2}else{if(mode==0){1}else{0}});var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
        failure(runner::execute(ref p,if(mode==2){0}else{3000000},ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links),if(mode==0 || mode==3){14}else{if(mode==1){7}else{8}});clean(ref auth,ref c,ref links,ref l,ref f);
        if(mode<2){assert(a.owners.depth==1 && cell(owners::read(ref a.owners,a.tokens[0],2,bytes::view(ref b)))==42);}else if(mode==2){assert(a.owners.depth==0 && a.owners.arena.used==0);}mode+=1;
    }
}
@test
fn void recursive_counter_calls_use_shared_scalar_control_and_combined_depth(){
    let ir::Program base=compiled(b"module main;fn i32 f(ref mut u8[] p,i32 n){if(n==0){p[0]=42;return 42;}return f(ref mut p,n-1);}fn i32 main(){var u8[1] a=[0;1];let ref mut u8[] p=ref mut a;return f(ref mut p,30);}");var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    assert(checked(runner::execute(ref base,8000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);clean(ref auth,ref c,ref links,ref l,ref f);
    var ir::Program too_deep=base;var usize i=0;while(i<too_deep.constant_count){if(too_deep.constants[i]==30){too_deep.constants[i]=31;}i+=1;}
    assert(switch(runner::execute(ref too_deep,8000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{false}case .err(e):{e.kind==12}});clean(ref auth,ref c,ref links,ref l,ref f);
    let ir::Program reused=compiled(b"module main;fn i32 f(ref mut u8[] p,i32 n){p[0]=42;return n;}fn i32 main(){var u8[1] a=[0;1];let ref mut u8[] p=ref mut a;return f(ref mut p,20)+f(ref mut p,22);}");var arrays::State again=arrays::empty(64);var bytes::Buffer buffer=backing();assert(checked(runner::execute(ref reused,3000000,ref mut again,ref mut buffer,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);clean(ref auth,ref c,ref links,ref l,ref f);
}
@test
fn void scalar_control_is_unchanged_until_canonical_admission_commits(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref mut u8[] p,i32 n){p[0]=42;return n;}fn i32 main(){var u8[1] a=[0;1];let ref mut u8[] p=ref mut a;return f(ref mut p,42);}");var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    var records::State record_state=records::empty();let owners::Token root=create(ref mut a.owners,10,1,bytes::view_mut(ref mut b));a.tokens[0]=root;let usize call=at(ref p,9,0);let usize arg=p.code[call*8+3] as usize;let usize source=(p.call_args[arg*8] as usize)-160;let usize scalar=p.call_args[arg*8+1] as usize;let slices::Ticket opened=ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,root,0,1,64));l.tickets[source]=opened;let proof::Sites sites=switch(runner::inspect(ref p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};
    var i64[256] r=[99;256];r[scalar]=42;var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];let usize price=built(calls::cost(ref p,call,p.offsets[call]));var usize mode=0;while(mode<3){let usize fuel=if(mode==0){price-1}else{price};let usize span=if(mode==1){128}else{256};let usize controls=if(mode==2){1}else{32};assert(switch(control::step_canonical(ref p,ref sites,call,0,ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref record_state,ref a,ref b,ref mut r[..span],ref mut pcs[..controls],ref mut dsts,fuel)){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else{5}}});assert(auth[0].depth==0 && c[0].pcs[0]==256 && l.tickets[source].generation==opened.generation);var usize i=0;while(i<256){assert(r[i]==if(i==scalar){42}else{99});i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}mode+=1;}
    assert(built(control::step_canonical(ref p,ref sites,call,0,ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref record_state,ref a,ref b,ref mut r,ref mut pcs,ref mut dsts,price))==0);assert(auth[0].frame==1 && r[128+p.register_starts[0]+1]==42 && pcs[1]==call+1 && dsts[1]==p.code[call*8+1] as usize);
    assert(checked(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.ok(42)))==42);clean(ref auth,ref c,ref links,ref l,ref f);
}
@test
fn void failed_cleanup_keeps_live_core_maps_and_successful_retry_preserves_outcome(){
    let ir::Program p=program(10,42,1,false,true,1);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    let proof::Sites sites=switch(runner::inspect(ref p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};
    let Result<i64,errors::Error> result=execution::execute_canonical(ref p,ref sites,3000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links);failure(result,14);assert(auth[0].depth==2 && auth[0].frame==1 && c[0].pcs[0]!=256 && links[0].children[1]==1);
    let usize epoch=a.owners.slots[0].read_generation;a.owners.slots[0].read_generation+=1;assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(errors::make(14,77)))){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(auth[0].depth==2 && c[0].pcs[0]!=256 && links[0].children[1]==1);a.owners.slots[0].read_generation=epoch;
    failure(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(errors::make(14,77))),14);clean(ref auth,ref c,ref links,ref l,ref f);assert(cell(owners::read(ref a.owners,a.tokens[0],2,bytes::view(ref b)))==42);
}
@test
fn void unsupported_modes_dirty_invocations_and_legacy_execution_fail_before_effects(){
    let ir::Program p=program(10,42,1,false,true,0);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var bytes::Buffer b=backing();
    assert(!verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,3000000,64)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(switch(execution::execute(ref p,3000000,ref mut a,ref mut b,ref mut l,ref mut f)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(a.owners.depth==0);
    dirty(ref mut links[0],0);assert(switch(runner::execute(ref p,3000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(links[0].children[30]==0 && a.owners.depth==0);dirty(ref mut links[0],16);
    let ir::Program scalar=compiled(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){return f(42);}");assert(verifier::verify(ref scalar).is_ok);assert(switch(runner::execute(ref scalar,0,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{false}case .err(e):{e.kind==5}});assert(a.owners.depth==0);clean(ref auth,ref c,ref links,ref l,ref f);
    let ir::Program readonly=compiled(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){let u8[1] a=[0;1];let ref u8[] p=ref a;return f(ref p);}");assert(switch(runner::execute(ref readonly,3000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{false}case .err(e):{e.kind==5}});clean(ref auth,ref c,ref links,ref l,ref f);
}
