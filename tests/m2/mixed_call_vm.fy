module tests::m2::mixed_call_vm;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import mixed_call_vm as mixed;
import slice_call_vm as borrowed;
import struct_call_vm as owned;
import slice_vm as loans;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_vm as arrays;
import struct_vm as records;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v):{v} case .err(_):{assert(false);0} }; }
fn usize count(Result<usize,owners::Error> r) { return switch(r) { case .ok(v):{v} case .err(_):{assert(false);0} }; }
fn owners::Token token(Result<owners::Token,owners::Error> r) { return switch(r) { case .ok(v):{v} case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}} }; }
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r) { return switch(r) { case .ok(v):{v} case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}} }; }
fn bytes::Buffer backing() { return switch(arrays::prepare(128)) { case .ok(v):{v} case .err(_):{assert(false);bytes::empty()} }; }
fn ir::Program program(bool boolean) {
    let ref u8[] source=if(boolean) {
        b"module main;struct P{bool good;i32 x;}fn i32 f(ref u8[] p,bool[2] a,P r,ref u8[] q){return 42;}fn i32 main(){let u8[4] b=[65;4];let bool[2] a=[true;2];let P r=P{.good=true,.x=20};let ref u8[] p=ref b;return f(ref p,a,r,ref p);}"
    } else {
        b"module main;struct P{bool good;i32 x;}fn i32 f(ref u8[] p,u8[4] a,P r,ref u8[] q){return f(ref p,a,r,ref q);}fn i32 main(){let u8[4] a=[65;4];let P r=P{.good=true,.x=20};let ref u8[] p=ref a;return f(ref p,a,r,ref p);}"
    };
    var ir::Program p=switch(compiler::compile(source)) { case .ok(v):{v} case .err(_):{assert(false);ir::empty()} };
    assert(verifier::inspect(ref p).is_ok && !verifier::verify(ref p).is_ok);
    var usize pc=0; while(pc<p.count) { if(p.code[pc*8]==9) { p.offsets[pc]=77; } pc+=1; } return p;
}
fn usize call_pc(ref ir::Program p,usize f) { var usize pc=p.starts[f]; while(pc<p.ends[f] && p.code[pc*8]!=9) { pc+=1; } assert(pc<p.ends[f]); return pc; }
fn void initialize(ref ir::Program p,ref mut loans::State loan,ref mut arrays::State a,ref mut records::State r,ref mut bytes::Buffer buffer,bool empty) {
    let usize pc=call_pc(p,p.entry); let usize site=p.code[pc*8+3] as usize;
    let usize slice=p.call_args[site*8] as usize-160; let usize root=p.slice_roots[slice] as usize-1;
    let usize array=p.call_args[site*8+1] as usize-128; let usize record=p.call_args[site*8+2] as usize-144;
    {
        let ref mut u8[] data=bytes::view_mut(buffer);
        let layouts::Array u8s=switch(layouts::scalar(10,4)) { case .ok(v):{v} case .err(_):{assert(false);layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4}} };
        let owners::Token root_token=token(owners::create(ref u8s,65,data,ref mut a.owners)); a.tokens[root]=root_token;
        if(array!=root) {
            let layouts::Array shape=switch(layouts::scalar(p.arrays.elements[array],p.arrays.lengths[array])) { case .ok(v):{v} case .err(_):{assert(false);u8s} };
            let owners::Token array_token=token(owners::create(ref shape,1,data,ref mut a.owners)); a.tokens[array]=array_token;
        }
        let i64[2] fields=[1,20];
        let owners::Token record_token=token(owners::create_record(ref p.records.layouts,p.records.records[record] as usize,ref fields,data,ref mut a.owners)); r.tokens[record]=record_token;
    }
    let owners::Token root_token=a.tokens[root]; let slices::Ticket opened=ticket(slices::open(ref mut loan.pool,ref mut a.owners,root_token,if(empty){4}else{1},if(empty){4}else{3},128)); loan.tickets[slice]=opened;
}
fn void same(ref borrowed::Frames f,ref borrowed::Frames oldf,ref loans::State l,ref loans::State oldl,ref arrays::State a,ref arrays::State olda,ref records::State r,ref records::State oldr,ref u8[] data,ref u8[] old) {
    var usize i=0; while(i<256) { assert(f.origins[i].slot==oldf.origins[i].slot && f.origins[i].generation==oldf.origins[i].generation); i+=1; }
    i=0; while(i<512) {
        assert(l.tickets[i].slot==oldl.tickets[i].slot && l.tickets[i].generation==oldl.tickets[i].generation);
        assert(a.tokens[i].slot==olda.tokens[i].slot && a.tokens[i].generation==olda.tokens[i].generation);
        assert(r.tokens[i].slot==oldr.tokens[i].slot && r.tokens[i].generation==oldr.tokens[i].generation); i+=1;
    }
    assert(a.owners.depth==olda.owners.depth && a.owners.arena.used==olda.owners.arena.used && a.owners.arena.limit==olda.owners.arena.limit);
    i=0; while(i<16) {
        let slices::Slot x=l.pool.slots[i]; let slices::Slot y=oldl.pool.slots[i];
        assert(x.live==y.live && x.generation==y.generation && x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation && x.view.element==y.view.element && x.view.length==y.view.length && x.view.start==y.view.start && x.view.end==y.view.end && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);
        let owners::Owner b=a.owners.slots[i]; let owners::Owner c=olda.owners.slots[i];
        assert(b.generation==c.generation && b.occupied==c.occupied && b.live==c.live && b.reading==c.reading && b.read_generation==c.read_generation && b.mark==c.mark && b.base==c.base && b.end==c.end && b.element==c.element && b.length==c.length && b.record==c.record && b.alignment==c.alignment && a.owners.order[i]==olda.owners.order[i]); i+=1;
    }
    assert(data.len==old.len); i=0; while(i<data.len) { assert(data[i]==old[i]); i+=1; }
}
fn void rejected(ref ir::Program p,usize pc,usize parent,ref mut borrowed::Frames f,ref mut loans::State l,ref mut arrays::State a,ref mut records::State r,ref mut bytes::Buffer b,usize fuel,u8 kind) {
    let borrowed::Frames oldf=borrowed::Frames{.origins=f.origins}; let loans::State oldl=loans::State{.pool=slices::Pool{.slots=l.pool.slots},.tickets=l.tickets};
    let arrays::State olda=arrays::State{.owners=owners::Table{.slots=a.owners.slots,.order=a.owners.order,.depth=a.owners.depth,.arena=a.owners.arena},.tokens=a.tokens};
    let records::State oldr=records::State{.tokens=r.tokens}; var u8[128] old=[0;128]; let usize size=bytes::len(b); { let ref u8[] data=bytes::view(b); assert(data.len<=128); var usize i=0; while(i<data.len) { old[i]=data[i]; i+=1; } }
    assert(switch(mixed::step(p,pc,parent,f,l,r,a,b,fuel)) { case .ok(_):{false} case .err(e):{e.kind==kind && e.offset==77} });
    same(f,ref oldf,l,ref oldl,a,ref olda,r,ref oldr,bytes::view(b),ref old[..size]);
}

