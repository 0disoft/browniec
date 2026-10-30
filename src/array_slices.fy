module array_slices;
import array_owners as owners;

// Private table-local shared read handles. No guest pointer or payload ownership.
pub struct Ticket { usize slot; usize generation; }
pub struct Slot { usize generation; bool live; owners::View view; owners::ReadLease lease; }
pub struct Pool { Slot[16] slots; }

fn Slot fresh() {
    let owners::Token none = owners::Token { .slot = 16, .generation = 0 };
    return Slot { .generation = 1, .live = false,
        .view = owners::View { .root = none, .element = 0, .length = 0, .start = 0, .end = 0 },
        .lease = owners::ReadLease { .root = none, .generation = 0 } };
}
pub fn Pool empty() { return Pool { .slots = [fresh(); 16] }; }
fn bool same_root(owners::Token a, owners::Token b) {
    return a.slot == b.slot && a.generation == b.generation;
}
// Validate all retained sessions and descriptors before changing either table.
fn Result<usize, owners::Error> validate(ref Pool pool, ref owners::Table table, usize capacity) {
    var usize count = 0;
    var usize i = 0;
    while (i < 16) {
        let Slot entry = pool.slots[i];
        if (entry.live) {
            if (entry.generation == 0) { return .err(.State); }
            let usize length = owners::leased_length(table, entry.lease, ref entry.view, capacity)?;
            count += 1;
        }
        i += 1;
    }
    return .ok(count);
}
fn Result<usize, owners::Error> resolve(ref Pool pool, Ticket ticket, ref owners::Table table, usize capacity) {
    if (ticket.slot >= 16 || ticket.generation == 0) { return .err(.Token); }
    let Slot entry = pool.slots[ticket.slot];
    if (!entry.live || entry.generation != ticket.generation) { return .err(.Token); }
    let usize count = validate(pool, table, capacity)?;
    return .ok(ticket.slot);
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
fn Ticket publish(ref mut Pool pool, usize index, owners::View view, owners::ReadLease lease) {
    let usize generation = pool.slots[index].generation;
    pool.slots[index] = Slot { .generation = generation, .live = true, .view = view, .lease = lease };
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
            return .ok(publish(pool, index, view, entry.lease));
        }
        i += 1;
    }
    let owners::ReadLease lease = owners::begin_read(table, root, capacity)?;
    // Publication cannot fail after acquiring the sole session for this root.
    return .ok(publish(pool, index, view, lease));
}
pub fn Result<Ticket, owners::Error> subslice(ref mut Pool pool, Ticket parent,
    ref owners::Table table, usize start, usize end, usize capacity) {
    let usize source = resolve(pool, parent, table, capacity)?;
    let usize index = free_slot(pool)?;
    let Slot entry = pool.slots[source];
    let owners::View view = owners::subview(table, ref entry.view, start, end, capacity)?;
    return .ok(publish(pool, index, view, entry.lease));
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
    return owners::leased_read(table, entry.lease, ref entry.view, index, bytes);
}
pub fn Result<bool, owners::Error> utf8(ref Pool pool, Ticket ticket, ref owners::Table table, ref u8[] bytes) {
    let usize index = resolve(pool, ticket, table, bytes.len)?;
    let Slot entry = pool.slots[index];
    return owners::leased_utf8(table, entry.lease, ref entry.view, bytes);
}
pub fn Result<usize, owners::Error> close(ref mut Pool pool, Ticket ticket,
    ref mut owners::Table table, usize capacity) {
    let usize index = resolve(pool, ticket, table, capacity)?;
    let Slot entry = pool.slots[index];
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
            let usize closed = close(ref mut planned, Ticket { .slot = i, .generation = entry.generation },
                ref mut planned_table, capacity)?;
        }
    }
    pool.slots = planned.slots;
    table.slots = planned_table.slots;
    return .ok(count);
}
