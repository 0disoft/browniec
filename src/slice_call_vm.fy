module slice_call_vm;
import ir as ir;
import errors as errors;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import std::bytes as bytes;

// Private prospective CALL context, not yet allocated by the executable VM.
// Formal ordinals need at most 8 roots per frame; derived sites share them.
pub struct Frames { owners::Token[256] origins; }
pub fn Frames empty() { return Frames { .origins = [owners::Token { .slot=16, .generation=0 };256] }; }
fn bool none(owners::Token token) { return token.slot==16 && token.generation==0; }
fn bool same(owners::Token a, owners::Token b) { return a.slot==b.slot && a.generation==b.generation; }

// This private boundary requires a successfully inspected immutable Program.
// Prepay one frame cleanup reserve and one retain reserve per borrowed formal.
// Existing scalar/owned CALL prices are separate and unchanged.
pub fn Result<usize, errors::Error> cost(ref ir::Program p, usize target, usize offset) {
    if (p.function_count==0 || p.function_count>16 || target>=p.function_count ||
        p.registers>128 || p.arities[target]>8 || p.register_starts[target]>p.registers ||
        p.arities[target]>p.registers-p.register_starts[target]) { return .err(errors::make(5,offset)); }
    var usize count=0; var usize i=0; var usize seen=0; let usize one=1;
    while(i<p.arities[target]) {
        let usize r=p.register_starts[target]+i; let usize encoded=p.slice_parameters[r] as usize;
        if(encoded!=0) {
            if(encoded>16 || p.types[r]!=0 || p.slots[r] || p.array_parameters[r]!=0 || p.record_parameters[r]!=0) { return .err(errors::make(5,offset)); }
            let usize site=encoded-1;
            if(p.slice_roots[site]!=0 || p.slice_origins[site] as usize!=encoded ||
                p.slice_functions[site] as usize!=target+1 || (seen & (one<<site))!=0) { return .err(errors::make(5,offset)); }
            seen|=one<<site; count+=1;
        }
        i+=1;
    }
    return .ok(if(count==0){0}else{65537*(count+1)});
}

// A formal root binding survives closing its ticket, so retained children can
// still be authenticated and forwarded. Native root generations are preserved.
pub fn Result<owners::Token, errors::Error> root(ref ir::Program p, usize function, usize frame,
    usize site, ref Frames frames, ref arrays::State state, usize offset) {
    if(p.function_count>16 || function>=p.function_count || frame>=32 || site>=16 ||
        p.registers>128 || p.arities[function]>8 || p.register_starts[function]>p.registers ||
        p.arities[function]>p.registers-p.register_starts[function]) { return .err(errors::make(5,offset)); }
    let usize owned=p.slice_roots[site] as usize;
    if(owned!=0) {
        if(owned>16 || owned>p.arrays.count || p.array_functions[owned-1] as usize!=function ||
            p.slice_origins[site]!=0 || p.slice_functions[site]!=0) { return .err(errors::make(5,offset)); }
        return .ok(state.tokens[frame*16+owned-1]);
    }
    let usize origin=p.slice_origins[site] as usize;
    if(origin==0 || origin>16 || p.slice_functions[site] as usize!=function+1 ||
        p.slice_roots[origin-1]!=0 || p.slice_origins[origin-1] as usize!=origin ||
        p.slice_functions[origin-1]!=p.slice_functions[site]) { return .err(errors::make(5,offset)); }
    var usize i=0;
    while(i<p.arities[function]) {
        if(p.slice_parameters[p.register_starts[function]+i] as usize==origin) {
            let owners::Token token=frames.origins[frame*8+i];
            if(token.slot>=16 || token.generation==0) { return .err(errors::make(5,offset)); }
            return .ok(token);
        }
        i+=1;
    }
    return .err(errors::make(5,offset));
}
fn Result<owners::Token, errors::Error> checked(ref ir::Program p, usize function, usize frame,
    usize site, ref Frames frames, ref loans::State loan, ref arrays::State state, usize capacity, usize offset) {
    let owners::Token expected=root(p,function,frame,site,frames,state,offset)?;
    let slices::Ticket ticket=loan.tickets[frame*16+site];
    let usize length=switch(slices::length(ref loan.pool,ticket,ref state.owners,capacity)) {
        case .ok(v): { v } case .err(e): { return .err(arrays::failure(e,offset)); }
    };
    let slices::Slot entry=loan.pool.slots[ticket.slot];
    let usize owned=p.slice_roots[site] as usize;
    let u8 element=if(owned==0){10}else{p.arrays.elements[owned-1]};
    if(!same(entry.view.root,expected) || entry.view.element!=element || entry.view.length==0 || entry.view.length>4096 ||
        (owned!=0 && entry.view.length!=p.arrays.lengths[owned-1])) { return .err(errors::make(5,offset)); }
    return .ok(expected);
}

