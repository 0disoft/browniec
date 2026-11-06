module tests::m2::array_places;

import array_places as places;
import array_owners as owners;
import array_layout as layouts;
import struct_layout as records;

fn owners::Token created(u8 element, usize length, i64 fill,
    ref mut u8[] bytes, ref mut owners::Table table) {
    let layouts::Array layout = switch (layouts::scalar(element, length)) {
        case .ok(value): { value }
        case .err(_): { assert(false); layouts::Array { .element = 0, .length = 0,
            .stride = 0, .alignment = 0, .bytes = 0 } }
    };
    return switch (owners::create(ref layout, fill, bytes, table)) {
        case .ok(value): { value } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } }
    };
}
fn places::Place selected(ref owners::Table table, owners::Token root, usize index, usize capacity) {
    return switch (places::select(table, root, index, capacity)) {
        case .ok(value): { value }
        case .err(_): { assert(false); places::Place { .root = root, .element = 0, .length = 0,
            .mark = 0, .base = 0, .end = 0, .index = 0, .offset = 0 } }
    };
}
fn i64 value(ref owners::Table table, owners::Token root, usize index, ref u8[] bytes) {
    return switch (owners::read(table, root, index, bytes)) {
        case .ok(cell): { cell } case .err(_): { assert(false); 0 }
    };
}

@test fn void descriptor_and_index_changes_preserve_the_original_target() {
    var u8[32] bytes = [85; 32]; var owners::Table table = owners::empty(32);
    var owners::Token descriptor = created(1, 2, 20, ref mut bytes, ref mut table);
    let owners::Token original = descriptor; var usize index = 0;
    let places::Place place = selected(ref table, descriptor, index, bytes.len);
    // Simulated RHS changes both variables and allocates another live root.
    index = 1; descriptor = created(1, 2, 99, ref mut bytes, ref mut table);
    assert(places::store(ref table, ref place, 42, ref mut bytes).is_ok);
    assert(value(ref table, original, 0, ref bytes) == 42);
    assert(value(ref table, original, index, ref bytes) == 20);
    assert(value(ref table, descriptor, 0, ref bytes) == 99);
    assert(table.depth == 2 && table.arena.used == 16);
}

@test fn void compound_old_scalar_precedes_rhs_writes_and_all_six_widths_work() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12]; var usize i = 0;
    while (i < 6) {
        var u8[32] bytes = [85; 32]; var owners::Table table = owners::empty(32);
        let i64 initial = if (tags[i] == 2) { 0 } else { 20 };
        let owners::Token root = created(tags[i], 2, initial, ref mut bytes, ref mut table);
        let places::Place place = selected(ref table, root, 1, bytes.len);
        let i64 old = switch (places::read(ref table, ref place, ref bytes)) {
            case .ok(cell): { cell } case .err(_): { assert(false); 0 }
        };
        let i64 rhs = if (tags[i] == 2) { 1 } else { 99 };
        assert(owners::write(ref table, root, 1, rhs, ref mut bytes).is_ok);
        let i64 result = if (tags[i] == 2) { 1 } else { old + 22 };
        assert(places::store(ref table, ref place, result, ref mut bytes).is_ok);
        assert(value(ref table, root, 0, ref bytes) == initial);
        assert(value(ref table, root, 1, ref bytes) == result);
        i += 1;
    }
}

@test fn void selection_is_metadata_only_and_store_encoding_is_atomic() {
    var u8[8] bytes = [85; 8]; var owners::Table table = owners::empty(8);
    let owners::Token root = created(2, 2, 0, ref mut bytes, ref mut table);
    bytes[1] = 7;
    let places::Place place = selected(ref table, root, 1, bytes.len);
    assert(!places::read(ref table, ref place, ref bytes).is_ok);
    assert(!places::store(ref table, ref place, 2, ref mut bytes).is_ok);
    assert(bytes[0] == 0 && bytes[1] == 7 && bytes[2] == 85);
    assert(places::store(ref table, ref place, 1, ref mut bytes).is_ok);
    assert(bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 85);
    assert(table.depth == 1 && table.arena.used == 2);
}

@test fn void empty_ranges_last_and_host_max_indices_fail_before_rhs_work() {
    var u8[4096] bytes = [85; 4096]; var owners::Table table = owners::empty(4096);
    assert(!layouts::scalar(10, 0).is_ok);
    let owners::Token root = created(10, 4096, 20, ref mut bytes, ref mut table);
    assert(owners::view(ref table, root, 4096, 4096, bytes.len).is_ok);
    let places::Place last = selected(ref table, root, 4095, bytes.len);
    assert(last.offset == 4095 && last.end == 4096);
    assert(!places::select(ref table, root, 4096, bytes.len).is_ok);
    assert(!places::select(ref table, root, 18446744073709551615, bytes.len).is_ok);
    assert(!places::select(ref table, root, 0, 4095).is_ok);
    assert(places::store(ref table, ref last, 42, ref mut bytes).is_ok);
    assert(bytes[4094] == 20 && bytes[4095] == 42);
}

