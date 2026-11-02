module tests::m2::slice_owned_call_authority;
import ir as ir;
import compiler as compiler;
import errors as errors;
import vm_reborrow_execution as runner;
import vm_execution as execution;
import slice_reborrow_ir as proof;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_context as context;
import slice_vm as loans;
import slice_call_vm as shared;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import struct_vm as records;
import slice_mutable_call_vm as legacy;
import call_frame_vm as control;
import std::bytes as bytes;

fn ir::Program compiled(ref u8[] s){return switch(compiler::compile(s)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 answer(Result<i64,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize done(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn layouts::Array shape(u8 tag,usize n){return switch(layouts::scalar(tag,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=1,.length=1,.stride=4,.alignment=4,.bytes=4}}};}
fn owners::Token create(ref mut arrays::State a,ref mut bytes::Buffer b,u8 tag,usize n,i64 value){let layouts::Array s=shape(tag,n);return switch(owners::create(ref s,value,bytes::view_mut(b),ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};}
fn usize pc(ref ir::Program p){var usize at=p.starts[p.entry];while(at<p.ends[p.entry] && p.code[at*8]!=9){at+=1;}assert(at<p.ends[p.entry]);return at;}
fn proof::Sites sites(ref ir::Program p){return switch(runner::inspect(p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn ir::Program fixture(){return compiled(b"module main;fn i32 f(u8[2] a,ref u8[] q,ref mut i32[] p,ref u8[] r,bool[2] b){if(b[0]){p[0]=a[0] as i32+q[0] as i32;}return p[0];}fn i32 main(){let u8[2] a=[21;2];let bool[2] b=[true;2];var i32[2] c=[0;2];let ref u8[] q=ref a;let ref mut i32[] p=ref mut c;return f(a,ref q,ref mut p,ref q,b);}");}
fn void initialize(ref ir::Program p,ref mut arrays::State a,ref mut loans::State l,ref mut bytes::Buffer b){
    var usize i=0;while(i<p.arrays.count){if(p.array_functions[i] as usize==p.entry){let owners::Token root=create(a,b,p.arrays.elements[i],p.arrays.lengths[i],if(p.arrays.elements[i]==2){1}else{21});a.tokens[i]=root;}i+=1;}
    let usize args=p.code[pc(p)*8+3] as usize;i=0;while(i<5){let usize source=p.call_args[args*8+i] as usize;if(source>=160){let usize site=source-160;if(l.tickets[site].generation==0){let owners::Token root=a.tokens[(p.slice_roots[site] as usize)-1];
        let slices::Ticket t=if(ir::exclusive(p,site)){ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,root,0,2,256))}else{ticket(slices::open(ref mut l.pool,ref mut a.owners,root,0,2,256))};l.tickets[site]=t;}}i+=1;}
}
fn arrays::State saved_arrays(ref arrays::State a){return arrays::State{.owners=owners::Table{.slots=a.owners.slots,.order=a.owners.order,.depth=a.owners.depth,.arena=a.owners.arena},.tokens=a.tokens};}
fn loans::State saved_loans(ref loans::State l){return loans::State{.pool=slices::Pool{.slots=l.pool.slots},.tickets=l.tickets};}
fn u8[256] saved_bytes(ref bytes::Buffer b){var u8[256] v=[0;256];let ref u8[] data=bytes::view(b);var usize i=0;while(i<256){v[i]=data[i];i+=1;}return v;}
fn void unchanged(ref arrays::State a,ref arrays::State old,ref loans::State l,ref loans::State previous,ref bytes::Buffer b,ref u8[] data,ref authority::State auth,ref calls::Bindings c,ref shared::Frames f){
    assert(auth.depth==0 && auth.frame==0 && a.owners.depth==old.owners.depth && a.owners.arena.used==old.owners.arena.used && a.owners.arena.limit==old.owners.arena.limit);
    var usize i=0;while(i<512){assert(a.tokens[i].slot==old.tokens[i].slot && a.tokens[i].generation==old.tokens[i].generation && l.tickets[i].slot==previous.tickets[i].slot && l.tickets[i].generation==previous.tickets[i].generation);i+=1;}
    i=0;while(i<16){let slices::Slot x=l.pool.slots[i];let slices::Slot y=previous.pool.slots[i];let owners::Owner u=a.owners.slots[i];let owners::Owner v=old.owners.slots[i];
        assert(x.live==y.live && x.exclusive==y.exclusive && x.generation==y.generation && x.lease.generation==y.lease.generation && x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation && x.view.start==y.view.start && x.view.end==y.view.end);
        assert(u.generation==v.generation && u.occupied==v.occupied && u.live==v.live && u.reading==v.reading && u.writing==v.writing && u.read_generation==v.read_generation && u.mark==v.mark && u.base==v.base && u.end==v.end && a.owners.order[i]==old.owners.order[i]);i+=1;}
    i=0;while(i<31){assert(c.pcs[i]==256);i+=1;}i=0;while(i<248){assert(c.detached[i].slot==16 && c.detached[i].generation==0);i+=1;}i=0;while(i<256){assert(f.origins[i].slot==16 && f.origins[i].generation==0 && bytes::view(b)[i]==data[i]);i+=1;}
}
fn void run(ref u8[] source,i64 expected){let ir::Program p=compiled(source);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();
    assert(answer(runner::execute(ref p,10000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==expected);assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok && a.owners.depth==0 && a.owners.arena.used==0);
}

@test
fn void six_tags_owned_only_recursion_and_reused_frames_execute(){
    run(b"module main;fn i32 f(i32[1] a,bool[1] b,i64[1] c,u8[1] d,u32[1] e,usize[1] g){if(a[0]!=-2147483648 || !b[0] || c[0]!=-9223372036854775808 || d[0]!=255 || e[0]!=4294967295 || g[0]!=18446744073709551615){return 0;}return 42;}fn i32 main(){let i32[1] a=[-2147483648;1];let bool[1] b=[true;1];let i64[1] c=[-9223372036854775808;1];let u8[1] d=[255;1];let u32[1] e=[4294967295;1];let usize[1] g=[18446744073709551615;1];return f(a,b,c,d,e,g);}",42);
    run(b"module main;fn i32 f(i32[1] a,i32 n){if(n==0){return a[0];}return f(a,n-1);}fn i32 main(){let i32[1] a=[21;1];return f(a,5)+f(a,5);}",42);
    run(b"module main;fn i32 f(u8[1] a,u8[1] b,u8[1] c,u8[1] d,u8[1] e,u8[1] f,u8[1] g,u8[1] h){return a[0] as i32+h[0] as i32;}fn i32 main(){let u8[1] a=[21;1];return f(a,a,a,a,a,a,a,a);}",42);
}
@test
fn void owned_shared_writer_mixture_executes_and_copies_are_independent(){
    run(b"module main;fn i32 f(u8[2] a,ref u8[] q,ref mut i32[] p,bool[2] b){if(b[0]){p[0]=a[0] as i32+q[0] as i32;}return p[0];}fn i32 main(){let u8[2] a=[21;2];let bool[2] b=[true;2];var i32[1] c=[0;1];let ref u8[] q=ref a;let ref mut i32[] p=ref mut c;return f(a,ref q,ref mut p,b);}",42);
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut l,ref mut b);let usize at=pc(ref p);
    assert(built(calls::cost(ref p,at,77))==built(legacy::cost(ref p,0,77)));let usize used=a.owners.arena.used;let usize count=a.owners.depth;assert(built(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref mut b,built(calls::cost(ref p,at,77))))==0);
    let usize dst=(p.array_parameters[0] as usize)-1;let usize src=(p.call_args[(p.code[at*8+3] as usize)*8] as usize)-128;assert(a.owners.depth==count+2 && a.owners.arena.used==used+4 && a.tokens[16+dst].slot!=a.tokens[src].slot && auth.depth==1 && auth.counts[0]==1);
    let owners::Token child=a.tokens[16+dst];let usize written=done(owners::write(ref a.owners,child,0,99,bytes::view_mut(ref mut b)));assert(switch(owners::read(ref a.owners,a.tokens[src],0,bytes::view(ref b))){case .ok(v):{v==21}case .err(_):{false}});
    assert(!calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref b,77).is_ok && auth.depth==1);
    var usize arg=5;while(arg>0){arg-=1;let usize id=p.array_parameters[arg] as usize;if(id!=0){let usize slot=16+id-1;let owners::Token root=a.tokens[slot];let usize released=done(owners::release(ref mut a.owners,root,256));a.tokens[slot]=owners::Token{.slot=0,.generation=0};}}
    assert(built(calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref b,77))==1 && a.owners.depth==count && a.owners.arena.used==used);assert(answer(calls::finish(ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref b,.ok(42)))==42);
}
@test
fn void late_owned_failures_and_earlier_loan_failures_preserve_every_original(){
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);let usize at=pc(ref p);let usize args=p.code[at*8+3] as usize;let usize price=built(calls::cost(ref p,at,77));var usize mode=0;
    while(mode<8){var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut l,ref mut b);
        let usize boolean=(p.call_args[args*8+4] as usize)-128;let usize q=(p.call_args[args*8+1] as usize)-160;let usize w=(p.call_args[args*8+2] as usize)-160;
        if(mode==1){let usize limit=a.owners.arena.used+2;a.owners.arena.limit=limit;}
        else if(mode==2){let usize pos=a.owners.slots[a.tokens[boolean].slot].base;bytes::view_mut(ref mut b)[pos]=2;}
        else if(mode==3){a.tokens[boolean].generation+=1;}
        else if(mode==4){while(a.owners.depth<16){let owners::Token extra=create(ref mut a,ref mut b,1,1,0);}}
        else if(mode==5){let slices::Ticket source=l.tickets[q];var usize i=0;while(i<13){let slices::Ticket extra=ticket(slices::subslice(ref mut l.pool,source,ref a.owners,0,2,256));i+=1;}}
        else if(mode==6){let usize slot=l.tickets[w].slot;l.pool.slots[slot].generation=18446744073709551615;l.tickets[w].generation=18446744073709551615;}
        else if(mode==7){a.tokens[16]=owners::Token{.slot=0,.generation=1};}
        let arrays::State old=saved_arrays(ref a);let loans::State previous=saved_loans(ref l);let u8[256] data=saved_bytes(ref b);
        assert(switch(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref mut b,if(mode==0){price-1}else{price})){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else{if(mode==1 || mode==4 || mode==5){13}else{5}}}});
        unchanged(ref a,ref old,ref l,ref previous,ref b,ref data,ref auth,ref c,ref f);mode+=1;
    }
}
@test
fn void scalar_control_preflight_and_compatibility_entry_cannot_publish_owned_calls(){
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);let usize at=pc(ref p);let usize price=built(calls::cost(ref p,at,77));var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut l,ref mut b);
    let arrays::State old=saved_arrays(ref a);let loans::State previous=saved_loans(ref l);let u8[256] data=saved_bytes(ref b);var i64[256] r=[99;256];var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];
    assert(!control::step_canonical(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref s,ref mut a,ref mut b,ref mut r[..128],ref mut pcs,ref mut dsts,price).is_ok);assert(!calls::enter(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref a,ref s,ref b,price).is_ok);unchanged(ref a,ref old,ref l,ref previous,ref b,ref data,ref auth,ref c,ref f);
    var usize i=0;while(i<256){assert(r[i]==99);i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}
}
@test
fn void static_shape_and_aggregate_gates_reject_before_effects(){
    let ir::Program p=fixture();let usize at=pc(ref p);var ir::Program bad=p;bad.arrays.mutable[0]=true;assert(!runner::inspect(ref bad).is_ok && !calls::cost(ref bad,at,77).is_ok);bad=p;bad.arrays.lengths[0]=3;assert(!runner::inspect(ref bad).is_ok);bad=p;bad.call_args[(p.code[at*8+3] as usize)*8]=144;assert(!calls::cost(ref bad,at,77).is_ok);
    let ir::Program record=compiled(b"module main;struct P{i32 x;}fn i32 f(P p){return p.x;}fn i32 main(){return f(P{.x=42});}");assert(!runner::inspect(ref record).is_ok);
    let ir::Program result=compiled(b"module main;fn u8[1] f(u8[1] p){return p;}fn i32 main(){let u8[1] a=[42;1];let u8[1] b=f(a);return b[0] as i32;}");assert(!runner::inspect(ref result).is_ok);
}
@test
fn void abort_preserves_copied_owners_payload_writes_and_failed_cleanup_records(){
    let ir::Program p=compiled(b"module main;fn i32 f(u8[1] a,ref u8[] q,ref mut i32[] p,i32 z){p[0]=a[0] as i32+q[0] as i32;return 1/z;}fn i32 main(){let u8[1] a=[21;1];var i32[1] c=[0;1];let ref u8[] q=ref a;let ref mut i32[] p=ref mut c;return f(a,ref q,ref mut p,0);}");let proof::Sites map=sites(ref p);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();
    let errors::Error failure=switch(execution::execute_canonical(ref p,ref map,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{assert(false);errors::make(0,0)}case .err(e):{e}};assert(failure.kind==7 && auth[0].depth==1 && a.owners.depth==3);
    let usize source=(p.call_args[(p.code[pc(ref p)*8+3] as usize)*8] as usize)-128;let usize slot=a.tokens[source].slot;let usize epoch=a.owners.slots[slot].read_generation;a.owners.slots[slot].read_generation+=1;assert(!context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure)).is_ok);assert(auth[0].depth==1 && c[0].pcs[0]!=256);a.owners.slots[slot].read_generation=epoch;
    assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==failure.offset}});assert(a.owners.depth==3 && context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok);
    let usize dst=(p.array_parameters[0] as usize)-1;assert(switch(owners::read(ref a.owners,a.tokens[16+dst],0,bytes::view(ref b))){case .ok(v):{v==21}case .err(_):{false}});let usize writer=(p.call_args[(p.code[pc(ref p)*8+3] as usize)*8+2] as usize)-160;let usize root=(p.slice_roots[writer] as usize)-1;assert(switch(owners::read(ref a.owners,a.tokens[root],0,bytes::view(ref b))){case .ok(v):{v==42}case .err(_):{false}});
}
