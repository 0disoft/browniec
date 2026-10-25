module tests::m2::struct_nested_copy;
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
fn void all_scalar_bits_copy_independently_and_nested_padding_is_zeroed() {
    var layouts::Catalog c = layouts::empty(); c.count = 3;
    c.fields[0] = 3; c.types[0] = 10; c.kinds[1] = 1; c.types[1] = 1; c.kinds[2] = 1; c.types[2] = 1;
    c.fields[1] = 3; c.types[16] = 1; c.types[17] = 2; c.kinds[18] = 1; c.types[18] = 2;
    c.fields[2] = 3; c.types[32] = 9; c.types[33] = 11; c.types[34] = 12;
    let i64[11] fields = [255, -2147483648, 1, -9223372036854775808, 4294967295, -1, 42, 0, 99, 10, 11];
    var u8[192] bytes = [85; 192]; var arenas::Arena arena = arenas::empty(192);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0);
    let u8[192] canonical = bytes;
    bytes[1] = 85; bytes[13] = 99; bytes[28] = 86;
    assert(ok(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena)) == 72 && arena.used == 144);
    var usize i = 0; while (i < 72) { assert(bytes[72 + i] == canonical[i]); i += 1; }
    assert(bytes[1] == 85 && bytes[13] == 99 && bytes[28] == 86);
    let usize[3] path = [1, 2, 0];
    assert(ok(store::write(ref c, 0, 0, ref path, 42, ref mut bytes, ref arena)) == 8);
    assert(value(store::read(ref c, 0, 72, ref path, ref bytes, ref arena)) == -9223372036854775808);
    assert(ok(store::assign(ref c, 0, 0, 72, ref mut bytes, ref arena)) == 72);
    i = 0; while (i < 72) { assert(bytes[i] == canonical[i]); i += 1; }
    i = 144; while (i < 192) { assert(bytes[i] == 85); i += 1; }
    assert(arena.used == 144 && arena.limit == 192);
}

@test
fn void copy_charges_existing_bytes_and_alignment_before_publication() {
    let layouts::Catalog c = pair(); let i64[4] fields = [42, 1, 99, 0];
    var u8[80] bytes = [85; 80]; var arenas::Arena arena = arenas::empty(71);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0);
    bytes[32] = 123; arena.used = 33; let u8[80] before = bytes;
    assert(failed(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena), .Quota));
    unchanged(ref bytes, ref before); assert(arena.used == 33 && arena.limit == 71);
    arena.limit = 72;
    assert(ok(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena)) == 40 && arena.used == 72);
    var usize i = 33; while (i < 40) { assert(bytes[i] == 0); i += 1; }
    assert(bytes[32] == 123 && bytes[72] == 85 && bytes[71] == 0);
    let usize[2] path = [1, 0];
    assert(value(store::read(ref c, 0, 40, ref path, ref bytes, ref arena)) == 99);
}

fn void overlapping(bool forward) {
    var layouts::Catalog c = pair(); c.fields[0] = 1; c.kinds[1] = 0; c.types[1] = 0;
    let i64[2] first = [72623859790382856, 1]; let i64[2] second = [1, 0];
    var u8[32] bytes = [85; 32]; var arenas::Arena arena = arenas::empty(32);
    assert(ok(store::initialize(ref c, 0, ref first, ref mut bytes, ref mut arena)) == 0);
    assert(ok(store::initialize(ref c, 0, ref second, ref mut bytes, ref mut arena)) == 16);
    let u8[32] before = bytes;
    let usize destination = if (forward) { 8 } else { 0 }; let usize source = if (forward) { 0 } else { 8 };
    let usize[2] integer = [0, 0]; let usize[2] boolean = [0, 1];
    let i64 number = value(store::read(ref c, 0, source, ref integer, ref bytes, ref arena));
    let i64 flag = value(store::read(ref c, 0, source, ref boolean, ref bytes, ref arena));
    assert(ok(store::assign(ref c, 0, destination, source, ref mut bytes, ref arena)) == 16);
    assert(value(store::read(ref c, 0, destination, ref integer, ref bytes, ref arena)) == number);
    assert(value(store::read(ref c, 0, destination, ref boolean, ref bytes, ref arena)) == flag);
    var usize i = 0;
    while (i < 32) { if (i < destination || i >= destination + 16) { assert(bytes[i] == before[i]); } i += 1; }
    i = destination + 9; while (i < destination + 16) { bytes[i] = 85; i += 1; }
    assert(ok(store::assign(ref c, 0, destination, destination, ref mut bytes, ref arena)) == 16);
    i = destination + 9; while (i < destination + 16) { assert(bytes[i] == 0); i += 1; }
    assert(arena.used == 32 && arena.limit == 32);
}
@test
fn void both_overlap_directions_and_self_assignment_use_prewrite_values() {
    overlapping(true); overlapping(false);
}

