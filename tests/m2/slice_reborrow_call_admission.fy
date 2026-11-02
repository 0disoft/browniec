module tests::m2::slice_reborrow_call_admission;
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
fn void fail(Result<admission::Prepared,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
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
fn ir::Program program(u8 tag,bool formal,usize levels,usize argc,bool mixed){
    var ir::Program p=ir::empty();p.function_count=3;p.entry=2;p.arities[0]=argc;p.return_types[0]=1;p.return_types[1]=1;p.return_types[2]=1;
    var usize[2] callee=[16;2];var usize row=0;
    while(row<argc){callee[row]=built(if(mixed && row==1){builders::parameter_typed(ref mut p,0,tag,77)}else{builders::parameter_exclusive(ref mut p,0,tag,77)});row+=1;}
    row=0;while(row<argc){let usize close=built(ir::slice_close(ref mut p,callee[row],77));row+=1;}
    let usize answer=built(ir::literal(ref mut p,42,77));let usize done=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,0);
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
    let usize[2] args=[160+sites[levels],160+sites[if(mixed){16}else{16+levels}]];
    let usize result=built(ir::call(ref mut p,0,ref args[..argc],77));
    row=width;while(row>0){row-=1;var usize level=if(mixed && row==1){0}else{levels};while(level>0){let usize end=built(forest::end(ref mut p,sites[row*16+level],sites[row*16+level-1],77));level-=1;}}
    row=width;while(row>0){row-=1;let usize length=built(ir::slice_length(ref mut p,sites[row*16],77));let usize close=built(ir::slice_close(ref mut p,sites[row*16],77));if(!formal){let usize drop=built(ir::array_drop(ref mut p,roots[row],77));}}
    let usize returned=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);
    let usize entry=p.count;let usize end_regs=p.registers;p.starts[2]=entry;p.register_starts[2]=end_regs;
    if(formal){
        var usize[2] actual=[0;2];row=0;let usize zero=built(ir::integer(ref mut p,0,12,77));let usize high=built(ir::integer(ref mut p,1,12,77));let usize fill=built(if(tag==2){ir::boolean(ref mut p,false,77)}else{ir::integer(ref mut p,0,tag,77)});
        while(row<width){let usize root=built(ir::array_in(ref mut p,2,tag,2,!(mixed && row==1),77));let usize site=built(if(mixed && row==1){ir::slice(ref mut p,root,77)}else{ir::exclusive_slice(ref mut p,root,77)});let usize init=built(ir::array_init(ref mut p,root,fill,77));let usize opened=built(ir::slice_open(ref mut p,site,zero,high,77));actual[row]=160+site;row+=1;}
        let usize called=built(ir::call(ref mut p,1,ref actual[..width],77));row=width;while(row>0){row-=1;let usize closed=built(ir::slice_close(ref mut p,actual[row]-160,77));let usize dropped=built(ir::array_drop(ref mut p,row,77));}
    }
    let usize entry_answer=built(ir::literal(ref mut p,42,77));let usize entry_return=built(ir::emit(ref mut p,8,entry_answer,0,77));finish(ref mut p,2);assert(verifier::inspect_reborrow_calls(ref p).is_ok);return p;
}

struct Runtime { arrays::State arrays; records::State records; loans::State loan;
    calls::Bindings calls; children::Bindings children; authority::State auth; shared::Frames frames; }
