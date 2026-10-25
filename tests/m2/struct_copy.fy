module tests::m2::struct_copy;
import struct_layout as layouts;
import struct_storage as store;
import array_storage as arenas;

fn store::Shape prepared(ref u8[] tags) {
    var layouts::Catalog catalog = layouts::empty(); catalog.count = 1;
    var usize i = 0;
    while (i < tags.len) { catalog.fields[0] += 1; catalog.types[i] = tags[i]; i += 1; }
    return switch (store::prepare(ref catalog, 0)) {
        case .ok(shape): { shape }
        case .err(_): { assert(false); store::Shape { .count = 0, .tags = [0; 16], .offsets = [0; 16], .bytes = 0, .alignment = 0 } }
    };
}
fn u8 code(store::Error error) {
    return switch (error) {
        case .Layout: { 1 } case .Type: { 2 } case .Fields: { 3 } case .Metadata: { 4 }
        case .Overflow: { 5 } case .Quota: { 6 } case .Bounds: { 7 } case .Alignment: { 8 }
        case .Value: { 9 } case .State: { 10 }
    };
}
fn bool failed(Result<usize, store::Error> result, u8 expected) {
    return switch (result) { case .ok(_): { false } case .err(error): { code(error) == expected } };
}
fn usize success(Result<usize, store::Error> result) {
    return switch (result) { case .ok(value): { value } case .err(_): { assert(false); 0 } };
}
fn i64 read(ref store::Shape shape, usize base, usize field, ref u8[] bytes, ref arenas::Arena arena) {
    return switch (store::read(shape, base, field, bytes, arena)) {
        case .ok(value): { value } case .err(_): { assert(false); 0 }
    };
}
fn void unchanged(ref u8[] actual, ref u8[] expected) {
    assert(actual.len == expected.len);
    var usize i = 0;
    while (i < actual.len) { assert(actual[i] == expected[i]); i += 1; }
}

@test
fn void all_scalar_bits_copy_independently_and_padding_is_sanitized() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12]; let store::Shape shape = prepared(ref tags);
    let i64[6] values = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var u8[96] bytes = [85; 96]; var arenas::Arena arena = arenas::empty(96);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 0);
    bytes[5] = 85; bytes[6] = 85; bytes[7] = 85; bytes[17] = 99;
    let usize destination = success(store::copy(ref shape, 0, ref mut bytes, ref mut arena));
    assert(destination == 32 && arena.used == 64);
    var usize i = 0;
    while (i < 6) { assert(read(ref shape, destination, i, ref bytes, ref arena) == values[i]); i += 1; }
    assert(bytes[5] == 85 && bytes[17] == 99);
    assert(bytes[37] == 0 && bytes[38] == 0 && bytes[39] == 0 && bytes[49] == 0);
    i = 64; while (i < 96) { assert(bytes[i] == 85); i += 1; }
    assert(store::write(ref shape, destination, 0, 42, ref mut bytes, ref arena).is_ok);
    assert(read(ref shape, 0, 0, ref bytes, ref arena) == -2147483648);
    assert(success(store::assign(ref shape, 0, destination, ref mut bytes, ref arena)) == 32);
    assert(read(ref shape, 0, 0, ref bytes, ref arena) == 42 && bytes[5] == 0 && bytes[17] == 0);
    assert(arena.used == 64 && arena.limit == 96);
}

