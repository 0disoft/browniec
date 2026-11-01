module slice_handoff;
import array_slices as slices;
import array_owners as owners;

// Private, invocation-local CALL receipt. No Program or pool-slot fields grow.
// The trusted caller keeps one receipt per active CALL, updates callee bindings
// after nested returns, and never clones receipts or mutates pool sessions.
pub struct Batch { slices::Ticket[8] tickets; owners::WriteLease[8] leases; usize count; usize frame; }
fn owners::WriteLease none() {
    return owners::WriteLease { .view=owners::View { .root=owners::Token { .slot=16,.generation=0 },
        .element=0,.length=0,.start=0,.end=0 },.generation=0 };
}
pub fn Batch empty() {
    return Batch { .tickets=[slices::Ticket { .slot=16,.generation=0 };8],.leases=[none();8],.count=0,.frame=0 };
}
fn bool same(ref owners::WriteLease expected, ref slices::Slot entry) {
    return entry.exclusive && entry.lease.generation==expected.generation &&
        entry.view.root.slot==expected.view.root.slot && entry.view.root.generation==expected.view.root.generation &&
        entry.view.element==expected.view.element && entry.view.length==expected.view.length &&
        entry.view.start==expected.view.start && entry.view.end==expected.view.end;
}
fn bool unused(slices::Ticket ticket,ref owners::WriteLease lease) {
    return ticket.slot==16 && ticket.generation==0 && lease.generation==0 &&
        lease.view.root.slot==16 && lease.view.root.generation==0 && lease.view.element==0 &&
        lease.view.length==0 && lease.view.start==0 && lease.view.end==0;
}

// frame is the current caller's zero-based VM depth, 0..30. The admitted child
// needs one new ticket now plus one return per outstanding ancestor. This is a
// conservative reserve even when some ancestors do not borrow this root.
pub fn Result<Batch,owners::Error> begin(ref mut slices::Pool pool,ref slices::Ticket[] sources,
    ref owners::Table table,usize capacity,usize frame) {
    if(sources.len>8) { return .err(.Length); }
    if(frame>=31) { return .err(.State); }
    var Batch result=empty();
    // Resolve every original input before staging rotations. A guessed later
    // ticket must not become valid because an earlier argument advanced a slot.
    var usize i=0;
    while(i<sources.len) {
        let usize length=slices::length(pool,sources[i],table,capacity)?;
        let slices::Slot entry=pool.slots[sources[i].slot];
        if(!entry.exclusive || entry.generation>18446744073709551615-(frame+2)) { return .err(.State); }
        var usize j=0;
        while(j<i) {
            if(sources[j].slot==sources[i].slot ||
                (result.leases[j].view.root.slot==entry.view.root.slot && result.leases[j].view.root.generation==entry.view.root.generation)) { return .err(.State); }
            j+=1;
        }
        result.leases[i]=owners::WriteLease { .view=entry.view,.generation=entry.lease.generation };
        i+=1;
    }
    var slices::Pool planned=slices::Pool { .slots=pool.slots };
    i=0;
    while(i<sources.len) {
        result.tickets[i]=slices::rotate_exclusive(ref mut planned,sources[i],table,capacity)?;
        i+=1;
    }
    result.count=sources.len;result.frame=if(sources.len==0){0}else{frame};
    pool.slots=planned.slots;
    return .ok(result);
}

// current contains the callee's latest authoritative tickets in argument order,
// including replacements returned by nested CALLs. Publish fresh caller tickets
// only after every receipt/session and generation reserve has been checked.
pub fn Result<slices::Arguments,owners::Error> restore(ref mut slices::Pool pool,ref mut Batch batch,
    ref slices::Ticket[] current,ref owners::Table table,usize capacity) {
    if(batch.count>8 || current.len!=batch.count) { return .err(.Length); }
    if(batch.frame>=31 || (batch.count==0 && batch.frame!=0)) { return .err(.State); }
    var usize i=0;
    while(i<8) {
        let slices::Ticket issued=batch.tickets[i];
        if(i<batch.count) {
            if(issued.slot>=16 || issued.generation==0 || current[i].slot!=issued.slot ||
                current[i].generation<issued.generation) { return .err(.Token); }
            let usize length=slices::length(pool,current[i],table,capacity)?;
            let slices::Slot entry=pool.slots[current[i].slot];
            if(!same(ref batch.leases[i],ref entry) || entry.generation>18446744073709551615-(batch.frame+1)) { return .err(.State); }
            var usize j=0;while(j<i){if(current[j].slot==current[i].slot){return .err(.State);}j+=1;}
        } else if(!unused(issued,ref batch.leases[i])) { return .err(.State); }
        i+=1;
    }
    var slices::Pool planned=slices::Pool { .slots=pool.slots };
    var slices::Arguments result=slices::empty_arguments();
    i=batch.count;
    while(i>0) {
        i-=1;result.tickets[i]=slices::rotate_exclusive(ref mut planned,current[i],table,capacity)?;
    }
    result.count=batch.count;
    pool.slots=planned.slots;
    batch.tickets=[slices::Ticket { .slot=16,.generation=0 };8];batch.leases=[none();8];batch.count=0;batch.frame=0;
    return .ok(result);
}
