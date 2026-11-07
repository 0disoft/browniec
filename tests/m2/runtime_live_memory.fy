module tests::m2::runtime_live_memory;
import runtime_live_memory as memory;

fn u8 code(memory::Error error) {
    return switch (error) {
        case .Invalid: { 1 } case .Quota: { 2 } case .State: { 3 }
    };
}

fn memory::Budget budget(usize instance, usize instances) {
    return switch (memory::create(memory::Limits{.instance=instance, .instances=instances})) {
        case .ok(b): { b }
        case .err(_): {
            assert(false);
            memory::Budget{.instance_limit=1, .instances_limit=1, .current=0, .peak=0, .closed=false}
        }
    };
}

fn memory::Plan plan(ref memory::Budget b, usize old, usize next, usize transient) {
    return switch (memory::prepare(b, old, next, transient)) {
        case .ok(p): { p }
        case .err(_): {
            assert(false);
            memory::Plan{.old_bytes=0, .new_bytes=0, .peak_bytes=0,
                .aggregate_before=0, .aggregate_after=0, .aggregate_peak=0}
        }
    };
}

fn void value(Result<usize,memory::Error> result, usize expected) {
    switch (result) {
        case .ok(actual): { assert(actual == expected); }
        case .err(_): { assert(false); }
    };
}

fn void rejected(Result<usize,memory::Error> result, u8 expected) {
    switch (result) {
        case .ok(_): { assert(false); }
        case .err(error): { assert(code(error) == expected); }
    };
}

fn void prep_rejected(ref memory::Budget b, usize old, usize next, usize transient, u8 expected) {
    let memory::Observation before = memory::observe(b);
    switch (memory::prepare(b, old, next, transient)) {
        case .ok(_): { assert(false); }
        case .err(error): { assert(code(error) == expected); }
    };
    unchanged(b, ref before);
}

fn void state(ref memory::Budget b, usize current, usize peak, bool closed) {
    let memory::Observation o = memory::observe(b);
    assert(o.current == current && o.peak == peak && o.closed == closed);
}

fn void unchanged(ref memory::Budget b, ref memory::Observation before) {
    let memory::Observation after = memory::observe(b);
    assert(after.instance_limit == before.instance_limit);
    assert(after.instances_limit == before.instances_limit);
    assert(after.current == before.current && after.peak == before.peak && after.closed == before.closed);
}

fn void invalid(usize instance, usize instances) {
    switch (memory::create(memory::Limits{.instance=instance, .instances=instances})) {
        case .ok(_): { assert(false); }
        case .err(error): { assert(code(error) == 1); }
    };
}

@test
fn void limits_caps_and_detached_flat_observation() {
    invalid(0, 0); invalid(0, 1); invalid(1, 0); invalid(2, 1);
    invalid(268435457, 536870912); invalid(268435456, 536870913);
    invalid(18446744073709551615, 536870912);
    invalid(1, 18446744073709551615);
    let memory::Budget small = budget(1, 1);
    state(ref small, 0, 0, false);
    var memory::Budget b = budget(268435456, 536870912);
    let memory::Observation detached = memory::observe(ref b);
    assert(detached.instance_limit == 268435456 && detached.instances_limit == 536870912);
    let memory::Plan p = plan(ref b, 0, 1, 0);
    value(memory::commit(ref mut b, ref p), 1);
    assert(detached.current == 0 && detached.peak == 0 && !detached.closed);
    state(ref b, 1, 1, false);
}

@test
fn void per_instance_exact_and_one_less_include_transient() {
    var memory::Budget exact = budget(10, 30);
    let memory::Budget short = budget(9, 30);
    let memory::Plan p = plan(ref exact, 0, 7, 3);
    assert(p.old_bytes == 0 && p.new_bytes == 7 && p.peak_bytes == 10);
    assert(p.aggregate_before == 0 && p.aggregate_after == 7 && p.aggregate_peak == 10);
    state(ref exact, 0, 0, false);
    prep_rejected(ref short, 0, 7, 3, 2);
    prep_rejected(ref exact, 0, 11, 0, 2);
    value(memory::commit(ref mut exact, ref p), 7);
    let memory::Plan shrink = plan(ref exact, 7, 2, 3);
    assert(shrink.peak_bytes == 10 && shrink.aggregate_after == 2);
    prep_rejected(ref exact, 7, 2, 4, 2);
    value(memory::commit(ref mut exact, ref shrink), 2);
    state(ref exact, 2, 10, false);
}

