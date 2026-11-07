module runtime_live_memory;

// Trusted synchronous Engine ledger; callers supply retained payload charges.
// No allocator, owner identity, token, synchronization or global Engine budget.
pub enum Error { Invalid; Quota; State; }
pub struct Limits { usize instance; usize instances; }
pub struct Budget {
    usize instance_limit; usize instances_limit; usize current; usize peak; bool closed;
}
pub struct Plan {
    usize old_bytes; usize new_bytes; usize peak_bytes;
    usize aggregate_before; usize aggregate_after; usize aggregate_peak;
}
pub struct Observation {
    usize instance_limit; usize instances_limit; usize current; usize peak; bool closed;
}

fn bool valid_limits(usize instance, usize instances) {
    return instance > 0 && instance <= 268435456 &&
        instances > 0 && instances <= 536870912 && instance <= instances;
}

fn bool open(ref Budget b) {
    return !b.closed && valid_limits(b.instance_limit, b.instances_limit) &&
        b.current <= b.peak && b.peak <= b.instances_limit;
}

pub fn Result<Budget,Error> create(Limits limits) {
    if (!valid_limits(limits.instance, limits.instances)) { return .err(.Invalid); }
    return .ok(Budget{.instance_limit=limits.instance, .instances_limit=limits.instances,
        .current=0, .peak=0, .closed=false});
}

// Detached scalar snapshot, including after close.
pub fn Observation observe(ref Budget b) {
    return Observation{.instance_limit=b.instance_limit, .instances_limit=b.instances_limit,
        .current=b.current, .peak=b.peak, .closed=b.closed};
}

// old_bytes is this Instance's entire retained charge, replaced by new_bytes.
// Conservative preparation peak: max(old,new) + transient. Other Instances
// remain charged throughout. Prove headroom by subtraction before every sum.
pub fn Result<Plan,Error> prepare(ref Budget b, usize old_bytes, usize new_bytes, usize transient) {
    if (!open(b) || old_bytes > b.current) { return .err(.State); }
    let usize retained_peak = if (old_bytes > new_bytes) { old_bytes } else { new_bytes };
    if (retained_peak > b.instance_limit) { return .err(.Quota); }
    if (transient > b.instance_limit - retained_peak) { return .err(.Quota); }
    let usize peak_bytes = retained_peak + transient;
    let usize others = b.current - old_bytes;
    if (peak_bytes > b.instances_limit - others) { return .err(.Quota); }
    return .ok(Plan{.old_bytes=old_bytes, .new_bytes=new_bytes, .peak_bytes=peak_bytes,
        .aggregate_before=b.current, .aggregate_after=others+new_bytes,
        .aggregate_peak=others+peak_bytes});
}

// Plans are trusted synchronous values, not guest input or owner capabilities.
// Baseline and scalar consistency checks precede all mutation. A peak-only
// record leaves the baseline intact so the same plan can subsequently commit.
fn bool applicable(ref Budget b, ref Plan p) {
    if (!open(b) || p.aggregate_before != b.current || p.old_bytes > b.current) { return false; }
    if (p.peak_bytes > b.instance_limit || p.old_bytes > p.peak_bytes ||
        p.new_bytes > p.peak_bytes) { return false; }
    let usize others = b.current - p.old_bytes;
    if (p.peak_bytes > b.instances_limit - others) { return false; }
    return p.aggregate_after == others + p.new_bytes &&
        p.aggregate_peak == others + p.peak_bytes;
}

// Record admitted reservation pressure even if a later allocation fails.
// The return value is this plan's aggregate peak, not the historical maximum.
pub fn Result<usize,Error> record(ref mut Budget b, ref Plan p) {
    if (!applicable(b, p)) { return .err(.State); }
    if (p.aggregate_peak > b.peak) { b.peak = p.aggregate_peak; }
    return .ok(p.aggregate_peak);
}

// Publish only after the caller has successfully prepared the replacement.
// Calling record first is optional; commit also retains reservation pressure.
pub fn Result<usize,Error> commit(ref mut Budget b, ref Plan p) {
    if (!applicable(b, p)) { return .err(.State); }
    b.current = p.aggregate_after;
    if (p.aggregate_peak > b.peak) { b.peak = p.aggregate_peak; }
    return .ok(b.current);
}

// Caller proves ownership. Zero-byte owners require no synthetic reservation.
pub fn Result<usize,Error> release(ref mut Budget b, usize bytes) {
    if (!open(b) || bytes > b.current) { return .err(.State); }
    b.current -= bytes;
    return .ok(b.current);
}

pub fn Result<usize,Error> close(ref mut Budget b) {
    if (!open(b) || b.current != 0) { return .err(.State); }
    b.closed = true;
    return .ok(0);
}