// A private, single-use plan over an immutable inspected Program. Between
// prepare and publish only the owned CALL copier may run: it preserves existing
// roots, sessions and the slice pool. Never publish after another slice mutation.
pub struct Admission {
    slices::Pool pool; slices::Ticket[8] tickets; owners::Token[8] roots;
    usize[8] sites; usize[8] positions; usize count; usize child; usize remaining;
}
pub fn Result<Admission, errors::Error> prepare(ref ir::Program p, usize pc, usize parent,
    ref Frames frames, ref loans::State loan, ref arrays::State state, ref bytes::Buffer buffer, usize fuel) {
    if(pc>=p.count || pc>=256 || p.code[pc*8]!=9) { return .err(errors::make(5,0)); }
    let usize offset=p.offsets[pc]; let usize target=p.code[pc*8+2] as usize; let usize call=p.code[pc*8+3] as usize;
    let usize work=cost(p,target,offset)?;
    if(call>=p.call_count || call>=32 || p.call_arities[call] as usize!=p.arities[target]) { return .err(errors::make(5,offset)); }
    if(fuel<work) { return .err(errors::make(8,offset)); }
    if(parent>=31) { return .err(errors::make(12,offset)); }
    var Admission plan=Admission { .pool=slices::Pool{.slots=loan.pool.slots},
        .tickets=[slices::Ticket{.slot=16,.generation=0};8],
        .roots=[owners::Token{.slot=16,.generation=0};8],.sites=[0;8],.positions=[0;8],
        .count=0,.child=parent+1,.remaining=fuel-work };
    if(work==0) { return .ok(plan); }
    var usize caller=0;
    while(caller<p.function_count && (pc<p.starts[caller] || pc>=p.ends[caller])) { caller+=1; }
    if(caller==p.function_count) { return .err(errors::make(5,offset)); }
    let usize child=parent+1; var usize i=0;
    while(i<16) {
        let slices::Ticket ticket=loan.tickets[child*16+i];
        if(ticket.slot!=16 || ticket.generation!=0) { return .err(errors::make(5,offset)); } i+=1;
    }
    i=0; while(i<8) { if(!none(frames.origins[child*8+i])) { return .err(errors::make(5,offset)); } i+=1; }
    var slices::Ticket[8] sources=[slices::Ticket { .slot=16,.generation=0 };8];
    var owners::Token[8] roots=[owners::Token { .slot=16,.generation=0 };8];
    var usize[8] sites=[0;8]; var usize[8] positions=[0;8]; var usize count=0; i=0;
    while(i<p.arities[target]) {
        let usize encoded=p.slice_parameters[p.register_starts[target]+i] as usize;
        if(encoded!=0) {
            let usize source=p.call_args[call*8+i] as usize;
            if(source<160 || source>=176) { return .err(errors::make(5,offset)); }
            roots[count]=checked(p,caller,parent,source-160,frames,loan,state,bytes::len(buffer),offset)?;
            sources[count]=loan.tickets[parent*16+source-160];
            if(loan.pool.slots[sources[count].slot].view.element!=10) { return .err(errors::make(5,offset)); }
            sites[count]=encoded-1; positions[count]=i; count+=1;
        }
        i+=1;
    }
    let slices::Arguments retained=switch(slices::borrow_arguments(ref mut plan.pool,ref sources[..count],ref state.owners,bytes::len(buffer))) {
        case .ok(v): { v } case .err(e): { return .err(arrays::failure(e,offset)); }
    };
    plan.tickets=retained.tickets; plan.roots=roots; plan.sites=sites;
    plan.positions=positions; plan.count=count;
    return .ok(plan);
}