@test
fn void aggregate_exact_and_one_less_preserve_peer_charges() {
    var memory::Budget exact = budget(10, 15);
    var memory::Budget short = budget(10, 14);
    let memory::Plan peer = plan(ref exact, 0, 5, 0);
    value(memory::commit(ref mut exact, ref peer), 5);
    let memory::Plan peer_short = plan(ref short, 0, 5, 0);
    value(memory::commit(ref mut short, ref peer_short), 5);
    let memory::Plan p = plan(ref exact, 0, 8, 2);
    assert(p.aggregate_before == 5 && p.aggregate_after == 13 && p.aggregate_peak == 15);
    prep_rejected(ref short, 0, 8, 2, 2);
    value(memory::commit(ref mut exact, ref p), 13);
    let memory::Plan replace = plan(ref exact, 8, 9, 1);
    assert(replace.aggregate_after == 14 && replace.aggregate_peak == 15);
    value(memory::commit(ref mut exact, ref replace), 14);
    value(memory::release(ref mut exact, 9), 5);
    state(ref exact, 5, 15, false);
}

@test
fn void replacement_grows_shrinks_and_removes_only_old_owner() {
    var memory::Budget b = budget(20, 30);
    let memory::Plan seed = plan(ref b, 0, 10, 0);
    value(memory::commit(ref mut b, ref seed), 10);
    let memory::Plan peer = plan(ref b, 0, 4, 0);
    value(memory::commit(ref mut b, ref peer), 14);
    let memory::Plan grow = plan(ref b, 10, 15, 5);
    assert(grow.peak_bytes == 20 && grow.aggregate_after == 19 && grow.aggregate_peak == 24);
    value(memory::commit(ref mut b, ref grow), 19);
    let memory::Plan shrink = plan(ref b, 15, 6, 3);
    assert(shrink.peak_bytes == 18 && shrink.aggregate_after == 10 && shrink.aggregate_peak == 22);
    value(memory::commit(ref mut b, ref shrink), 10);
    state(ref b, 10, 24, false);
    let memory::Plan same = plan(ref b, 6, 6, 0);
    value(memory::commit(ref mut b, ref same), 10);
    let memory::Plan remove = plan(ref b, 6, 0, 0);
    assert(remove.aggregate_after == 4 && remove.aggregate_peak == 10);
    value(memory::commit(ref mut b, ref remove), 4);
    value(memory::release(ref mut b, 4), 0);
    state(ref b, 0, 24, false);
}

@test
fn void prepare_failure_recorded_failed_allocation_and_commit_are_distinct() {
    var memory::Budget b = budget(16, 24);
    let memory::Plan seed = plan(ref b, 0, 4, 0);
    value(memory::commit(ref mut b, ref seed), 4);
    let memory::Observation before = memory::observe(ref b);
    let memory::Plan p = plan(ref b, 4, 9, 7);
    unchanged(ref b, ref before);
    prep_rejected(ref b, 4, 9, 8, 2);
    prep_rejected(ref b, 5, 0, 0, 3);
    // An admitted allocation fails: retain peak pressure, not new live bytes.
    value(memory::record(ref mut b, ref p), 16);
    state(ref b, 4, 16, false);
    value(memory::record(ref mut b, ref p), 16);
    state(ref b, 4, 16, false);
    // Retry is caller policy. Successful preparation can publish this baseline.
    value(memory::commit(ref mut b, ref p), 9);
    state(ref b, 9, 16, false);
    let memory::Plan lower = plan(ref b, 9, 2, 0);
    value(memory::record(ref mut b, ref lower), 9);
    state(ref b, 9, 16, false);
    value(memory::commit(ref mut b, ref lower), 2);
    state(ref b, 2, 16, false);
}

