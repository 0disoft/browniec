module tests::m2::array_copy;

import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

fn layouts::Array layout(u8 tag, usize length) {
    return switch (layouts::scalar(tag, length)) {
        case .ok(value): { value }
        case .err(_): { assert(false); layouts::Array { .element = 0, .length = 0, .stride = 0, .alignment = 0, .bytes = 0 } }
    };
}
fn owners::Token created(ref layouts::Array array, i64 fill, ref mut u8[] data, ref mut owners::Table table) {
    return switch (owners::create(array, fill, data, table)) {
        case .ok(token): { token } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } }
    };
}
fn owners::Token copied(owners::Token source, ref mut u8[] data, ref mut owners::Table table) {
    return switch (owners::copy(source, data, table)) {
        case .ok(token): { token } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } }
    };
}
fn i64 read(ref owners::Table table, owners::Token token, usize index, ref u8[] data) {
    return switch (owners::read(table, token, index, data)) {
        case .ok(value): { value } case .err(_): { assert(false); 0 }
    };
}
fn void unchanged(ref u8[] data, ref u8[] before) {
    var usize i = 0;
    while (i < data.len) { assert(data[i] == before[i]); i += 1; }
}

@test
fn void all_scalar_copies_are_typed_independent_values() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] values = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var usize i = 0;
    while (i < tags.len) {
        var u8[64] data = [85; 64];
        var owners::Table table = owners::empty(64);
        let layouts::Array array = layout(tags[i], 3);
        let owners::Token source = created(ref array, values[i], ref mut data, ref mut table);
        let owners::Token copy = copied(source, ref mut data, ref mut table);
        assert(source.slot != copy.slot && table.arena.used == array.bytes * 2);
        assert(read(ref table, copy, 0, ref data) == values[i]);
        assert(read(ref table, copy, 2, ref data) == values[i]);
        assert(owners::write(ref table, source, 0, 0, ref mut data).is_ok);
        assert(read(ref table, copy, 0, ref data) == values[i]);
        assert(owners::write(ref table, copy, 2, 0, ref mut data).is_ok);
        assert(read(ref table, source, 2, ref data) == values[i]);
        assert(owners::release(ref mut table, source, data.len).is_ok);
        assert(read(ref table, copy, 0, ref data) == values[i]);
        assert(owners::release(ref mut table, copy, data.len).is_ok);
        assert(table.arena.used == 0 && table.depth == 0);
        i += 1;
    }
}

@test
fn void failed_copy_preserves_bytes_cursor_and_destination_generation() {
    var u8[32] data = [85; 32];
    var owners::Table table = owners::empty(16);
    let layouts::Array prefix = layout(10, 3);
    let layouts::Array word = layout(9, 1);
    let owners::Token source = created(ref word, -1, ref mut data, ref mut table);
    let owners::Token other = created(ref prefix, 7, ref mut data, ref mut table);
    let u8[32] before = data;
    // Source + prefix occupy 11 bytes; copying the word requires 24 including padding.
    assert(!owners::copy(source, ref mut data, ref mut table).is_ok);
    assert(table.arena.used == 11 && table.depth == 2 && table.slots[2].generation == 1);
    unchanged(ref data, ref before);
    table.arena.limit = 24;
    let owners::Token copy = copied(source, ref mut data, ref mut table);
    assert(table.slots[copy.slot].base == 16 && table.arena.used == 24);
    assert(read(ref table, other, 2, ref data) == 7 && read(ref table, copy, 0, ref data) == -1);
    var usize i = 11;
    while (i < 16) { assert(data[i] == 0); i += 1; }
    assert(data[24] == 85);
}

@test
fn void noncanonical_bool_stale_source_and_owner_pressure_do_not_publish() {
    var u8[64] data = [85; 64];
    var owners::Table table = owners::empty(64);
    let layouts::Array array = layout(2, 3);
    let owners::Token source = created(ref array, 1, ref mut data, ref mut table);
    data[2] = 2;
    let u8[64] corrupt = data;
    assert(!owners::copy(source, ref mut data, ref mut table).is_ok);
    assert(table.depth == 1 && table.arena.used == 3 && table.slots[1].generation == 1);
    unchanged(ref data, ref corrupt);
    data[2] = 1;
    var usize i = 1;
    while (i < 16) { let owners::Token next = copied(source, ref mut data, ref mut table); i += 1; }
    let u8[64] full = data;
    assert(!owners::copy(source, ref mut data, ref mut table).is_ok);
    assert(table.depth == 16 && table.arena.used == 48); unchanged(ref data, ref full);
    assert(owners::clear(ref mut table, data.len).is_ok);
    let u8[64] cleared = data;
    assert(!owners::copy(source, ref mut data, ref mut table).is_ok);
    assert(table.depth == 0 && table.arena.used == 0); unchanged(ref data, ref cleared);
}

@test
fn void full_width_array_copy_fits_exact_peak_and_survives_source_release() {
    var bytes::Buffer backing = switch (bytes::with_capacity(65538)) {
        case .ok(value): { value } case .err(_): { assert(false); bytes::empty() }
    };
    assert(bytes::resize_zeroed(ref mut backing, 65538).is_ok);
    var owners::Table table = owners::empty(65536);
    let layouts::Array array = layout(12, 4096);
    {
        let ref mut u8[] all = bytes::view_mut(ref mut backing);
        all[0] = 85; all[65537] = 85;
        let ref mut u8[] data = all[1..65537];
        let owners::Token source = created(ref array, -1, data, ref mut table);
        assert(owners::assign(source,source,data,ref table).is_ok);
        assert(read(ref table,source,4095,data)==-1 && table.depth==1 && table.arena.used==32768);
        table.arena.limit = 65535;
        assert(!owners::copy(source, data, ref mut table).is_ok);
        assert(table.arena.used == 32768 && table.depth == 1 && data[32768] == 0);
        table.arena.limit = 65536;
        let owners::Token copy = copied(source, data, ref mut table);
        assert(table.arena.used == 65536 && read(ref table, copy, 4095, data) == -1);
        assert(owners::write(ref table, source, 4095, -9223372036854775808, data).is_ok);
        assert(read(ref table, copy, 4095, data) == -1);
        assert(owners::release(ref mut table, source, data.len).is_ok);
        assert(read(ref table, copy, 4095, data) == -1);
        assert(owners::release(ref mut table, copy, data.len).is_ok);
        assert(table.arena.used == 0 && table.depth == 0);
    }
    let ref u8[] after = bytes::view(ref backing);
    assert(after[0] == 85 && after[65537] == 85);
}
