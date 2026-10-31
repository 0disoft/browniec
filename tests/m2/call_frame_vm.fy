module tests::m2::call_frame_vm;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import call_frame_vm as calls;
import mixed_call_vm as mixed;
import slice_call_vm as borrowed;
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
fn ir::Program program() {
    var ir::Program p=switch(compiler::compile(b"module main;fn i32 f(ref u8[] part,bool[2] a,i32 n){return f(ref part,a,n);}fn i32 main(){let u8[4] root=[65;4];let bool[2] a=[true;2];let ref u8[] part=ref root;return f(ref part,a,42);}")) {
        case .ok(v):{v} case .err(_):{assert(false);ir::empty()}
    };
    assert(verifier::inspect(ref p).is_ok && !verifier::verify(ref p).is_ok);
    var usize pc=0; while(pc<p.count) { if(p.code[pc*8]==9) {p.offsets[pc]=77;} pc+=1; } return p;
}
fn usize call_pc(ref ir::Program p,usize f) {
    var usize pc=p.starts[f]; while(pc<p.ends[f] && p.code[pc*8]!=9) {pc+=1;}
    assert(pc<p.ends[f]); return pc;
}
fn void initialize(ref ir::Program p,ref mut loans::State l,ref mut arrays::State a,ref mut bytes::Buffer b,ref mut i64[] regs) {
    let usize pc=call_pc(p,p.entry); let usize site=p.code[pc*8+3] as usize;
    let usize slice=p.call_args[site*8] as usize-160; let usize root=p.slice_roots[slice] as usize-1;
    let usize array=p.call_args[site*8+1] as usize-128;
    {
        let ref mut u8[] data=bytes::view_mut(b);
        let layouts::Array shape=switch(layouts::scalar(10,4)) {case .ok(v):{v} case .err(_):{assert(false);layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4}}};
        let owners::Token made=token(owners::create(ref shape,65,data,ref mut a.owners));a.tokens[root]=made;
        let layouts::Array bools=switch(layouts::scalar(2,2)) {case .ok(v):{v} case .err(_):{assert(false);shape}};
        let owners::Token other=token(owners::create(ref bools,1,data,ref mut a.owners));a.tokens[array]=other;
    }
    let owners::Token origin=a.tokens[root];let usize capacity=bytes::len(b);
    let slices::Ticket opened=ticket(slices::open(ref mut l.pool,ref mut a.owners,origin,1,3,capacity));l.tickets[slice]=opened;
    regs[p.call_args[site*8+2] as usize]=42;
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
fn void rejected(ref ir::Program p,usize pc,usize parent,ref mut borrowed::Frames f,ref mut loans::State l,ref mut arrays::State a,ref mut records::State r,ref mut bytes::Buffer b,ref mut i64[] regs,ref mut usize[] pcs,ref mut usize[] dsts,usize fuel,u8 kind) {
    let borrowed::Frames oldf=borrowed::Frames{.origins=f.origins}; let loans::State oldl=loans::State{.pool=slices::Pool{.slots=l.pool.slots},.tickets=l.tickets};
    let arrays::State olda=arrays::State{.owners=owners::Table{.slots=a.owners.slots,.order=a.owners.order,.depth=a.owners.depth,.arena=a.owners.arena},.tokens=a.tokens};
    let records::State oldr=records::State{.tokens=r.tokens}; var u8[128] old=[0;128]; let usize size=bytes::len(b);
    {let ref u8[] data=bytes::view(b); var usize i=0; while(i<size) {old[i]=data[i];i+=1;}}
    var i64[4096] oldregs=[0;4096]; var usize i=0; while(i<regs.len) {oldregs[i]=regs[i];i+=1;}
    var usize[32] oldpcs=[0;32]; var usize[32] olddsts=[0;32]; i=0;
    while(i<pcs.len) {oldpcs[i]=pcs[i];i+=1;} i=0;while(i<dsts.len) {olddsts[i]=dsts[i];i+=1;}
    assert(switch(calls::step(p,pc,parent,f,l,r,a,b,regs,pcs,dsts,fuel)) {case .ok(_):{false} case .err(e):{e.kind==kind && e.offset==77}});
    same(f,ref oldf,l,ref oldl,a,ref olda,r,ref oldr,bytes::view(b),ref old[..size]);
    i=0;while(i<regs.len) {assert(regs[i]==oldregs[i]);i+=1;} i=0;
    while(i<pcs.len) {assert(pcs[i]==oldpcs[i]);i+=1;} i=0;while(i<dsts.len) {assert(dsts[i]==olddsts[i]);i+=1;}
}

