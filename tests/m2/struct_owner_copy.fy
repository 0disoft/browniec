module tests::m2::struct_owner_copy;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;

fn records::Catalog catalog() {
    var records::Catalog c = records::empty(); c.count = 2;
    c.fields[0] = 1; c.kinds[0] = 1; c.types[0] = 1;
    c.fields[1] = 2; c.types[16] = 9; c.types[17] = 2;
    return c;
}
fn arrays::Array byte_array() {
    return arrays::Array { .element = 10, .length = 1, .stride = 1, .alignment = 1, .bytes = 1 };
}
fn owners::Token token(Result<owners::Token, owners::Error> result) {
    return switch (result) { case .ok(t): { t } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } } };
}
fn usize size(Result<usize, owners::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn i64 value(Result<i64, owners::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn u8 code(owners::Error error) {
    return switch (error) { case .Token: { 1 } case .Owners: { 2 } case .State: { 3 }
        case .Type: { 4 } case .Length: { 5 } case .Metadata: { 6 } case .Overflow: { 7 }
        case .Quota: { 8 } case .Bounds: { 9 } case .Alignment: { 10 } case .Value: { 11 } };
}
fn bool failed_token(Result<owners::Token, owners::Error> result, u8 expected) {
    return switch (result) { case .ok(_): { false } case .err(e): { code(e) == expected } };
}
fn bool failed_read(Result<i64, owners::Error> result, u8 expected) {
    return switch (result) { case .ok(_): { false } case .err(e): { code(e) == expected } };
}
fn bool failed(Result<usize, owners::Error> result, u8 expected) {
    return switch (result) { case .ok(_): { false } case .err(e): { code(e) == expected } };
}
fn void same(ref owners::Table a, ref owners::Table b, ref u8[] bytes, ref u8[] before) {
    assert(a.depth == b.depth && a.arena.used == b.arena.used && a.arena.limit == b.arena.limit);
    var usize i = 0;
    while (i < 16) {
        assert(a.order[i] == b.order[i]);
        assert(a.slots[i].generation == b.slots[i].generation && a.slots[i].live == b.slots[i].live);
        assert(a.slots[i].occupied == b.slots[i].occupied && a.slots[i].mark == b.slots[i].mark);
        assert(a.slots[i].base == b.slots[i].base && a.slots[i].end == b.slots[i].end);
        assert(a.slots[i].element == b.slots[i].element && a.slots[i].length == b.slots[i].length);
        assert(a.slots[i].record == b.slots[i].record && a.slots[i].alignment == b.slots[i].alignment);
        i += 1;
    }
    assert(bytes.len == before.len); i = 0;
    while (i < bytes.len) { assert(bytes[i] == before[i]); i += 1; }
}

@test
fn void copies_are_independent_survive_source_release_and_preserve_mixed_arrays() {
    let records::Catalog c = catalog(); let arrays::Array array = byte_array(); let i64[2] fields = [-9223372036854775808, 1];
    var u8[96] bytes = [85; 96]; var owners::Table table = owners::empty(96);
    let owners::Token a = token(owners::create(ref array, 123, ref mut bytes, ref mut table));
    let owners::Token source = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    var usize i = 17; while (i < 24) { bytes[i] = 85; i += 1; }
    let owners::Token copy = token(owners::copy_record(ref c, source, ref mut bytes, ref mut table));
    assert(source.slot != copy.slot && table.depth == 3 && table.arena.used == 40);
    assert(table.slots[copy.slot].record == 0 && table.slots[copy.slot].length == 16 && table.slots[copy.slot].alignment == 8);
    i = 33; while (i < 40) { assert(bytes[i] == 0); i += 1; } assert(bytes[17] == 85 && bytes[40] == 85);
    let usize[2] path = [0, 0];
    assert(size(owners::write_record(ref c, ref table, source, ref path, 99, ref mut bytes)) == 8);
    assert(value(owners::read_record(ref c, ref table, copy, ref path, ref bytes)) == -9223372036854775808);
    assert(size(owners::write_record(ref c, ref table, copy, ref path, -1, ref mut bytes)) == 8);
    assert(value(owners::read_record(ref c, ref table, source, ref path, ref bytes)) == 99);
    let owners::Token acopy = token(owners::copy(a, ref mut bytes, ref mut table));
    assert(value(owners::read(ref table, acopy, 0, ref bytes)) == 123);
    assert(size(owners::release(ref mut table, acopy, bytes.len)) == 1);
    let owners::Token[1] sources = [a]; let arrays::Array[1] shapes = [array];
    let owners::Copies captures = switch (owners::copy_arguments(ref sources, ref shapes, ref mut bytes, ref mut table)) {
        case .ok(copies): { copies }
        case .err(_): { assert(false); owners::Copies { .tokens = [owners::Token { .slot = 0, .generation = 0 }; 8], .count = 0 } }
    };
    assert(captures.count == 1 && value(owners::read(ref table, captures.tokens[0], 0, ref bytes)) == 123);
    assert(value(owners::read_record(ref c, ref table, copy, ref path, ref bytes)) == -1);
    assert(size(owners::release(ref mut table, captures.tokens[0], bytes.len)) == 1);
    assert(size(owners::release(ref mut table, source, bytes.len)) == 0);
    assert(value(owners::read_record(ref c, ref table, copy, ref path, ref bytes)) == -1);
    assert(size(owners::release(ref mut table, a, bytes.len)) == 0);
    assert(size(owners::release(ref mut table, copy, bytes.len)) == 40 && table.depth == 0 && table.arena.used == 0);
}

@test
fn void matching_layouts_with_distinct_record_ids_and_array_tokens_are_rejected() {
    let records::Catalog c = catalog(); let arrays::Array array = byte_array(); let i64[2] fields = [42, 1];
    var u8[64] bytes = [85; 64]; var owners::Table table = owners::empty(64);
    let owners::Token a = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    let owners::Token b = token(owners::create_record(ref c, 1, ref fields, ref mut bytes, ref mut table));
    let owners::Token scalar = token(owners::create(ref array, 123, ref mut bytes, ref mut table));
    let owners::Table before = table; let u8[64] saved = bytes;
    assert(failed(owners::assign_record(ref c, a, b, ref mut bytes, ref table), 4));
    assert(failed(owners::assign_record(ref c, b, a, ref mut bytes, ref table), 4));
    assert(failed(owners::assign_record(ref c, scalar, a, ref mut bytes, ref table), 4));
    assert(failed(owners::assign_record(ref c, a, scalar, ref mut bytes, ref table), 4));
    assert(failed_token(owners::copy_record(ref c, scalar, ref mut bytes, ref mut table), 4));
    same(ref table, ref before, ref bytes, ref saved);
}

@test
fn void full_capacity_assignment_and_self_assignment_keep_owner_metadata() {
    var records::Catalog c = records::empty(); c.count = 2; c.fields[0] = 8; c.fields[1] = 16;
    var usize i = 0;
    while (i < 16) { c.types[16 + i] = 2; if (i < 8) { c.kinds[i] = 1; c.types[i] = 1; } i += 1; }
    let i64[128] fields = [1; 128]; var u8[256] bytes = [85; 256]; var owners::Table table = owners::empty(256);
    let owners::Token source = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    let owners::Token target = token(owners::copy_record(ref c, source, ref mut bytes, ref mut table));
    bytes[127] = 0; let owners::Table before = table;
    assert(size(owners::assign_record(ref c, target, source, ref mut bytes, ref table)) == 128);
    i = 0; while (i < 127) { assert(bytes[128 + i] == 1); i += 1; } assert(bytes[255] == 0);
    let u8[256] assigned = bytes;
    assert(size(owners::assign_record(ref c, target, target, ref mut bytes, ref table)) == 128);
    same(ref table, ref before, ref bytes, ref assigned);
    assert(failed_token(owners::copy_record(ref c, source, ref mut bytes, ref mut table), 8));
    same(ref table, ref before, ref bytes, ref assigned);
}

@test
fn void quota_alignment_and_full_mixed_descriptor_pressure_are_atomic() {
    let records::Catalog c = catalog(); let arrays::Array array = byte_array(); let i64[2] fields = [42, 1];
    var u8[512] bytes = [85; 512]; var owners::Table table = owners::empty(47);
    let owners::Token a = token(owners::create(ref array, 123, ref mut bytes, ref mut table));
    let owners::Token source = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    let owners::Token b = token(owners::create(ref array, 99, ref mut bytes, ref mut table));
    let owners::Table limited = table; let u8[512] saved = bytes;
    assert(failed_token(owners::copy_record(ref c, source, ref mut bytes, ref mut table), 8));
    same(ref table, ref limited, ref bytes, ref saved); assert(table.arena.used == 25);
    table.arena.limit = 48;
    let owners::Token copy = token(owners::copy_record(ref c, source, ref mut bytes, ref mut table));
    assert(table.slots[copy.slot].base == 32 && table.arena.used == 48);
    var usize i = 25; while (i < 32) { assert(bytes[i] == 0); i += 1; }
    assert(bytes[24] == 99 && bytes[48] == 85);
    assert(size(owners::clear(ref mut table, bytes.len)) == 48); table.arena.limit = 512;
    var owners::Token last = owners::Token { .slot = 0, .generation = 0 }; i = 0;
    while (i < 8) {
        let owners::Token t = token(owners::create(ref array, 1, ref mut bytes, ref mut table));
        last = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table)); i += 1;
    }
    let owners::Table full = table; let u8[512] full_bytes = bytes;
    assert(failed_token(owners::copy_record(ref c, last, ref mut bytes, ref mut table), 2));
    assert(size(owners::assign_record(ref c, last, last, ref mut bytes, ref table)) == 16);
    same(ref table, ref full, ref bytes, ref full_bytes); assert(table.depth == 16 && table.arena.used == 192);
}