@test fn void released_reused_and_cleared_roots_cannot_resurrect_a_place() {
    var u8[16] bytes = [85; 16]; var owners::Table table = owners::empty(16);
    let owners::Token first = created(1, 2, 20, ref mut bytes, ref mut table);
    let places::Place old = selected(ref table, first, 0, bytes.len);
    assert(owners::release(ref mut table, first, bytes.len).is_ok);
    let owners::Token next = created(1, 2, 99, ref mut bytes, ref mut table);
    assert(first.slot == next.slot && first.generation != next.generation);
    assert(!places::store(ref table, ref old, 42, ref mut bytes).is_ok);
    assert(value(ref table, next, 0, ref bytes) == 99);
    let places::Place cleared = selected(ref table, next, 0, bytes.len);
    assert(owners::clear(ref mut table, bytes.len).is_ok);
    assert(!places::store(ref table, ref cleared, 42, ref mut bytes).is_ok);
    let owners::Token final = created(1, 2, 7, ref mut bytes, ref mut table);
    assert(!places::read(ref table, ref cleared, ref bytes).is_ok);
    assert(!places::store(ref table, ref cleared, 42, ref mut bytes).is_ok);
    assert(value(ref table, final, 0, ref bytes) == 7);
}

@test fn void outstanding_loans_block_capture_and_commit_but_completed_loans_do_not() {
    var u8[16] bytes = [85; 16]; var owners::Table table = owners::empty(16);
    let owners::Token root = created(1, 2, 20, ref mut bytes, ref mut table);
    let places::Place place = selected(ref table, root, 0, bytes.len);
    let owners::ReadLease shared = switch (owners::begin_read(ref mut table, root, bytes.len)) {
        case .ok(value): { value } case .err(_): { assert(false); owners::ReadLease { .root = root, .generation = 0 } }
    };
    assert(!places::select(ref table, root, 0, bytes.len).is_ok);
    assert(!places::store(ref table, ref place, 42, ref mut bytes).is_ok);
    assert(owners::end_read(ref mut table, shared, bytes.len).is_ok);
    let owners::WriteLease exclusive = switch (owners::begin_write(ref mut table, root, 0, 2, bytes.len)) {
        case .ok(value): { value }
        case .err(_): { assert(false); owners::WriteLease { .view = owners::View {
            .root = root, .element = 1, .length = 2, .start = 0, .end = 2 }, .generation = 0 } }
    };
    assert(!places::select(ref table, root, 0, bytes.len).is_ok);
    assert(!places::store(ref table, ref place, 42, ref mut bytes).is_ok);
    assert(owners::end_write(ref mut table, ref exclusive, bytes.len).is_ok);
    assert(value(ref table, root, 0, ref bytes) == 20);
    assert(places::store(ref table, ref place, 42, ref mut bytes).is_ok);
    assert(value(ref table, root, 0, ref bytes) == 42);
}

@test fn void malformed_shape_extent_and_offset_never_publish_bytes() {
    var u8[32] bytes = [85; 32]; var owners::Table table = owners::empty(32);
    let owners::Token root = created(1, 2, 20, ref mut bytes, ref mut table);
    let places::Place place = selected(ref table, root, 0, bytes.len);
    var places::Place bad = place; bad.element = 9;
    assert(!places::store(ref table, ref bad, 42, ref mut bytes).is_ok);
    bad = place; bad.length = 1;
    assert(!places::store(ref table, ref bad, 42, ref mut bytes).is_ok);
    bad = place; bad.mark = 1;
    assert(!places::store(ref table, ref bad, 42, ref mut bytes).is_ok);
    bad = place; bad.base = 4;
    assert(!places::store(ref table, ref bad, 42, ref mut bytes).is_ok);
    bad = place; bad.end = 4;
    assert(!places::store(ref table, ref bad, 42, ref mut bytes).is_ok);
    bad = place; bad.offset = 4;
    assert(!places::store(ref table, ref bad, 42, ref mut bytes).is_ok);
    bad = place; bad.index = 1;
    assert(!places::store(ref table, ref bad, 42, ref mut bytes).is_ok);
    assert(!places::store(ref table, ref place, 2147483648, ref mut bytes).is_ok);
    assert(value(ref table, root, 0, ref bytes) == 20 && value(ref table, root, 1, ref bytes) == 20);
    assert(table.depth == 1 && table.arena.used == 8 && bytes[8] == 85);
}

@test fn void malformed_owner_metadata_and_record_tokens_fail_closed() {
    var u8[32] bytes = [85; 32]; var owners::Table table = owners::empty(32);
    let owners::Token root = created(1, 2, 20, ref mut bytes, ref mut table);
    let places::Place place = selected(ref table, root, 0, bytes.len);
    table.slots[root.slot].base = 18446744073709551615;
    assert(!places::store(ref table, ref place, 42, ref mut bytes).is_ok);
    assert(!places::select(ref table, root, 0, bytes.len).is_ok);
    table.slots[root.slot].base = 0; table.order[0] = 16;
    assert(!places::store(ref table, ref place, 42, ref mut bytes).is_ok);
    table.order[0] = root.slot;
    assert(value(ref table, root, 0, ref bytes) == 20);
    var records::Catalog catalog = records::empty(); catalog.count = 1;
    catalog.fields[0] = 1; catalog.types[0] = 1;
    let i64[1] fields = [99];
    let owners::Token record = switch (owners::create_record(ref catalog, 0, ref fields, ref mut bytes, ref mut table)) {
        case .ok(value): { value } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } }
    };
    assert(!places::select(ref table, record, 0, bytes.len).is_ok);
    assert(value(ref table, root, 0, ref bytes) == 20);
}
