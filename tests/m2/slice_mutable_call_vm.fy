module tests::m2::slice_mutable_call_vm;
import slice_mutable_call_vm as calls;
import slice_call_vm as shared;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import struct_vm as records;
import struct_call_vm as owned;
import slice_builders as builders;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize count(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn usize pc(ref ir::Program p,usize f){var usize i=p.starts[f];while(i<p.ends[f] && p.code[i*8]!=9){i+=1;}assert(i<p.ends[f]);return i;}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn void inspected(ref ir::Program p){assert(verifier::inspect(p).is_ok && verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,0,0)){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn ir::Program program(u8 tag,bool recursive){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize formal=built(builders::parameter_exclusive(ref mut p,0,tag,77));let usize[1] forwarded=[160+formal];let usize value=built(if(recursive){ir::call(ref mut p,0,ref forwarded,77)}else{ir::literal(ref mut p,42,77)});let usize close=built(ir::slice_close(ref mut p,formal,77));let usize ret=built(ir::emit(ref mut p,8,value,0,77));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;let usize root=built(ir::array_in(ref mut p,1,tag,3,true,77));let usize site=built(ir::exclusive_slice(ref mut p,root,77));let usize fill=built(if(tag==2){ir::boolean(ref mut p,false,77)}else{ir::integer(ref mut p,0,tag,77)});let usize init=built(ir::array_init(ref mut p,root,fill,77));let usize lo=built(ir::integer(ref mut p,0,12,77));let usize hi=built(ir::integer(ref mut p,3,12,77));let usize open=built(ir::slice_open(ref mut p,site,lo,hi,77));let usize[1] args=[160+site];let usize result=built(ir::call(ref mut p,0,ref args,77));let usize closed=built(ir::slice_close(ref mut p,site,77));let usize drop=built(ir::array_drop(ref mut p,root,77));let usize done=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);inspected(ref p);return p;
}
fn owners::Token create(ref mut arrays::State state,u8 tag,usize length,i64 fill,ref mut bytes::Buffer buffer){
    let layouts::Array shape=switch(layouts::scalar(tag,length)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};return token(owners::create(ref shape,fill,bytes::view_mut(buffer),ref mut state.owners));
}
fn void initialize(ref ir::Program p,ref mut loans::State l,ref mut arrays::State a,ref mut bytes::Buffer b,bool empty){
    let owners::Token root=create(a,p.arrays.elements[0],3,0,b);a.tokens[0]=root;let slices::Ticket opened=ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,root,if(empty){3}else{1},if(empty){3}else{2},256));l.tickets[1]=opened;
}
fn ir::Program mixed(){
    var ir::Program p=switch(compiler::compile(b"module main;struct P{bool good;i32 x;}fn i32 f(ref u8[] w,bool[2] a,P r,ref u8[] s,ref u8[] q){return 42;}fn i32 main(){var u8[3] w=[65;3];let bool[2] a=[true;2];let P r=P{.good=true,.x=20};let u8[2] s=[65;2];let ref u8[] p=ref w;let ref u8[] q=ref s;return f(ref p,a,r,ref q,ref q);}")){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    let usize call=pc(ref p,p.entry);let usize base=(p.code[call*8+3] as usize)*8;let usize site=(p.call_args[base] as usize)-160;let usize formal=(p.slice_parameters[p.register_starts[0]] as usize)-1;let u8 element=p.slice_elements[formal];p.slice_elements[formal]=element|128;p.slice_elements[site]=128;p.offsets[call]=77;inspected(ref p);return p;
}
fn void initialize_mixed(ref ir::Program p,ref mut loans::State l,ref mut arrays::State a,ref mut records::State r,ref mut bytes::Buffer b){
    var usize i=0;while(i<p.arrays.count){if(p.array_functions[i] as usize==p.entry){let owners::Token created=create(a,p.arrays.elements[i],p.arrays.lengths[i],if(p.arrays.elements[i]==2){1}else{65},b);a.tokens[i]=created;}i+=1;}
    i=0;while(i<p.records.count){if(p.record_functions[i] as usize==p.entry){let i64[2] values=[1,20];r.tokens[i]=token(owners::create_record(ref p.records.layouts,p.records.records[i] as usize,ref values,bytes::view_mut(b),ref mut a.owners));}i+=1;}
    let usize call=pc(p,p.entry);let usize base=(p.code[call*8+3] as usize)*8;i=0;while(i<5){if(p.slice_parameters[p.register_starts[0]+i]!=0){let usize site=(p.call_args[base+i] as usize)-160;let usize root=(p.slice_roots[site] as usize)-1;let owners::Token owner=a.tokens[root];if(l.tickets[site].generation==0){let slices::Ticket opened=ticket(if(ir::exclusive(p,site)){slices::open_exclusive(ref mut l.pool,ref mut a.owners,owner,1,2,256)}else{slices::open(ref mut l.pool,ref mut a.owners,owner,0,p.arrays.lengths[root],256)});l.tickets[site]=opened;}}i+=1;}
}
fn void same_view(owners::View x,owners::View y){assert(x.root.slot==y.root.slot && x.root.generation==y.root.generation && x.element==y.element && x.length==y.length && x.start==y.start && x.end==y.end);}
fn void same_receipt(ref calls::Frame x,ref calls::Frame y){assert(x.parent==y.parent && x.caller==y.caller && x.target==y.target && x.active==y.active && x.batch.count==y.batch.count && x.batch.frame==y.batch.frame);var usize i=0;while(i<8){assert(x.sources[i]==y.sources[i] && x.sites[i]==y.sites[i] && x.positions[i]==y.positions[i] && x.detached[i].slot==y.detached[i].slot && x.detached[i].generation==y.detached[i].generation && x.batch.tickets[i].slot==y.batch.tickets[i].slot && x.batch.tickets[i].generation==y.batch.tickets[i].generation && x.batch.leases[i].generation==y.batch.leases[i].generation);same_view(x.batch.leases[i].view,y.batch.leases[i].view);i+=1;}}
fn void same(ref shared::Frames f,ref shared::Frames oldf,ref loans::State l,ref loans::State oldl,ref arrays::State a,ref arrays::State olda,ref records::State r,ref records::State oldr){
    var usize i=0;while(i<256){assert(f.origins[i].slot==oldf.origins[i].slot && f.origins[i].generation==oldf.origins[i].generation);i+=1;}i=0;while(i<512){assert(l.tickets[i].slot==oldl.tickets[i].slot && l.tickets[i].generation==oldl.tickets[i].generation && a.tokens[i].slot==olda.tokens[i].slot && a.tokens[i].generation==olda.tokens[i].generation && r.tokens[i].slot==oldr.tokens[i].slot && r.tokens[i].generation==oldr.tokens[i].generation);i+=1;}
    assert(a.owners.depth==olda.owners.depth && a.owners.arena.used==olda.owners.arena.used && a.owners.arena.limit==olda.owners.arena.limit);i=0;while(i<16){let slices::Slot x=l.pool.slots[i];let slices::Slot y=oldl.pool.slots[i];assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);same_view(x.view,y.view);let owners::Owner u=a.owners.slots[i];let owners::Owner v=olda.owners.slots[i];assert(u.generation==v.generation && u.occupied==v.occupied && u.live==v.live && u.reading==v.reading && u.writing==v.writing && u.read_generation==v.read_generation && u.mark==v.mark && u.base==v.base && u.end==v.end && u.element==v.element && u.length==v.length && u.record==v.record && u.alignment==v.alignment && a.owners.order[i]==olda.owners.order[i]);i+=1;}
}
fn void rejected(ref ir::Program p,usize call,usize parent,ref mut calls::Frame receipt,ref mut shared::Frames f,ref mut loans::State l,ref mut arrays::State a,ref mut records::State r,ref mut bytes::Buffer b,usize fuel,u8 kind,bool leaving){
    let calls::Frame old= calls::Frame{.batch=receipt.batch,.detached=receipt.detached,.sources=receipt.sources,.sites=receipt.sites,.positions=receipt.positions,.parent=receipt.parent,.caller=receipt.caller,.target=receipt.target,.active=receipt.active};let shared::Frames oldf=shared::Frames{.origins=f.origins};let loans::State oldl=loans::State{.pool=slices::Pool{.slots=l.pool.slots},.tickets=l.tickets};let arrays::State olda=arrays::State{.owners=owners::Table{.slots=a.owners.slots,.order=a.owners.order,.depth=a.owners.depth,.arena=a.owners.arena},.tokens=a.tokens};let records::State oldr=records::State{.tokens=r.tokens};var u8[256] olddata=[0;256];{let ref u8[] data=bytes::view(b);var usize i=0;while(i<data.len){olddata[i]=data[i];i+=1;}}
    assert(switch(if(leaving){calls::leave(p,0,1,receipt,f,l,a,b,77)}else{calls::enter(p,call,parent,receipt,f,l,r,a,b,fuel)}){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});same_receipt(receipt,ref old);same(f,ref oldf,l,ref oldl,a,ref olda,r,ref oldr);let ref u8[] data=bytes::view(b);var usize i=0;while(i<data.len){assert(data[i]==olddata[i]);i+=1;}
}