fn Runtime empty(){return Runtime{.arrays=arrays::empty(256),.records=records::empty(),.loan=loans::empty(),.calls=calls::empty(),.children=children::empty(),.auth=authority::empty(),.frames=shared::empty()};}
fn void unchanged(ref Runtime before,ref Runtime after,ref u8[] payload,ref bytes::Buffer b){
    same_pool(ref before.loan.pool,ref after.loan.pool);same_owners(ref before.arrays.owners,ref after.arrays.owners);same_state(ref before.auth,ref after.auth);
    var usize i=0;while(i<512){assert(before.arrays.tokens[i].slot==after.arrays.tokens[i].slot && before.arrays.tokens[i].generation==after.arrays.tokens[i].generation && before.records.tokens[i].slot==after.records.tokens[i].slot && before.records.tokens[i].generation==after.records.tokens[i].generation && before.loan.tickets[i].slot==after.loan.tickets[i].slot && before.loan.tickets[i].generation==after.loan.tickets[i].generation);i+=1;}
    i=0;while(i<31){assert(before.children.parents[i]==after.children.parents[i] && before.children.children[i]==after.children.children[i] && before.children.functions[i]==after.children.functions[i] && before.calls.pcs[i]==after.calls.pcs[i]);i+=1;}
    i=0;while(i<248){assert(before.calls.detached[i].slot==after.calls.detached[i].slot && before.calls.detached[i].generation==after.calls.detached[i].generation);i+=1;}
    i=0;while(i<256){assert(before.frames.origins[i].slot==after.frames.origins[i].slot && before.frames.origins[i].generation==after.frames.origins[i].generation);i+=1;}
    let ref u8[] actual=bytes::view(b);assert(actual.len==payload.len);i=0;while(i<payload.len){assert(actual[i]==payload[i]);i+=1;}
}
fn void snapshot(ref bytes::Buffer b,ref mut u8[] saved){let ref u8[] data=bytes::view(b);var usize i=0;while(i<saved.len){saved[i]=data[i];i+=1;}}
fn void initialize(ref ir::Program p,ref forest::Sites map,bool formal,usize frame,ref mut Runtime r,ref mut bytes::Buffer b){
    var arrays::State a=r.arrays;var records::State record_state=r.records;var loans::State l=r.loan;var calls::Bindings c=r.calls;var children::Bindings links=r.children;var authority::State auth=r.auth;var shared::Frames frames=r.frames;

    var i64[128] cells=[0;128];var usize pc=0;while(pc<p.count){if(p.code[pc*8]==1){cells[p.code[pc*8+1] as usize]=p.constants[p.code[pc*8+2] as usize];}pc+=1;}
    let usize owner=if(formal){2}else{1};let usize original=if(formal){0}else{frame};var usize root=0;
    while(root<p.arrays.count){if(p.array_functions[root] as usize==owner){
        let layouts::Array shape=switch(layouts::scalar(p.arrays.elements[root],p.arrays.lengths[root])){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
        let owners::Token token=switch(owners::create(ref shape,0,bytes::view_mut(b),ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};a.tokens[original*16+root]=token;
    }root+=1;}
    if(!formal){let slices::Ticket[1] no_args=[slices::Ticket{.slot=16,.generation=0};1];var usize f=0;while(f<frame){let slices::Arguments entered=arguments(authority::enter_call(ref mut auth,ref mut l.pool,ref no_args[..0],ref a.owners,256,f));f+=1;}}
    pc=p.starts[owner];while(pc<p.ends[owner]){if(p.code[pc*8]==54){let usize opened=built(if(ir::exclusive(p,p.code[pc*8+1] as usize)){ordinary::step(p,owner,pc,original,ref mut l,ref mut a,b,ref mut cells,65537)}else{loans::step(p,pc,original,ref mut l,ref mut a,b,ref mut cells,65537)});}pc+=1;}
    if(formal){let usize entered=built(calls::enter(p,map,at(p,9,2),0,ref mut c,ref mut auth,ref mut frames,ref mut l,ref a,ref record_state,b,2000000));assert(frame==1);}
    pc=p.starts[1];while(pc<p.ends[1]){if(p.code[pc*8]==61){let usize opened=built(adapter::step(p,map,1,pc,frame,ref mut links,ref c,ref mut auth,ref frames,ref mut l,ref a,b,ref cells,65537));}pc+=1;}
    r.arrays=a;r.records=record_state;r.loan=l;r.calls=c;r.children=links;r.auth=auth;r.frames=frames;
}
fn Result<admission::Prepared,errors::Error> prepare(ref ir::Program p,ref forest::Sites map,usize frame,ref Runtime r,ref bytes::Buffer b,usize fuel){return admission::prepare(p,map,at(p,9,1),frame,ref r.children,ref r.calls,ref r.auth,ref r.frames,ref r.loan,ref r.arrays,ref r.records,b,fuel);}
fn void dispose(ref mut Runtime r,ref bytes::Buffer b){
    var arrays::State a=r.arrays;var loans::State l=r.loan;var calls::Bindings c=r.calls;var children::Bindings links=r.children;var authority::State auth=r.auth;var shared::Frames frames=r.frames;
    assert(switch(adapter::finish(ref mut links,ref mut c,ref mut auth,ref mut frames,ref mut l,ref mut a,b,.ok(42))){case .ok(n):{n==42}case .err(_):{false}});assert(auth.depth==0 && auth.frame==0);
    r.arrays=a;r.loan=l;r.calls=c;r.children=links;r.auth=auth;r.frames=frames;
}
fn Result<usize,errors::Error> legacy_enter(ref ir::Program p,ref forest::Sites map,ref mut Runtime r,ref bytes::Buffer b){
    var loans::State l=r.loan;var calls::Bindings c=r.calls;var authority::State auth=r.auth;var shared::Frames frames=r.frames;
    let Result<usize,errors::Error> result=calls::enter(p,map,at(p,9,1),0,ref mut c,ref mut auth,ref mut frames,ref mut l,ref r.arrays,ref r.records,b,2000000);
    r.loan=l;r.calls=c;r.auth=auth;r.frames=frames;return result;
}
@test
fn void six_scalar_owned_and_formal_child_tickets_prepare_without_any_publication(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){var usize variant=0;while(variant<2){
        let bool formal=variant==1;let usize frame=variant;let ir::Program p=program(tags[i],formal,2,1,false);let forest::Sites map=sites(ref p);var Runtime r=empty();var bytes::Buffer b=backing();initialize(ref p,ref map,formal,frame,ref mut r,ref mut b);
        let usize call=at(ref p,9,1);let usize source=(p.call_args[0] as usize)-160;let slices::Ticket current=r.loan.tickets[frame*16+source];let usize charge=built(calls::cost(ref p,call,77));let Runtime before=r;var u8[256] data=[0;256];snapshot(ref b,ref mut data);
        assert(switch(prepare(ref p,ref map,frame,ref r,ref b,charge)){case .ok(plan):{assert(plan.remaining==0 && plan.pc==call && plan.frame==frame && plan.depth==r.auth.depth && plan.receipt.kind==1 && plan.receipt.call.count==1 && plan.receipt.call.frame==r.auth.depth && plan.retained.count==0);let slices::Ticket next=plan.receipt.call.tickets[0];assert(next.slot==current.slot && next.generation==current.generation+1);assert(!slices::length(ref plan.pool,current,ref r.arrays.owners,256).is_ok);assert(size(slices::length(ref plan.pool,next,ref r.arrays.owners,256))==1);assert(plan.roots[0].slot==r.arrays.tokens[0].slot && plan.roots[0].generation==r.arrays.tokens[0].generation);true}case .err(_):{false}});
        unchanged(ref before,ref r,ref data,ref b);assert(size(slices::length(ref r.loan.pool,current,ref r.arrays.owners,256))==1);dispose(ref mut r,ref b);variant+=1;}i+=1;}
}
@test
fn void mixed_shared_retention_and_multiple_writers_are_staged_from_original_inputs(){
    var usize variant=0;while(variant<2){let bool mixed=variant==0;let ir::Program p=program(10,false,1,2,mixed);let forest::Sites map=sites(ref p);var Runtime r=empty();var bytes::Buffer b=backing();initialize(ref p,ref map,false,0,ref mut r,ref mut b);let Runtime before=r;var u8[256] data=[0;256];snapshot(ref b,ref mut data);
        assert(switch(prepare(ref p,ref map,0,ref r,ref b,2000000)){case .ok(plan):{assert(plan.receipt.call.count==if(mixed){1}else{2});assert(plan.retained.count==if(mixed){1}else{0});if(mixed){let usize source=(p.call_args[1] as usize)-160;let slices::Ticket original=r.loan.tickets[source];let slices::Ticket retained=plan.retained.tickets[0];assert(retained.slot!=original.slot && size(slices::length(ref plan.pool,original,ref r.arrays.owners,256))==1 && size(slices::length(ref plan.pool,retained,ref r.arrays.owners,256))==1);}true}case .err(_):{false}});
        unchanged(ref before,ref r,ref data,ref b);
        if(mixed){let usize site=(p.call_args[0] as usize)-160;let slices::Ticket current=r.loan.tickets[site];let usize almost=18446744073709551614;r.loan.pool.slots[current.slot].generation=almost;r.loan.tickets[site]=slices::Ticket{.slot=current.slot,.generation=almost};let Runtime exhausted=r;fail(prepare(ref p,ref map,0,ref r,ref b,2000000),5);unchanged(ref exhausted,ref r,ref data,ref b);r.loan.pool.slots[current.slot].generation=current.generation;r.loan.tickets[site]=current;}
        dispose(ref mut r,ref b);variant+=1;}
}
@test
fn void short_fuel_precedes_runtime_authentication_and_late_failure_publishes_nothing(){
    let ir::Program p=program(10,false,2,2,false);let forest::Sites map=sites(ref p);var Runtime r=empty();var bytes::Buffer b=backing();initialize(ref p,ref map,false,0,ref mut r,ref mut b);let usize charge=built(calls::cost(ref p,at(ref p,9,1),77));let usize source=(p.call_args[1] as usize)-160;let slices::Ticket original=r.loan.tickets[source];r.loan.tickets[source]=slices::Ticket{.slot=16,.generation=0};let Runtime before=r;var u8[256] data=[0;256];snapshot(ref b,ref mut data);
    fail(prepare(ref p,ref map,0,ref r,ref b,charge-1),8);unchanged(ref before,ref r,ref data,ref b);fail(prepare(ref p,ref map,0,ref r,ref b,charge),5);unchanged(ref before,ref r,ref data,ref b);r.loan.tickets[source]=original;dispose(ref mut r,ref b);
}
@test
fn void forged_child_receipts_wrong_frames_and_dirty_destinations_are_rejected_atomically(){
    let ir::Program p=program(10,true,2,1,false);let forest::Sites map=sites(ref p);var Runtime r=empty();var bytes::Buffer b=backing();initialize(ref p,ref map,true,1,ref mut r,ref mut b);var u8[256] data=[0;256];snapshot(ref b,ref mut data);
    let Runtime original=r;fail(prepare(ref p,ref map,0,ref r,ref b,2000000),5);unchanged(ref original,ref r,ref data,ref b);
    r.auth.children[2].selected.end=0;let Runtime forged=r;fail(prepare(ref p,ref map,1,ref r,ref b,2000000),5);unchanged(ref forged,ref r,ref data,ref b);let usize ending=original.auth.children[2].selected.end;r.auth.children[2].selected.end=ending;
    r.arrays.tokens[32]=owners::Token{.slot=1,.generation=0};let Runtime dirty=r;fail(prepare(ref p,ref map,1,ref r,ref b,2000000),5);unchanged(ref dirty,ref r,ref data,ref b);r.arrays.tokens[32]=owners::Token{.slot=0,.generation=0};dispose(ref mut r,ref b);
}
@test
fn void combined_depth_and_generation_reserves_include_every_pending_lexical_restore(){
    let ir::Program p=program(10,false,1,1,false);let forest::Sites map=sites(ref p);var usize frame=29;while(frame<=30){var Runtime r=empty();var bytes::Buffer b=backing();initialize(ref p,ref map,false,frame,ref mut r,ref mut b);let usize depth=r.auth.depth;let Runtime before=r;var u8[256] data=[0;256];snapshot(ref b,ref mut data);
        if(frame==30){assert(depth==31);fail(prepare(ref p,ref map,frame,ref r,ref b,2000000),12);}
        else{assert(depth==30);let usize site=(p.call_args[0] as usize)-160;let slices::Ticket original=r.loan.tickets[frame*16+site];let usize maximum=18446744073709551615-(depth+2);r.loan.pool.slots[original.slot].generation=maximum;r.loan.tickets[frame*16+site]=slices::Ticket{.slot=original.slot,.generation=maximum};
            assert(switch(prepare(ref p,ref map,frame,ref r,ref b,2000000)){case .ok(plan):{plan.receipt.call.frame==30 && plan.receipt.call.tickets[0].generation==maximum+1}case .err(_):{false}});
            r.loan.pool.slots[original.slot].generation=maximum+1;r.loan.tickets[frame*16+site]=slices::Ticket{.slot=original.slot,.generation=maximum+1};let Runtime exhausted=r;fail(prepare(ref p,ref map,frame,ref r,ref b,2000000),5);unchanged(ref exhausted,ref r,ref data,ref b);r.loan.pool.slots[original.slot].generation=original.generation;r.loan.tickets[frame*16+site]=original;
        }
        unchanged(ref before,ref r,ref data,ref b);dispose(ref mut r,ref b);frame+=1;}
}
@test
fn void preparation_keeps_legacy_and_public_execution_gates(){
    let ir::Program p=program(10,false,2,1,false);let forest::Sites map=sites(ref p);var Runtime r=empty();var bytes::Buffer b=backing();initialize(ref p,ref map,false,0,ref mut r,ref mut b);let Runtime before=r;var u8[256] data=[0;256];snapshot(ref b,ref mut data);
    assert(prepare(ref p,ref map,0,ref r,ref b,2000000).is_ok);assert(!verifier::inspect(ref p).is_ok && !verifier::verify(ref p).is_ok && runner::inspect(ref p).is_ok);assert(!vm::run_with_array_limit(ref p,0,0).is_ok);
    assert(!legacy_enter(ref p,ref map,ref mut r,ref b).is_ok);unchanged(ref before,ref r,ref data,ref b);dispose(ref mut r,ref b);
}
