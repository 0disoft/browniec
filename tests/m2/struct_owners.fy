module tests::m2::struct_owners;
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
fn void arrays_and_nested_records_share_slots_arena_and_typed_access() {
    let records::Catalog c = catalog(); let arrays::Array array = byte_array(); let i64[2] fields = [-9223372036854775808, 1];
    var u8[64] bytes = [85; 64]; var owners::Table table = owners::empty(64);
    let owners::Token a = token(owners::create(ref array, 123, ref mut bytes, ref mut table));
    let owners::Token r = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    assert(table.depth == 2 && table.arena.used == 24 && table.slots[r.slot].base == 8);
    let usize[2] number = [0, 0]; let usize[2] flag = [0, 1];
    assert(value(owners::read_record(ref c, ref table, r, ref number, ref bytes)) == -9223372036854775808);
    assert(size(owners::write_record(ref c, ref table, r, ref number, 42, ref mut bytes)) == 8);
    assert(value(owners::read_record(ref c, ref table, r, ref number, ref bytes)) == 42);
    assert(value(owners::read_record(ref c, ref table, r, ref flag, ref bytes)) == 1);
    assert(value(owners::read(ref table, a, 0, ref bytes)) == 123);
    assert(failed_read(owners::read(ref table, r, 0, ref bytes), 4));
    assert(failed(owners::write(ref table, r, 0, 9, ref mut bytes), 4));
    assert(failed(owners::fill(ref table, r, 0, ref mut bytes), 4));
    assert(failed_token(owners::copy(r, ref mut bytes, ref mut table), 4));
    assert(failed(owners::assign(a, r, ref mut bytes, ref table), 4));
    assert(failed(owners::assign(r, a, ref mut bytes, ref table), 4));
    assert(failed(owners::validate_result(ref table, r, 10, 16, ref bytes), 4));
    assert(failed_read(owners::read_record(ref c, ref table, a, ref number, ref bytes), 4));
    assert(failed(owners::write_record(ref c, ref table, a, ref number, 1, ref mut bytes), 4));
    var usize i = 1; while (i < 8) { assert(bytes[i] == 0); i += 1; }
    i = 17; while (i < 24) { assert(bytes[i] == 0); i += 1; }
    assert(bytes[24] == 85 && table.arena.used == 24);
}

@test
fn void mixed_middle_holes_reclaim_padding_and_stale_tokens_never_revive() {
    let records::Catalog c = catalog(); let arrays::Array array = byte_array(); let i64[2] fields = [42, 1];
    var u8[64] bytes = [85; 64]; var owners::Table table = owners::empty(64);
    let owners::Token a = token(owners::create(ref array, 123, ref mut bytes, ref mut table));
    let owners::Token r = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    let owners::Token b = token(owners::create(ref array, 99, ref mut bytes, ref mut table));
    assert(size(owners::release(ref mut table, r, bytes.len)) == 0 && table.arena.used == 25);
    let usize[2] path = [0, 0];
    assert(failed_read(owners::read_record(ref c, ref table, r, ref path, b""), 1));
    assert(failed(owners::write_record(ref c, ref table, r, ref path, 0, ref mut bytes), 1));
    assert(failed(owners::release(ref mut table, r, bytes.len), 1));
    assert(size(owners::release(ref mut table, b, bytes.len)) == 24 && table.arena.used == 1 && table.depth == 1);
    let owners::Token fresh = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    assert(fresh.slot == r.slot && fresh.generation != r.generation);
    assert(failed_read(owners::read_record(ref c, ref table, r, ref path, ref bytes), 1));
    assert(size(owners::release(ref mut table, a, bytes.len)) == 0);
    assert(size(owners::release(ref mut table, fresh, bytes.len)) == 24 && table.depth == 0 && table.arena.used == 0);
}

@test
fn void generation_retirement_and_clear_apply_to_both_owner_kinds() {
    let records::Catalog c = catalog(); let arrays::Array array = byte_array(); let i64[2] fields = [42, 1];
    var u8[64] bytes = [85; 64]; var owners::Table table = owners::empty(64);
    let owners::Token old = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    table.slots[old.slot].generation = 18446744073709551615;
    let owners::Token last = owners::Token { .slot = old.slot, .generation = 18446744073709551615 };
    assert(size(owners::release(ref mut table, last, bytes.len)) == 16 && table.slots[old.slot].generation == 0);
    let owners::Token a = token(owners::create(ref array, 1, ref mut bytes, ref mut table));
    let owners::Token r = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    assert(a.slot != old.slot && r.slot != old.slot);
    assert(size(owners::clear(ref mut table, bytes.len)) == 24 && table.depth == 0);
    let usize[2] path = [0, 0];
    assert(failed_read(owners::read_record(ref c, ref table, r, ref path, b""), 1));
    assert(failed_read(owners::read(ref table, a, 0, b""), 1));
    assert(table.slots[old.slot].generation == 0);
    let owners::Token fresh = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    assert(fresh.slot != old.slot && fresh.generation != r.generation);
}

