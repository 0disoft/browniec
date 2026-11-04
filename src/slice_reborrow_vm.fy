module slice_reborrow_vm;
import ir as ir;
import errors as errors;
import fuel as meter;
import cells as cells;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_authority as authority;
import slice_reborrow_ir as proof;
import std::bytes as bytes;

// Invocation-private site maps only; canonical Loan/Batch receipts stay in
// authority. Immutable inspected IR and its derived Sites are prerequisites.
pub struct Bindings { usize[31] parents; usize[31] children; usize[31] functions; }
pub fn Bindings empty() { return Bindings { .parents=[16;31],.children=[16;31],.functions=[16;31] }; }
fn slices::Ticket none() { return slices::Ticket { .slot=16,.generation=0 }; }
fn bool absent(slices::Ticket t) { return t.slot==16 && t.generation==0; }
fn bool same(owners::View a,owners::View b) {
    return a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element &&
        a.length==b.length && a.start==b.start && a.end==b.end;
}
fn Result<usize,errors::Error> root(ref ir::Program p,usize function,usize site,usize offset) {
    if(p.function_count>16 || function>=p.function_count || site>=16 || !ir::exclusive(p,site) ||
        p.slice_origins[site]!=0 || p.slice_functions[site]!=0 || p.slice_roots[site]==0) { return .err(errors::make(5,offset)); }
    let usize id=(p.slice_roots[site] as usize)-1;
    if(p.arrays.count>16 || id>=p.arrays.count || id>=16 || p.array_functions[id] as usize!=function || !p.arrays.mutable[id]) { return .err(errors::make(5,offset)); }
    let u8 element=ir::slice_element(p,site,offset)?;
    return .ok(id);
}
fn Result<usize,errors::Error> checked(ref ir::Program p,ref proof::Sites sites,
    ref Bindings bindings,ref authority::State receipts,ref loans::State loan,usize offset) {
    let usize depth=switch(authority::inspect(receipts)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    var usize i=0;while(i<31) {
        if(receipts.kinds[i]==2) {
            let usize c=bindings.children[i];let usize a=bindings.parents[i];let usize f=bindings.functions[i];
            if(c>=16 || a>=16 || c==a || f>=16 || sites.parents[c]!=a || !absent(loan.tickets[receipts.frames[i]*16+a])) { return .err(errors::make(5,offset)); }
            let usize child_root=root(p,f,c,offset)?;let usize parent_root=root(p,f,a,offset)?;
            if(child_root!=parent_root) { return .err(errors::make(5,offset)); }
            var usize j=0;while(j<i) {
                if(receipts.kinds[j]==2 && receipts.frames[j]==receipts.frames[i] && bindings.children[j]==c) { return .err(errors::make(5,offset)); }j+=1;
            }
        } else if(bindings.parents[i]!=16 || bindings.children[i]!=16 || bindings.functions[i]!=16) { return .err(errors::make(5,offset)); }
        i+=1;
    }
    return .ok(depth);
}
fn Result<owners::View,errors::Error> view(ref ir::Program p,ref proof::Sites sites,
    usize function,usize frame,usize site,ref Bindings bindings,ref authority::State receipts,
    ref loans::State loan,ref arrays::State state,usize capacity,usize offset) {
    let usize origin=root(p,function,site,offset)?;let slices::Ticket ticket=loan.tickets[frame*16+site];
    let usize length=switch(slices::length(ref loan.pool,ticket,ref state.owners,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    let slices::Slot entry=loan.pool.slots[ticket.slot];let owners::Token token=state.tokens[frame*16+origin];
    if(!entry.exclusive || entry.view.root.slot!=token.slot || entry.view.root.generation!=token.generation ||
        entry.view.element!=p.arrays.elements[origin] || entry.view.length!=p.arrays.lengths[origin]) { return .err(errors::make(5,offset)); }
    if(sites.parents[site]!=16) {
        var usize i=0;while(i<receipts.depth && !(receipts.frames[i]==frame && bindings.children[i]==site && bindings.functions[i]==function)) { i+=1; }
        if(i==receipts.depth || receipts.kinds[i]!=2 || receipts.children[i].issued.slot!=ticket.slot ||
            ticket.generation<receipts.children[i].issued.generation || entry.lease.generation!=receipts.children[i].parent.generation ||
            !same(entry.view,receipts.children[i].selected)) { return .err(errors::make(5,offset)); }
    }
    return .ok(entry.view);
}

// Each private transition prepays bounded authentication/publication and abort
// cleanup. A short budget fails before reading runtime tickets, bounds or maps.
// Rootless formals await canonical CALL parameter/site mapping integration.
pub fn Result<usize,errors::Error> step(ref ir::Program p,ref proof::Sites sites,usize function,usize pc,usize frame,
    ref mut Bindings bindings,ref mut authority::State receipts,ref mut loans::State loan,
    ref arrays::State state,ref bytes::Buffer buffer,ref i64[] registers,usize fuel) {
    if(pc>=p.count || pc>=256) { return .err(errors::make(5,0)); }
    let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];
    let usize child=p.code[at+1] as usize;let usize parent=p.code[at+2] as usize;
    let usize lo=p.code[at+3] as usize;let usize hi=p.code[at+4] as usize;
    if((op!=61 && op!=62) || function>=p.function_count || function>=16 || pc<p.starts[function] || pc>=p.ends[function] ||
        frame>=32 || registers.len>128 || child>=16 || parent>=16 || sites.parents[child]!=parent ||
        p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0 ||
        (op==62 && (lo!=0 || hi!=0)) || (op==61 && (lo>=registers.len || hi>=registers.len ||
        p.types[lo]!=12 || p.types[hi]!=12 || p.slots[lo] || p.slots[hi] || p.array_parameters[lo]!=0 ||
        p.array_parameters[hi]!=0 || p.record_parameters[lo]!=0 || p.record_parameters[hi]!=0 ||
        p.slice_parameters[lo]!=0 || p.slice_parameters[hi]!=0 || lo<p.register_starts[function] ||
        hi<p.register_starts[function] || lo>=p.register_ends[function] || hi>=p.register_ends[function]))) { return .err(errors::make(5,offset)); }
    let usize child_root=root(p,function,child,offset)?;let usize parent_root=root(p,function,parent,offset)?;
    if(child_root!=parent_root) { return .err(errors::make(5,offset)); }
    if(fuel<meter::slice_base(op,0)) { return .err(errors::make(8,offset)); }
    let usize depth=checked(p,sites,bindings,receipts,loan,offset)?;
    if(frame!=receipts.frame) { return .err(errors::make(5,offset)); }
    let usize c=frame*16+child;let usize a=frame*16+parent;let usize capacity=bytes::len(buffer);
    if(op==61) {
        if(depth>=31) { return .err(errors::make(12,offset)); }
        if(!absent(loan.tickets[c])) { return .err(errors::make(5,offset)); }
        var usize i=0;while(i<depth) { if(receipts.frames[i]==frame && bindings.children[i]==child) { return .err(errors::make(5,offset)); }i+=1; }
        let owners::View selected=view(p,sites,function,frame,parent,bindings,receipts,loan,state,capacity,offset)?;
        let usize start=cells::unpack(registers[lo],offset)?;let usize end=cells::unpack(registers[hi],offset)?;
        let slices::Ticket current=loan.tickets[a];
        let slices::Ticket issued=switch(authority::enter_child(receipts,ref mut loan.pool,current,ref state.owners,start,end,capacity,frame)) {
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
        bindings.parents[depth]=parent;bindings.children[depth]=child;bindings.functions[depth]=function;
        loan.tickets[a]=none();loan.tickets[c]=issued;
    } else {
        if(depth==0 || receipts.kinds[depth-1]!=2 || bindings.parents[depth-1]!=parent ||
            bindings.children[depth-1]!=child || bindings.functions[depth-1]!=function || !absent(loan.tickets[a])) { return .err(errors::make(5,offset)); }
        let owners::View selected=view(p,sites,function,frame,child,bindings,receipts,loan,state,capacity,offset)?;
        let slices::Ticket current=loan.tickets[c];
        let slices::Ticket resumed=switch(authority::leave_child(receipts,ref mut loan.pool,current,ref state.owners,capacity,frame)) {
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
        bindings.parents[depth-1]=16;bindings.children[depth-1]=16;bindings.functions[depth-1]=16;
        loan.tickets[c]=none();loan.tickets[a]=resumed;
    }
    return .ok(fuel-meter::slice_base(op,0));
}

// Invocation abort, not lexical restore. Drain first; preserve all metadata if
// cleanup fails. Earlier writes and the original result survive successful drain.
pub fn Result<i64,errors::Error> finish(ref mut Bindings bindings,ref mut authority::State receipts,
    ref mut shared::Frames frames,ref mut loans::State loan,ref mut arrays::State state,
    ref bytes::Buffer buffer,Result<i64,errors::Error> outcome) {
    var bool failed=false;var errors::Error failure=errors::make(0,0);
    let i64 value=switch(outcome){case .ok(v):{v}case .err(e):{failed=true;failure=e;0}};
    let usize closed=switch(authority::finish(receipts,ref mut loan.pool,ref mut state.owners,bytes::len(buffer))) {
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}
    };
    var usize i=0;while(i<31) { bindings.parents[i]=16;bindings.children[i]=16;bindings.functions[i]=16;i+=1; }
    i=0;while(i<512) { loan.tickets[i]=none();i+=1; }
    i=0;while(i<256) { frames.origins[i]=owners::Token{.slot=16,.generation=0};i+=1; }
    if(failed) { return .err(failure); }return .ok(value);
}