@test
fn void six_scalar_writes_exact_fuel_empty_ranges_formal_release_and_fresh_restore(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];var usize i=0;
    while(i<6){let ir::Program p=program(tags[i],false);let usize charge=built(calls::cost(ref p,0,77));assert(charge==196613);var usize empty=0;
        while(empty<2){var calls::Frame receipt=calls::empty();var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State r=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut l,ref mut a,ref mut b,empty==1);let slices::Ticket parent=l.tickets[1];let usize used=a.owners.arena.used;let usize depth=a.owners.depth;
            rejected(ref p,pc(ref p,1),0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge-1,8,false);
            assert(built(calls::enter(ref p,pc(ref p,1),0,ref mut receipt,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge+7))==7);let slices::Ticket child=l.tickets[16];assert(l.tickets[1].generation==0 && child.slot==parent.slot && child.generation==parent.generation+1 && a.owners.arena.used==used && a.owners.depth==depth);
            if(empty==0){assert(count(slices::write(ref l.pool,child,ref a.owners,0,values[i],bytes::view_mut(ref mut b)))>0 && cell(slices::read(ref l.pool,child,ref a.owners,0,bytes::view(ref b)))==values[i]);}else{assert(count(slices::length(ref l.pool,child,ref a.owners,256))==0 && !slices::write(ref l.pool,child,ref a.owners,0,values[i],bytes::view_mut(ref mut b)).is_ok);}
            assert(!owners::read(ref a.owners,a.tokens[0],0,bytes::view(ref b)).is_ok && !slices::read(ref l.pool,parent,ref a.owners,0,bytes::view(ref b)).is_ok);
            assert(switch(calls::release(ref p,0,1,0,ref mut receipt,ref f,ref mut l,ref a,ref b,4096,77)){case .ok(_):{false}case .err(e):{e.kind==8}});assert(l.tickets[16].generation==child.generation && receipt.detached[0].generation==0);
            assert(built(calls::release(ref p,0,1,0,ref mut receipt,ref f,ref mut l,ref a,ref b,4097,77))==0 && l.tickets[16].generation==0 && a.owners.slots[a.tokens[0].slot].writing);
            assert(!calls::release(ref p,0,1,0,ref mut receipt,ref f,ref mut l,ref a,ref b,4097,77).is_ok);assert(built(calls::leave(ref p,0,1,ref mut receipt,ref mut f,ref mut l,ref mut a,ref b,77))==1 && !receipt.active);
            let slices::Ticket resumed=l.tickets[1];assert(resumed.generation==parent.generation+2 && !slices::length(ref l.pool,child,ref a.owners,256).is_ok && a.owners.slots[a.tokens[0].slot].writing);assert(count(slices::close(ref mut l.pool,resumed,ref mut a.owners,256))==0);assert(cell(owners::read(ref a.owners,a.tokens[0],1,bytes::view(ref b)))==if(empty==0){values[i]}else{0});empty+=1;
        }i+=1;
    }
}

