module tests::m2::array_owners;

import array_owners as owners;
import array_layout as layouts;

fn layouts::Array layout(u8 tag, usize length) {
    return switch (layouts::scalar(tag, length)) {
        case .ok(value): { value }
        case .err(_): { assert(false); layouts::Array { .element = 0, .length = 0, .stride = 0, .alignment = 0, .bytes = 0 } }
    };
}
fn owners::Token created(ref layouts::Array array, i64 fill, ref mut u8[] bytes, ref mut owners::Table table) {
    return switch (owners::create(array, fill, bytes, table)) {
        case .ok(token): { token } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } }
    };
}
fn i64 read(ref owners::Table table, owners::Token token, usize index, ref u8[] bytes) {
    return switch (owners::read(table, token, index, bytes)) {
        case .ok(value): { value } case .err(_): { assert(false); 0 }
    };
}
fn usize released(ref mut owners::Table table, owners::Token token, usize capacity) {
    return switch (owners::release(table, token, capacity)) {
        case .ok(value): { value } case .err(_): { assert(false); 0 }
    };
}
fn bool stale(ref owners::Table table, owners::Token token, ref u8[] bytes) {
    return switch (owners::read(table, token, 0, bytes)) {
        case .ok(_): { false } case .err(e): { switch (e) {
            case .Token: { true } case .Owners: { false } case .State: { false }
            case .Type: { false } case .Length: { false } case .Metadata: { false }
            case .Overflow: { false } case .Quota: { false } case .Bounds: { false }
            case .Alignment: { false } case .Value: { false }
        } }
    };
}

@test
fn void generation_reuse_rejects_old_tokens_before_payload() {
    var u8[32] bytes = [85; 32];
    var owners::Table table = owners::empty(32);
    let layouts::Array array = layout(1, 2);
    let owners::Token first = created(ref array, 42, ref mut bytes, ref mut table);
    assert(read(ref table, first, 1, ref bytes) == 42);
    assert(owners::write(ref table, first, 1, 7, ref mut bytes).is_ok);
    assert(read(ref table, first, 1, ref bytes) == 7);
    assert(released(ref mut table, first, bytes.len) == 8);
    let owners::Token second = created(ref array, 99, ref mut bytes, ref mut table);
    assert(first.slot == second.slot && first.generation != second.generation);
    // An empty payload view proves a stale token is rejected before bounds/data.
    assert(stale(ref table, first, b""));
    assert(!owners::write(ref table, first, 0, 0, ref mut bytes).is_ok);
    assert(!owners::release(ref mut table, first, bytes.len).is_ok);
    assert(read(ref table, second, 0, ref bytes) == 99);
    assert(stale(ref table, owners::Token { .slot = 16, .generation = 1 }, b""));
    assert(stale(ref table, owners::Token { .slot = 0, .generation = 0 }, b""));
}

@test
fn void middle_release_defers_bytes_and_tail_release_collapses_holes() {
    var u8[32] bytes = [85; 32];
    var owners::Table table = owners::empty(32);
    let layouts::Array prefix = layout(10, 3);
    let layouts::Array word = layout(9, 1);
    let owners::Token a = created(ref prefix, 1, ref mut bytes, ref mut table);
    let owners::Token b = created(ref word, 2, ref mut bytes, ref mut table);
    let owners::Token c = created(ref word, 3, ref mut bytes, ref mut table);
    assert(table.arena.used == 24 && table.depth == 3);
    assert(released(ref mut table, b, bytes.len) == 0);
    assert(table.arena.used == 24 && stale(ref table, b, ref bytes));
    assert(read(ref table, c, 0, ref bytes) == 3);
    assert(released(ref mut table, c, bytes.len) == 21);
    assert(table.arena.used == 3 && table.depth == 1);
    assert(read(ref table, a, 0, ref bytes) == 1);
    let owners::Token replacement = created(ref word, 4, ref mut bytes, ref mut table);
    assert(replacement.slot == b.slot && replacement.generation != b.generation);
    assert(table.arena.used == 16 && read(ref table, replacement, 0, ref bytes) == 4);
}

@test
fn void retired_generation_never_wraps_and_clear_invalidates_all_live_tokens() {
    var u8[32] bytes = [85; 32];
    var owners::Table table = owners::empty(32);
    let layouts::Array array = layout(10, 1);
    let owners::Token original = created(ref array, 7, ref mut bytes, ref mut table);
    table.slots[original.slot].generation = 18446744073709551615;
    let owners::Token last = owners::Token { .slot = original.slot, .generation = 18446744073709551615 };
    assert(released(ref mut table, last, bytes.len) == 1);
    assert(table.slots[original.slot].generation == 0);
    let owners::Token next = created(ref array, 8, ref mut bytes, ref mut table);
    assert(next.slot != original.slot);
    assert(owners::clear(ref mut table, bytes.len).is_ok);
    assert(table.arena.used == 0 && table.depth == 0 && stale(ref table, next, b""));
    assert(stale(ref table, last, b""));
    let owners::Token again = created(ref array, 9, ref mut bytes, ref mut table);
    assert(again.slot == next.slot && again.generation != next.generation);
    assert(table.slots[original.slot].generation == 0);
}

@test
fn void quota_value_and_owner_pressure_fail_without_publication() {
    var u8[32] bytes = [85; 32];
    var owners::Table table = owners::empty(1);
    let layouts::Array word = layout(1, 1);
    assert(!owners::create(ref word, 0, ref mut bytes, ref mut table).is_ok);
    assert(table.depth == 0 && table.arena.used == 0 && table.slots[0].generation == 1);
    table.arena.limit = 32;
    assert(!owners::create(ref word, 2147483648, ref mut bytes, ref mut table).is_ok);
    assert(table.depth == 0 && table.arena.used == 0 && bytes[0] == 85);
    let layouts::Array byte = layout(10, 1);
    var usize i = 0;
    while (i < 16) { let owners::Token token = created(ref byte, 7, ref mut bytes, ref mut table); i += 1; }
    assert(!owners::create(ref byte, 8, ref mut bytes, ref mut table).is_ok);
    assert(table.depth == 16 && table.arena.used == 16 && bytes[16] == 85);
}

@test
fn void corrupt_extent_order_and_cursor_are_rejected_without_byte_access() {
    var u8[32] bytes = [85; 32];
    var owners::Table table = owners::empty(32);
    let layouts::Array array = layout(1, 1);
    let owners::Token token = created(ref array, 42, ref mut bytes, ref mut table);
    table.slots[token.slot].base = 18446744073709551615;
    assert(!owners::read(ref table, token, 0, ref bytes).is_ok);
    assert(!owners::release(ref mut table, token, bytes.len).is_ok);
    assert(table.slots[token.slot].live && table.slots[token.slot].generation == token.generation);
    table.slots[token.slot].base = 0; table.order[0] = 16;
    assert(!owners::write(ref table, token, 0, 99, ref mut bytes).is_ok);
    table.order[0] = token.slot; table.arena.limit = 33;
    assert(!owners::clear(ref mut table, bytes.len).is_ok);
    assert(bytes[0] == 42 && table.arena.used == 4 && table.depth == 1);
    table.arena.limit = 32;
    assert(read(ref table, token, 0, ref bytes) == 42);
    assert(!owners::read(ref table, token, 1, ref bytes).is_ok);
    assert(!owners::read(ref table, token, 18446744073709551615, ref bytes).is_ok);
}
