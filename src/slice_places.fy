module slice_places;

import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_storage as storage;

// Invocation-private metadata. The canonical coordinator supplies the current
// binding after completed CALL/reborrow restoration; never discover a newer
// ticket from the pool or resurrect a suspended binding from this snapshot.
pub struct Place {
    owners::WriteLease lease; slices::Ticket ticket;
    usize mark; usize base; usize end; usize index; usize offset;
}

// Authenticate the whole pool/session and original range without reading data.
// index is relative to this view, not to its root or a later binding's range.
pub fn Result<Place,owners::Error> select(ref slices::Pool pool,slices::Ticket ticket,
    ref owners::Table table,usize index,usize capacity) {
    let usize length=slices::length(pool,ticket,table,capacity)?;
    let slices::Slot entry=pool.slots[ticket.slot];
    if(!entry.exclusive){return .err(.State);}
    if(index>=length){return .err(.Bounds);}
    let owners::Owner owner=table.slots[entry.view.root.slot];
    let layouts::Array layout=switch(layouts::scalar(entry.view.element,entry.view.length)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    let usize offset=switch(layouts::offset(ref layout,owner.base,entry.view.start+index,table.arena.used)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    return .ok(Place{.lease=owners::WriteLease{.view=entry.view,.generation=entry.lease.generation},
        .ticket=ticket,.mark=owner.mark,.base=owner.base,.end=owner.end,.index=index,.offset=offset});
}

// Ticket generations may advance within the SAME exclusive session. Owner
// epoch and the exact restored range must still agree: closing/reopening a
// session or using a still narrowed child cannot redirect the selected target.
fn Result<layouts::Array,owners::Error> validate(ref slices::Pool pool,slices::Ticket current,
    ref owners::Table table,ref Place place,usize capacity) {
    if(place.ticket.slot>=16 || place.ticket.generation==0 || current.slot!=place.ticket.slot ||
        current.generation<place.ticket.generation){return .err(.Token);}
    let Place now=select(pool,current,table,place.index,capacity)?;
    let owners::View a=place.lease.view;let owners::View b=now.lease.view;
    if(a.root.slot!=b.root.slot || a.root.generation!=b.root.generation){return .err(.Token);}
    if(a.element!=b.element){return .err(.Type);}
    if(a.length!=b.length){return .err(.Length);}
    if(place.lease.generation!=now.lease.generation || a.start!=b.start || a.end!=b.end ||
        place.mark!=now.mark || place.base!=now.base || place.end!=now.end || place.offset!=now.offset){return .err(.State);}
    return switch(layouts::scalar(a.element,a.length)){
        case .ok(v):{.ok(v)}case .err(_):{.err(.State)}
    };
}
fn owners::Error failure(storage::Error error) {
    return switch(error){
        case .Type:{.Type}case .Length:{.Length}case .Metadata:{.Metadata}
        case .Overflow:{.Overflow}case .Quota:{.Quota}case .Bounds:{.Bounds}
        case .Alignment:{.Alignment}case .Value:{.Value}case .State:{.State}
    };
}
pub fn Result<i64,owners::Error> read(ref slices::Pool pool,slices::Ticket current,
    ref owners::Table table,ref Place place,ref u8[] bytes) {
    let layouts::Array layout=validate(pool,current,table,place,bytes.len)?;
    return switch(storage::read(ref layout,place.base,place.lease.view.start+place.index,bytes,ref table.arena)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };
}
// The existing codec stages <=8 bytes. No owner, pool or snapshot is mutated;
// failed validation/encoding leaves all backing bytes unchanged.
pub fn Result<usize,owners::Error> store(ref slices::Pool pool,slices::Ticket current,
    ref owners::Table table,ref Place place,i64 cell,ref mut u8[] bytes) {
    let layouts::Array layout=validate(pool,current,table,place,bytes.len)?;
    return switch(storage::write(ref layout,place.base,place.lease.view.start+place.index,cell,bytes,ref table.arena)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };
}
