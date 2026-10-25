module tests::m2::struct_nested_storage;
import struct_nested_storage as store;
import struct_layout as layouts;
import array_storage as arenas;

fn usize ok(Result<usize, store::Error> result) {
    return switch (result) { case .ok(value): { value } case .err(_): { assert(false); 0 } };
}
fn i64 value(Result<i64, store::Error> result) {
    return switch (result) { case .ok(number): { number } case .err(_): { assert(false); 0 } };
}
fn u8 code(store::Error error) {
    return switch (error) { case .Layout: { 1 } case .Bounds: { 2 } case .Fields: { 3 }
        case .State: { 4 } case .Alignment: { 5 } case .Quota: { 6 } case .Overflow: { 7 }
        case .Value: { 8 } case .Type: { 9 } };
}
fn bool failed(Result<usize, store::Error> result, store::Error expected) {
    return switch (result) { case .ok(_): { false } case .err(error): { code(error) == code(expected) } };
}
fn bool read_failed(Result<i64, store::Error> result) {
    return switch (result) { case .ok(_): { false } case .err(_): { true } };
}
fn void unchanged(ref u8[] bytes, ref u8[] before) {
    assert(bytes.len == before.len);
    var usize i = 0; while (i < bytes.len) { assert(bytes[i] == before[i]); i += 1; }
}
fn layouts::Catalog pair() {
    var layouts::Catalog c = layouts::empty(); c.count = 2;
    c.fields[0] = 2; c.kinds[0] = 1; c.kinds[1] = 1; c.types[0] = 1; c.types[1] = 1;
    c.fields[1] = 2; c.types[16] = 9; c.types[17] = 2;
    return c;
}

@test
fn void repeated_nested_records_preserve_scalar_bits_and_all_padding() {
    var layouts::Catalog c = layouts::empty(); c.count = 3;
    c.fields[0] = 3; c.types[0] = 10; c.kinds[1] = 1; c.types[1] = 1; c.kinds[2] = 1; c.types[2] = 1;
    c.fields[1] = 3; c.types[16] = 1; c.types[17] = 2; c.kinds[18] = 1; c.types[18] = 2;
    c.fields[2] = 3; c.types[32] = 9; c.types[33] = 11; c.types[34] = 12;
    let i64[11] fields = [255, -2147483648, 1, -9223372036854775808, 4294967295, -1, 42, 0, 99, 10, 11];
    var u8[96] bytes = [85; 96]; var arenas::Arena arena = arenas::Arena { .used = 3, .limit = 96 };
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 8);
    assert(arena.used == 80 && bytes[0] == 85 && bytes[80] == 85);
    let usize[3] signed_path = [1, 2, 0]; let usize[3] unsigned_path = [1, 2, 2];
    let usize[3] other_path = [2, 2, 0]; let usize[2] bool_path = [1, 1];
    assert(value(store::read(ref c, 0, 8, ref signed_path, ref bytes, ref arena)) == -9223372036854775808);
    assert(value(store::read(ref c, 0, 8, ref unsigned_path, ref bytes, ref arena)) == -1);
    assert(value(store::read(ref c, 0, 8, ref other_path, ref bytes, ref arena)) == 99);
    assert(value(store::read(ref c, 0, 8, ref bool_path, ref bytes, ref arena)) == 1);
    let usize[1] first = [0]; let usize[2] i32_path = [1, 0]; let usize[3] u32_path = [1, 2, 1];
    assert(value(store::read(ref c, 0, 8, ref first, ref bytes, ref arena)) == 255);
    assert(value(store::read(ref c, 0, 8, ref i32_path, ref bytes, ref arena)) == -2147483648);
    assert(value(store::read(ref c, 0, 8, ref u32_path, ref bytes, ref arena)) == 4294967295);
    var usize i = 3; while (i < 8) { assert(bytes[i] == 0); i += 1; }
    i = 9; while (i < 16) { assert(bytes[i] == 0); i += 1; }
    assert(bytes[21] == 0 && bytes[23] == 0 && bytes[36] == 0 && bytes[39] == 0);
    assert(ok(store::write(ref c, 0, 8, ref other_path, 42, ref mut bytes, ref arena)) == 8);
    assert(value(store::read(ref c, 0, 8, ref other_path, ref bytes, ref arena)) == 42);
    assert(value(store::read(ref c, 0, 8, ref signed_path, ref bytes, ref arena)) == -9223372036854775808);
}

@test
fn void initialization_errors_preserve_every_byte_and_cursor() {
    let layouts::Catalog c = pair(); let i64[4] invalid = [42, 1, 99, 2]; let i64[4] fields = [42, 1, 99, 0];
    let i64[5] extra = [42, 1, 99, 0, 1]; var u8[64] bytes = [85; 64]; let u8[64] before = bytes;
    var arenas::Arena arena = arenas::empty(64);
    assert(failed(store::initialize(ref c, 0, ref invalid, ref mut bytes, ref mut arena), .Value));
    assert(failed(store::initialize(ref c, 0, ref fields[..3], ref mut bytes, ref mut arena), .Fields));
    assert(failed(store::initialize(ref c, 0, ref extra, ref mut bytes, ref mut arena), .Fields));
    assert(failed(store::initialize(ref c, 0, ref fields[..0], ref mut bytes, ref mut arena), .Fields));
    unchanged(ref bytes, ref before); assert(arena.used == 0);
    arena.used = 3; arena.limit = 39;
    assert(failed(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena), .Quota));
    unchanged(ref bytes, ref before); assert(arena.used == 3);
    arena.limit = 40;
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 8 && arena.used == 40);
    assert(bytes[3] == 0 && bytes[7] == 0 && bytes[40] == 85);
}

