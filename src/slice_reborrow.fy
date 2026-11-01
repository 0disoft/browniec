module slice_reborrow;
import array_slices as slices;
import array_owners as owners;

// Invocation-private, linear receipt. The coordinator retains one per pending
// restoration, never clones it and supplies the latest ticket after nested work.
// No Program, owner, pool-slot or payload fields grow.
pub struct Loan {
    owners::WriteLease parent;
    owners::View selected;
    slices::Ticket issued;
    usize depth;
    bool active;
}
fn owners::View none() {
    return owners::View { .root=owners::Token { .slot=16,.generation=0 },
        .element=0,.length=0,.start=0,.end=0 };
}
pub fn Loan empty() {
    return Loan { .parent=owners::WriteLease { .view=none(),.generation=0 },
        .selected=none(),.issued=slices::Ticket { .slot=16,.generation=0 },.depth=0,.active=false };
}
fn bool same(owners::View a,owners::View b) {
    return a.root.slot==b.root.slot && a.root.generation==b.root.generation &&
        a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end;
}

// depth counts ALL outstanding authority restorations, not only VM CALL frames.
// Reserve the child rotation and every ancestor's return before publication.
// Bounds are relative to the parent's currently selected range, including empty.
pub fn Result<Loan,owners::Error> begin(ref mut slices::Pool pool,slices::Ticket parent,
    ref owners::Table table,usize start,usize end,usize capacity,usize depth) {
    if(depth>=31) { return .err(.State); }
    let usize length=slices::length(pool,parent,table,capacity)?;
    let slices::Slot entry=pool.slots[parent.slot];
    if(!entry.exclusive) { return .err(.State); }
    if(start>end || end>length) { return .err(.Bounds); }
    if(entry.generation>18446744073709551615-(depth+2)) { return .err(.State); }
    // The range check proves both sums fit within the original owner length.
    let owners::View child=owners::View { .root=entry.view.root,.element=entry.view.element,
        .length=entry.view.length,.start=entry.view.start+start,.end=entry.view.start+end };
    let slices::Ticket issued=slices::Ticket { .slot=parent.slot,.generation=parent.generation+1 };
    let Loan receipt=Loan { .parent=owners::WriteLease { .view=entry.view,.generation=entry.lease.generation },
        .selected=child,.issued=issued,.depth=depth,.active=true };
    pool.slots[parent.slot].view=child;
    pool.slots[parent.slot].generation=issued.generation;
    return .ok(receipt);
}

pub fn Result<slices::Ticket,owners::Error> restore(ref mut slices::Pool pool,ref mut Loan loan,
    slices::Ticket current,ref owners::Table table,usize capacity) {
    if(!loan.active || loan.depth>=31) { return .err(.State); }
    if(loan.issued.slot>=16 || loan.issued.generation==0 || current.slot!=loan.issued.slot ||
        current.generation<loan.issued.generation) { return .err(.Token); }
    let usize original=owners::exclusive_length(table,ref loan.parent,capacity)?;
    let owners::View parent=loan.parent.view;
    let owners::View selected=loan.selected;
    if(selected.root.slot!=parent.root.slot || selected.root.generation!=parent.root.generation ||
        selected.element!=parent.element || selected.length!=parent.length || selected.start<parent.start ||
        selected.start>selected.end || selected.end>parent.end) { return .err(.State); }
    let usize length=slices::length(pool,current,table,capacity)?;
    let slices::Slot entry=pool.slots[current.slot];
    if(!entry.exclusive || !same(entry.view,selected) || entry.lease.generation!=loan.parent.generation ||
        entry.generation>18446744073709551615-(loan.depth+1)) { return .err(.State); }
    let slices::Ticket resumed=slices::Ticket { .slot=current.slot,.generation=current.generation+1 };
    pool.slots[current.slot].view=parent;
    pool.slots[current.slot].generation=resumed.generation;
    let Loan cleared=empty();
    loan.parent=cleared.parent;loan.selected=cleared.selected;loan.issued=cleared.issued;
    loan.depth=0;loan.active=false;
    return .ok(resumed);
}

// Invocation abort, not a lexical child close. Drain the selected active slot,
// then discard suspended receipts. Failed drain preserves both pool and receipts.
pub fn Result<usize,owners::Error> finish(ref mut slices::Pool pool,ref mut Loan[] loans,
    ref mut owners::Table table,usize capacity) {
    if(loans.len>32) { return .err(.Length); }
    let usize count=slices::clear(pool,table,capacity)?;
    var usize i=0;
    while(i<loans.len) { loans[i]=empty(); i+=1; }
    return .ok(count);
}