@test
fn void thirty_one_nested_frames_restore_latest_tickets_and_reuse_receipts_without_extra_slots(){
    let ir::Program p=program(10,true);let usize charge=built(calls::cost(ref p,0,77));var calls::Frame[31] receipts=[calls::empty();31];var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State r=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut l,ref mut a,ref mut b,false);let slices::Ticket original=l.tickets[1];var usize d=0;
    while(d<31){assert(built(calls::enter(ref p,pc(ref p,if(d==0){1}else{0}),d,ref mut receipts[d],ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge))==0);d+=1;}
    var calls::Frame extra=calls::empty();assert(switch(calls::enter(ref p,pc(ref p,0),31,ref mut extra,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge)){case .ok(_):{false}case .err(e):{e.kind==12}});let slices::Ticket deepest=l.tickets[31*16];assert(count(slices::write(ref l.pool,deepest,ref a.owners,0,42,bytes::view_mut(ref mut b)))==1);
    while(d>0){assert(built(calls::leave(ref p,0,d,ref mut receipts[d-1],ref mut f,ref mut l,ref mut a,ref b,77))==1);d-=1;}
    assert(l.tickets[1].generation==original.generation+62 && a.owners.depth==1 && cell(slices::read(ref l.pool,l.tickets[1],ref a.owners,0,bytes::view(ref b)))==42);
    assert(built(calls::enter(ref p,pc(ref p,1),0,ref mut receipts[0],ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge))==0);assert(built(calls::leave(ref p,0,1,ref mut receipts[0],ref mut f,ref mut l,ref mut a,ref b,77))==1);assert(count(slices::clear(ref mut l.pool,ref mut a.owners,256))==1);
}

