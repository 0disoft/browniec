module tests::m2::slice_reborrow_vm;
import slice_authority as authority;
import slice_reborrow as reborrow;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import ir as ir;
import errors as errors;
import slice_builders as builders;
import slice_reborrow_ir as proof;
import slice_reborrow_vm as adapter;
import slice_exclusive_vm as ordinary;
import slice_vm as loans;
import slice_call_vm as shared;
import array_vm as arrays;
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
fn slices::Ticket call(ref mut authority::State state,ref mut slices::Pool pool,slices::Ticket source,ref owners::Table table,usize capacity){let usize frame=state.frame;let slices::Ticket[1] input=[source];let slices::Arguments a=arguments(authority::enter_call(state,pool,ref input,table,capacity,frame));assert(a.count==1);return a.tickets[0];}
fn slices::Ticket leave(ref mut authority::State state,ref mut slices::Pool pool,slices::Ticket source,ref owners::Table table,usize capacity){let usize frame=state.frame;let slices::Ticket[1] input=[source];let slices::Arguments a=arguments(authority::leave_call(state,pool,ref input,table,capacity,frame));assert(a.count==1);return a.tickets[0];}
fn void same_state(ref authority::State a,ref authority::State b){
    assert(a.depth==b.depth && a.frame==b.frame);var usize i=0;while(i<31){assert(a.kinds[i]==b.kinds[i] && a.frames[i]==b.frames[i] && a.counts[i]==b.counts[i] && a.reserves[i]==b.reserves[i]);let reborrow::Loan x=a.children[i];let reborrow::Loan y=b.children[i];same_view(x.parent.view,y.parent.view);same_view(x.selected,y.selected);assert(x.parent.generation==y.parent.generation && x.issued.slot==y.issued.slot && x.issued.generation==y.issued.generation && x.depth==y.depth && x.active==y.active);i+=1;}
    i=0;while(i<248){assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation && a.leases[i].generation==b.leases[i].generation);same_view(a.leases[i].view,b.leases[i].view);i+=1;}
}

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void fail(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn usize at(ref ir::Program p,u8 op,usize occurrence){var usize i=0;var usize n=0;while(i<p.count){if(p.code[i*8]==op){if(n==occurrence){return i;}n+=1;}i+=1;}assert(false);return 0;}
fn usize constant(ref mut ir::Program p,u8 tag,i64 n){return built(if(tag==2){ir::boolean(p,n==1,77)}else{ir::integer(p,n,tag,77)});}
fn void end_function(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;p.ends[f]=n;p.register_ends[f]=r;}
fn ir::Program program(u8 tag,i64 value,usize levels,bool empty,bool formal){
    var ir::Program p=ir::empty();p.function_count=if(formal){2}else{1};p.entry=if(formal){1}else{0};p.return_types[0]=1;p.return_types[1]=if(formal){1}else{0};var usize root=16;var usize parent=16;
    if(formal){p.arities[0]=1;parent=built(builders::parameter_exclusive(ref mut p,0,tag,77));}
    else{root=built(ir::array(ref mut p,tag,4,true,77));parent=built(ir::exclusive_slice(ref mut p,root,77));let usize fill=constant(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,root,fill,77));}
    let usize one=constant(ref mut p,12,1);let usize high=constant(ref mut p,12,4);let usize zero=constant(ref mut p,12,0);let usize two=constant(ref mut p,12,2);let usize cell=constant(ref mut p,tag,value);
    if(!formal){let usize opened=built(ir::slice_open(ref mut p,parent,one,high,77));}
    var usize[16] sites=[16;16];sites[0]=parent;var usize i=1;while(i<=levels){sites[i]=built(proof::derived(ref mut p,sites[i-1],77));let usize begin=built(proof::begin(ref mut p,sites[i],sites[i-1],if(i==1){one}else{zero},if(empty){if(i==1){one}else{zero}}else{if(i==1){two}else{one}},77));i+=1;}
    let usize length=built(ir::slice_length(ref mut p,sites[levels],77));if(tag==10){let usize utf=built(ir::slice_utf8(ref mut p,sites[levels],77));}let usize write=built(ir::slice_write(ref mut p,sites[levels],zero,cell,77));let usize read=built(ir::slice_read(ref mut p,sites[levels],zero,77));
    i=levels;while(i>0){let usize done=built(proof::end(ref mut p,sites[i],sites[i-1],77));i-=1;}
    let usize closed=built(ir::slice_close(ref mut p,parent,77));if(!formal){let usize drop=built(ir::array_drop(ref mut p,root,77));}let usize answer=built(ir::literal(ref mut p,42,77));let usize returned=built(ir::emit(ref mut p,8,answer,0,77));end_function(ref mut p,0);
    if(formal){let usize n=p.count;let usize r=p.registers;p.starts[1]=n;p.register_starts[1]=r;let usize v=built(ir::literal(ref mut p,42,77));let usize ret=built(ir::emit(ref mut p,8,v,0,77));end_function(ref mut p,1);}
    assert(verifier::inspect(ref p).is_ok);return p;
}
fn proof::Sites sites(ref ir::Program p){return switch(proof::metadata(p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn void initialize(ref ir::Program p,usize frame,ref mut arrays::State state,ref mut bytes::Buffer buffer,ref mut i64[] registers){let owners::Token token=create(ref mut state.owners,p.arrays.elements[0],4,bytes::view_mut(buffer));state.tokens[frame*16]=token;var usize i=0;while(i<p.count){if(p.code[i*8]==1){registers[p.code[i*8+1] as usize]=p.constants[p.code[i*8+2] as usize];}i+=1;}}
fn usize old_step(ref ir::Program p,u8 op,usize frame,ref mut loans::State loan,ref mut arrays::State state,ref mut bytes::Buffer buffer,ref mut i64[] r,usize fuel){return built(ordinary::step(p,0,at(p,op,0),frame,loan,state,buffer,r,fuel));}
fn usize go(ref ir::Program p,ref proof::Sites map,usize pc,usize frame,ref mut adapter::Bindings bindings,ref mut authority::State receipts,ref mut loans::State loan,ref arrays::State state,ref bytes::Buffer buffer,ref i64[] r,usize fuel){return built(adapter::step(p,map,0,pc,frame,bindings,receipts,loan,state,buffer,r,fuel));}
fn void clean(ref adapter::Bindings b,ref authority::State a,ref loans::State l,ref shared::Frames f){assert(a.depth==0 && a.frame==0);var usize i=0;while(i<31){assert(b.parents[i]==16 && b.children[i]==16 && b.functions[i]==16);i+=1;}i=0;while(i<512){assert(l.tickets[i].slot==16 && l.tickets[i].generation==0);i+=1;}i=0;while(i<256){assert(f.origins[i].slot==16 && f.origins[i].generation==0);i+=1;}}
@test
fn void six_scalar_nested_transitions_charge_exact_fuel_and_use_existing_child_reads_writes(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];let usize[6] widths=[4,1,8,1,4,8];var usize t=0;while(t<6){let ir::Program p=program(tags[t],values[t],2,false,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var adapter::Bindings links=adapter::empty();var authority::State auth=authority::empty();initialize(ref p,0,ref mut a,ref mut b,ref mut r);let usize opened=old_step(ref p,54,0,ref mut l,ref mut a,ref mut b,ref mut r,65537);let owners::Table before=a.owners;let slices::Ticket parent=l.tickets[0];var usize i=0;
        while(i<2){let usize pc=at(ref p,61,i);let usize d=p.code[pc*8+1] as usize;let usize s=p.code[pc*8+2] as usize;let slices::Ticket current=l.tickets[s];fail(adapter::step(ref p,ref map,0,pc,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65536),8);assert(auth.depth==i && links.children[i]==16 && l.tickets[s].generation==current.generation && l.tickets[d].generation==0);assert(go(ref p,ref map,pc,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537)==0);assert(l.tickets[s].generation==0 && links.children[i]==d);i+=1;}
        let usize length=old_step(ref p,57,0,ref mut l,ref mut a,ref mut b,ref mut r,4097);assert(r[p.code[at(ref p,57,0)*8+1] as usize]==1);if(tags[t]==10){let usize utf=old_step(ref p,55,0,ref mut l,ref mut a,ref mut b,ref mut r,4113);}
        let usize write=old_step(ref p,60,0,ref mut l,ref mut a,ref mut b,ref mut r,4130+2*widths[t]);let usize read=old_step(ref p,58,0,ref mut l,ref mut a,ref mut b,ref mut r,4130+widths[t]);assert(r[p.code[at(ref p,58,0)*8+1] as usize]==values[t] && !slices::length(ref l.pool,parent,ref a.owners,64).is_ok);
        i=0;while(i<2){let usize pc=at(ref p,62,i);let usize depth=auth.depth;let usize generation=l.pool.slots[parent.slot].generation;fail(adapter::step(ref p,ref map,0,pc,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65536),8);assert(auth.depth==depth && l.pool.slots[parent.slot].generation==generation);assert(go(ref p,ref map,pc,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537)==0);i+=1;}
        assert(auth.depth==0 && l.tickets[0].generation==parent.generation+4 && cell(slices::read(ref l.pool,l.tickets[0],ref a.owners,1,bytes::view(ref b)))==values[t]);same_owners(ref a.owners,ref before);let usize closed=old_step(ref p,56,0,ref mut l,ref mut a,ref mut b,ref mut r,4097);assert(!a.owners.slots[0].writing);t+=1;
    }
}
@test
fn void fifteen_nested_equal_ranges_and_empty_ranges_obey_site_and_receipt_order(){
    var usize mode=0;while(mode<2){let usize levels=if(mode==0){15}else{2};let ir::Program p=program(10,42,levels,mode==1,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var adapter::Bindings links=adapter::empty();var authority::State auth=authority::empty();initialize(ref p,0,ref mut a,ref mut b,ref mut r);let usize open=old_step(ref p,54,0,ref mut l,ref mut a,ref mut b,ref mut r,65537);var usize i=0;while(i<levels){let usize rem=go(ref p,ref map,at(ref p,61,i),0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);i+=1;}let slices::Pool saved=l.pool;let authority::State before=auth;fail(adapter::step(ref p,ref map,0,at(ref p,62,levels-1),0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),5);same_pool(ref l.pool,ref saved);same_state(ref auth,ref before);
        if(mode==1){let usize length=old_step(ref p,57,0,ref mut l,ref mut a,ref mut b,ref mut r,4097);assert(r[p.code[at(ref p,57,0)*8+1] as usize]==0);fail(ordinary::step(ref p,0,at(ref p,60,0),0,ref mut l,ref mut a,ref mut b,ref mut r,5000),14);}
        i=0;while(i<levels){let usize rem=go(ref p,ref map,at(ref p,62,i),0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);i+=1;}let usize closed=old_step(ref p,56,0,ref mut l,ref mut a,ref mut b,ref mut r,4097);mode+=1;
    }
}
@test
fn void bounds_stale_tokens_occupied_children_and_short_backing_preserve_publication(){
    let ir::Program p=program(10,42,1,false,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var adapter::Bindings links=adapter::empty();var authority::State auth=authority::empty();initialize(ref p,0,ref mut a,ref mut b,ref mut r);let usize open=old_step(ref p,54,0,ref mut l,ref mut a,ref mut b,ref mut r,65537);let usize begin=at(ref p,61,0);let usize lo=p.code[begin*8+3] as usize;let usize hi=p.code[begin*8+4] as usize;let slices::Pool saved=l.pool;let slices::Ticket parent=l.tickets[0];
    r[lo]=3;r[hi]=1;fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),14);r[lo]=-1;fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),14);r[lo]=1;r[hi]=99;fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),14);r[hi]=2;
    l.tickets[1]=parent;fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),5);l.tickets[1]=slices::Ticket{.slot=16,.generation=0};l.tickets[0].generation+=1;links.parents[30]=0;fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65536),8);links.parents[30]=16;fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),5);l.tickets[0]=parent;
    assert(bytes::resize_zeroed(ref mut b,0).is_ok);fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),5);assert(bytes::resize_zeroed(ref mut b,64).is_ok);same_pool(ref l.pool,ref saved);assert(auth.depth==0 && links.children[0]==16 && l.tickets[0].generation==parent.generation);let usize rem=go(ref p,ref map,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);let usize end=go(ref p,ref map,at(ref p,62,0),0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);let usize closed=old_step(ref p,56,0,ref mut l,ref mut a,ref mut b,ref mut r,4097);
}
@test
fn void caller_frames_canonical_receipts_and_combined_depth_are_checked_after_fuel(){
    let ir::Program p=program(10,42,2,false,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var adapter::Bindings links=adapter::empty();var authority::State auth=authority::empty();let slices::Ticket[1] none=[slices::Ticket{.slot=16,.generation=0}];let slices::Arguments call=arguments(authority::enter_call(ref mut auth,ref mut l.pool,ref none[..0],ref a.owners,64,0));initialize(ref p,1,ref mut a,ref mut b,ref mut r);let usize open=old_step(ref p,54,1,ref mut l,ref mut a,ref mut b,ref mut r,65537);let usize begin=at(ref p,61,0);fail(adapter::step(ref p,ref map,0,begin,0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),5);let usize rem=go(ref p,ref map,begin,1,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);let usize end=at(ref p,62,1);let usize lease=auth.children[1].parent.generation;auth.children[1].parent.generation+=1;fail(adapter::step(ref p,ref map,0,end,1,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),5);auth.children[1].parent.generation=lease;let usize resumed=go(ref p,ref map,end,1,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);let usize closed=old_step(ref p,56,1,ref mut l,ref mut a,ref mut b,ref mut r,4097);let slices::Arguments ret=arguments(authority::leave_call(ref mut auth,ref mut l.pool,ref none[..0],ref a.owners,64,1));
    var usize i=0;while(i<30){let slices::Arguments c=arguments(authority::enter_call(ref mut auth,ref mut l.pool,ref none[..0],ref a.owners,64,i));i+=1;}initialize(ref p,30,ref mut a,ref mut b,ref mut r);let usize opened=old_step(ref p,54,30,ref mut l,ref mut a,ref mut b,ref mut r,65537);let usize first=go(ref p,ref map,begin,30,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);let slices::Pool saved=l.pool;fail(adapter::step(ref p,ref map,0,at(ref p,61,1),30,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537),12);assert(auth.depth==31 && auth.frame==30);same_pool(ref l.pool,ref saved);var shared::Frames frames=shared::empty();assert(switch(adapter::finish(ref mut links,ref mut auth,ref mut frames,ref mut l,ref mut a,ref b,.err(errors::make(12,77)))){case .ok(_):{false}case .err(e):{e.kind==12 && e.offset==77}});clean(ref links,ref auth,ref l,ref frames);
}
@test
fn void abort_drains_before_clearing_preserves_writes_results_and_failed_cleanup_metadata(){
    let ir::Program p=program(10,42,1,false,false);let proof::Sites map=sites(ref p);var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var bytes::Buffer b=backing();var i64[128] r=[0;128];var adapter::Bindings links=adapter::empty();var authority::State auth=authority::empty();var shared::Frames frames=shared::empty();initialize(ref p,0,ref mut a,ref mut b,ref mut r);let usize open=old_step(ref p,54,0,ref mut l,ref mut a,ref mut b,ref mut r,65537);let usize rem=go(ref p,ref map,at(ref p,61,0),0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,65537);let usize write=old_step(ref p,60,0,ref mut l,ref mut a,ref mut b,ref mut r,5000);frames.origins[0]=a.tokens[0];let usize epoch=a.owners.slots[0].read_generation;a.owners.slots[0].read_generation+=1;let slices::Pool saved=l.pool;let authority::State before=auth;assert(switch(adapter::finish(ref mut links,ref mut auth,ref mut frames,ref mut l,ref mut a,ref b,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});same_pool(ref l.pool,ref saved);same_state(ref auth,ref before);assert(links.children[0]==1 && l.tickets[1].generation!=0 && frames.origins[0].generation!=0);a.owners.slots[0].read_generation=epoch;
    assert(switch(adapter::finish(ref mut links,ref mut auth,ref mut frames,ref mut l,ref mut a,ref b,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});clean(ref links,ref auth,ref l,ref frames);assert(cell(owners::read(ref a.owners,a.tokens[0],2,bytes::view(ref b)))==42 && a.owners.depth==1 && a.owners.arena.used==4);assert(switch(adapter::finish(ref mut links,ref mut auth,ref mut frames,ref mut l,ref mut a,ref b,.ok(42))){case .ok(v):{v==42}case .err(_):{false}});
}
@test
fn void rootless_formals_and_public_internal_execution_stay_gated(){
    let ir::Program p=program(10,42,1,false,false);assert(!verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,1000000,64)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var bytes::Buffer b=backing();var shared::Frames frames=shared::empty();assert(switch(execution::execute(ref p,1000000,ref mut a,ref mut b,ref mut l,ref mut frames)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(a.owners.depth==0);
    let ir::Program formal=program(10,42,1,false,true);let proof::Sites map=sites(ref formal);var adapter::Bindings links=adapter::empty();var authority::State auth=authority::empty();let i64[128] r=[0;128];fail(adapter::step(ref formal,ref map,0,at(ref formal,61,0),0,ref mut links,ref mut auth,ref mut l,ref a,ref b,ref r,0),5);assert(auth.depth==0 && links.children[0]==16);
}
