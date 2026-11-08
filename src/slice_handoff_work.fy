module slice_handoff_work;
import array_slices as slices;
import array_owners as owners;
import slice_handoff as handoff;

// Private work only: the caller pins the original pool, owner table and inputs
// until completion, and publishes the result as one separate transaction.
pub struct State {
    slices::Pool planned; handoff::Batch batch; slices::Arguments returned;
    slices::Ticket[8] inputs; usize count; usize frame; usize at;
    u8 mode; u8 phase; bool active; bool done; usize total; usize last;
}
fn slices::Ticket none() { return slices::Ticket { .slot=16,.generation=0 }; }
pub fn State empty() {
    return State { .planned=slices::empty(),.batch=handoff::empty(),.returned=slices::empty_arguments(),
        .inputs=[none();8],.count=0,.frame=0,.at=0,.mode=0,.phase=0,
        .active=false,.done=false,.total=0,.last=0 };
}
fn bool root(owners::Token a,owners::Token b) { return a.slot==b.slot && a.generation==b.generation; }
fn bool same(ref owners::WriteLease expected,ref slices::Slot entry) {
    return entry.exclusive && entry.lease.generation==expected.generation &&
        root(entry.view.root,expected.view.root) && entry.view.element==expected.view.element &&
        entry.view.length==expected.view.length && entry.view.start==expected.view.start && entry.view.end==expected.view.end;
}
fn bool unused(slices::Ticket ticket,ref owners::WriteLease lease) {
    return ticket.slot==16 && ticket.generation==0 && lease.generation==0 &&
        lease.view.root.slot==16 && lease.view.root.generation==0 && lease.view.element==0 &&
        lease.view.length==0 && lease.view.start==0 && lease.view.end==0;
}

pub fn Result<usize,owners::Error> start_enter(ref mut State w,ref slices::Pool original,ref slices::Ticket[] sources,usize frame) {
    if(sources.len>8) { return .err(.Length); }
    if(frame>=31) { return .err(.State); }
    if(w.active) { return .err(.State); }
    let State fresh=empty();*w=fresh;w.planned=*original;w.count=sources.len;w.frame=frame;w.mode=1;w.phase=1;w.active=true;
    var usize i=0;while(i<sources.len) { w.inputs[i]=sources[i];i+=1; }
    return .ok(sources.len);
}
pub fn Result<usize,owners::Error> start_restore(ref mut State w,ref slices::Pool original,ref handoff::Batch batch,ref slices::Ticket[] current) {
    if(batch.count>8 || current.len!=batch.count) { return .err(.Length); }
    if(batch.frame>=31 || (batch.count==0 && batch.frame!=0)) { return .err(.State); }
    if(w.active) { return .err(.State); }
    let State fresh=empty();*w=fresh;w.planned=*original;w.batch=*batch;w.count=current.len;w.frame=batch.frame;w.mode=2;w.phase=1;w.active=true;
    var usize i=0;while(i<current.len) { w.inputs[i]=current[i];i+=1; }
    return .ok(current.len);
}
fn Result<usize,owners::Error> check_enter(ref mut State w,ref slices::Pool original,ref owners::Table table,usize capacity,usize i) {
    let slices::Ticket source=w.inputs[i];let usize n=slices::length(original,source,table,capacity)?;
    let slices::Slot entry=original.slots[source.slot];
    if(!entry.exclusive || entry.generation>18446744073709551615-(w.frame+2)) { return .err(.State); }
    var usize j=0;while(j<i) {
        if(w.inputs[j].slot==source.slot || root(w.batch.leases[j].view.root,entry.view.root)) { return .err(.State); }
        j+=1;
    }
    w.batch.leases[i]=owners::WriteLease { .view=entry.view,.generation=entry.lease.generation };
    return .ok(i);
}
fn Result<usize,owners::Error> check_restore(ref State w,ref slices::Pool original,ref owners::Table table,usize capacity,usize i) {
    let slices::Ticket issued=w.batch.tickets[i];
    if(i>=w.count) { if(!unused(issued,ref w.batch.leases[i])) { return .err(.State); } return .ok(i); }
    let slices::Ticket current=w.inputs[i];
    if(issued.slot>=16 || issued.generation==0 || current.slot!=issued.slot || current.generation<issued.generation) { return .err(.Token); }
    let usize n=slices::length(original,current,table,capacity)?;let slices::Slot entry=original.slots[current.slot];
    if(!same(ref w.batch.leases[i],ref entry) || entry.generation>18446744073709551615-(w.frame+1)) { return .err(.State); }
    var usize j=0;while(j<i) { if(w.inputs[j].slot==current.slot) { return .err(.State); } j+=1; }
    return .ok(i);
}

// One action checks one original (including one unused receipt tail), rotates
// one already checked input, or completes an empty enter. Each action has a
// conservative 2048 metadata-entry budget; at most two actions run per step.
pub fn Result<bool,owners::Error> advance(ref mut State w,ref slices::Pool original,ref owners::Table table,usize capacity,usize allowance) {
    w.last=0;
    if(!w.active || w.done || allowance==0 || allowance>2 || (w.mode!=1 && w.mode!=2) || (w.phase!=1 && w.phase!=2)) { return .err(.State); }
    while(w.last<allowance && !w.done) {
        if(w.total==18446744073709551615) { return .err(.Overflow); }
        // Charge the action actually being attempted, including a failed check.
        w.last+=1;w.total+=1;
        if(w.phase==1) {
            if(w.mode==1 && w.count==0) { w.batch.count=0;w.batch.frame=0;w.done=true;w.active=false; }
            else {
                let usize i=w.at;
                if(w.mode==1) { let usize checked=check_enter(w,original,table,capacity,i)?; }
                else { let usize checked=check_restore(w,original,table,capacity,i)?; }
                w.at+=1;
                if((w.mode==1 && w.at==w.count) || (w.mode==2 && w.at==8)) {
                    w.phase=2;w.at=if(w.mode==1){0}else{w.count};
                    if(w.count==0) { w.returned.count=0;w.batch=handoff::empty();w.done=true;w.active=false; }
                }
            }
        } else {
            let usize i=if(w.mode==1){w.at}else{w.at-1};
            let slices::Ticket input=w.inputs[i];
            let slices::Ticket rotated=slices::rotate_exclusive(ref mut w.planned,input,table,capacity)?;
            if(w.mode==1) { w.batch.tickets[i]=rotated;w.at+=1; }
            else { w.returned.tickets[i]=rotated;w.at-=1; }
            if((w.mode==1 && w.at==w.count) || (w.mode==2 && w.at==0)) {
                if(w.mode==1) { w.batch.count=w.count;w.batch.frame=w.frame; }
                else { w.returned.count=w.count;w.batch=handoff::empty(); }
                w.done=true;w.active=false;
            }
        }
    }
    return .ok(w.done);
}