@test
fn void mixed_owned_and_shared_copies_publish_with_writers_only_after_every_late_check(){
    let ir::Program p=mixed();let usize call=pc(ref p,1);let usize base=(p.code[call*8+3] as usize)*8;let usize charge=built(calls::cost(ref p,0,77));assert(charge==6+built(owned::cost(ref p,0,77))+327685);
    var calls::Frame receipt=calls::empty();var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State r=records::empty();var bytes::Buffer b=backing();initialize_mixed(ref p,ref mut l,ref mut a,ref mut r,ref mut b);
    let owners::Token occupied=a.tokens[(p.call_args[base+1] as usize)-128];a.tokens[31]=occupied;rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5,false);a.tokens[31]=owners::Token{.slot=0,.generation=0};
    let usize array=(p.call_args[base+1] as usize)-128;let usize at=a.owners.slots[a.tokens[array].slot].base;{let ref mut u8[] data=bytes::view_mut(ref mut b);data[at]=2;}rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5,false);{let ref mut u8[] data=bytes::view_mut(ref mut b);data[at]=1;}
    let usize limit=a.owners.arena.limit;let usize used=a.owners.arena.used;a.owners.arena.limit=used+2;rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,13,false);a.owners.arena.limit=limit;
    let usize record=(p.call_args[base+2] as usize)-144;r.tokens[record].generation+=1;rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5,false);r.tokens[record].generation-=1;let usize depth=a.owners.depth;
    assert(built(calls::enter(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge))==0 && a.owners.depth==depth+2);let usize x=(p.slice_parameters[3] as usize)-1;let usize y=(p.slice_parameters[4] as usize)-1;assert(l.tickets[16+x].slot!=l.tickets[16+y].slot && f.origins[11].slot==f.origins[12].slot);assert(built(calls::leave(ref p,0,1,ref mut receipt,ref mut f,ref mut l,ref mut a,ref b,77))==3);
}

@test
fn void corrupt_return_and_late_restore_failure_preserve_readers_writers_receipts_and_backing(){
    let ir::Program p=mixed();let usize call=pc(ref p,1);let usize charge=built(calls::cost(ref p,0,77));var calls::Frame receipt=calls::empty();var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State r=records::empty();var bytes::Buffer b=backing();initialize_mixed(ref p,ref mut l,ref mut a,ref mut r,ref mut b);let usize entered=built(calls::enter(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge));
    let usize epoch=receipt.batch.leases[0].generation;receipt.batch.leases[0].generation+=1;rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,0,5,true);receipt.batch.leases[0].generation=epoch;
    let usize formal_site=receipt.sites[0];let usize issued=receipt.batch.tickets[0].generation;receipt.batch.tickets[0].generation=0;assert(!calls::release(ref p,0,1,formal_site,ref mut receipt,ref f,ref mut l,ref a,ref b,4097,77).is_ok);receipt.batch.tickets[0].generation=issued;
    let usize source=receipt.sources[0];receipt.sources[0]=16;rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,0,5,true);receipt.sources[0]=source;
    receipt.detached[7]=l.tickets[16];rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,0,5,true);receipt.detached[7]=slices::Ticket{.slot=16,.generation=0};
    f.origins[12].generation+=1;rejected(ref p,call,0,ref mut receipt,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,0,5,true);f.origins[12].generation-=1;assert(built(calls::leave(ref p,0,1,ref mut receipt,ref mut f,ref mut l,ref mut a,ref b,77))==3);
}