@test
fn void mixed_publication_copies_only_scalars_and_supports_nested_forwarding() {
    let ir::Program p=program(); let usize pc=call_pc(ref p,p.entry); let usize charge=built(mixed::cost(ref p,0,77));
    var borrowed::Frames f=borrowed::empty(); var loans::State l=loans::empty(); var arrays::State a=arrays::empty(128);var records::State r=records::empty();var bytes::Buffer b=backing();
    var i64[4096] regs=[-91;4096];var usize[32] pcs=[99;32];var usize[32] dsts=[98;32];
    initialize(ref p,ref mut l,ref mut a,ref mut b,ref mut regs);
    assert(built(calls::step(ref p,pc,0,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge+7))==7);
    let usize formal=p.register_starts[0]; assert(regs[128+formal]==-91 && regs[128+formal+1]==-91 && regs[128+formal+2]==42);
    assert(pcs[1]==pc+1 && dsts[1]==p.code[pc*8+1] as usize && pcs[0]==99 && dsts[2]==98);
    let usize nested=call_pc(ref p,0);
    assert(built(calls::step(ref p,nested,1,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge))==0);
    assert(regs[256+formal]==-91 && regs[256+formal+1]==-91 && regs[256+formal+2]==42 && pcs[2]==nested+1);
    assert(f.origins[8].slot==f.origins[16].slot && f.origins[8].generation==f.origins[16].generation);
    assert(built(borrowed::leave(ref p,0,2,ref mut f,ref mut l,ref mut a,ref b,77))==1);
    assert(built(borrowed::leave(ref p,0,1,ref mut f,ref mut l,ref mut a,ref b,77))==1);
    assert(switch(vm::run_with_array_limit(ref p,0,0)) {case .ok(_):{false} case .err(e):{e.kind==5}});
}

@test
fn void late_owned_or_borrowed_failure_preserves_registers_control_and_all_transactions() {
    let ir::Program p=program();let usize pc=call_pc(ref p,p.entry);let usize site=p.code[pc*8+3] as usize;let usize charge=built(mixed::cost(ref p,0,77));
    var borrowed::Frames f=borrowed::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(128);var records::State r=records::empty();var bytes::Buffer b=backing();
    var i64[4096] regs=[-91;4096];var usize[32] pcs=[99;32];var usize[32] dsts=[98;32];initialize(ref p,ref mut l,ref mut a,ref mut b,ref mut regs);
    let usize array=p.call_args[site*8+1] as usize-128;let usize at=a.owners.slots[a.tokens[array].slot].base;
    {let ref mut u8[] data=bytes::view_mut(ref mut b);data[at]=2;}
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge,5);
    {let ref mut u8[] data=bytes::view_mut(ref mut b);data[at]=1;}
    let usize slice=p.call_args[site*8] as usize-160;l.tickets[slice].generation+=1;
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge,5);l.tickets[slice].generation-=1;
    a.owners.arena.limit=a.owners.arena.used;
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge,13);
}

@test
fn void scalar_control_and_span_preflight_precedes_any_mixed_publication() {
    var ir::Program p=program();let usize pc=call_pc(ref p,p.entry);let usize site=p.code[pc*8+3] as usize;let usize charge=built(mixed::cost(ref p,0,77));
    var borrowed::Frames f=borrowed::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(128);var records::State r=records::empty();var bytes::Buffer b=backing();
    var i64[4096] regs=[-91;4096];var usize[32] pcs=[99;32];var usize[32] dsts=[98;32];initialize(ref p,ref mut l,ref mut a,ref mut b,ref mut regs);
    rejected(ref p,pc,31,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge-1,8);
    rejected(ref p,pc,31,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge,12);
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs[..255],ref mut pcs,ref mut dsts,charge,5);
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs[..1],ref mut dsts,charge,5);
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts[..1],charge,5);
    let u8 saved=p.call_args[site*8+2];p.call_args[site*8+2]=160;
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge,5);p.call_args[site*8+2]=saved;
    let u8 dest=p.code[pc*8+1];p.code[pc*8+1]=160;
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge,5);p.code[pc*8+1]=dest;
    p.call_args[site*8+2]=0;
    rejected(ref p,pc,0,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,charge,5);
}

@test
fn void executable_scalar_and_owned_calls_keep_fuel_results_and_frame_reuse() {
    let ir::Program p=switch(compiler::compile(b"module main;fn i32 f(i32 n){return n;}fn i32 main(){return f(20)+f(22);}")){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,10)) {case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run(ref p,9)) {case .ok(_):{false}case .err(e):{e.kind==8}});
    let ir::Program owned=switch(compiler::compile(b"module main;struct P{i32 x;}fn i32 f(u8[2] a,P p,i32 n){return (a[0] as i32)+p.x+n;}fn i32 main(){let u8[2] a=[20;2];let P p=P{.x=20};return f(a,p,2);}")){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(switch(vm::run(ref owned,1000000)){case .ok(n):{n==42}case .err(_):{false}});
}