@test
fn void one_hundred_twenty_eight_leaves_fit_and_larger_roots_are_rejected() {
    var layouts::Catalog c = layouts::empty(); c.count = 2; c.fields[0] = 8; c.fields[1] = 16;
    var usize i = 0;
    while (i < 16) { c.types[16 + i] = 10; if (i < 8) { c.kinds[i] = 1; c.types[i] = 1; } i += 1; }
    let i64[128] fields = [255; 128]; var u8[128] bytes = [85; 128]; var arenas::Arena arena = arenas::empty(128);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0 && arena.used == 128);
    i = 0; while (i < 128) { assert(bytes[i] == 255); i += 1; }
    let usize[2] last = [7, 15]; let usize[2] first = [0, 15];
    assert(ok(store::write(ref c, 0, 0, ref last, 0, ref mut bytes, ref arena)) == 1);
    assert(value(store::read(ref c, 0, 0, ref last, ref bytes, ref arena)) == 0);
    assert(value(store::read(ref c, 0, 0, ref first, ref bytes, ref arena)) == 255);
    let u8[128] before = bytes; c.fields[0] = 9; c.kinds[8] = 1; c.types[8] = 1;
    assert(failed(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena), .Quota));
    assert(failed(store::write(ref c, 0, 0, ref last, 1, ref mut bytes, ref arena), .Quota));
    unchanged(ref bytes, ref before); assert(arena.used == 128);
}

@test
fn void depth_sixteen_is_iterative_and_seventeen_is_rejected() {
    var layouts::Catalog c = layouts::empty(); c.count = 16; var usize i = 0; var u8 child = 1;
    while (i < 16) { c.fields[i] = 1; if (i < 15) { c.kinds[i * 16] = 1; c.types[i * 16] = child; } i += 1; child += 1; }
    c.types[240] = 10;
    let i64[1] fields = [42]; let usize[16] path = [0; 16]; var u8[8] bytes = [85; 8]; var arenas::Arena arena = arenas::empty(8);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0 && arena.used == 1);
    assert(value(store::read(ref c, 0, 0, ref path, ref bytes, ref arena)) == 42);
    assert(ok(store::write(ref c, 0, 0, ref path, 99, ref mut bytes, ref arena)) == 1 && bytes[0] == 99);
    let u8[8] before = bytes;
    c.count = 17; c.kinds[240] = 1; c.types[240] = 16; c.fields[16] = 1; c.types[256] = 10;
    assert(failed(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena), .Layout));
    unchanged(ref bytes, ref before); assert(arena.used == 1);
}

@test
fn void paths_require_the_whole_root_and_scalar_endpoint_before_writes() {
    let layouts::Catalog c = pair(); let i64[4] fields = [42, 1, 99, 0];
    var u8[64] bytes = [85; 64]; var arenas::Arena arena = arenas::empty(64);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0);
    let u8[64] before = bytes; let usize[2] path = [0, 1]; let usize[3] long_path = [0, 1, 0]; let usize[2] outside = [2, 0];
    assert(failed(store::write(ref c, 0, 0, ref path, 2, ref mut bytes, ref arena), .Value));
    assert(failed(store::write(ref c, 0, 0, ref path[..0], 1, ref mut bytes, ref arena), .Bounds));
    assert(failed(store::write(ref c, 0, 0, ref path[..1], 1, ref mut bytes, ref arena), .Type));
    assert(failed(store::write(ref c, 0, 0, ref long_path, 1, ref mut bytes, ref arena), .Type));
    assert(failed(store::write(ref c, 0, 0, ref outside, 1, ref mut bytes, ref arena), .Bounds));
    assert(failed(store::write(ref c, 0, 1, ref path, 1, ref mut bytes, ref arena), .Alignment));
    assert(failed(store::write(ref c, 0, 18446744073709551608, ref path, 1, ref mut bytes, ref arena), .Bounds));
    arena.used = 31;
    assert(failed(store::write(ref c, 0, 0, ref path, 1, ref mut bytes, ref arena), .Bounds));
    assert(read_failed(store::read(ref c, 0, 0, ref path, ref bytes, ref arena)));
    arena.used = 32; arena.limit = 65;
    assert(failed(store::write(ref c, 0, 0, ref path, 1, ref mut bytes, ref arena), .State));
    arena.limit = 64; unchanged(ref bytes, ref before);
    bytes[8] = 2; assert(read_failed(store::read(ref c, 0, 0, ref path, ref bytes, ref arena)));
}

@test
fn void the_entire_catalog_is_revalidated_without_capping_unselected_records() {
    var layouts::Catalog c = layouts::empty(); c.count = 3;
    c.fields[0] = 1; c.types[0] = 10;
    c.fields[1] = 2; c.kinds[16] = 1; c.types[16] = 2; c.kinds[17] = 1; c.types[17] = 2;
    c.fields[2] = 16; var usize i = 0; while (i < 16) { c.types[32 + i] = 9; i += 1; }
    let i64[1] fields = [42]; var u8[8] bytes = [85; 8]; var arenas::Arena arena = arenas::empty(8);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0 && arena.used == 1);
    let u8[8] before = bytes;
    assert(failed(store::initialize(ref c, 3, ref fields, ref mut bytes, ref mut arena), .Bounds));
    c.types[511] = 10;
    assert(failed(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena), .Layout));
    c.types[511] = 0; c.types[0] = 3;
    assert(failed(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena), .Layout));
    c.types[0] = 10; c.count = 4; c.fields[3] = 1; c.kinds[48] = 1; c.types[48] = 3;
    assert(failed(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena), .Layout));
    unchanged(ref bytes, ref before); assert(arena.used == 1);
}
