module array_slices;
import array_owners as owners;

// One bounded table for shared read and exclusive range handles. No guest pointer.
pub struct Ticket { usize slot; usize generation; }
pub struct Slot { usize generation; bool live; bool exclusive; owners::View view; owners::ReadLease lease; }
pub struct Pool { Slot[16] slots; }
// Private call-entry batch. Every result is an independent retained range ticket.
pub struct Arguments { Ticket[8] tickets; usize count; }
pub fn Arguments empty_arguments() {
    return Arguments { .tickets = [Ticket { .slot = 16, .generation = 0 }; 8], .count = 0 };
}

fn Slot fresh() {
    let owners::Token none = owners::Token { .slot = 16, .generation = 0 };
    return Slot { .generation = 1, .live = false, .exclusive = false,
        .view = owners::View { .root = none, .element = 0, .length = 0, .start = 0, .end = 0 },
        .lease = owners::ReadLease { .root = none, .generation = 0 } };
}
pub fn Pool empty() { return Pool { .slots = [fresh(); 16] }; }
fn bool same_root(owners::Token a, owners::Token b) {
    return a.slot == b.slot && a.generation == b.generation;
}
fn owners::WriteLease writer(ref Slot entry) {
    return owners::WriteLease { .view = entry.view, .generation = entry.lease.generation };
}
// Validate all retained sessions and descriptors before changing either table.
fn Result<usize, owners::Error> validate(ref Pool pool, ref owners::Table table, usize capacity) {
    var usize count = 0;
    var usize i = 0;
    while (i < 16) {
        let Slot entry = pool.slots[i];
        if (entry.live) {
            if (entry.generation == 0) { return .err(.State); }
            if (!same_root(entry.view.root, entry.lease.root)) { return .err(.Token); }
            if (entry.exclusive) {
                let owners::WriteLease lease = writer(ref entry);
                let usize length = owners::exclusive_length(table, ref lease, capacity)?;
                var usize j = 0;
                while (j < 16) {
                    if (j != i && pool.slots[j].live && same_root(pool.slots[j].view.root, entry.view.root)) { return .err(.State); }
                    j += 1;
                }
            } else { let usize length = owners::leased_length(table, entry.lease, ref entry.view, capacity)?; }
            count += 1;
        } else if (entry.exclusive) { return .err(.State); }
        i += 1;
    }
    return .ok(count);
}
// Private staged cleanup preflight; no pool or owner mutation.
pub fn Result<usize,owners::Error> inspect_cleanup(ref Pool pool,ref owners::Table table,usize capacity){return validate(pool,table,capacity);}
// Identity only. Batch admission uses this after validating the immutable pool.
fn Result<usize, owners::Error> lookup(ref Pool pool, Ticket ticket) {
    if (ticket.slot >= 16 || ticket.generation == 0) { return .err(.Token); }
    let Slot entry = pool.slots[ticket.slot];
    if (!entry.live || entry.generation != ticket.generation) { return .err(.Token); }
    return .ok(ticket.slot);
}
fn Result<usize, owners::Error> resolve(ref Pool pool, Ticket ticket, ref owners::Table table, usize capacity) {
    let usize index = lookup(pool, ticket)?;
    let usize count = validate(pool, table, capacity)?;
    return .ok(index);
}
fn Result<usize, owners::Error> free_slot(ref Pool pool) {
    var usize i = 0;
    while (i < 16) {
        let Slot entry = pool.slots[i];
        if (!entry.live && entry.generation != 0) { return .ok(i); }
        i += 1;
    }
    return .err(.Owners);
}
fn Ticket publish(ref mut Pool pool, usize index, owners::View view, owners::ReadLease lease, bool exclusive) {
    let usize generation = pool.slots[index].generation;
    pool.slots[index] = Slot { .generation = generation, .live = true, .exclusive = exclusive, .view = view, .lease = lease };
    return Ticket { .slot = index, .generation = generation };
}
fn void retire(ref mut Pool pool, usize index) {
    let usize generation = pool.slots[index].generation;
    var Slot entry = fresh();
    entry.generation = if (generation == 18446744073709551615) { 0 } else { generation + 1 };
    pool.slots[index] = entry;
}
pub fn Result<Ticket, owners::Error> open(ref mut Pool pool, ref mut owners::Table table,
    owners::Token root, usize start, usize end, usize capacity) {
    let usize count = validate(pool, table, capacity)?;
    let usize index = free_slot(pool)?;
    // Validate shape/range before acquiring a new session: failure changes nothing.
    let owners::View view = owners::view(table, root, start, end, capacity)?;
    var usize i = 0;
    while (i < 16) {
        let Slot entry = pool.slots[i];
        if (entry.live && same_root(entry.view.root, root)) {
            return .ok(publish(pool, index, view, entry.lease, false));
        }
        i += 1;
    }
    let owners::ReadLease lease = owners::begin_read(table, root, capacity)?;
    // Publication cannot fail after acquiring the sole session for this root.
    return .ok(publish(pool, index, view, lease, false));
}
pub fn Result<Ticket, owners::Error> open_exclusive(ref mut Pool pool, ref mut owners::Table table,
    owners::Token root, usize start, usize end, usize capacity) {
    let usize count = validate(pool, table, capacity)?;
    let usize index = free_slot(pool)?;
    let owners::WriteLease lease = owners::begin_write(table, root, start, end, capacity)?;
    // All admission failures precede session acquisition. Publication cannot fail.
    return .ok(publish(pool, index, lease.view,
        owners::ReadLease { .root = root, .generation = lease.generation }, true));
}
pub fn Result<Ticket, owners::Error> subslice(ref mut Pool pool, Ticket parent,
    ref owners::Table table, usize start, usize end, usize capacity) {
    let usize source = resolve(pool, parent, table, capacity)?;
    let usize index = free_slot(pool)?;
    let Slot entry = pool.slots[source];
    if (entry.exclusive) { return .err(.State); }
    let owners::View view = owners::subview(table, ref entry.view, start, end, capacity)?;
    return .ok(publish(pool, index, view, entry.lease, false));
}
pub fn Result<usize, owners::Error> length(ref Pool pool, Ticket ticket, ref owners::Table table, usize capacity) {
    let usize index = resolve(pool, ticket, table, capacity)?;
    let Slot entry = pool.slots[index];
    return .ok(entry.view.end - entry.view.start);
}
pub fn Result<i64, owners::Error> read(ref Pool pool, Ticket ticket, ref owners::Table table,
    usize index, ref u8[] bytes) {
    let usize slot = resolve(pool, ticket, table, bytes.len)?;
    let Slot entry = pool.slots[slot];
    if (entry.exclusive) {
        let owners::WriteLease lease = writer(ref entry);
        return owners::exclusive_read(table, ref lease, index, bytes);
    }
    return owners::leased_read(table, entry.lease, ref entry.view, index, bytes);
}
// Authenticate once, then read a narrowed logical window of the same lease.
// No extra pool slot/session is needed for instruction-local generic ranges.
pub fn Result<i64,owners::Error> read_window(ref Pool pool,Ticket ticket,ref owners::Table table,
    usize start,usize length,usize index,ref u8[] bytes){
    let usize slot=resolve(pool,ticket,table,bytes.len)?;let Slot entry=pool.slots[slot];
    let usize size=entry.view.end-entry.view.start;
    if(start>size || length>size-start){return .err(.State);}
    if(index>=length){return .err(.Bounds);}
    if(entry.exclusive){let owners::WriteLease lease=writer(ref entry);
        return owners::exclusive_read(table,ref lease,start+index,bytes);}
    return owners::leased_read(table,entry.lease,ref entry.view,start+index,bytes);
}
pub fn Result<bool, owners::Error> utf8(ref Pool pool, Ticket ticket, ref owners::Table table, ref u8[] bytes) {
    let usize index = resolve(pool, ticket, table, bytes.len)?;
    let Slot entry = pool.slots[index];
    if (entry.exclusive) {
        let owners::WriteLease lease = writer(ref entry);
        return owners::exclusive_utf8(table, ref lease, bytes);
    }
    return owners::leased_utf8(table, entry.lease, ref entry.view, bytes);
}
pub fn Result<usize, owners::Error> write(ref Pool pool, Ticket ticket, ref owners::Table table,
    usize index, i64 cell, ref mut u8[] bytes) {
    let usize slot = resolve(pool, ticket, table, bytes.len)?;
    let Slot entry = pool.slots[slot];
    if (!entry.exclusive) { return .err(.State); }
    let owners::WriteLease lease = writer(ref entry);
    return owners::exclusive_write(table, ref lease, index, cell, bytes);
}
// Private authority transfer within one live exclusive slot. Never resurrect a
// prior generation or end/reopen the owner session. Batch callers reserve the
// headroom required by all outstanding returns before issuing a child ticket.
pub fn Result<Ticket, owners::Error> rotate_exclusive(ref mut Pool pool, Ticket ticket,
    ref owners::Table table, usize capacity) {
    let usize index = resolve(pool, ticket, table, capacity)?;
    let Slot entry = pool.slots[index];
    if (!entry.exclusive || entry.generation == 18446744073709551615) { return .err(.State); }
    let usize generation = entry.generation + 1;
    pool.slots[index].generation = generation;
    return .ok(Ticket { .slot = index, .generation = generation });
}
pub fn Result<usize, owners::Error> close(ref mut Pool pool, Ticket ticket,
    ref mut owners::Table table, usize capacity) {
    let usize index = resolve(pool, ticket, table, capacity)?;
    return close_prepared(pool, index, table, capacity);
}
// The caller authenticated this live slot and the entire pool. Retiring one
// slot preserves every remaining descriptor: only the last reader ends its
// root session, and a validated writer has no peers. Owner end APIs still
// authenticate independently. No callback or outside mutation may intervene.
fn Result<usize, owners::Error> close_prepared(ref mut Pool pool, usize index,
    ref mut owners::Table table, usize capacity) {
    let Slot entry = pool.slots[index];
    if (entry.exclusive) {
        let owners::WriteLease lease = writer(ref entry);
        let usize ended = owners::end_write(table, ref lease, capacity)?;
        retire(pool, index);
        return .ok(index);
    }
    var usize i = 0;
    while (i < 16) {
        let Slot other = pool.slots[i];
        if (i != index && other.live && same_root(other.view.root, entry.view.root)) {
            retire(pool, index);
            return .ok(index);
        }
        i += 1;
    }
    // Keep the ticket on failure; do not unlock until the final handle closes.
    let usize ended = owners::end_read(table, entry.lease, capacity)?;
    retire(pool, index);
    return .ok(index);
}
pub fn Result<usize, owners::Error> clear(ref mut Pool pool, ref mut owners::Table table, usize capacity) {
    let usize count = validate(pool, table, capacity)?;
    // Stage metadata only. Never partially end sessions if a later root fails.
    var Pool planned = Pool { .slots = pool.slots };
    var owners::Table planned_table = owners::Table { .slots = table.slots,
        .order = table.order, .depth = table.depth, .arena = table.arena };
    var usize i = 16;
    while (i > 0) {
        i -= 1;
        let Slot entry = planned.slots[i];
        if (entry.live) {
            let usize closed = close_prepared(ref mut planned, i, ref mut planned_table, capacity)?;
        }
    }
    pool.slots = planned.slots;
    table.slots = planned_table.slots;
    return .ok(count);
}

