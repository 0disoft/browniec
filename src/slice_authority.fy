module slice_authority;
import array_slices as slices;
import array_owners as owners;
import slice_handoff as handoff;
import slice_reborrow as reborrow;

// One invocation-owned canonical stack. Native callers must not clone/mutate it
// or perform unrelated rotations/session changes. It contains no guest data.
// kind: 0 empty, 1 CALL, 2 lexical child. Only one receipt is active.
pub struct Entry { handoff::Batch call; reborrow::Loan child; usize kind; usize frame; }
// Flat columns keep fixed arrays inside this one owner, avoiding nested arrays
// of Batch records. Entry is only an unpublished native staging value.
pub struct State {
    slices::Ticket[248] tickets; owners::WriteLease[248] leases;
    usize[31] counts; usize[31] reserves; reborrow::Loan[31] children;
    usize[31] kinds; usize[31] frames; usize depth; usize frame;
}
fn Entry unused() { return Entry { .call=handoff::empty(),.child=reborrow::empty(),.kind=0,.frame=0 }; }
pub fn State empty() {
    let handoff::Batch blank=handoff::empty();
    return State { .tickets=[slices::Ticket{.slot=16,.generation=0};248],.leases=[blank.leases[0];248],
        .counts=[0;31],.reserves=[0;31],.children=[reborrow::empty();31],
        .kinds=[0;31],.frames=[0;31],.depth=0,.frame=0 };
}
fn Entry get(ref State state,usize index) {
    var handoff::Batch batch=handoff::empty();var usize i=0;
    while(i<8) { batch.tickets[i]=state.tickets[index*8+i];batch.leases[i]=state.leases[index*8+i];i+=1; }
    batch.count=state.counts[index];batch.frame=state.reserves[index];
    return Entry { .call=batch,.child=state.children[index],.kind=state.kinds[index],.frame=state.frames[index] };
}
fn void put(ref mut State state,usize index,Entry entry) {
    var usize i=0;while(i<8) { state.tickets[index*8+i]=entry.call.tickets[i];state.leases[index*8+i]=entry.call.leases[i];i+=1; }
    state.counts[index]=entry.call.count;state.reserves[index]=entry.call.frame;
    state.children[index]=entry.child;state.kinds[index]=entry.kind;state.frames[index]=entry.frame;
}

// Only after cleanup has authenticated/drained the pinned pool. No receipt is
// trusted or restored here; initialize exactly one unpublished authority row.
pub fn void reset_cleanup_entry(ref mut State state,usize index){assert(index<31);put(state,index,unused());}

// Validate bounded ownership and canonical tails before touching pool metadata.
// CALLs with no writers still consume a frame and a combined-depth entry.
fn Result<usize,owners::Error> valid(ref State state) {
    if(state.depth>31 || state.frame>31) { return .err(.State); }
    var usize frames=0;var usize i=0;
    while(i<31) {
        let usize kind=state.kinds[i];let usize owner=state.frames[i];let reborrow::Loan child=state.children[i];
        let usize count=state.counts[i];let usize reserve=state.reserves[i];
        if(i>=state.depth) {
            if(kind!=0 || owner!=0 || child.active || count!=0 || reserve!=0) { return .err(.State); }
        } else if(kind==1) {
            if(owner!=frames || frames>=31 || child.active || count>8 ||
                reserve!=if(count==0){0}else{i}) { return .err(.State); }
            frames+=1;
        } else if(kind==2) {
            if(owner!=frames || !child.active || child.depth!=i || count!=0 || reserve!=0) { return .err(.State); }
        } else { return .err(.State); }
        i+=1;
    }
    if(frames!=state.frame) { return .err(.State); }
    return .ok(state.depth);
}

// Read-only admission for private adapters using this canonical receipt stack.
pub fn Result<usize,owners::Error> inspect(ref State state) { return valid(state); }