@test
fn void exact_combined_fuel_duplicate_empty_ranges_and_owned_copies_publish_together() {
    let ir::Program p=program(false); let usize pc=call_pc(ref p,p.entry); let usize site=p.code[pc*8+3] as usize;
    let usize charge=built(mixed::cost(ref p,0,77)); assert(charge==5+built(owned::cost(ref p,0,77))+built(borrowed::cost(ref p,0,77)));
    var usize iteration=0; while(iteration<2) {
        var borrowed::Frames f=borrowed::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(128); var records::State r=records::empty(); var bytes::Buffer b=backing();
        initialize(ref p,ref mut l,ref mut a,ref mut r,ref mut b,iteration==1); let usize used=a.owners.arena.used; let usize depth=a.owners.depth;
        rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge-1,8);
        assert(built(mixed::step(ref p,pc,0,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge))==0);
        assert(a.owners.depth==depth+2 && a.owners.arena.used==used+12);
        let usize first=p.slice_parameters[p.register_starts[0]] as usize-1; let usize last=p.slice_parameters[p.register_starts[0]+3] as usize-1;
        assert(l.tickets[16+first].slot!=l.tickets[16+last].slot);
        assert(count(slices::length(ref l.pool,l.tickets[16+first],ref a.owners,128))==if(iteration==1){0}else{2});
        let usize array=p.array_parameters[p.register_starts[0]+1] as usize-1; let usize record=p.record_parameters[p.register_starts[0]+2] as usize-1;
        assert(a.tokens[16+array].generation!=0 && r.tokens[16+record].generation!=0);
        let owners::Owner copy=a.owners.slots[a.tokens[16+array].slot]; let owners::Owner rec=a.owners.slots[r.tokens[16+record].slot]; let ref u8[] data=bytes::view(ref b);
        assert(data[copy.base]==65 && data[copy.end-1]==65 && data[rec.base]==1 && data[rec.base+4]==20);
        assert(built(borrowed::leave(ref p,0,1,ref mut f,ref mut l,ref mut a,ref b,77))==2);
        let usize caller=p.call_args[site*8] as usize-160; assert(count(slices::length(ref l.pool,l.tickets[caller],ref a.owners,128))==if(iteration==1){0}else{2});
        iteration+=1;
    }
    assert(switch(vm::run_with_array_limit(ref p,0,0)) { case .err(e):{e.kind==5} case .ok(_):{false} });
}

