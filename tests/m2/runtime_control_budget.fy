module tests::m2::runtime_control_budget;
import runtime_control_budget as budget;

fn u8 error_code(budget::Error error) {
    return switch (error) {
        case .Invalid: { 1 } case .Quota: { 2 } case .State: { 3 }
    };
}

fn void value(Result<usize,budget::Error> result, usize expected) {
    switch (result) {
        case .ok(actual): { assert(actual == expected); }
        case .err(_): { assert(false); return; }
    };
}

fn void rejected(Result<usize,budget::Error> result, u8 expected) {
    switch (result) {
        case .ok(_): { assert(false); return; }
        case .err(error): { assert(error_code(error) == expected); }
    };
}

fn void create_rejected(usize limit, usize initial, u8 expected) {
    switch (budget::create(limit, initial)) {
        case .ok(_): { assert(false); return; }
        case .err(error): { assert(error_code(error) == expected); }
    };
}

fn void state(ref budget::Budget b, usize limit, usize reserved, usize peak, bool closed) {
    let budget::Observation actual = budget::observe(b);
    assert(actual.limit == limit && actual.reserved == reserved);
    assert(actual.peak == peak && actual.closed == closed);
}

fn void unchanged(ref budget::Budget b, ref budget::Observation before) {
    state(b, before.limit, before.reserved, before.peak, before.closed);
}

@test
fn void creation_validates_limits_and_reports_initial_reservation() {
    create_rejected(0, 0, 1);
    create_rejected(0, 1, 1);
    create_rejected(7, 8, 2);
    create_rejected(1, 18446744073709551615, 2);
    let budget::Budget empty = switch (budget::create(1, 0)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    state(ref empty, 1, 0, 0, false);
    let budget::Budget full = switch (budget::create(7, 7)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    state(ref full, 7, 7, 7, false);
}

@test
fn void exact_budget_succeeds_and_one_less_rejects_without_mutation() {
    var budget::Budget exact = switch (budget::create(8, 3)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    var budget::Budget short = switch (budget::create(7, 3)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    value(budget::reserve(ref mut exact, 5), 8);
    state(ref exact, 8, 8, 8, false);
    let budget::Observation before = budget::observe(ref short);
    rejected(budget::reserve(ref mut short, 5), 2);
    unchanged(ref short, ref before);
    value(budget::reserve(ref mut short, 4), 7);
    state(ref short, 7, 7, 7, false);
    value(budget::reserve(ref mut exact, 0), 8);
    let budget::Observation full = budget::observe(ref exact);
    rejected(budget::reserve(ref mut exact, 1), 2);
    unchanged(ref exact, ref full);
}

@test
fn void maximum_usize_reservations_reject_overflow_and_preserve_state() {
    let usize maximum = 18446744073709551615;
    var budget::Budget b = switch (budget::create(maximum, maximum - 1)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    state(ref b, maximum, maximum - 1, maximum - 1, false);
    let budget::Observation before = budget::observe(ref b);
    rejected(budget::reserve(ref mut b, 2), 2);
    unchanged(ref b, ref before);
    rejected(budget::reserve(ref mut b, maximum), 2);
    unchanged(ref b, ref before);
    value(budget::reserve(ref mut b, 1), maximum);
    let budget::Observation full = budget::observe(ref b);
    state(ref b, maximum, maximum, maximum, false);
    rejected(budget::reserve(ref mut b, 1), 2);
    unchanged(ref b, ref full);
    value(budget::reserve(ref mut b, 0), maximum);
    unchanged(ref b, ref full);
    value(budget::release(ref mut b, maximum), 0);
    state(ref b, maximum, 0, maximum, false);
    value(budget::reserve(ref mut b, maximum), maximum);
    state(ref b, maximum, maximum, maximum, false);
    value(budget::release(ref mut b, maximum), 0);
    value(budget::close(ref mut b), 0);
    state(ref b, maximum, 0, maximum, true);
}

@test
fn void peak_survives_release_and_only_grows_on_a_new_high_water_mark() {
    var budget::Budget b = switch (budget::create(12, 4)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    value(budget::reserve(ref mut b, 4), 8);
    value(budget::release(ref mut b, 6), 2);
    state(ref b, 12, 2, 8, false);
    value(budget::reserve(ref mut b, 5), 7);
    state(ref b, 12, 7, 8, false);
    value(budget::reserve(ref mut b, 2), 9);
    state(ref b, 12, 9, 9, false);
    value(budget::release(ref mut b, 0), 9);
    state(ref b, 12, 9, 9, false);
    value(budget::release(ref mut b, 9), 0);
    state(ref b, 12, 0, 9, false);
    value(budget::release(ref mut b, 0), 0);
    value(budget::reserve(ref mut b, 0), 0);
    state(ref b, 12, 0, 9, false);
    value(budget::close(ref mut b), 0);
    state(ref b, 12, 0, 9, true);
}

@test
fn void overrelease_and_nonempty_close_reject_without_poisoning_the_budget() {
    var budget::Budget b = switch (budget::create(10, 4)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    value(budget::reserve(ref mut b, 2), 6);
    value(budget::release(ref mut b, 2), 4);
    let budget::Observation before = budget::observe(ref b);
    rejected(budget::release(ref mut b, 5), 3);
    unchanged(ref b, ref before);
    rejected(budget::release(ref mut b, 18446744073709551615), 3);
    unchanged(ref b, ref before);
    rejected(budget::close(ref mut b), 3);
    unchanged(ref b, ref before);
    value(budget::reserve(ref mut b, 1), 5);
    value(budget::release(ref mut b, 5), 0);
    let budget::Observation empty = budget::observe(ref b);
    rejected(budget::release(ref mut b, 1), 3);
    unchanged(ref b, ref empty);
    value(budget::close(ref mut b), 0);
    state(ref b, 10, 0, 6, true);
}

@test
fn void closed_budget_rejects_even_zero_operations_and_stays_observable() {
    var budget::Budget b = switch (budget::create(4, 2)) {
        case .ok(b): { b } case .err(_): { assert(false); return; }
    };
    value(budget::release(ref mut b, 2), 0);
    value(budget::close(ref mut b), 0);
    state(ref b, 4, 0, 2, true);
    let budget::Observation closed = budget::observe(ref b);
    let usize[3] amounts = [0, 1, 18446744073709551615];
    var usize i = 0;
    while (i < amounts.len) {
        rejected(budget::reserve(ref mut b, amounts[i]), 3);
        unchanged(ref b, ref closed);
        rejected(budget::release(ref mut b, amounts[i]), 3);
        unchanged(ref b, ref closed);
        i += 1;
    }
    rejected(budget::close(ref mut b), 3);
    unchanged(ref b, ref closed);
}