@test
fn void abort_drain_keeps_prior_writes_and_original_error_or_retains_failed_cleanup_metadata(){
    let ir::Program p=program(10,false);let usize charge=built(calls::cost(ref p,0,77));var calls::Frame[1] receipts=[calls::empty();1];var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State r=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut l,ref mut a,ref mut b,false);let usize entered=built(calls::enter(ref p,pc(ref p,1),0,ref mut receipts[0],ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge));assert(count(slices::write(ref l.pool,l.tickets[16],ref a.owners,0,42,bytes::view_mut(ref mut b)))==1);let usize closed=built(calls::release(ref p,0,1,0,ref mut receipts[0],ref f,ref mut l,ref a,ref b,4097,77));
    let usize root=a.tokens[0].slot;let usize epoch=a.owners.slots[root].read_generation;a.owners.slots[root].read_generation+=1;let calls::Frame old=receipts[0];let usize generation=l.pool.slots[old.batch.tickets[0].slot].generation;
    assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==5}});same_receipt(ref receipts[0],ref old);assert(l.pool.slots[old.batch.tickets[0].slot].generation==generation && f.origins[8].generation!=0 && a.owners.slots[root].writing);
    a.owners.slots[root].read_generation=epoch;assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,.err(errors::make(8,77)))){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});assert(!receipts[0].active && cell(owners::read(ref a.owners,a.tokens[0],1,bytes::view(ref b)))==42);var usize i=0;while(i<512){assert(l.tickets[i].generation==0);i+=1;}i=0;while(i<256){assert(f.origins[i].generation==0);i+=1;}i=0;while(i<16){assert(!l.pool.slots[i].live && !a.owners.slots[i].writing && !a.owners.slots[i].reading);i+=1;}assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,.ok(42))){case .ok(v):{v==42}case .err(_):{false}});
}

@test
fn void full_sixteen_slot_pool_transfers_eight_writers_without_allocating_owners_or_payload(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=8;p.return_types[0]=1;p.return_types[1]=1;var usize i=0;while(i<8){let usize formal=built(builders::parameter_exclusive(ref mut p,0,10,77));i+=1;}i=0;while(i<8){let usize close=built(ir::slice_close(ref mut p,i,77));i+=1;}let usize value=built(ir::literal(ref mut p,42,77));let usize ret=built(ir::emit(ref mut p,8,value,0,77));finish(ref mut p,0);let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;let usize fill=built(ir::integer(ref mut p,65,10,77));let usize lo=built(ir::integer(ref mut p,0,12,77));let usize hi=built(ir::integer(ref mut p,1,12,77));var usize[8] args=[0;8];i=0;while(i<8){let usize root=built(ir::array_in(ref mut p,1,10,1,true,77));let usize site=built(ir::exclusive_slice(ref mut p,root,77));let usize init=built(ir::array_init(ref mut p,root,fill,77));let usize open=built(ir::slice_open(ref mut p,site,lo,hi,77));args[i]=160+site;i+=1;}let usize result=built(ir::call(ref mut p,0,ref args,77));i=8;while(i>0){i-=1;let usize close=built(ir::slice_close(ref mut p,i+8,77));let usize drop=built(ir::array_drop(ref mut p,i,77));}let usize done=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);inspected(ref p);
    var calls::Frame receipt=calls::empty();var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State r=records::empty();var bytes::Buffer b=backing();i=0;while(i<16){let owners::Token owner=create(ref mut a,10,1,65,ref mut b);let slices::Ticket opened=ticket(if(i<8){slices::open_exclusive(ref mut l.pool,ref mut a.owners,owner,0,1,256)}else{slices::open(ref mut l.pool,ref mut a.owners,owner,0,1,256)});if(i<8){a.tokens[i]=owner;l.tickets[i+8]=opened;}i+=1;}
    let usize used=a.owners.arena.used;let usize charge=built(calls::cost(ref p,0,77));let usize entered=built(calls::enter(ref p,pc(ref p,1),0,ref mut receipt,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge));assert(a.owners.depth==16 && a.owners.arena.used==used && receipt.batch.count==8);assert(built(calls::leave(ref p,0,1,ref mut receipt,ref mut f,ref mut l,ref mut a,ref b,77))==8 && a.owners.arena.used==used);assert(count(slices::clear(ref mut l.pool,ref mut a.owners,256))==16);
}
