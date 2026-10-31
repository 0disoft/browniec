module tests::m2::slice_call_vm;
import ir as ir;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import slice_call_vm as calls;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); slices::Ticket{.slot=16,.generation=0} } }; }
fn usize length(Result<usize,owners::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn bytes::Buffer backing() { return switch(arrays::prepare(16)) { case .ok(v): { v } case .err(_): { assert(false); bytes::empty() } }; }
fn void kind(Result<usize,errors::Error> r,u8 expected) { assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind==expected && e.offset==77 } }); }
fn ir::Program program(u8 mode) {
    let ref u8[] source=if(mode==1) {
        b"module main;fn i32 f(ref u8[] p,ref u8[] q){return 42;}fn i32 main(){let u8[4] a=[65;4];let ref u8[] p=ref a[1..3];let ref u8[] q=ref a;return f(ref p,ref q);}"
    } else if(mode==2) {
        b"module main;fn i32 f(ref u8[] p){let ref u8[] q=ref p;return f(ref q);}fn i32 main(){let u8[4] a=[65;4];let ref u8[] p=ref a[1..3];return f(ref p);}"
    } else if(mode==3) {
        b"module main;fn i32 f(ref u8[] a,ref u8[] b,ref u8[] c,ref u8[] d,ref u8[] e,ref u8[] f,ref u8[] g,ref u8[] h){return 42;}fn i32 main(){let u8[4] a=[65;4];let ref u8[] p=ref a;return f(ref p,ref p,ref p,ref p,ref p,ref p,ref p,ref p);}"
    } else {
        b"module main;struct P{i32 x;}fn i32 f(i32 n,ref u8[] p,u8[4] a,P r,ref u8[] q){return n+p[0] as i32+r.x;}fn i32 main(){let u8[4] a=[65;4];let ref u8[] p=ref a[1..3];let P r=P{.x=0};return f(0,ref p,a,r,ref p);}"
    };
    var ir::Program p=switch(compiler::compile(source)) { case .ok(v): { v } case .err(_): { assert(false); ir::empty() } };
    assert(verifier::inspect(ref p).is_ok && verifier::verify(ref p).is_ok);
    var usize pc=0; while(pc<p.count) { if(p.code[pc*8]==9) { p.offsets[pc]=77; } pc+=1; } return p;
}
fn usize call_pc(ref ir::Program p,usize function) { var usize pc=p.starts[function]; while(pc<p.ends[function] && p.code[pc*8]!=9) { pc+=1; } assert(pc<p.ends[function]); return pc; }
fn void initialize(ref ir::Program p,ref mut loans::State loan,ref mut arrays::State state,ref mut bytes::Buffer buffer,bool empty) {
    let usize pc=call_pc(p,p.entry); let usize call=p.code[pc*8+3] as usize; let usize target=p.code[pc*8+2] as usize;
    var usize i=0;
    while(i<p.arities[target]) {
        if(p.slice_parameters[p.register_starts[target]+i]!=0) {
            let usize site=p.call_args[call*8+i] as usize-160; let usize root=p.slice_roots[site] as usize-1;
            if(state.tokens[root].generation==0) {
                let layouts::Array shape=switch(layouts::scalar(10,4)) { case .ok(v): { v } case .err(_): { assert(false); layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4} } };
                { let ref mut u8[] data=bytes::view_mut(buffer); let owners::Token created=switch(owners::create(ref shape,65,data,ref mut state.owners)) { case .ok(v): { v } case .err(_): { assert(false); owners::Token{.slot=16,.generation=0} } }; state.tokens[root]=created; }
            }
            if(loan.tickets[site].generation==0) { let owners::Token owner=state.tokens[root]; let slices::Ticket opened=ticket(slices::open(ref mut loan.pool,ref mut state.owners,owner,if(empty){4}else{1},if(empty){4}else{3},16)); loan.tickets[site]=opened; }
        }
        i+=1;
    }
}
fn void same(ref calls::Frames frame,ref calls::Frames old_frame,ref loans::State loan,ref loans::State old_loan,ref arrays::State state,ref arrays::State old_state) {
    var usize i=0; while(i<256) { assert(frame.origins[i].slot==old_frame.origins[i].slot && frame.origins[i].generation==old_frame.origins[i].generation); i+=1; }
    i=0; while(i<512) { assert(loan.tickets[i].slot==old_loan.tickets[i].slot && loan.tickets[i].generation==old_loan.tickets[i].generation && state.tokens[i].slot==old_state.tokens[i].slot && state.tokens[i].generation==old_state.tokens[i].generation); i+=1; }
    assert(state.owners.depth==old_state.owners.depth && state.owners.arena.used==old_state.owners.arena.used && state.owners.arena.limit==old_state.owners.arena.limit);
    i=0; while(i<16) {
        let slices::Slot a=loan.pool.slots[i]; let slices::Slot b=old_loan.pool.slots[i];
        assert(a.live==b.live && a.generation==b.generation && a.view.root.slot==b.view.root.slot && a.view.root.generation==b.view.root.generation && a.view.element==b.view.element && a.view.length==b.view.length && a.view.start==b.view.start && a.view.end==b.view.end && a.lease.root.slot==b.lease.root.slot && a.lease.root.generation==b.lease.root.generation && a.lease.generation==b.lease.generation);
        let owners::Owner x=state.owners.slots[i]; let owners::Owner y=old_state.owners.slots[i];
        assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment && state.owners.order[i]==old_state.owners.order[i]); i+=1;
    }
}
fn calls::Frames copy_frames(ref calls::Frames frame) { return calls::Frames { .origins=frame.origins }; }
fn loans::State copy_loans(ref loans::State loan) { return loans::State { .pool=slices::Pool{.slots=loan.pool.slots},.tickets=loan.tickets }; }
fn arrays::State copy_arrays(ref arrays::State state) { return arrays::State { .owners=owners::Table{.slots=state.owners.slots,.order=state.owners.order,.depth=state.owners.depth,.arena=state.owners.arena},.tokens=state.tokens }; }
fn void rejected_enter(ref ir::Program p,usize pc,usize parent,ref mut calls::Frames frame,ref mut loans::State loan,ref mut arrays::State state,ref bytes::Buffer buffer,usize fuel,u8 expected) {
    let calls::Frames old_frame=copy_frames(frame); let loans::State old_loan=copy_loans(loan); let arrays::State old_state=copy_arrays(state);
    kind(calls::enter(p,pc,parent,frame,loan,state,buffer,fuel),expected); same(frame,ref old_frame,loan,ref old_loan,state,ref old_state);
}
fn void rejected_leave(ref ir::Program p,ref mut calls::Frames frame,ref mut loans::State loan,ref mut arrays::State state,ref bytes::Buffer buffer) {
    let calls::Frames old_frame=copy_frames(frame); let loans::State old_loan=copy_loans(loan); let arrays::State old_state=copy_arrays(state);
    kind(calls::leave(p,0,1,frame,loan,state,buffer,77),5); same(frame,ref old_frame,loan,ref old_loan,state,ref old_state);
}

