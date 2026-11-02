module tests::m2::slice_reborrow_owned_atomic;
import compiler as compiler;
import ir as ir;
import errors as errors;
import verifier as verifier;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import struct_vm as records;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_ir as proof;
import slice_reborrow_call_vm as derived;
import slice_exclusive_vm as ordinary;
import slice_formal_reborrow_vm as adapter;
import call_frame_vm as control;
import std::bytes as bytes;

struct Runtime { arrays::State arrays; records::State records; loans::State loan;
    calls::Bindings calls; children::Bindings children; authority::State auth; shared::Frames frames;
    i64[256] cells; usize[32] pcs; usize[32] dsts; }
fn usize built(Result<usize,errors::Error> result){return switch(result){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn ir::Program fixture(){return switch(compiler::compile(b"module main;fn i32 f(ref mut i32[] q,u8[1] b,bool[1] c){return 42;}fn i32 main(){var i32[1] a=[0;1];let u8[1] b=[42;1];let bool[1] c=[true;1];let ref mut i32[] p=ref mut a[0..1];let ref mut i32[] q=ref mut p[0..1];return f(ref mut q,b,c);}")){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn ir::Program array_fixture(){return switch(compiler::compile(b"module main;fn u8[1] f(ref mut i32[] q,u8[1] b,bool[1] c){return b;}fn i32 main(){var i32[1] a=[0;1];let u8[1] b=[42;1];let bool[1] c=[true;1];let ref mut i32[] p=ref mut a[0..1];let ref mut i32[] q=ref mut p[0..1];let u8[1] answer=f(ref mut q,b,c);return answer[0] as i32;}")){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn ir::Program record_fixture(){return switch(compiler::compile(b"module main;struct P{i32 x;}fn P f(ref mut i32[] q,u8[1] b,bool[1] c){q[0]=b[0] as i32;return P{.x=q[0]};}fn i32 main(){var i32[1] a=[0;1];let u8[1] b=[42;1];let bool[1] c=[true;1];let ref mut i32[] p=ref mut a[0..1];let ref mut i32[] q=ref mut p[0..1];let P answer=f(ref mut q,b,c);return answer.x;}")){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn proof::Sites sites(ref ir::Program p){return switch(verifier::verify_sites(p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(256)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};}
fn usize initialize(ref ir::Program p,ref proof::Sites map,ref mut arrays::State array_state,ref mut loans::State loan,ref mut calls::Bindings call_sites,ref mut children::Bindings links,ref mut authority::State auth,ref shared::Frames frames,ref mut i64[] cells,ref mut bytes::Buffer b){
    var usize pc=p.starts[p.entry];
    while(pc<p.ends[p.entry]){let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize other=p.code[at+3] as usize;
        if(op==9){return pc;}
        if(op==1){cells[dst]=p.constants[a];}
        else if(op==33){let usize n=built(arrays::execute(op,dst,a,other,0,ref p.arrays,array_state,b,cells,p.offsets[pc]));}
        else if(op==54){let usize n=built(ordinary::step(p,p.entry,pc,0,loan,array_state,b,cells,65537));}
        else if(op==61){let usize n=built(adapter::step(p,map,p.entry,pc,0,links,call_sites,auth,frames,loan,array_state,b,cells,65537));}
        else{assert(false);}pc+=1;
    }assert(false);return 0;
}
fn bool same_token(owners::Token a,owners::Token b){return a.slot==b.slot && a.generation==b.generation;}
fn bool same_ticket(slices::Ticket a,slices::Ticket b){return a.slot==b.slot && a.generation==b.generation;}
fn void same_view(owners::View a,owners::View b){assert(same_token(a.root,b.root) && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void unchanged(ref Runtime a,ref Runtime b,ref u8[] data,ref bytes::Buffer payload){
    assert(a.arrays.owners.depth==b.arrays.owners.depth && a.arrays.owners.arena.used==b.arrays.owners.arena.used && a.arrays.owners.arena.limit==b.arrays.owners.arena.limit && a.auth.depth==b.auth.depth && a.auth.frame==b.auth.frame);
    var usize i=0;while(i<16){let owners::Owner x=a.arrays.owners.slots[i];let owners::Owner y=b.arrays.owners.slots[i];assert(a.arrays.owners.order[i]==b.arrays.owners.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);
        let slices::Slot u=a.loan.pool.slots[i];let slices::Slot v=b.loan.pool.slots[i];assert(u.generation==v.generation && u.live==v.live && u.exclusive==v.exclusive && same_token(u.lease.root,v.lease.root) && u.lease.generation==v.lease.generation);same_view(u.view,v.view);i+=1;}
    i=0;while(i<512){assert(same_token(a.arrays.tokens[i],b.arrays.tokens[i]) && same_token(a.records.tokens[i],b.records.tokens[i]) && same_ticket(a.loan.tickets[i],b.loan.tickets[i]));i+=1;}
    i=0;while(i<31){assert(a.auth.kinds[i]==b.auth.kinds[i] && a.auth.frames[i]==b.auth.frames[i] && a.auth.counts[i]==b.auth.counts[i] && a.auth.reserves[i]==b.auth.reserves[i] && a.calls.pcs[i]==b.calls.pcs[i] && a.children.parents[i]==b.children.parents[i] && a.children.children[i]==b.children.children[i] && a.children.functions[i]==b.children.functions[i]);
        same_view(a.auth.children[i].parent.view,b.auth.children[i].parent.view);same_view(a.auth.children[i].selected,b.auth.children[i].selected);assert(a.auth.children[i].parent.generation==b.auth.children[i].parent.generation && same_ticket(a.auth.children[i].issued,b.auth.children[i].issued) && a.auth.children[i].depth==b.auth.children[i].depth && a.auth.children[i].active==b.auth.children[i].active);i+=1;}
    i=0;while(i<248){assert(same_ticket(a.calls.detached[i],b.calls.detached[i]) && same_ticket(a.auth.tickets[i],b.auth.tickets[i]) && a.auth.leases[i].generation==b.auth.leases[i].generation);same_view(a.auth.leases[i].view,b.auth.leases[i].view);i+=1;}
    i=0;while(i<256){assert(same_token(a.frames.origins[i],b.frames.origins[i]) && a.cells[i]==b.cells[i]);i+=1;}
    i=0;while(i<32){assert(a.pcs[i]==b.pcs[i] && a.dsts[i]==b.dsts[i]);i+=1;}
    let ref u8[] after=bytes::view(payload);assert(after.len==data.len);i=0;while(i<data.len){assert(data[i]==after[i]);i+=1;}
}
fn Runtime snapshot(ref arrays::State a,ref records::State r,ref loans::State l,ref calls::Bindings c,ref children::Bindings child,ref authority::State auth,ref shared::Frames f,ref i64[] cells,ref usize[] pcs,ref usize[] dsts){
    var Runtime result=Runtime{
        .arrays=arrays::State{.owners=owners::Table{.slots=a.owners.slots,.order=a.owners.order,.depth=a.owners.depth,.arena=a.owners.arena},.tokens=a.tokens},
        .records=records::State{.tokens=r.tokens},.loan=loans::State{.pool=slices::Pool{.slots=l.pool.slots},.tickets=l.tickets},
        .calls=calls::Bindings{.pcs=c.pcs,.detached=c.detached},.children=children::Bindings{.parents=child.parents,.children=child.children,.functions=child.functions},
        .auth=authority::State{.tickets=auth.tickets,.leases=auth.leases,.counts=auth.counts,.reserves=auth.reserves,.children=auth.children,.kinds=auth.kinds,.frames=auth.frames,.depth=auth.depth,.frame=auth.frame},
        .frames=shared::Frames{.origins=f.origins},.cells=[0;256],.pcs=[0;32],.dsts=[0;32]};
    var usize i=0;while(i<256){result.cells[i]=cells[i];i+=1;}i=0;while(i<32){result.pcs[i]=pcs[i];result.dsts[i]=dsts[i];i+=1;}return result;
}
fn void check_unchanged(ref Runtime before,ref arrays::State a,ref records::State r,ref loans::State l,ref calls::Bindings c,ref children::Bindings child,ref authority::State auth,ref shared::Frames f,ref i64[] cells,ref usize[] pcs,ref usize[] dsts,ref u8[] data,ref bytes::Buffer b){let Runtime after=snapshot(a,r,l,c,child,auth,f,cells,pcs,dsts);unchanged(before,ref after,data,b);}
fn ir::Program program(usize mode){
    if(mode>=9){return record_fixture();}if(mode>=7){return array_fixture();}return fixture();
}
fn void exercise(usize mode){
    let ir::Program p=program(mode);let proof::Sites map=sites(ref p);var arrays::State array_state=arrays::empty(256);var records::State record_state=records::empty();var loans::State loan=loans::empty();var calls::Bindings call_sites=calls::empty();var children::Bindings links=children::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();var i64[256] cells=[99;256];var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];var bytes::Buffer b=backing();let usize pc=initialize(ref p,ref map,ref mut array_state,ref mut loan,ref mut call_sites,ref mut links,ref mut auth,ref frames,ref mut cells[..128],ref mut b);let usize args=p.code[pc*8+3] as usize;let usize boolean=(p.call_args[args*8+2] as usize)-128;let owners::Token source=array_state.tokens[boolean];let usize price=built(calls::cost(ref p,pc,p.offsets[pc]));
    if(mode==1){let ref mut u8[] payload=bytes::view_mut(ref mut b);payload[array_state.owners.slots[source.slot].base]=2;}
    if(mode==2){let usize used=array_state.owners.arena.used;array_state.owners.arena.limit=used;}
    if(mode==3){array_state.tokens[boolean]=owners::Token{.slot=source.slot,.generation=source.generation+1};}
    if(mode==4){array_state.tokens[16]=owners::Token{.slot=1,.generation=0};}
    let usize destination=if(mode>=9){(p.code[pc*8+1] as usize)-144}else if(mode>=7){(p.code[pc*8+1] as usize)-128}else{0};
    if(mode>=7 && mode<9){array_state.tokens[destination]=if(mode==7){source}else{owners::Token{.slot=1,.generation=0}};}
    if(mode>=9){record_state.tokens[destination]=if(mode==9){let i64[1] fields=[42];switch(owners::create_record(ref p.records.layouts,p.records.records[destination] as usize,ref fields,bytes::view_mut(ref mut b),ref mut array_state.owners)){case .ok(t):{t}case .err(_):{assert(false);source}}}else if(mode==10){owners::Token{.slot=1,.generation=0}}else{owners::Token{.slot=0,.generation=1}};}
    let Runtime before=snapshot(ref array_state,ref record_state,ref loan,ref call_sites,ref links,ref auth,ref frames,ref cells,ref pcs,ref dsts);var u8[256] saved=[0;256];let ref u8[] payload=bytes::view(ref b);var usize i=0;while(i<256){saved[i]=payload[i];i+=1;}
    // The readonly-backing compatibility adapter still refuses owned arguments.
    assert(!derived::enter(ref p,ref map,pc,0,ref links,ref mut call_sites,ref mut auth,ref mut frames,ref mut loan,ref array_state,ref record_state,ref b,price).is_ok);check_unchanged(ref before,ref array_state,ref record_state,ref loan,ref call_sites,ref links,ref auth,ref frames,ref cells,ref pcs,ref dsts,ref saved,ref b);
    let Result<usize,errors::Error> result=control::step_canonical_derived(ref p,ref map,pc,0,ref links,ref mut call_sites,ref mut auth,ref mut frames,ref mut loan,ref mut record_state,ref mut array_state,ref mut b,ref mut cells[..if(mode==5){128}else{256}],ref mut pcs,ref mut dsts,if(mode==0){price-1}else{price});
    if(mode<6 || mode>=7){assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else if(mode==2){13}else{5} && e.offset==p.offsets[pc]}});check_unchanged(ref before,ref array_state,ref record_state,ref loan,ref call_sites,ref links,ref auth,ref frames,ref cells,ref pcs,ref dsts,ref saved,ref b);}
    else{
        assert(built(result)==0 && auth.depth==2 && auth.frame==1 && pcs[1]==pc+1);
        let usize u8formal=(p.array_parameters[1] as usize)-1;let usize boolformal=(p.array_parameters[2] as usize)-1;
        assert(!same_token(array_state.tokens[16+u8formal],array_state.tokens[(p.call_args[args*8+1] as usize)-128]));
        assert(switch(owners::read(ref array_state.owners,array_state.tokens[16+u8formal],0,bytes::view(ref b))){case .ok(n):{n==42}case .err(_):{false}});
        let usize drop_bool=built(arrays::execute(37,boolformal,0,0,1,ref p.arrays,ref mut array_state,ref mut b,ref mut cells,0));
        let usize drop_u8=built(arrays::execute(37,u8formal,0,0,1,ref p.arrays,ref mut array_state,ref mut b,ref mut cells,0));
        let usize formal=(p.slice_parameters[0] as usize)-1;let usize closed=built(calls::release(ref p,0,1,formal,ref mut call_sites,ref auth,ref frames,ref mut loan,ref array_state,ref b,4097,0));
        let usize restored=built(calls::leave(ref p,0,1,ref mut call_sites,ref mut auth,ref mut frames,ref mut loan,ref mut array_state,ref record_state,ref b,0));assert(auth.depth==1 && auth.frame==0);
        let usize child=(p.call_args[args*8] as usize)-160;let owners::View resumed=switch(adapter::view(ref p,ref map,p.entry,0,child,ref links,ref call_sites,ref auth,ref frames,ref loan,ref array_state,256,0)){case .ok(v):{v}case .err(_):{assert(false);before.auth.children[0].selected}};same_view(resumed,before.auth.children[0].selected);
    }
    if(mode==2){array_state.owners.arena.limit=256;}if(mode==3){array_state.tokens[boolean]=source;}if(mode==4){array_state.tokens[16]=owners::Token{.slot=0,.generation=0};}
    if(mode>=7 && mode<9){array_state.tokens[destination]=owners::Token{.slot=0,.generation=0};}
    if(mode>=9){record_state.tokens[destination]=owners::Token{.slot=0,.generation=0};}
    assert(switch(adapter::finish(ref mut links,ref mut call_sites,ref mut auth,ref mut frames,ref mut loan,ref mut array_state,ref b,.ok(42))){case .ok(v):{v==42}case .err(_):{false}});assert(auth.depth==0);
}
@test
fn void copy_and_preflight_failures_preserve_payload_receipts_maps_and_control(){var usize mode=0;while(mode<6){exercise(mode);mode+=1;}}
@test
fn void exact_full_charge_copies_before_publication_and_restores_child_on_return(){exercise(6);}

@test
fn void array_result_destinations_reject_live_and_malformed_tokens_before_publication(){exercise(7);exercise(8);}

@test
fn void record_result_destinations_reject_live_slot_only_and_generation_only_before_effects(){exercise(9);exercise(10);exercise(11);}
