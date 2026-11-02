module tests::m2::slice_formal_reborrow_vm;
import slice_formal_reborrow_vm as adapter;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as legacy;
import slice_authority as authority;
import slice_reborrow as reborrow;
import slice_reborrow_ir as proof;
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
import vm_execution as execution;
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
fn ir::Program program(u8 tag,i64 value,usize levels,bool empty,bool formal,bool recursive){
    var ir::Program p=ir::empty();p.function_count=if(formal){2}else{1};p.entry=if(formal){1}else{0};p.return_types[0]=1;p.return_types[1]=if(formal){1}else{0};var usize root=16;var usize parent=16;
    if(formal){p.arities[0]=1;parent=built(builders::parameter_exclusive(ref mut p,0,tag,77));}
    else{root=built(ir::array(ref mut p,tag,4,true,77));parent=built(ir::exclusive_slice(ref mut p,root,77));let usize fill=constant(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,root,fill,77));}
    let usize one=constant(ref mut p,12,1);let usize high=constant(ref mut p,12,4);let usize zero=constant(ref mut p,12,0);let usize two=constant(ref mut p,12,2);let usize cell=constant(ref mut p,tag,value);
    if(!formal){let usize opened=built(ir::slice_open(ref mut p,parent,one,high,77));}
    if(formal && recursive){let usize[1] args=[160+parent];let usize call=built(ir::call(ref mut p,0,ref args,77));}
    var usize[16] sites=[16;16];sites[0]=parent;var usize i=1;while(i<=levels){sites[i]=built(proof::derived(ref mut p,sites[i-1],77));let usize begin=built(proof::begin(ref mut p,sites[i],sites[i-1],if(i==1){one}else{zero},if(empty){if(i==1){one}else{zero}}else{if(i==1){two}else{one}},77));i+=1;}
    let usize length=built(ir::slice_length(ref mut p,sites[levels],77));if(tag==10){let usize utf=built(ir::slice_utf8(ref mut p,sites[levels],77));}let usize write=built(ir::slice_write(ref mut p,sites[levels],zero,cell,77));let usize read=built(ir::slice_read(ref mut p,sites[levels],zero,77));
    i=levels;while(i>0){let usize done=built(proof::end(ref mut p,sites[i],sites[i-1],77));i-=1;}
    let usize closed=built(ir::slice_close(ref mut p,parent,77));if(!formal){let usize drop=built(ir::array_drop(ref mut p,root,77));}let usize answer=built(ir::literal(ref mut p,42,77));let usize returned=built(ir::emit(ref mut p,8,answer,0,77));end_function(ref mut p,0);
    if(formal){let usize n=p.count;let usize r=p.registers;p.starts[1]=n;p.register_starts[1]=r;
        let usize id=built(ir::array_in(ref mut p,1,tag,4,true,77));let usize source=built(ir::exclusive_slice(ref mut p,id,77));let usize fill=constant(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,id,fill,77));
        let usize lo=constant(ref mut p,12,1);let usize hi=constant(ref mut p,12,4);let usize opened=built(ir::slice_open(ref mut p,source,lo,hi,77));let usize[1] args=[160+source];let usize result=built(ir::call(ref mut p,0,ref args,77));
        let usize closed=built(ir::slice_close(ref mut p,source,77));let usize drop=built(ir::array_drop(ref mut p,id,77));let usize ret=built(ir::emit(ref mut p,8,result,0,77));end_function(ref mut p,1);}
    assert(verifier::inspect(ref p).is_ok);return p;
}
fn proof::Sites sites(ref ir::Program p){return switch(proof::metadata(p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn usize caller(ref ir::Program p){return p.function_count-1;}
fn usize call_pc(ref ir::Program p,usize f){var usize i=p.starts[f];while(i<p.ends[f] && p.code[i*8]!=9){i+=1;}assert(i<p.ends[f]);return i;}
fn void initialize(ref ir::Program p,ref mut arrays::State state,ref mut loans::State loan,ref mut bytes::Buffer buffer,ref mut i64[] r){
    let owners::Token token=create(ref mut state.owners,p.arrays.elements[0],4,bytes::view_mut(buffer));state.tokens[0]=token;
    var usize i=0;while(i<p.count){if(p.code[i*8]==1){r[p.code[i*8+1] as usize]=p.constants[p.code[i*8+2] as usize];}i+=1;}
    let usize f=caller(p);var usize pc=p.starts[f];while(pc<p.ends[f] && p.code[pc*8]!=54){pc+=1;}assert(pc<p.ends[f]);let usize n=built(ordinary::step(p,f,pc,0,loan,state,buffer,r,65537));
}
fn usize enter(ref ir::Program p,ref proof::Sites map,usize frame,ref mut calls::Bindings c,ref mut authority::State auth,
    ref mut shared::Frames frames,ref mut loans::State l,ref arrays::State a,ref records::State s,ref bytes::Buffer b){
    return built(calls::enter(p,map,call_pc(p,if(frame==0){1}else{0}),frame,c,auth,frames,l,a,s,b,2000000));
}
fn usize go(ref ir::Program p,ref proof::Sites map,usize pc,usize frame,ref mut legacy::Bindings links,ref calls::Bindings c,
    ref mut authority::State auth,ref shared::Frames frames,ref mut loans::State l,ref arrays::State a,ref bytes::Buffer b,ref i64[] r,usize fuel){
    return built(adapter::step(p,map,0,pc,frame,links,c,auth,frames,l,a,b,r,fuel));
}
fn usize access(ref ir::Program p,ref proof::Sites map,u8 op,usize frame,ref legacy::Bindings links,ref calls::Bindings c,
    ref authority::State auth,ref shared::Frames frames,ref loans::State l,ref arrays::State a,ref mut bytes::Buffer b,ref mut i64[] r,usize fuel){
    return built(adapter::access(p,map,0,at(p,op,0),frame,links,c,auth,frames,l,a,b,r,fuel));
}
fn void clear(ref legacy::Bindings links,ref calls::Bindings c,ref authority::State auth,ref loans::State l,ref shared::Frames frames){
    assert(auth.depth==0 && auth.frame==0);var usize i=0;while(i<31){assert(links.parents[i]==16 && links.children[i]==16 && links.functions[i]==16 && c.pcs[i]==256);i+=1;}i=0;while(i<248){assert(c.detached[i].slot==16 && c.detached[i].generation==0);i+=1;}i=0;while(i<512){assert(l.tickets[i].slot==16 && l.tickets[i].generation==0);i+=1;}i=0;while(i<256){assert(frames.origins[i].slot==16 && frames.origins[i].generation==0);i+=1;}
}

@test
fn void six_scalar_formals_reborrow_nested_ranges_meter_access_and_restore_call(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];let usize[6] widths=[4,1,8,1,4,8];var usize t=0;while(t<6){let ir::Program p=program(tags[t],values[t],2,false,true,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var records::State s=records::empty();var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var legacy::Bindings links=legacy::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();initialize(ref p,ref mut a,ref mut l,ref mut b,ref mut r);
        let usize entered=enter(ref p,ref map,0,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref s,ref b);let slices::Ticket initial=l.tickets[16];var usize i=0;while(i<2){let usize pc=at(ref p,61,i);let slices::Pool before=l.pool;fail(adapter::step(ref p,ref map,0,pc,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65536),8);same_pool(ref l.pool,ref before);assert(go(ref p,ref map,pc,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537)==0);i+=1;}
        assert(!calls::view(ref p,0,1,0,ref c,ref auth,ref frames,ref l,ref a,64,77).is_ok);assert(access(ref p,ref map,57,1,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,4097)==0);assert(r[p.code[at(ref p,57,0)*8+1] as usize]==1);
        let usize w=4130+2*widths[t];let usize read=4130+widths[t];let usize pc=at(ref p,60,0);fail(adapter::access(ref p,ref map,0,pc,1,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,w-1),8);assert(access(ref p,ref map,60,1,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,w)==0);assert(access(ref p,ref map,58,1,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,read)==0);assert(r[p.code[at(ref p,58,0)*8+1] as usize]==values[t]);
        if(tags[t]==10){let usize utf=at(ref p,55,0);r[p.code[utf*8+1] as usize]=123;fail(adapter::access(ref p,ref map,0,utf,1,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,4112),8);assert(r[p.code[utf*8+1] as usize]==123);assert(access(ref p,ref map,55,1,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,4113)==0);assert(r[p.code[utf*8+1] as usize]==0);}
        i=0;while(i<2){let usize pc=at(ref p,62,i);fail(adapter::step(ref p,ref map,0,pc,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65536),8);assert(go(ref p,ref map,pc,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537)==0);i+=1;}assert(l.tickets[16].generation==initial.generation+4);
        let usize released=built(calls::release(ref p,0,1,0,ref mut c,ref auth,ref frames,ref mut l,ref a,ref b,4097,77));let usize returned=built(calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,ref s,ref b,77));let usize source=(p.call_args[(p.code[call_pc(ref p,1)*8+3] as usize)*8] as usize)-160;assert(cell(slices::read(ref l.pool,l.tickets[source],ref a.owners,1,bytes::view(ref b)))==values[t]);t+=1;
    }
}
@test
fn void combined_depth_31_restores_children_before_twenty_nine_recursive_call_frames(){
    let ir::Program p=program(10,42,3,false,true,true);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var records::State s=records::empty();var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var legacy::Bindings links=legacy::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();initialize(ref p,ref mut a,ref mut l,ref mut b,ref mut r);
    var usize frame=0;while(frame<29){let usize rem=enter(ref p,ref map,frame,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref s,ref b);frame+=1;}
    let usize first=go(ref p,ref map,at(ref p,61,0),29,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize second=go(ref p,ref map,at(ref p,61,1),29,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let slices::Pool saved=l.pool;fail(adapter::step(ref p,ref map,0,at(ref p,61,2),29,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),12);same_pool(ref l.pool,ref saved);assert(auth.depth==31 && auth.frame==29);
    fail(calls::leave(ref p,0,29,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,ref s,ref b,77),5);fail(calls::release(ref p,0,29,0,ref mut c,ref auth,ref frames,ref mut l,ref a,ref b,4097,77),5);
    let usize end2=go(ref p,ref map,at(ref p,62,1),29,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize end1=go(ref p,ref map,at(ref p,62,2),29,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);while(frame>0){let usize returned=built(calls::leave(ref p,0,frame,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,ref s,ref b,77));frame-=1;}assert(auth.depth==0 && auth.frame==0);
}
@test
fn void wrong_origins_sessions_ranges_maps_and_stale_children_fail_before_publication(){
    let ir::Program p=program(10,42,2,false,true,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var records::State s=records::empty();var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var legacy::Bindings links=legacy::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();initialize(ref p,ref mut a,ref mut l,ref mut b,ref mut r);
    let usize entered=enter(ref p,ref map,0,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref s,ref b);let usize begin=at(ref p,61,0);let usize lo=p.code[begin*8+3] as usize;let usize hi=p.code[begin*8+4] as usize;let slices::Pool original=l.pool;r[lo]=-1;fail(adapter::step(ref p,ref map,0,begin,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),14);same_pool(ref l.pool,ref original);r[lo]=1;
    let usize start=go(ref p,ref map,begin,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let slices::Pool saved=l.pool;let usize second=at(ref p,61,1);let owners::Token token=frames.origins[8];frames.origins[8].generation+=1;fail(adapter::step(ref p,ref map,0,second,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65536),8);fail(adapter::step(ref p,ref map,0,second,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),5);frames.origins[8]=token;
    auth.children[1].parent.view.start+=1;fail(adapter::step(ref p,ref map,0,second,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),5);auth.children[1].parent.view.start-=1;auth.children[1].parent.generation+=1;fail(adapter::step(ref p,ref map,0,second,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),5);auth.children[1].parent.generation-=1;
    links.parents[1]=2;fail(adapter::step(ref p,ref map,0,second,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),5);links.parents[1]=0;let usize slot=l.tickets[17].slot;l.tickets[17].generation+=1;fail(adapter::step(ref p,ref map,0,second,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),5);l.tickets[17].generation-=1;same_pool(ref l.pool,ref saved);
    let usize next=go(ref p,ref map,second,1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);fail(adapter::step(ref p,ref map,0,at(ref p,62,1),1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),5);let usize end=go(ref p,ref map,at(ref p,62,0),1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize end2=go(ref p,ref map,at(ref p,62,1),1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);
}
@test
fn void empty_ranges_and_existing_owned_roots_share_site_map_layout_without_extra_receipts(){
    var usize mode=0;while(mode<2){let ir::Program p=program(10,42,2,mode==0,mode==0,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var records::State s=records::empty();var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var legacy::Bindings links=legacy::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();initialize(ref p,ref mut a,ref mut l,ref mut b,ref mut r);
        let usize frame=if(mode==0){1}else{0};if(mode==0){let usize n=enter(ref p,ref map,0,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref s,ref b);}
        let usize one=go(ref p,ref map,at(ref p,61,0),frame,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize two=go(ref p,ref map,at(ref p,61,1),frame,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize n=access(ref p,ref map,57,frame,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,4097);assert(r[p.code[at(ref p,57,0)*8+1] as usize]==if(mode==0){0}else{1});
        if(mode==0){fail(adapter::access(ref p,ref map,0,at(ref p,60,0),frame,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,5000),14);}else{let usize write=access(ref p,ref map,60,frame,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,5000);let usize read=access(ref p,ref map,58,frame,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,5000);assert(r[p.code[at(ref p,58,0)*8+1] as usize]==42);}
        let usize end=go(ref p,ref map,at(ref p,62,0),frame,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize end2=go(ref p,ref map,at(ref p,62,1),frame,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);mode+=1;
    }
}
@test
fn void abort_preserves_writes_outcome_and_all_maps_when_cleanup_fails(){
    let ir::Program p=program(10,42,1,false,true,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var records::State s=records::empty();var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var legacy::Bindings links=legacy::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();initialize(ref p,ref mut a,ref mut l,ref mut b,ref mut r);
    let usize entered=enter(ref p,ref map,0,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref s,ref b);let usize start=go(ref p,ref map,at(ref p,61,0),1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize write=access(ref p,ref map,60,1,ref links,ref c,ref auth,ref frames,ref l,ref a,ref mut b,ref mut r,5000);let usize epoch=a.owners.slots[0].read_generation;a.owners.slots[0].read_generation+=1;let slices::Pool saved=l.pool;
    assert(switch(adapter::finish(ref mut links,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,ref b,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});same_pool(ref l.pool,ref saved);assert(auth.depth==2 && c.pcs[0]!=256 && links.children[1]==1 && l.tickets[17].generation!=0 && frames.origins[8].generation!=0);a.owners.slots[0].read_generation=epoch;
    assert(switch(adapter::finish(ref mut links,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,ref b,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});clear(ref links,ref c,ref auth,ref l,ref frames);assert(cell(owners::read(ref a.owners,a.tokens[0],2,bytes::view(ref b)))==42);assert(switch(adapter::finish(ref mut links,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,ref b,.ok(42))){case .ok(v):{v==42}case .err(_):{false}});
}
@test
fn void public_recursion_and_legacy_wrong_frames_keep_distinct_boundaries(){
    let ir::Program p=program(10,42,1,false,true,true);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var records::State s=records::empty();var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var legacy::Bindings links=legacy::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();initialize(ref p,ref mut a,ref mut l,ref mut b,ref mut r);
    assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,16000000,64)){case .ok(_):{false}case .err(e):{e.kind==12}});let usize entered=enter(ref p,ref map,0,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref s,ref b);
    fail(adapter::step(ref p,ref map,0,at(ref p,61,0),0,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537),5);let usize start=go(ref p,ref map,at(ref p,61,0),1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);fail(calls::enter(ref p,ref map,call_pc(ref p,0),1,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref s,ref b,2000000),5);
    assert(!adapter::view(ref p,ref map,0,1,0,ref links,ref c,ref auth,ref frames,ref l,ref a,64,77).is_ok);fail(legacy::step(ref p,ref map,0,at(ref p,62,0),1,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),5);let usize end=go(ref p,ref map,at(ref p,62,0),1,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,ref b,ref r,65537);let usize returned=built(calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,ref s,ref b,77));
}