@test
fn void mixed_formal_ordinals_duplicate_ranges_exact_fuel_and_frame_reuse_preserve_caller_storage() {
    let ir::Program p=program(0); let usize pc=call_pc(ref p,1); let usize work=built(calls::cost(ref p,0,77)); assert(work==196611 && built(calls::cost(ref p,p.entry,77))==0);
    var calls::Frames frame=calls::empty(); var loans::State loan=loans::empty(); var arrays::State state=arrays::empty(16); var bytes::Buffer data=backing();
    initialize(ref p,ref mut loan,ref mut state,ref mut data,false); let usize depth=state.owners.depth; let usize used=state.owners.arena.used;
    assert(built(calls::enter(ref p,pc,0,ref mut frame,ref mut loan,ref state,ref data,work+7))==7);
    assert(loan.tickets[16].slot!=loan.tickets[17].slot && loan.tickets[16].slot!=loan.tickets[2].slot);
    assert(frame.origins[8].generation==0 && frame.origins[9].generation!=0 && frame.origins[12].generation==frame.origins[9].generation);
    assert(length(slices::length(ref loan.pool,loan.tickets[16],ref state.owners,16))==2);
    assert(state.owners.depth==depth && state.owners.arena.used==used);
    var usize i=16; while(i<32) { assert(state.tokens[i].generation==0); i+=1; }
    assert(built(calls::leave(ref p,0,1,ref mut frame,ref mut loan,ref mut state,ref data,77))==2);
    assert(length(slices::length(ref loan.pool,loan.tickets[2],ref state.owners,16))==2);
    assert(built(calls::enter(ref p,pc,0,ref mut frame,ref mut loan,ref state,ref data,work))==0);
    assert(built(calls::leave(ref p,0,1,ref mut frame,ref mut loan,ref mut state,ref data,77))==2);
    let ref u8[] payload=bytes::view(ref data); assert(payload[0]==65 && payload[3]==65 && payload[4]==0 && payload.len==16);
    assert(switch(vm::run_with_array_limit(ref p,0,0)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
}

@test
fn void forwarding_retained_children_after_formal_close_keeps_origin_roots_and_parent_frames() {
    let ir::Program p=program(2); var calls::Frames frame=calls::empty(); var loans::State loan=loans::empty(); var arrays::State state=arrays::empty(16); var bytes::Buffer data=backing();
    initialize(ref p,ref mut loan,ref mut state,ref mut data,false); let usize work=built(calls::cost(ref p,0,77)); assert(work==131074);
    let usize entered=built(calls::enter(ref p,call_pc(ref p,1),0,ref mut frame,ref mut loan,ref state,ref data,work));
    let slices::Ticket formal=loan.tickets[16];
    let slices::Ticket derived=ticket(slices::subslice(ref mut loan.pool,formal,ref state.owners,0,2,16)); loan.tickets[17]=derived;
    let usize closed=length(slices::close(ref mut loan.pool,formal,ref mut state.owners,16)); loan.tickets[16]=slices::Ticket{.slot=16,.generation=0};
    let owners::Token root=switch(calls::root(ref p,0,1,1,ref frame,ref state,77)) { case .ok(v): { v } case .err(_): { assert(false); owners::Token{.slot=16,.generation=0} } };
    assert(root.generation==frame.origins[8].generation);
    assert(built(calls::enter(ref p,call_pc(ref p,0),1,ref mut frame,ref mut loan,ref state,ref data,work))==0);
    assert(length(slices::length(ref loan.pool,loan.tickets[32],ref state.owners,16))==2 && frame.origins[16].generation==root.generation);
    assert(built(calls::leave(ref p,0,2,ref mut frame,ref mut loan,ref mut state,ref data,77))==1);
    assert(length(slices::length(ref loan.pool,loan.tickets[17],ref state.owners,16))==2);
    assert(built(calls::leave(ref p,0,1,ref mut frame,ref mut loan,ref mut state,ref data,77))==1 && frame.origins[8].generation==0);
    assert(length(slices::length(ref loan.pool,loan.tickets[2],ref state.owners,16))==2);
}

@test
fn void admission_failures_precede_publication_and_fuel_precedes_ticket_backing_and_frame_work() {
    let ir::Program p=program(1); let usize pc=call_pc(ref p,1); let usize work=built(calls::cost(ref p,0,77));
    var calls::Frames frame=calls::empty(); var loans::State loan=loans::empty(); var arrays::State state=arrays::empty(16); var bytes::Buffer data=backing();
    initialize(ref p,ref mut loan,ref mut state,ref mut data,false);
    rejected_enter(ref p,pc,0,ref mut frame,ref mut loan,ref mut state,ref data,work-1,8);
    rejected_enter(ref p,pc,31,ref mut frame,ref mut loan,ref mut state,ref data,work,12);
    let bytes::Buffer missing=bytes::empty(); rejected_enter(ref p,pc,0,ref mut frame,ref mut loan,ref mut state,ref missing,work-1,8);
    rejected_enter(ref p,pc,0,ref mut frame,ref mut loan,ref mut state,ref missing,work,5);
    frame.origins[8]=owners::Token{.slot=0,.generation=1}; rejected_enter(ref p,pc,0,ref mut frame,ref mut loan,ref mut state,ref data,work,5); frame=calls::empty();
    loan.tickets[16]=slices::Ticket{.slot=16,.generation=1}; rejected_enter(ref p,pc,0,ref mut frame,ref mut loan,ref mut state,ref data,work,5); loan.tickets[16]=slices::Ticket{.slot=16,.generation=0};
    let slices::Ticket saved=loan.tickets[3]; loan.tickets[3]=slices::Ticket{.slot=2,.generation=1};
    rejected_enter(ref p,pc,0,ref mut frame,ref mut loan,ref mut state,ref data,work,5); loan.tickets[3]=saved;
    let slices::Ticket parent=loan.tickets[2];
    var usize i=2; while(i<15) { let slices::Ticket peer=ticket(slices::subslice(ref mut loan.pool,parent,ref state.owners,0,2,16)); i+=1; }
    rejected_enter(ref p,pc,0,ref mut frame,ref mut loan,ref mut state,ref data,work,13);
}

@test
fn void late_cleanup_failures_preserve_all_tables_and_eight_empty_arguments_remain_bounded() {
    let ir::Program p=program(0); let usize work=built(calls::cost(ref p,0,77));
    var calls::Frames frame=calls::empty(); var loans::State loan=loans::empty(); var arrays::State state=arrays::empty(16); var bytes::Buffer data=backing();
    initialize(ref p,ref mut loan,ref mut state,ref mut data,false); let usize entered=built(calls::enter(ref p,call_pc(ref p,1),0,ref mut frame,ref mut loan,ref state,ref data,work));
    let slices::Ticket saved=loan.tickets[16]; let slices::Ticket duplicate=loan.tickets[17]; loan.tickets[16]=duplicate; rejected_leave(ref p,ref mut frame,ref mut loan,ref mut state,ref data); loan.tickets[16]=saved;
    loan.tickets[16].generation+=1; rejected_leave(ref p,ref mut frame,ref mut loan,ref mut state,ref data); loan.tickets[16]=saved;
    frame.origins[9].generation+=1; rejected_leave(ref p,ref mut frame,ref mut loan,ref mut state,ref data); frame.origins[9].generation-=1;
    assert(built(calls::leave(ref p,0,1,ref mut frame,ref mut loan,ref mut state,ref data,77))==2);
    let ir::Program eight=program(3); var calls::Frames large_frame=calls::empty(); var loans::State large_loan=loans::empty(); var arrays::State large_state=arrays::empty(16); var bytes::Buffer large_data=backing();
    initialize(ref eight,ref mut large_loan,ref mut large_state,ref mut large_data,true); let usize full=built(calls::cost(ref eight,0,77)); assert(full==589833);
    assert(built(calls::enter(ref eight,call_pc(ref eight,1),0,ref mut large_frame,ref mut large_loan,ref large_state,ref large_data,full))==0);
    var usize i=0; while(i<8) { assert(length(slices::length(ref large_loan.pool,large_loan.tickets[16+i],ref large_state.owners,16))==0); i+=1; }
    assert(built(calls::leave(ref eight,0,1,ref mut large_frame,ref mut large_loan,ref mut large_state,ref large_data,77))==8 && large_state.owners.depth==1);
}
