module storage;

import std::bytes as bytes;

pub enum Error { Quota; Overflow; Allocation; State; NoGrowth; Provider; }
pub struct Limits { usize object; usize instance; usize engine; }
pub struct Ledger {
    usize used; usize engine_used; usize peak; usize engine_peak;
    usize pending; usize old_capacity; usize new_capacity; usize allocations;
}

// One fixed owner record is charged as 64 logical bytes, separately from payload.
pub fn Ledger empty_ledger() {
    return Ledger { .used = 64, .engine_used = 64, .peak = 64, .engine_peak = 64,
        .pending = 0, .old_capacity = 0, .new_capacity = 0, .allocations = 0 };
}

fn Result<usize, Error> rounded(usize value) {
    if (value > 18446744073709551552) { return .err(.Overflow); }
    return .ok(((value + 63) / 64) * 64);
}

fn bool fits(usize capacity, Limits limits, ref Ledger ledger) {
    if (capacity > limits.object || capacity > 18446744073709551551) { return false; }
    let usize charge = capacity + 64;
    return ledger.used <= limits.instance && ledger.engine_used <= limits.engine &&
        charge <= limits.instance - ledger.used && charge <= limits.engine - ledger.engine_used;
}

pub fn Result<usize, Error> plan(usize old_capacity, usize required, Limits limits, ref Ledger ledger) {
    if (ledger.pending != 0) { return .err(.State); }
    if (required <= old_capacity) { return .ok(old_capacity); }
    let usize minimum = rounded(required)?;
    var usize preferred = minimum;
    if (old_capacity <= 18446744073709551615 - old_capacity / 2) {
        let usize grown = old_capacity + old_capacity / 2;
        if (grown > required) {
            preferred = switch (rounded(grown)) {
                case .ok(value): { value }
                case .err(_): { minimum }
            };
        }
    }
    if (fits(preferred, limits, ledger)) { return .ok(preferred); }
    if (fits(minimum, limits, ledger)) { return .ok(minimum); }
    return .err(.Quota);
}

fn void rollback(ref mut Ledger ledger) {
    ledger.used -= ledger.pending;
    ledger.engine_used -= ledger.pending;
    ledger.pending = 0;
    ledger.old_capacity = 0;
    ledger.new_capacity = 0;
}

// Preparation preserves the old owner. The caller replaces its root before commit.
pub fn Result<bytes::Buffer, Error> prepare(ref bytes::Buffer old, usize required, Limits limits, ref mut Ledger ledger) {
    let usize old_capacity = bytes::capacity(old);
    if (ledger.used < old_capacity + 64 || ledger.engine_used < old_capacity + 64) { return .err(.State); }
    let usize capacity = plan(old_capacity, required, limits, ledger)?;
    if (capacity == old_capacity) { return .err(.NoGrowth); }
    let usize charge = capacity + 64;
    ledger.pending = charge;
    ledger.old_capacity = old_capacity;
    ledger.new_capacity = capacity;
    ledger.used += charge;
    ledger.engine_used += charge;
    if (ledger.used > ledger.peak) { ledger.peak = ledger.used; }
    if (ledger.engine_used > ledger.engine_peak) { ledger.engine_peak = ledger.engine_used; }
    ledger.allocations += 1;
    var bytes::Buffer replacement = switch (bytes::with_capacity(capacity)) {
        case .ok(value): { value }
        case .err(_): { rollback(ledger); return .err(.Allocation); }
    };
    if (bytes::capacity(ref replacement) != capacity) {
        rollback(ledger);
        return .err(.Provider);
    }
    switch (bytes::append(ref mut replacement, bytes::view(old))) {
        case .ok(_): { }
        case .err(_): { rollback(ledger); return .err(.Provider); }
    };
    return .ok(replacement);
}

// Call only after root replacement has dropped the old allocation.
pub fn Result<usize, Error> commit(usize current_capacity, ref mut Ledger ledger) {
    if (ledger.pending == 0 || current_capacity != ledger.new_capacity) { return .err(.State); }
    let usize old_charge = ledger.old_capacity + 64;
    if (ledger.used < old_charge || ledger.engine_used < old_charge) { return .err(.State); }
    ledger.used -= old_charge;
    ledger.engine_used -= old_charge;
    ledger.pending = 0;
    ledger.old_capacity = 0;
    ledger.new_capacity = 0;
    return .ok(current_capacity);
}

// Call only after a prepared replacement has been dropped without publication.
pub fn Result<usize, Error> cancel(ref mut Ledger ledger) {
    if (ledger.pending == 0) { return .err(.State); }
    rollback(ledger);
    return .ok(ledger.used);
}
