module tests::m2::struct_storage;
import struct_layout as layouts;
import struct_storage as store;
import array_storage as arenas;
import array_layout as arrays;

fn store::Shape prepared(ref u8[] tags) {
    assert(tags.len > 0 && tags.len <= 16);
    var layouts::Catalog catalog = layouts::empty();
    catalog.count = 1;
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
fn usize initialized(ref store::Shape shape, ref i64[] fields, ref mut u8[] bytes, ref mut arenas::Arena arena) {
    return switch (store::initialize(shape, fields, bytes, arena)) {
        case .ok(base): { base } case .err(_): { assert(false); 0 }
    };
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
fn void prefix(ref mut u8[] bytes, ref mut arenas::Arena arena) {
    let arrays::Array shape = switch (arrays::scalar(10, 3)) {
        case .ok(value): { value } case .err(_): { assert(false); arrays::Array { .element = 0, .length = 0, .stride = 0, .alignment = 0, .bytes = 0 } }
    };
    assert(arenas::initialize(ref shape, 123, bytes, arena).is_ok);
}

@test
fn void all_six_scalars_roundtrip_in_a_shared_array_record_arena() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] fields = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    let store::Shape shape = prepared(ref tags);
    var u8[64] bytes = [85; 64];
    var arenas::Arena arena = arenas::empty(64);
    prefix(ref mut bytes, ref mut arena);
    let usize base = initialized(ref shape, ref fields, ref mut bytes, ref mut arena);
    assert(base == 8 && shape.bytes == 32 && arena.used == 40);
    var usize i = 0;
    while (i < 6) { assert(read(ref shape, base, i, ref bytes, ref arena) == fields[i]); i += 1; }
    assert(bytes[0] == 123 && bytes[1] == 123 && bytes[2] == 123);
    i = 3; while (i < 8) { assert(bytes[i] == 0); i += 1; }
    i = 13; while (i < 16) { assert(bytes[i] == 0); i += 1; }
    i = 25; while (i < 28) { assert(bytes[i] == 0); i += 1; }
    i = 40; while (i < 64) { assert(bytes[i] == 85); i += 1; }
}

@test
fn void complete_initializer_and_last_field_value_are_checked_before_writes() {
    let u8[2] tags = [1, 2]; let store::Shape shape = prepared(ref tags);
    var u8[32] bytes = [85; 32]; let u8[32] before = bytes;
    var arenas::Arena arena = arenas::empty(32);
    let i64[2] invalid = [42, 2];
    assert(failed(store::initialize(ref shape, ref invalid, ref mut bytes, ref mut arena), 9));
    let i64[1] missing = [42];
    assert(failed(store::initialize(ref shape, ref missing, ref mut bytes, ref mut arena), 3));
    let i64[3] extra = [42, 1, 0];
    assert(failed(store::initialize(ref shape, ref extra, ref mut bytes, ref mut arena), 3));
    assert(failed(store::initialize(ref shape, ref missing[..0], ref mut bytes, ref mut arena), 3));
    unchanged(ref bytes, ref before); assert(arena.used == 0 && arena.limit == 32);
}

@test
fn void signed_and_unsigned_range_failures_preserve_every_byte() {
    let u8[6] tags = [1, 1, 10, 10, 11, 11];
    let i64[6] invalid = [-2147483649, 2147483648, -1, 256, -1, 4294967296];
    var usize i = 0;
    while (i < 6) {
        let u8[1] one = [tags[i]]; let store::Shape shape = prepared(ref one);
        let i64[1] fields = [invalid[i]];
        var u8[16] bytes = [85; 16]; let u8[16] before = bytes;
        var arenas::Arena arena = arenas::empty(16);
        assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 9));
        unchanged(ref bytes, ref before); assert(arena.used == 0);
        i += 1;
    }
}

@test
fn void alignment_tail_padding_quota_and_retry_use_only_the_planned_extent() {
    let u8[2] tags = [9, 2]; let store::Shape shape = prepared(ref tags);
    let i64[2] fields = [42, 1];
    var u8[32] bytes = [85; 32]; var arenas::Arena arena = arenas::empty(23);
    prefix(ref mut bytes, ref mut arena); let u8[32] before = bytes;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 6));
    unchanged(ref bytes, ref before); assert(arena.used == 3 && arena.limit == 23);
    arena.limit = 24;
    assert(initialized(ref shape, ref fields, ref mut bytes, ref mut arena) == 8 && arena.used == 24);
    var usize i = 17; while (i < 24) { assert(bytes[i] == 0); i += 1; }
    i = 24; while (i < 32) { assert(bytes[i] == 85); i += 1; }
    let u8[32] full = bytes;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 6));
    unchanged(ref bytes, ref full); assert(arena.used == 24);
}