// Validate every caller ticket against the original pool before staging children.
// A fabricated later argument must not become valid through earlier publication.
pub fn Result<Arguments, owners::Error> borrow_arguments(ref mut Pool pool,
    ref Ticket[] sources, ref owners::Table table, usize capacity) {
    if (sources.len > 8) { return .err(.Length); }
    let usize checked = validate(pool, table, capacity)?;
    var usize i = 0;
    while (i < sources.len) {
        let usize source = lookup(pool, sources[i])?;
        if (pool.slots[source].exclusive) { return .err(.State); }
        i += 1;
    }
    var Pool planned = Pool { .slots = pool.slots };
    var Arguments result = empty_arguments();
    i = 0;
    while (i < sources.len) {
        let usize index = free_slot(ref planned)?;
        // Every source belongs to the validated ORIGINAL pool. Whole-range
        // cloning preserves its root-relative bounds and shared read epoch.
        // Publishing children changes neither original slots nor owner state.
        let Slot entry = pool.slots[sources[i].slot];
        let Ticket child = publish(ref mut planned, index, entry.view, entry.lease, false);
        result.tickets[i] = child;
        i += 1;
    }
    let usize count = sources.len;
    result.count = count;
    pool.slots = planned.slots;
    return .ok(result);
}

// Consume only the batch's handles in reverse order, staging all metadata first.
// Caller/peer handles survive; a late failure leaves the batch and tables intact.
pub fn Result<usize, owners::Error> close_arguments(ref mut Pool pool,
    ref mut Arguments arguments, ref mut owners::Table table, usize capacity) {
    if (arguments.count > 8) { return .err(.Length); }
    var usize i = 0;
    while (i < 8) {
        let Ticket ticket = arguments.tickets[i];
        if (i < arguments.count) {
            if (ticket.slot >= 16 || ticket.generation == 0) { return .err(.Token); }
            if (pool.slots[ticket.slot].exclusive) { return .err(.State); }
            var usize j = 0;
            while (j < i) {
                if (arguments.tickets[j].slot == ticket.slot) { return .err(.State); }
                j += 1;
            }
        } else if (ticket.slot != 16 || ticket.generation != 0) { return .err(.State); }
        i += 1;
    }
    let usize checked = validate(pool, table, capacity)?;
    var Pool planned = Pool { .slots = pool.slots };
    var owners::Table planned_table = owners::Table { .slots = table.slots,
        .order = table.order, .depth = table.depth, .arena = table.arena };
    let usize count = arguments.count;
    i = count;
    while (i > 0) {
        i -= 1;
        // Stale batch tickets retain their original reverse-order error point.
        let usize index = lookup(ref planned, arguments.tickets[i])?;
        let usize closed = close_prepared(ref mut planned, index, ref mut planned_table, capacity)?;
    }
    pool.slots = planned.slots;
    table.slots = planned_table.slots;
    arguments.tickets = [Ticket { .slot = 16, .generation = 0 }; 8];
    arguments.count = 0;
    return .ok(count);
}