// Reserve ALL pending restores, not merely CALL frames. The receipt remains in
// this stack; only the child tickets escape to the native binding coordinator.
pub fn Result<Entry,owners::Error> prepare_call(ref State state,
    ref mut slices::Pool pool,ref slices::Ticket[] sources,ref owners::Table table,usize capacity,usize frame) {
    let usize depth=valid(state)?;
    if(frame!=state.frame || frame>=31 || depth>=31) { return .err(.State); }
    let handoff::Batch receipt=handoff::begin(pool,sources,table,capacity,depth)?;
    return .ok(Entry { .call=receipt,.child=reborrow::empty(),.kind=1,.frame=frame });
}
// Private single-use plan: state must remain unchanged between prepare/publish.
// Only atomic owned copying may intervene; it preserves existing roots/sessions.
pub fn slices::Arguments publish_call(ref mut State state,Entry plan) {
    let usize depth=state.depth;let usize frame=state.frame;
    let slices::Arguments result=slices::Arguments { .tickets=plan.call.tickets,.count=plan.call.count };
    put(state,depth,plan);state.depth=depth+1;state.frame=frame+1;
    return result;
}
pub fn Result<slices::Arguments,owners::Error> enter_call(ref mut State state,
    ref mut slices::Pool pool,ref slices::Ticket[] sources,ref owners::Table table,usize capacity,usize frame) {
    let Entry plan=prepare_call(state,pool,sources,table,capacity,frame)?;
    let slices::Arguments result=publish_call(state,plan);
    return .ok(result);
}
// Private resumable counterpart: validate/copy the return receipt before any
// staged writer rotation. The owning transaction pins this exact stack.
pub fn Result<handoff::Batch,owners::Error> prepare_leave_call(ref State state,usize frame){
    let usize depth=valid(state)?;
    if(depth==0 || frame==0 || frame!=state.frame){return .err(.State);}
    let Entry entry=get(state,depth-1);if(entry.kind!=1){return .err(.State);}
    return .ok(entry.call);
}
// Infallible only after prepare_leave_call and complete staged handoff success.
pub fn void publish_leave_call(ref mut State state){
    let usize depth=state.depth;put(state,depth-1,unused());state.depth=depth-1;state.frame-=1;
}
pub fn Result<slices::Arguments,owners::Error> leave_call(ref mut State state,
    ref mut slices::Pool pool,ref slices::Ticket[] current,ref owners::Table table,usize capacity,usize frame) {
    let usize depth=valid(state)?;
    if(depth==0 || frame==0 || frame!=state.frame) { return .err(.State); }
    let Entry entry=get(state,depth-1);
    if(entry.kind!=1) { return .err(.State); }
    var handoff::Batch receipt=entry.call;
    let slices::Arguments result=handoff::restore(pool,ref mut receipt,current,table,capacity)?;
    put(state,depth-1,unused());state.depth=depth-1;state.frame=frame-1;
    return .ok(result);
}
pub fn Result<slices::Ticket,owners::Error> enter_child(ref mut State state,
    ref mut slices::Pool pool,slices::Ticket parent,ref owners::Table table,
    usize start,usize end,usize capacity,usize frame) {
    let usize depth=valid(state)?;
    if(frame!=state.frame || depth>=31) { return .err(.State); }
    let reborrow::Loan receipt=reborrow::begin(pool,parent,table,start,end,capacity,depth)?;
    put(state,depth,Entry { .call=handoff::empty(),.child=receipt,.kind=2,.frame=frame });state.depth=depth+1;
    return .ok(receipt.issued);
}
pub fn Result<slices::Ticket,owners::Error> leave_child(ref mut State state,
    ref mut slices::Pool pool,slices::Ticket current,ref owners::Table table,usize capacity,usize frame) {
    let usize depth=valid(state)?;
    if(depth==0 || frame!=state.frame) { return .err(.State); }
    let Entry entry=get(state,depth-1);
    if(entry.kind!=2) { return .err(.State); }
    var reborrow::Loan receipt=entry.child;
    let slices::Ticket result=reborrow::restore(pool,ref mut receipt,current,table,capacity)?;
    put(state,depth-1,unused());state.depth=depth-1;
    return .ok(result);
}

// Invocation abort drains the authenticated pool first. Receipt corruption must
// not prevent safe cleanup. Failed drain preserves the entire stack and pool.
pub fn Result<usize,owners::Error> finish(ref mut State state,ref mut slices::Pool pool,
    ref mut owners::Table table,usize capacity) {
    let usize count=slices::clear(pool,table,capacity)?;
    var usize i=0;while(i<31) { put(state,i,unused());i+=1; }
    state.depth=0;state.frame=0;return .ok(count);
}