@test
fn void corrupt_bool_stale_tokens_and_bad_metadata_never_publish_partial_copies() {
    var records::Catalog c = catalog(); let i64[2] fields = [42, 1];
    var u8[64] bytes = [85; 64]; var owners::Table table = owners::empty(64);
    let owners::Token source = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    let owners::Token target = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    bytes[8] = 255; let owners::Table before = table; let u8[64] saved = bytes;
    assert(failed_token(owners::copy_record(ref c, source, ref mut bytes, ref mut table), 11));
    assert(failed(owners::assign_record(ref c, target, source, ref mut bytes, ref table), 11));
    assert(failed(owners::assign_record(ref c, source, source, ref mut bytes, ref table), 11));
    same(ref table, ref before, ref bytes, ref saved);
    bytes[8] = 1; c.fields[1] = 1; c.types[17] = 0;
    let u8[64] repaired = bytes;
    assert(failed_token(owners::copy_record(ref c, source, ref mut bytes, ref mut table), 6));
    assert(failed(owners::assign_record(ref c, target, source, ref mut bytes, ref table), 6));
    same(ref table, ref before, ref bytes, ref repaired); c = catalog();
    table.slots[source.slot].alignment = 0;
    assert(failed_token(owners::copy_record(ref c, source, ref mut bytes, ref mut table), 3));
    assert(failed(owners::assign_record(ref c, target, source, ref mut bytes, ref table), 3));
    table.slots[source.slot].alignment = 8;
    assert(size(owners::release(ref mut table, source, bytes.len)) == 0);
    let owners::Table released = table; let u8[64] after = bytes;
    assert(failed_token(owners::copy_record(ref c, source, ref mut bytes[..0], ref mut table), 1));
    assert(failed(owners::assign_record(ref c, source, target, ref mut bytes, ref table), 1));
    assert(failed(owners::assign_record(ref c, target, source, ref mut bytes, ref table), 1));
    same(ref table, ref released, ref bytes, ref after);
}

@test
fn void deepest_records_copy_and_assign_without_per_field_owners() {
    var records::Catalog c = records::empty(); c.count = 16; var usize i = 0; var u8 child = 1;
    while (i < 16) { c.fields[i] = 1; if (i < 15) { c.kinds[i * 16] = 1; c.types[i * 16] = child; } i += 1; child += 1; }
    c.types[240] = 10; let i64[1] fields = [42]; let usize[16] path = [0; 16];
    var u8[2] bytes = [85; 2]; var owners::Table table = owners::empty(2);
    let owners::Token source = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    let owners::Token target = token(owners::copy_record(ref c, source, ref mut bytes, ref mut table));
    assert(table.depth == 2 && table.arena.used == 2);
    assert(size(owners::write_record(ref c, ref table, source, ref path, 99, ref mut bytes)) == 1);
    assert(size(owners::assign_record(ref c, target, source, ref mut bytes, ref table)) == 1);
    assert(value(owners::read_record(ref c, ref table, target, ref path, ref bytes)) == 99);
    assert(size(owners::release(ref mut table, source, bytes.len)) == 0);
    assert(size(owners::release(ref mut table, target, bytes.len)) == 2 && table.depth == 0);
}