@test
fn void invalid_values_quota_and_shared_sixteen_owner_pressure_roll_back() {
    let records::Catalog c = catalog(); let arrays::Array array = byte_array(); let i64[2] fields = [42, 1]; let i64[2] invalid = [42, 2];
    var u8[512] bytes = [85; 512]; var owners::Table table = owners::empty(512);
    let owners::Table before = table; let u8[512] saved = bytes;
    assert(failed_token(owners::create_record(ref c, 0, ref invalid, ref mut bytes, ref mut table), 11));
    assert(failed_token(owners::create_record(ref c, 0, ref fields[..1], ref mut bytes, ref mut table), 5));
    same(ref table, ref before, ref bytes, ref saved);
    var usize i = 0;
    while (i < 8) {
        let owners::Token a = token(owners::create(ref array, 1, ref mut bytes, ref mut table));
        let owners::Token r = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
        i += 1;
    }
    assert(table.depth == 16 && table.arena.used == 192);
    let owners::Table full = table; let u8[512] full_bytes = bytes;
    assert(failed_token(owners::create(ref array, 1, ref mut bytes, ref mut table), 2));
    assert(failed_token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table), 2));
    same(ref table, ref full, ref bytes, ref full_bytes);
    assert(size(owners::clear(ref mut table, bytes.len)) == 192);
    let owners::Token a = token(owners::create(ref array, 1, ref mut bytes, ref mut table));
    table.arena.limit = 23; let owners::Table limited = table; let u8[512] limited_bytes = bytes;
    assert(failed_token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table), 8));
    same(ref table, ref limited, ref bytes, ref limited_bytes);
}

@test
fn void forged_record_extents_and_catalog_mismatch_fail_before_mutation() {
    var records::Catalog c = catalog(); let i64[2] fields = [42, 1];
    var u8[64] bytes = [85; 64]; var owners::Table table = owners::empty(64);
    let owners::Token r = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    let usize[2] path = [0, 1]; let u8[64] before = bytes;
    table.slots[r.slot].alignment = 0;
    assert(failed_read(owners::read_record(ref c, ref table, r, ref path, ref bytes), 3));
    assert(failed(owners::release(ref mut table, r, bytes.len), 3));
    table.slots[r.slot].alignment = 8; table.slots[r.slot].end = 15;
    assert(failed(owners::write_record(ref c, ref table, r, ref path, 0, ref mut bytes), 3));
    table.slots[r.slot].end = 16; table.order[0] = 16;
    assert(failed(owners::clear(ref mut table, bytes.len), 3));
    table.order[0] = r.slot; c.fields[1] = 1; c.types[17] = 0;
    assert(failed(owners::write_record(ref c, ref table, r, ref path, 0, ref mut bytes), 6));
    c = catalog();
    assert(failed(owners::write_record(ref c, ref table, r, ref path, 2, ref mut bytes), 11));
    var usize i = 0; while (i < 64) { assert(bytes[i] == before[i]); i += 1; }
    assert(table.slots[r.slot].live && table.slots[r.slot].generation == r.generation && table.arena.used == 16);
}

@test
fn void one_owner_holds_maximum_leaves_or_maximum_depth() {
    var records::Catalog c = records::empty(); c.count = 2; c.fields[0] = 8; c.fields[1] = 16;
    var usize i = 0;
    while (i < 16) { c.types[16 + i] = 10; if (i < 8) { c.kinds[i] = 1; c.types[i] = 1; } i += 1; }
    let i64[128] fields = [255; 128]; var u8[128] bytes = [85; 128]; var owners::Table table = owners::empty(128);
    let owners::Token r = token(owners::create_record(ref c, 0, ref fields, ref mut bytes, ref mut table));
    assert(table.depth == 1 && table.arena.used == 128);
    let usize[2] path = [7, 15]; assert(value(owners::read_record(ref c, ref table, r, ref path, ref bytes)) == 255);
    assert(size(owners::release(ref mut table, r, bytes.len)) == 128);
    c = records::empty(); c.count = 16; i = 0; var u8 child = 1;
    while (i < 16) { c.fields[i] = 1; if (i < 15) { c.kinds[i * 16] = 1; c.types[i * 16] = child; } i += 1; child += 1; }
    c.types[240] = 10; let i64[1] one = [42]; let usize[16] deep = [0; 16];
    let owners::Token d = token(owners::create_record(ref c, 0, ref one, ref mut bytes, ref mut table));
    assert(table.depth == 1 && value(owners::read_record(ref c, ref table, d, ref deep, ref bytes)) == 42);
    assert(size(owners::write_record(ref c, ref table, d, ref deep, 99, ref mut bytes)) == 1);
    assert(size(owners::release(ref mut table, d, bytes.len)) == 1);
}
