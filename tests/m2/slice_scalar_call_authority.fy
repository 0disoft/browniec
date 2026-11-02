module tests::m2::slice_scalar_call_authority;
import ir as ir;
import errors as errors;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import vm_reborrow_execution as runner;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_context as context;
import slice_reborrow_ir as proof;
import slice_vm as loans;
import slice_call_vm as shared;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import struct_vm as records;
import mixed_call_vm as mixed;
import call_frame_vm as control;
import std::bytes as bytes;

fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 answer(Result<i64,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn usize pc(ref ir::Program p,usize f){var usize at=p.starts[f];while(at<p.ends[f] && p.code[at*8]!=9){at+=1;}assert(at<p.ends[f]);return at;}
fn proof::Sites sites(ref ir::Program p){return switch(runner::inspect(p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn void empty(ref authority::State[] auth,ref calls::Bindings[] c,ref children::Bindings[] links,ref loans::State l,ref shared::Frames f){assert(context::ready(ref auth[0],ref c[0],ref links[0],l,f).is_ok);}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation && x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation && x.view.element==y.view.element && x.view.length==y.view.length && x.view.start==y.view.start && x.view.end==y.view.end);i+=1;}}
fn void map_pc(ref mut calls::Bindings c,usize index,usize value){c.pcs[index]=value;}
fn void detach(ref mut calls::Bindings c,usize index,slices::Ticket value){c.detached[index]=value;}
fn owners::Token create(ref mut arrays::State a,ref mut bytes::Buffer b){let layouts::Array shape=switch(layouts::scalar(10,1)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};return switch(owners::create(ref shape,0,bytes::view_mut(b),ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn slices::Ticket open(ref mut loans::State l,ref mut arrays::State a,owners::Token root){return switch(slices::open_exclusive(ref mut l.pool,ref mut a.owners,root,0,1,64)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn void finish_function(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;p.ends[f]=n;p.register_ends[f]=r;}
fn ir::Program owned_reborrow(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize root=built(ir::array_in(ref mut p,0,10,2,true,77));let usize parent=built(ir::exclusive_slice(ref mut p,root,77));let usize zero=built(ir::integer(ref mut p,0,12,77));let usize one=built(ir::integer(ref mut p,1,12,77));let usize z=built(ir::integer(ref mut p,0,10,77));let usize init=built(ir::array_init(ref mut p,root,z,77));let usize opened=built(ir::slice_open(ref mut p,parent,zero,one,77));
    let usize child=built(proof::derived(ref mut p,parent,77));let usize begin=built(proof::begin(ref mut p,child,parent,zero,one,77));let usize value=built(ir::integer(ref mut p,42,10,77));let usize write=built(ir::slice_write(ref mut p,child,zero,value,77));let usize read=built(ir::slice_read(ref mut p,child,zero,77));let usize result=built(ir::widen(ref mut p,read,1,77));let usize end=built(proof::end(ref mut p,child,parent,77));let usize close=built(ir::slice_close(ref mut p,parent,77));let usize drop=built(ir::array_drop(ref mut p,root,77));let usize ret=built(ir::emit(ref mut p,8,result,0,77));finish_function(ref mut p,0);
    let usize n=p.count;let usize r=p.registers;p.starts[1]=n;p.register_starts[1]=r;let usize[1] args=[0];let usize call=built(ir::call(ref mut p,0,ref args[..0],77));let usize done=built(ir::emit(ref mut p,8,call,0,77));finish_function(ref mut p,1);assert(verifier::inspect(ref p).is_ok);return p;
}

@test
fn void zero_and_eight_scalar_arguments_and_tagged_results_execute_at_existing_prices(){
    let ir::Program p=compiled(b"module main;fn i32 f(bool b,i32 a,i64 c,u8 d,u32 e,usize g,Option<i32> o,Result<i32,bool> r){if(!b || a!=-2147483648 || c!=-9223372036854775808 || d!=255 || e!=4294967295 || g!=18446744073709551615){return 0;}let i32 x=switch(o){case .some(v):{v}case .none:{0}};let i32 y=switch(r){case .ok(v):{v}case .err(_):{0}};return x+y;}fn i32 main(){return f(true,-2147483648,-9223372036854775808,255,4294967295,18446744073709551615,.some(20),.ok(22));}");var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    let usize at=pc(ref p,p.entry);assert(built(calls::cost(ref p,at,p.offsets[at]))==9 && built(mixed::cost(ref p,0,p.offsets[at]))==9);assert(answer(runner::execute(ref p,10000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);empty(ref auth,ref c,ref links,ref l,ref f);
    let ir::Program zero=compiled(b"module main;fn i32 f(){return 42;}fn i32 main(){return f();}");let usize z=pc(ref zero,zero.entry);assert(built(calls::cost(ref zero,z,0))==1);assert(answer(runner::execute(ref zero,10000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);empty(ref auth,ref c,ref links,ref l,ref f);
    let ir::Program tagged=compiled(b"module main;fn Option<i32> maybe(bool b){if(b){return .some(42);}return .none;}fn i32 main(){switch(maybe(false)){case .some(_):{return 0;}case .none:{}}return switch(maybe(true)){case .some(v):{v}case .none:{0}};}");assert(answer(runner::execute(ref tagged,10000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);empty(ref auth,ref c,ref links,ref l,ref f);
}
@test
fn void zero_writer_control_admission_prices_and_corrupt_return_maps_are_atomic(){
    let ir::Program p=compiled(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){return f(42);}");var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    let proof::Sites map=sites(ref p);let usize at=pc(ref p,p.entry);let usize offset=p.offsets[at];let usize scalar=p.call_args[(p.code[at*8+3] as usize)*8] as usize;let usize price=built(calls::cost(ref p,at,offset));assert(price==2);let owners::Token root=create(ref mut a,ref mut b);a.tokens[0]=root;let slices::Ticket live=open(ref mut l,ref mut a,root);l.tickets[0]=live;let slices::Pool saved=l.pool;var records::State records=records::empty();var i64[256] r=[99;256];r[scalar]=42;var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];var usize mode=0;
    while(mode<3){let usize span=if(mode==1){128}else{256};let usize controls=if(mode==2){1}else{32};assert(switch(control::step_canonical(ref p,ref map,at,0,ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut records,ref mut a,ref mut b,ref mut r[..span],ref mut pcs[..controls],ref mut dsts,if(mode==0){price-1}else{price})){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else{5} && e.offset==offset}});same_pool(ref l.pool,ref saved);assert(auth[0].depth==0 && c[0].pcs[0]==256);var usize i=0;while(i<256){assert(r[i]==if(i==scalar){42}else{99});i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}mode+=1;}
    assert(built(control::step_canonical(ref p,ref map,at,0,ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut records,ref mut a,ref mut b,ref mut r,ref mut pcs,ref mut dsts,price))==0);assert(auth[0].depth==1 && auth[0].counts[0]==0 && c[0].pcs[0]==at && r[128]==42 && pcs[1]==at+1);same_pool(ref l.pool,ref saved);
    map_pc(ref mut c[0],0,256);assert(!calls::leave(ref p,0,1,ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref records,ref b,offset).is_ok);assert(auth[0].depth==1);map_pc(ref mut c[0],0,at);detach(ref mut c[0],0,live);assert(!calls::leave(ref p,0,1,ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref records,ref b,offset).is_ok);detach(ref mut c[0],0,slices::Ticket{.slot=16,.generation=0});assert(built(calls::leave(ref p,0,1,ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref records,ref b,offset))==0);same_pool(ref l.pool,ref saved);assert(l.tickets[0].generation==live.generation && auth[0].depth==0 && c[0].pcs[0]==256);
    assert(answer(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.ok(42)))==42);empty(ref auth,ref c,ref links,ref l,ref f);
}
@test
fn void scalar_helpers_interleave_with_mutable_formals_and_reuse_recursive_frames(){
    let ir::Program p=compiled(b"module main;fn i32 add(i32 x,i32 y){return x+y;}fn i32 f(ref mut i32[] p){p[0]=add(20,22);return p[0];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    assert(answer(runner::execute(ref p,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);empty(ref auth,ref c,ref links,ref l,ref f);
    let ir::Program recursive=compiled(b"module main;fn i32 f(i32 n){if(n==0){return 42;}return f(n-1);}fn i32 main(){return f(30);}");assert(answer(runner::execute(ref recursive,10000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);empty(ref auth,ref c,ref links,ref l,ref f);
    var ir::Program deep=recursive;var usize i=0;while(i<deep.constant_count){if(deep.constants[i]==30){deep.constants[i]=31;}i+=1;}assert(switch(runner::execute(ref deep,10000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{false}case .err(e):{e.kind==12}});empty(ref auth,ref c,ref links,ref l,ref f);
}
@test
fn void thirty_empty_calls_reserve_the_next_writer_and_the_following_frame_fails(){
    let ir::Program p=compiled(b"module main;fn i32 write(ref mut i32[] p){p[0]=42;return p[0];}fn i32 recurse(i32 n){if(n==0){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return write(ref mut p);}return recurse(n-1);}fn i32 main(){return recurse(29);}");var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    assert(answer(runner::execute(ref p,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);empty(ref auth,ref c,ref links,ref l,ref f);
    var ir::Program deep=p;var usize i=0;while(i<deep.constant_count){if(deep.constants[i]==29){deep.constants[i]=30;}i+=1;}assert(switch(runner::execute(ref deep,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{false}case .err(e):{e.kind==12}});empty(ref auth,ref c,ref links,ref l,ref f);
}
@test
fn void scalar_callees_execute_owned_reborrow_before_empty_batch_return(){
    let ir::Program p=owned_reborrow();var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    assert(!verifier::verify(ref p).is_ok);assert(answer(runner::execute(ref p,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==42);empty(ref auth,ref c,ref links,ref l,ref f);assert(a.owners.depth==0 && a.owners.arena.used==0);
}
@test
fn void empty_frame_abort_preserves_outer_writes_and_failed_cleanup_records(){
    let ir::Program p=compiled(b"module main;fn i32 fail(i32 z){return 1/z;}fn i32 f(ref mut i32[] p){p[0]=42;return fail(0);}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}");var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    let proof::Sites map=sites(ref p);let errors::Error failure=switch(execution::execute_canonical(ref p,ref map,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{assert(false);errors::make(0,0)}case .err(e):{e}};assert(failure.kind==7 && auth[0].depth==2 && auth[0].counts[0]==1 && auth[0].counts[1]==0 && c[0].pcs[1]!=256);let usize epoch=a.owners.slots[0].read_generation;a.owners.slots[0].read_generation+=1;assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure))){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(auth[0].depth==2 && c[0].pcs[0]!=256 && c[0].pcs[1]!=256);a.owners.slots[0].read_generation=epoch;
    assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==failure.offset}});empty(ref auth,ref c,ref links,ref l,ref f);assert(cell(owners::read(ref a.owners,a.tokens[0],0,bytes::view(ref b)))==42);
    let ir::Program shared=compiled(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){let u8[1] a=[0;1];let ref u8[] p=ref a;return f(ref p);}");assert(runner::inspect(ref shared).is_ok);
}