@test
fn void corrupt_last_nested_bool_rejects_copy_assign_and_self_atomically() {
    let layouts::Catalog c = pair(); let i64[4] fields = [42, 1, 99, 1];
    var u8[96] bytes = [85; 96]; var arenas::Arena arena = arenas::empty(96);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 32);
    bytes[24] = 255; let u8[96] before = bytes;
    assert(failed(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena), .Value));
    assert(failed(store::assign(ref c, 0, 32, 0, ref mut bytes, ref arena), .Value));
    assert(failed(store::assign(ref c, 0, 0, 0, ref mut bytes, ref arena), .Value));
    unchanged(ref bytes, ref before); assert(arena.used == 64 && arena.limit == 96);
    bytes[24] = 1;
    assert(ok(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena)) == 64 && arena.used == 96);
    let usize[2] path = [1, 1]; assert(value(store::read(ref c, 0, 64, ref path, ref bytes, ref arena)) == 1);
}

@test
fn void maximum_leaves_and_depth_copy_and_assign_at_full_capacity() {
    var layouts::Catalog c = layouts::empty(); c.count = 2; c.fields[0] = 8; c.fields[1] = 16;
    var usize i = 0;
    while (i < 16) { c.types[16 + i] = 10; if (i < 8) { c.kinds[i] = 1; c.types[i] = 1; } i += 1; }
    let i64[128] fields = [255; 128]; var u8[256] bytes = [85; 256]; var arenas::Arena arena = arenas::empty(256);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0);
    assert(ok(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena)) == 128 && arena.used == 256);
    bytes[255] = 0;
    assert(ok(store::assign(ref c, 0, 0, 128, ref mut bytes, ref arena)) == 128);
    i = 0; while (i < 127) { assert(bytes[i] == 255); i += 1; } assert(bytes[127] == 0);
    let u8[256] before = bytes;
    assert(failed(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena), .Quota));
    unchanged(ref bytes, ref before); assert(arena.used == 256);
    c = layouts::empty(); c.count = 16; i = 0; var u8 child = 1;
    while (i < 16) { c.fields[i] = 1; if (i < 15) { c.kinds[i * 16] = 1; c.types[i * 16] = child; } i += 1; child += 1; }
    c.types[240] = 10; let i64[1] one = [42]; var u8[2] deep = [85; 2]; var arenas::Arena small = arenas::empty(2);
    assert(ok(store::initialize(ref c, 0, ref one, ref mut deep, ref mut small)) == 0);
    assert(ok(store::copy(ref c, 0, 0, ref mut deep, ref mut small)) == 1 && small.used == 2);
    deep[1] = 99; assert(ok(store::assign(ref c, 0, 0, 1, ref mut deep, ref small)) == 1 && deep[0] == 99);
}

@test
fn void catalogs_states_alignment_and_both_complete_extents_are_rechecked() {
    var layouts::Catalog c = pair(); let i64[4] fields = [42, 1, 99, 1];
    var u8[96] bytes = [85; 96]; var arenas::Arena arena = arenas::empty(96);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 0);
    assert(ok(store::initialize(ref c, 0, ref fields, ref mut bytes, ref mut arena)) == 32);
    let u8[96] before = bytes;
    assert(failed(store::copy(ref c, 2, 0, ref mut bytes, ref mut arena), .Bounds));
    assert(failed(store::copy(ref c, 0, 1, ref mut bytes, ref mut arena), .Alignment));
    assert(failed(store::copy(ref c, 0, 18446744073709551608, ref mut bytes, ref mut arena), .Bounds));
    assert(failed(store::assign(ref c, 0, 1, 0, ref mut bytes, ref arena), .Alignment));
    assert(failed(store::assign(ref c, 0, 0, 1, ref mut bytes, ref arena), .Alignment));
    assert(failed(store::assign(ref c, 0, 64, 0, ref mut bytes, ref arena), .Bounds));
    assert(failed(store::assign(ref c, 0, 0, 64, ref mut bytes, ref arena), .Bounds));
    arena.used = 63;
    assert(failed(store::copy(ref c, 0, 32, ref mut bytes, ref mut arena), .Bounds));
    assert(failed(store::assign(ref c, 0, 32, 0, ref mut bytes, ref arena), .Bounds));
    assert(failed(store::assign(ref c, 0, 0, 32, ref mut bytes, ref arena), .Bounds));
    arena.used = 64; arena.limit = 97;
    assert(failed(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena), .State));
    assert(failed(store::assign(ref c, 0, 32, 0, ref mut bytes, ref arena), .State));
    arena.limit = 96; c.types[511] = 10;
    assert(failed(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena), .Layout));
    assert(failed(store::assign(ref c, 0, 32, 0, ref mut bytes, ref arena), .Layout));
    c.types[511] = 0; c.kinds[16] = 1; c.types[16] = 0;
    assert(failed(store::copy(ref c, 0, 0, ref mut bytes, ref mut arena), .Layout));
    assert(failed(store::assign(ref c, 0, 32, 0, ref mut bytes, ref arena), .Layout));
    unchanged(ref bytes, ref before); assert(arena.used == 64 && arena.limit == 96);
}