@test
fn void late_owned_failures_discard_prepared_retains_without_consuming_generations_or_payload() {
    let ir::Program p=program(true); let usize pc=call_pc(ref p,p.entry); let usize site=p.code[pc*8+3] as usize; let usize charge=built(mixed::cost(ref p,0,77));
    var borrowed::Frames f=borrowed::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(128); var records::State r=records::empty(); var bytes::Buffer b=backing();
    initialize(ref p,ref mut l,ref mut a,ref mut r,ref mut b,false);
    let usize array=p.call_args[site*8+1] as usize-128; let usize record=p.call_args[site*8+2] as usize-144;
    let usize bool_at=a.owners.slots[a.tokens[array].slot].base; let usize record_at=a.owners.slots[r.tokens[record].slot].base;
    { let ref mut u8[] data=bytes::view_mut(ref mut b); data[bool_at]=2; }
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5);
    { let ref mut u8[] data=bytes::view_mut(ref mut b); data[bool_at]=1; data[record_at]=2; }
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5);
    { let ref mut u8[] data=bytes::view_mut(ref mut b); data[record_at]=1; }
    // The first owned bool array fits; the later record cannot be reserved.
    a.owners.arena.limit=a.owners.arena.used+2;
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,13); a.owners.arena.limit=128;
    r.tokens[record].generation+=1; rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5); r.tokens[record].generation-=1;
    let owners::Token live_record=r.tokens[record]; r.tokens[31]=live_record; rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5); r.tokens[31]=owners::Token{.slot=0,.generation=0};
    assert(built(mixed::step(ref p,pc,0,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge))==0);
}

@test
fn void borrowed_capacity_and_stale_tickets_fail_before_any_owned_copy() {
    let ir::Program p=program(false); let usize pc=call_pc(ref p,p.entry); let usize site=p.code[pc*8+3] as usize; let usize charge=built(mixed::cost(ref p,0,77));
    var borrowed::Frames f=borrowed::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(128); var records::State r=records::empty(); var bytes::Buffer b=backing(); initialize(ref p,ref mut l,ref mut a,ref mut r,ref mut b,false);
    let usize caller=p.call_args[site*8] as usize-160; l.tickets[caller].generation+=1;
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5); l.tickets[caller].generation-=1;
    f.origins[8]=owners::Token{.slot=0,.generation=1}; rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5); f=borrowed::empty();
    let slices::Ticket parent=l.tickets[caller]; var usize i=1; while(i<15) { let slices::Ticket extra=ticket(slices::subslice(ref mut l.pool,parent,ref a.owners,0,0,128)); i+=1; }
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,13);
}

@test
fn void nested_forwarding_copies_owned_parameters_and_retains_original_borrow_roots() {
    let ir::Program p=program(false); let usize charge=built(mixed::cost(ref p,0,77));
    var borrowed::Frames f=borrowed::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(128); var records::State r=records::empty(); var bytes::Buffer b=backing(); initialize(ref p,ref mut l,ref mut a,ref mut r,ref mut b,false);
    assert(built(mixed::step(ref p,call_pc(ref p,p.entry),0,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge+7))==7);
    assert(built(mixed::step(ref p,call_pc(ref p,0),1,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,charge))==0);
    assert(f.origins[8].slot==f.origins[16].slot && f.origins[8].generation==f.origins[16].generation && a.owners.depth==6);
    assert(built(borrowed::leave(ref p,0,2,ref mut f,ref mut l,ref mut a,ref b,77))==2);
    assert(built(borrowed::leave(ref p,0,1,ref mut f,ref mut l,ref mut a,ref b,77))==2);
}

@test
fn void fuel_precedes_frame_backing_and_scalar_only_calls_keep_exact_prices() {
    let ir::Program p=program(false); let usize pc=call_pc(ref p,p.entry); let usize charge=built(mixed::cost(ref p,0,77));
    var borrowed::Frames f=borrowed::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(0); var records::State r=records::empty(); var bytes::Buffer b=bytes::empty();
    rejected(ref p,pc,31,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge-1,8);
    rejected(ref p,pc,31,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,12);
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,charge,5);
    let ir::Program scalar=switch(compiler::compile(b"module main;fn i32 f(i32 x){return x;}fn i32 main(){return f(42);}")) { case .ok(v):{v} case .err(_):{assert(false);ir::empty()} };
    assert(built(mixed::cost(ref scalar,0,77))==2);
    assert(built(mixed::step(ref scalar,call_pc(ref scalar,scalar.entry),0,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,2))==0);
}