// Infallible publication, immediately after all borrowed and owned work succeeds.
// No payload, register or return-frame work belongs after the first publication.
pub fn void publish(ref Admission plan,ref mut Frames frames,ref mut loans::State loan) {
    if(plan.count==0) { return; }
    loan.pool.slots=plan.pool.slots;
    var usize i=0; while(i<plan.count) {
        loan.tickets[plan.child*16+plan.sites[i]]=plan.tickets[i];
        frames.origins[plan.child*8+plan.positions[i]]=plan.roots[i]; i+=1;
    }
}
pub fn Result<usize, errors::Error> enter(ref ir::Program p,usize pc,usize parent,
    ref mut Frames frames,ref mut loans::State loan,ref arrays::State state,ref bytes::Buffer buffer,usize fuel) {
    let Admission plan=prepare(p,pc,parent,frames,loan,state,buffer,fuel)?;
    publish(ref plan,frames,loan);
    return .ok(plan.remaining);
}

// The fixed cleanup reserve was prepaid by a successful borrowed enter.
// Reverse static-site order is sufficient for shared read handles; every close
// is staged, so late stale/duplicate tickets cannot partially release sessions.
pub fn Result<usize, errors::Error> leave(ref ir::Program p, usize function, usize frame,
    ref mut Frames frames, ref mut loans::State loan, ref mut arrays::State state, ref bytes::Buffer buffer, usize offset) {
    let usize work=cost(p,function,offset)?;
    if(work==0 || frame==0 || frame>=32) { return .err(errors::make(5,offset)); }
    var usize i=0;
    while(i<8) {
        let owners::Token token=frames.origins[frame*8+i];
        let bool borrowed=i<p.arities[function] && p.slice_parameters[p.register_starts[function]+i]!=0;
        if(borrowed) {
            let owners::View view=switch(owners::view(ref state.owners,token,0,0,bytes::len(buffer))) {
                case .ok(v): { v } case .err(e): { return .err(arrays::failure(e,offset)); }
            };
            if(view.element!=10 || view.length==0 || view.length>4096) { return .err(errors::make(5,offset)); }
        } else if(!none(token)) { return .err(errors::make(5,offset)); }
        i+=1;
    }
    var slices::Pool planned=slices::Pool { .slots=loan.pool.slots };
    var owners::Table planned_owners=owners::Table { .slots=state.owners.slots,.order=state.owners.order,.depth=state.owners.depth,.arena=state.owners.arena };
    var usize count=0; i=16;
    while(i>0) {
        i-=1; let slices::Ticket ticket=loan.tickets[frame*16+i];
        if(ticket.generation==0) { if(ticket.slot!=16) { return .err(errors::make(5,offset)); } }
        else {
            let owners::Token expected=checked(p,function,frame,i,frames,loan,state,bytes::len(buffer),offset)?;
            let usize closed=switch(slices::close(ref mut planned,ticket,ref mut planned_owners,bytes::len(buffer))) {
                case .ok(v): { v } case .err(e): { return .err(arrays::failure(e,offset)); }
            }; count+=1;
        }
    }
    loan.pool.slots=planned.slots; state.owners.slots=planned_owners.slots;
    i=0; while(i<16) { loan.tickets[frame*16+i]=slices::Ticket { .slot=16,.generation=0 }; i+=1; }
    i=0; while(i<8) { frames.origins[frame*8+i]=owners::Token { .slot=16,.generation=0 }; i+=1; }
    return .ok(count);
}