@test
fn void maximum_arithmetic_stale_and_invalid_state_fail_without_mutation() {
    let usize maximum = 18446744073709551615;
    var memory::Budget b = budget(268435456, 536870912);
    prep_rejected(ref b, 0, maximum, 0, 2);
    prep_rejected(ref b, 0, 0, maximum, 2);
    prep_rejected(ref b, 0, maximum, maximum, 2);
    prep_rejected(ref b, maximum, maximum, maximum, 3);
    let memory::Plan cap = plan(ref b, 0, 268435456, 0);
    value(memory::commit(ref mut b, ref cap), 268435456);
    prep_rejected(ref b, 268435456, 268435456, maximum, 2);
    prep_rejected(ref b, 268435456, maximum, 0, 2);
    let memory::Plan second = plan(ref b, 0, 268435456, 0);
    value(memory::commit(ref mut b, ref second), 536870912);
    state(ref b, 536870912, 536870912, false);
    prep_rejected(ref b, 0, 1, 0, 2);
    prep_rejected(ref b, 0, 0, maximum, 2);
    let memory::Observation full = memory::observe(ref b);
    rejected(memory::record(ref mut b, ref second), 3);
    rejected(memory::commit(ref mut b, ref second), 3);
    unchanged(ref b, ref full);
    let memory::Plan pending = plan(ref b, 268435456, 1, 0);
    value(memory::release(ref mut b, 1), 536870911);
    let memory::Observation changed = memory::observe(ref b);
    rejected(memory::record(ref mut b, ref pending), 3);
    rejected(memory::commit(ref mut b, ref pending), 3);
    unchanged(ref b, ref changed);
    // Flat public state still rejects inconsistent scalar invariants safely.
    var memory::Budget invalid_state = memory::Budget{.instance_limit=1,
        .instances_limit=1, .current=maximum, .peak=maximum, .closed=false};
    let memory::Observation invalid_before = memory::observe(ref invalid_state);
    prep_rejected(ref invalid_state, 0, 0, 0, 3);
    rejected(memory::record(ref mut invalid_state, ref cap), 3);
    rejected(memory::commit(ref mut invalid_state, ref cap), 3);
    rejected(memory::release(ref mut invalid_state, 0), 3);
    rejected(memory::close(ref mut invalid_state), 3);
    unchanged(ref invalid_state, ref invalid_before);
}

@test
fn void release_close_and_zero_byte_owners_preserve_historical_peak() {
    var memory::Budget b = budget(8, 16);
    let memory::Plan zero = plan(ref b, 0, 0, 0);
    value(memory::record(ref mut b, ref zero), 0);
    value(memory::commit(ref mut b, ref zero), 0);
    value(memory::release(ref mut b, 0), 0);
    let memory::Plan scratch = plan(ref b, 0, 0, 8);
    value(memory::record(ref mut b, ref scratch), 8);
    value(memory::commit(ref mut b, ref scratch), 0);
    state(ref b, 0, 8, false);
    let memory::Plan live = plan(ref b, 0, 3, 0);
    value(memory::commit(ref mut b, ref live), 3);
    let memory::Plan empty_peer = plan(ref b, 0, 0, 0);
    value(memory::commit(ref mut b, ref empty_peer), 3);
    value(memory::release(ref mut b, 0), 3);
    let memory::Observation before = memory::observe(ref b);
    rejected(memory::close(ref mut b), 3);
    rejected(memory::release(ref mut b, 4), 3);
    rejected(memory::release(ref mut b, 18446744073709551615), 3);
    unchanged(ref b, ref before);
    value(memory::release(ref mut b, 3), 0);
    let memory::Plan pending = plan(ref b, 0, 0, 0);
    value(memory::close(ref mut b), 0);
    state(ref b, 0, 8, true);
    let memory::Observation closed = memory::observe(ref b);
    prep_rejected(ref b, 0, 0, 0, 3);
    rejected(memory::record(ref mut b, ref pending), 3);
    rejected(memory::commit(ref mut b, ref pending), 3);
    rejected(memory::release(ref mut b, 0), 3);
    rejected(memory::close(ref mut b), 3);
    unchanged(ref b, ref closed);
    // Closing with only zero-byte owners has no retained payload to discard.
    var memory::Budget empty = budget(1, 1);
    let memory::Plan owner = plan(ref empty, 0, 0, 0);
    value(memory::commit(ref mut empty, ref owner), 0);
    value(memory::close(ref mut empty), 0);
    state(ref empty, 0, 0, true);
}
