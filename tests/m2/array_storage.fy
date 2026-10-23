module tests::m2::array_storage;

import array_layout as layouts;
import array_storage as store;
import std::bytes as bytes;

fn layouts::Array layout(u8 tag, usize length) {
    return switch (layouts::scalar(tag, length)) {
        case .ok(value): { value }
        case .err(_): { assert(false); layouts::Array { .element = 0, .length = 0, .stride = 0, .alignment = 0, .bytes = 0 } }
    };
}
fn usize initialized(ref layouts::Array array, i64 value, ref mut u8[] bytes, ref mut store::Arena arena) {
    return switch (store::initialize(array, value, bytes, arena)) {
        case .ok(base): { base } case .err(_): { assert(false); 0 }
    };
}
fn i64 read(ref layouts::Array array, usize base, usize index, ref u8[] bytes, ref store::Arena arena) {
    return switch (store::read(array, base, index, bytes, arena)) {
        case .ok(value): { value } case .err(_): { assert(false); 0 }
    };
}
fn void unchanged(ref u8[] bytes, ref u8[] before) {
    assert(bytes.len == before.len);
    var usize i = 0;
    while (i < bytes.len) { assert(bytes[i] == before[i]); i += 1; }
}

@test
fn void initialize_and_mutate_each_scalar_without_touching_neighbors() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] values = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var usize t = 0;
    while (t < tags.len) {
        var u8[32] bytes = [85; 32];
        var store::Arena arena = store::empty(32);
        let layouts::Array array = layout(tags[t], 3);
        let usize base = initialized(ref array, values[t], ref mut bytes, ref mut arena);
        assert(base == 0 && arena.used == array.bytes);
        assert(read(ref array, base, 0, ref bytes, ref arena) == values[t]);
        assert(read(ref array, base, 2, ref bytes, ref arena) == values[t]);
        assert(store::write(ref array, base, 1, 0, ref mut bytes, ref arena).is_ok);
        assert(read(ref array, base, 1, ref bytes, ref arena) == 0);
        assert(read(ref array, base, 0, ref bytes, ref arena) == values[t]);
        assert(read(ref array, base, 2, ref bytes, ref arena) == values[t]);
        var usize i = array.bytes;
        while (i < bytes.len) { assert(bytes[i] == 85); i += 1; }
        t += 1;
    }
}

@test
fn void alignment_is_zeroed_and_failed_initialization_rolls_back() {
    var u8[32] bytes = [85; 32];
    var store::Arena arena = store::empty(23);
    let layouts::Array prefix = layout(10, 3);
    let layouts::Array words = layout(9, 2);
    let usize first = initialized(ref prefix, 7, ref mut bytes, ref mut arena);
    let u8[32] before = bytes;
    assert(!store::initialize(ref words, -1, ref mut bytes, ref mut arena).is_ok);
    assert(arena.used == 3); unchanged(ref bytes, ref before);
    arena.limit = 24;
    let layouts::Array narrow = layout(1, 2);
    assert(!store::initialize(ref narrow, 2147483648, ref mut bytes, ref mut arena).is_ok);
    assert(arena.used == 3); unchanged(ref bytes, ref before);
    let usize second = initialized(ref words, -1, ref mut bytes, ref mut arena);
    assert(first == 0 && second == 8 && arena.used == 24);
    var usize i = 3;
    while (i < 8) { assert(bytes[i] == 0); i += 1; }
    assert(read(ref prefix, first, 2, ref bytes, ref arena) == 7);
    assert(read(ref words, second, 1, ref bytes, ref arena) == -1);
    assert(bytes[24] == 85);
}

@test
fn void unpublished_bounds_and_invalid_writes_preserve_state() {
    var u8[16] bytes = [85; 16];
    var store::Arena arena = store::empty(16);
    let layouts::Array array = layout(1, 2);
    assert(!store::read(ref array, 0, 0, ref bytes, ref arena).is_ok);
    let usize base = initialized(ref array, 42, ref mut bytes, ref mut arena);
    let u8[16] before = bytes;
    assert(!store::write(ref array, base, 0, 2147483648, ref mut bytes, ref arena).is_ok);
    assert(!store::write(ref array, base, 2, 0, ref mut bytes, ref arena).is_ok);
    assert(!store::write(ref array, base, 18446744073709551615, 0, ref mut bytes, ref arena).is_ok);
    assert(!store::read(ref array, 4, 0, ref bytes, ref arena).is_ok);
    assert(!store::read(ref array, 1, 0, ref bytes, ref arena).is_ok);
    assert(arena.used == 8); unchanged(ref bytes, ref before);
    let layouts::Array boolean = layout(2, 1);
    // Corrupt storage cannot turn a noncanonical byte into a VM bool.
    bytes[0] = 2;
    assert(!store::read(ref boolean, 0, 0, ref bytes, ref arena).is_ok);
}

@test
fn void corrupt_layout_and_cursor_fail_before_access_or_mutation() {
    var u8[16] bytes = [85; 16];
    let u8[16] before = bytes;
    var store::Arena arena = store::empty(16);
    var layouts::Array array = layout(9, 1);
    array.stride = 18446744073709551615;
    assert(!store::initialize(ref array, 0, ref mut bytes, ref mut arena).is_ok);
    assert(!store::write(ref array, 0, 0, 0, ref mut bytes, ref arena).is_ok);
    array.stride = 8; array.alignment = 0;
    assert(!store::read(ref array, 0, 0, ref bytes, ref arena).is_ok);
    assert(!store::initialize(ref array, 0, ref mut bytes, ref mut arena).is_ok);
    array.alignment = 8; arena.used = 17;
    assert(!store::initialize(ref array, 0, ref mut bytes, ref mut arena).is_ok);
    assert(!store::read(ref array, 0, 0, ref bytes, ref arena).is_ok);
    assert(!store::write(ref array, 0, 0, 0, ref mut bytes, ref arena).is_ok);
    arena.used = 0; arena.limit = 18446744073709551615;
    assert(!store::initialize(ref array, 0, ref mut bytes, ref mut arena).is_ok);
    assert(!store::read(ref array, 0, 0, ref bytes, ref arena).is_ok);
    assert(arena.used == 0); unchanged(ref bytes, ref before);
}

@test
fn void full_4096_element_payload_uses_backing_bytes_and_keeps_guards() {
    var bytes::Buffer guarded = switch (bytes::with_capacity(32770)) {
        case .ok(value): { value } case .err(_): { assert(false); bytes::empty() }
    };
    assert(bytes::resize_zeroed(ref mut guarded, 32770).is_ok);
    var store::Arena arena = store::empty(32768);
    let layouts::Array array = layout(12, 4096);
    {
        let ref mut u8[] all = bytes::view_mut(ref mut guarded);
        all[0] = 85; all[32769] = 85;
        let ref mut u8[] payload = all[1..32769];
        let usize base = initialized(ref array, -1, payload, ref mut arena);
        assert(arena.used == 32768 && base == 0);
        assert(read(ref array, base, 4095, payload, ref arena) == -1);
        assert(store::write(ref array, base, 4095, -9223372036854775808, payload, ref arena).is_ok);
        assert(read(ref array, base, 4095, payload, ref arena) == -9223372036854775808);
        assert(read(ref array, base, 4094, payload, ref arena) == -1);
        assert(!store::initialize(ref array, 0, payload, ref mut arena).is_ok);
    }
    let ref u8[] after = bytes::view(ref guarded);
    assert(after[0] == 85 && after[32769] == 85 && arena.used == 32768);
}