@test
fn void copy_reserves_old_plus_new_and_zeroes_alignment_before_publication() {
    let u8[2] tags = [9, 2]; let store::Shape shape = prepared(ref tags);
    let u8[1] small_tags = [10]; let store::Shape small = prepared(ref small_tags);
    let i64[2] values = [42, 1]; let i64[1] byte = [99];
    var u8[48] bytes = [85; 48]; var arenas::Arena arena = arenas::empty(39);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 0);
    assert(success(store::initialize(ref small, ref byte, ref mut bytes, ref mut arena)) == 16);
    let u8[48] before = bytes;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 6));
    unchanged(ref bytes, ref before); assert(arena.used == 17 && arena.limit == 39);
    arena.limit = 40;
    assert(success(store::copy(ref shape, 0, ref mut bytes, ref mut arena)) == 24 && arena.used == 40);
    var usize i = 17; while (i < 24) { assert(bytes[i] == 0); i += 1; }
    i = 33; while (i < 40) { assert(bytes[i] == 0); i += 1; }
    assert(bytes[16] == 99 && bytes[40] == 85 && read(ref shape, 24, 0, ref bytes, ref arena) == 42);
}

fn void overlap(bool forward) {
    let u8[2] tags = [9, 2]; let store::Shape shape = prepared(ref tags);
    let i64[2] first = [72623859790382856, 1]; let i64[2] second = [1, 0];
    var u8[48] bytes = [85; 48]; var arenas::Arena arena = arenas::empty(48);
    assert(success(store::initialize(ref shape, ref first, ref mut bytes, ref mut arena)) == 0);
    assert(success(store::initialize(ref shape, ref second, ref mut bytes, ref mut arena)) == 16);
    let u8[48] before = bytes;
    let usize destination = if (forward) { 8 } else { 0 };
    let usize source = if (forward) { 0 } else { 8 };
    let i64 value = read(ref shape, source, 0, ref bytes, ref arena);
    let i64 boolean = read(ref shape, source, 1, ref bytes, ref arena);
    assert(success(store::assign(ref shape, destination, source, ref mut bytes, ref arena)) == 16);
    assert(read(ref shape, destination, 0, ref bytes, ref arena) == value);
    assert(read(ref shape, destination, 1, ref bytes, ref arena) == boolean);
    var usize i = 0;
    while (i < 48) {
        if (i < destination || i >= destination + 16) { assert(bytes[i] == before[i]); }
        i += 1;
    }
    assert(arena.used == 32 && arena.limit == 48);
}
@test
fn void both_partial_overlap_directions_use_the_original_source_snapshot() {
    overlap(true); overlap(false);
}

@test
fn void invalid_final_bool_preserves_every_byte_and_the_arena() {
    let u8[3] tags = [2, 9, 2]; let store::Shape shape = prepared(ref tags);
    let i64[3] values = [1, -9223372036854775808, 1];
    var u8[96] bytes = [85; 96]; var arenas::Arena arena = arenas::empty(72);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 0);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 24);
    bytes[16] = 2; let u8[96] before = bytes;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 9));
    assert(failed(store::assign(ref shape, 24, 0, ref mut bytes, ref arena), 9));
    assert(failed(store::assign(ref shape, 0, 0, ref mut bytes, ref arena), 9));
    unchanged(ref bytes, ref before); assert(arena.used == 48 && arena.limit == 72);
    bytes[16] = 1;
    assert(success(store::copy(ref shape, 0, ref mut bytes, ref mut arena)) == 48 && arena.used == 72);
}

@test
fn void maximum_records_copy_at_exact_quota_and_assign_without_a_spare_extent() {
    let u8[16] tags = [12; 16]; let store::Shape shape = prepared(ref tags);
    let i64[16] values = [-1; 16];
    var u8[256] bytes = [85; 256]; var arenas::Arena arena = arenas::empty(256);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 0);
    assert(success(store::copy(ref shape, 0, ref mut bytes, ref mut arena)) == 128 && arena.used == 256);
    assert(read(ref shape, 128, 15, ref bytes, ref arena) == -1);
    assert(store::write(ref shape, 128, 15, 0, ref mut bytes, ref arena).is_ok);
    assert(success(store::assign(ref shape, 0, 128, ref mut bytes, ref arena)) == 128);
    assert(read(ref shape, 0, 0, ref bytes, ref arena) == -1 && read(ref shape, 0, 15, ref bytes, ref arena) == 0);
    let u8[256] before = bytes;
    assert(failed(store::copy(ref shape, 128, ref mut bytes, ref mut arena), 6));
    unchanged(ref bytes, ref before); assert(arena.used == 256 && arena.limit == 256);
}

