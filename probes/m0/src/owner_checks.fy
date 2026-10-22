module owner_checks;

import owners as owners;
import std::bytes as bytes;

fn owners::Token created(ref mut owners::Table table, usize start, usize length, usize storage_length) {
    return switch (owners::create(table, start, length, storage_length)) {
        case .ok(value): { value }
        case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } }
    };
}
fn void released(ref mut owners::Table table, owners::Token token) {
    switch (owners::release(table, token)) {
        case .ok(value): { assert(value == token.slot); }
        case .err(_): { assert(false); }
    };
}
fn void rejected(ref mut owners::Table table, owners::Token token, ref bytes::Buffer buffer) {
    let usize before = table.payload_reads;
    switch (owners::read(table, token, 0, buffer)) {
        case .ok(_): { assert(false); }
        case .err(_): { }
    };
    assert(table.payload_reads == before);
}

fn owners::Token expired(ref mut owners::Table table) {
    let bytes::Buffer temporary = switch (bytes::copy(b"freed")) {
        case .ok(value): { value }
        case .err(_): { assert(false); bytes::empty() }
    };
    let owners::Token token = created(table, 0, bytes::len(ref temporary), bytes::len(ref temporary));
    released(table, token);
    return token;
    // temporary's owning allocation is freed before this function returns.
}

pub fn void run() {
    var owners::Table table = owners::empty();
    let owners::Token freed = expired(ref mut table);
    let bytes::Buffer missing = bytes::empty();
    rejected(ref mut table, freed, ref missing);
    assert(table.payload_reads == 0);
    let bytes::Buffer live = switch (bytes::copy(b"AB")) {
        case .ok(value): { value }
        case .err(_): { assert(false); bytes::empty() }
    };
    let owners::Token first = created(ref mut table, 0, 2, 2);
    switch (owners::read(ref mut table, first, 1, ref live)) {
        case .ok(value): { assert(value == 66); }
        case .err(_): { assert(false); }
    };
    assert(table.payload_reads == 1);
    released(ref mut table, first);
    // No allocation backs this dead owner's replacement. Any payload access would trap.
    let bytes::Buffer dead = bytes::empty();
    rejected(ref mut table, first, ref dead);
    switch (owners::release(ref mut table, first)) {
        case .ok(_): { assert(false); }
        case .err(_): { }
    };
    let owners::Token second = created(ref mut table, 0, 2, 2);
    assert(first.slot == second.slot && first.generation != second.generation);
    rejected(ref mut table, first, ref live);
    rejected(ref mut table, owners::Token { .slot = 4, .generation = 1 }, ref live);
    rejected(ref mut table, owners::Token { .slot = 18446744073709551615, .generation = 1 }, ref live);
    rejected(ref mut table, owners::Token { .slot = 0, .generation = 0 }, ref live);
    switch (owners::read(ref mut table, second, 2, ref live)) {
        case .ok(_): { assert(false); }
        case .err(_): { }
    };
    rejected(ref mut table, second, ref dead);
    assert(table.payload_reads == 1);
    // A generation at MAX is retired instead of wrapping.
    table.slots[0].generation = 18446744073709551615;
    let owners::Token last = owners::Token { .slot = 0, .generation = 18446744073709551615 };
    released(ref mut table, last);
    assert(table.slots[0].generation == 0);
    let owners::Token next = created(ref mut table, 0, 1, 2);
    assert(next.slot == 1);
    rejected(ref mut table, last, ref live);
    let owners::Token third = created(ref mut table, 0, 1, 2);
    let owners::Token fourth = created(ref mut table, 1, 1, 2);
    assert(third.slot == 2 && fourth.slot == 3);
    switch (owners::create(ref mut table, 0, 1, 2)) {
        case .ok(_): { assert(false); }
        case .err(_): { }
    };
    switch (owners::create(ref mut table, 18446744073709551615, 2, 2)) {
        case .ok(_): { assert(false); }
        case .err(_): { }
    };
}