@test
fn void field_writes_are_independent_and_bad_bool_writes_are_atomic() {
    let u8[2] tags = [1, 2]; let store::Shape shape = prepared(ref tags);
    let i64[2] fields = [21, 1];
    var u8[32] bytes = [85; 32]; var arenas::Arena arena = arenas::empty(32);
    let usize base = initialized(ref shape, ref fields, ref mut bytes, ref mut arena);
    assert(store::write(ref shape, base, 0, 42, ref mut bytes, ref arena).is_ok);
    assert(read(ref shape, base, 0, ref bytes, ref arena) == 42 && read(ref shape, base, 1, ref bytes, ref arena) == 1);
    let u8[32] before = bytes;
    assert(failed(store::write(ref shape, base, 1, 2, ref mut bytes, ref arena), 9));
    assert(failed(store::write(ref shape, base, 2, 0, ref mut bytes, ref arena), 7));
    unchanged(ref bytes, ref before); assert(arena.used == 8 && arena.limit == 32);
    bytes[4] = 2;
    assert(switch (store::read(ref shape, base, 1, ref bytes, ref arena)) { case .ok(_): { false } case .err(e): { code(e) == 9 } });
    assert(store::write(ref shape, base, 1, 0, ref mut bytes, ref arena).is_ok);
    assert(read(ref shape, base, 1, ref bytes, ref arena) == 0);
}

@test
fn void field_access_requires_alignment_and_the_entire_published_record() {
    let u8[2] tags = [9, 2]; let store::Shape shape = prepared(ref tags);
    let i64[2] fields = [42, 1];
    var u8[32] bytes = [85; 32]; var arenas::Arena arena = arenas::empty(24);
    prefix(ref mut bytes, ref mut arena);
    assert(initialized(ref shape, ref fields, ref mut bytes, ref mut arena) == 8);
    let u8[32] before = bytes;
    assert(failed(store::write(ref shape, 9, 0, 0, ref mut bytes, ref arena), 8));
    assert(failed(store::write(ref shape, 18446744073709551608, 0, 0, ref mut bytes, ref arena), 7));
    assert(failed(store::write(ref shape, 8, 18446744073709551615, 0, ref mut bytes, ref arena), 7));
    arena.used = 23;
    assert(failed(store::write(ref shape, 8, 0, 0, ref mut bytes, ref arena), 7));
    arena.used = 25;
    assert(failed(store::write(ref shape, 8, 0, 0, ref mut bytes, ref arena), 10));
    arena.used = 24; arena.limit = 33;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 10));
    arena.limit = 24;
    assert(switch (store::read(ref shape, 8, 0, ref bytes[..23], ref arena)) { case .ok(_): { false } case .err(e): { code(e) == 10 } });
    unchanged(ref bytes, ref before);
}

@test
fn void maximum_sixteen_fields_fit_exactly_and_never_allocate_another_extent() {
    let u8[16] tags = [12; 16]; let store::Shape shape = prepared(ref tags);
    let i64[16] fields = [-1; 16];
    var u8[128] bytes = [85; 128]; var arenas::Arena arena = arenas::empty(128);
    assert(shape.bytes == 128 && shape.alignment == 8);
    assert(initialized(ref shape, ref fields, ref mut bytes, ref mut arena) == 0 && arena.used == 128);
    assert(read(ref shape, 0, 15, ref bytes, ref arena) == -1);
    assert(store::write(ref shape, 0, 15, 0, ref mut bytes, ref arena).is_ok);
    assert(read(ref shape, 0, 0, ref bytes, ref arena) == -1 && read(ref shape, 0, 15, ref bytes, ref arena) == 0);
    let u8[128] before = bytes;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 6));
    unchanged(ref bytes, ref before); assert(arena.used == 128);
}

@test
fn void prepared_metadata_is_recomputed_and_nested_storage_remains_rejected() {
    let u8[1] tags = [1]; var store::Shape shape = prepared(ref tags);
    let i64[1] fields = [42]; var u8[16] bytes = [85; 16]; let u8[16] before = bytes;
    var arenas::Arena arena = arenas::empty(16);
    shape.alignment = 0;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 4));
    shape = prepared(ref tags); shape.offsets[0] = 18446744073709551615;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 4));
    shape = prepared(ref tags); shape.bytes = 18446744073709551615;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 4));
    shape = prepared(ref tags); shape.offsets[15] = 1;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 4));
    shape = prepared(ref tags); shape.tags[0] = 3;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 2));
    shape.count = 17;
    assert(failed(store::initialize(ref shape, ref fields, ref mut bytes, ref mut arena), 3));
    unchanged(ref bytes, ref before); assert(arena.used == 0);
    var layouts::Catalog catalog = layouts::empty(); catalog.count = 2;
    catalog.fields[0] = 1; catalog.kinds[0] = 1; catalog.types[0] = 1;
    catalog.fields[1] = 1; catalog.types[16] = 10;
    assert(switch (store::prepare(ref catalog, 0)) { case .ok(_): { false } case .err(e): { code(e) == 2 } });
    assert(store::prepare(ref catalog, 1).is_ok);
    assert(switch (store::prepare(ref catalog, 2)) { case .ok(_): { false } case .err(e): { code(e) == 7 } });
    catalog.types[0] = 0;
    assert(switch (store::prepare(ref catalog, 0)) { case .ok(_): { false } case .err(e): { code(e) == 1 } });
}