@test
fn void copy_and_assignment_validate_state_alignment_and_complete_extents() {
    let u8[2] tags = [9, 2]; let store::Shape shape = prepared(ref tags);
    let i64[2] values = [42, 1];
    var u8[64] bytes = [85; 64]; var arenas::Arena arena = arenas::empty(64);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 0);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 16);
    let u8[64] before = bytes;
    assert(failed(store::copy(ref shape, 1, ref mut bytes, ref mut arena), 8));
    assert(failed(store::copy(ref shape, 18446744073709551608, ref mut bytes, ref mut arena), 7));
    assert(failed(store::assign(ref shape, 32, 0, ref mut bytes, ref arena), 7));
    assert(failed(store::assign(ref shape, 0, 32, ref mut bytes, ref arena), 7));
    assert(failed(store::assign(ref shape, 1, 0, ref mut bytes, ref arena), 8));
    arena.used = 31;
    assert(failed(store::copy(ref shape, 16, ref mut bytes, ref mut arena), 7));
    assert(failed(store::assign(ref shape, 16, 0, ref mut bytes, ref arena), 7));
    arena.used = 32; arena.limit = 65;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 10));
    assert(failed(store::assign(ref shape, 16, 0, ref mut bytes, ref arena), 10));
    arena.limit = 64;
    unchanged(ref bytes, ref before); assert(arena.used == 32);
}

@test
fn void forged_prepared_metadata_is_rejected_before_copy_or_assignment() {
    let u8[2] tags = [9, 2]; var store::Shape shape = prepared(ref tags);
    let i64[2] values = [42, 1];
    var u8[64] bytes = [85; 64]; var arenas::Arena arena = arenas::empty(64);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 0);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 16);
    let u8[64] before = bytes;
    shape.alignment = 0;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 4));
    assert(failed(store::assign(ref shape, 16, 0, ref mut bytes, ref arena), 4));
    shape = prepared(ref tags); shape.offsets[1] = 18446744073709551615;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 4));
    shape = prepared(ref tags); shape.bytes = 18446744073709551615;
    assert(failed(store::assign(ref shape, 16, 0, ref mut bytes, ref arena), 4));
    shape = prepared(ref tags); shape.tags[15] = 2;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 4));
    shape = prepared(ref tags); shape.tags[0] = 3;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 2));
    shape = prepared(ref tags); shape.count = 17;
    assert(failed(store::assign(ref shape, 16, 0, ref mut bytes, ref arena), 3));
    shape.count = 0;
    assert(failed(store::copy(ref shape, 0, ref mut bytes, ref mut arena), 3));
    unchanged(ref bytes, ref before); assert(arena.used == 32);
}

@test
fn void self_assignment_at_full_capacity_preserves_values_and_normalizes_tail_padding() {
    let u8[2] tags = [9, 2]; let store::Shape shape = prepared(ref tags);
    let i64[2] values = [-9223372036854775808, 1];
    var u8[16] bytes = [85; 16]; var arenas::Arena arena = arenas::empty(16);
    assert(success(store::initialize(ref shape, ref values, ref mut bytes, ref mut arena)) == 0);
    var usize i = 9; while (i < 16) { bytes[i] = 85; i += 1; }
    assert(success(store::assign(ref shape, 0, 0, ref mut bytes, ref arena)) == 16);
    assert(read(ref shape, 0, 0, ref bytes, ref arena) == -9223372036854775808 && read(ref shape, 0, 1, ref bytes, ref arena) == 1);
    i = 9; while (i < 16) { assert(bytes[i] == 0); i += 1; }
    assert(arena.used == 16 && arena.limit == 16);
}
