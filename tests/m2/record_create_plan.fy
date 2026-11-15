module tests::m2::record_create_plan;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import struct_nested_storage as storage;
import array_storage as arenas;

// Frozen ce99a01 owner preflight/publication. Raw initialize keeps its API and
// exact checked encoding order; separate goldens cover raw bytes and receipts.
fn owners::Error mapped(storage::Error error) {
    return switch (error) {
        case .Layout: { .Metadata } case .Bounds: { .Bounds } case .Fields: { .Length }
        case .State: { .State } case .Alignment: { .Alignment } case .Quota: { .Quota }
        case .Overflow: { .Overflow } case .Value: { .Value } case .Type: { .Type }
    };
}

fn Result<arrays::Array, owners::Error> original_layout(ref owners::Owner owner) {
    if (owner.element != 0) {
        if (owner.record != 0 || owner.alignment != 0) { return .err(.State); }
        return switch (arrays::scalar(owner.element, owner.length)) {
            case .ok(value): { .ok(value) } case .err(_): { .err(.State) }
        };
    }
    if (owner.record >= 32 || owner.length == 0 || owner.length > 128) { return .err(.State); }
    if (owner.alignment != 1 && owner.alignment != 4 && owner.alignment != 8) { return .err(.State); }
    if (owner.length % owner.alignment != 0) { return .err(.State); }
    let u8 tag = if (owner.alignment == 1) { 10 } else if (owner.alignment == 4) { 11 } else { 12 };
    return switch (arrays::scalar(tag, owner.length / owner.alignment)) {
        case .ok(value): { .ok(value) } case .err(_): { .err(.State) }
    };
}

fn bool original_valid(ref owners::Table table, usize capacity) {
    if (table.depth > 16 || table.arena.used > table.arena.limit || table.arena.limit > capacity) { return false; }
    // Sixteen owner identities fit one scalar mask; no nested scratch bank.
    var usize seen = 0;let usize one=1;
    var usize cursor = 0;
    var usize i = 0;
    while (i < table.depth) {
        let usize slot = table.order[i];
        if (slot >= 16) { return false; }
        let usize bit=one<<slot;if ((seen&bit)!=0) { return false; }
        seen|=bit;
        let owners::Owner owner = table.slots[slot];
        if (!owner.occupied || owner.mark != cursor || (owner.live && owner.generation == 0)) { return false; }
        if ((owner.reading || owner.writing) && (!owner.live || owner.element == 0 || owner.read_generation == 0)) { return false; }
        if (owner.reading && owner.writing) { return false; }
        let arrays::Array layout = switch (original_layout(ref owner)) {
            case .ok(value): { value } case .err(_): { return false; }
        };
        let arrays::Reservation plan = switch (arrays::reserve(ref layout, cursor, table.arena.limit)) {
            case .ok(value): { value } case .err(_): { return false; }
        };
        if (owner.base != plan.offset || owner.end != plan.end) { return false; }
        cursor = owner.end;
        i += 1;
    }
    if (cursor != table.arena.used) { return false; }
    i = 0;
    while (i < 16) {
        let owners::Owner owner=table.slots[i];let bool retained=(seen&(one<<i))!=0;
        if (owner.occupied != retained || (owner.live && !retained)) { return false; }
        if ((owner.reading || owner.writing) && !retained) { return false; }
        i += 1;
    }
    return true;
}

fn Result<usize, owners::Error> original_slot(ref owners::Table table) {
    var usize i = 0;
    while (i < 16) {
        if (!table.slots[i].occupied && table.slots[i].generation != 0) { return .ok(i); }
        i += 1;
    }
    return .err(.Owners);
}

fn owners::Token original_publish(ref mut owners::Table table, usize slot, usize record, usize bytes,
    usize alignment, usize mark, usize base) {
    let usize generation = table.slots[slot].generation;
    let usize end = table.arena.used;
    let usize depth = table.depth;
    table.slots[slot] = owners::Owner { .generation = generation, .occupied = true, .live = true,
        .reading = false, .writing = false, .read_generation = 1,
        .mark = mark, .base = base, .end = end, .element = 0,
        .length = bytes, .record = record, .alignment = alignment };
    table.order[depth] = slot;
    table.depth += 1;
    return owners::Token { .slot = slot, .generation = generation };
}

fn Result<owners::Token, owners::Error> original(ref records::Catalog catalog, usize record,
    ref i64[] fields, ref mut u8[] bytes, ref mut owners::Table table) {
    if (!original_valid(table, bytes.len)) { return .err(.State); }
    let usize slot = original_slot(table)?;
    let records::Plan plan = switch (records::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Metadata); }
    };
    if (record >= plan.count) { return .err(.Bounds); }
    if (plan.bytes[record] > 128) { return .err(.Quota); }
    let usize mark = table.arena.used;
    let usize base = switch (storage::initialize(catalog, record, fields, bytes, ref mut table.arena)) {
        case .ok(value): { value } case .err(error): { return .err(mapped(error)); }
    };
    return .ok(original_publish(table, slot, record, plan.bytes[record], plan.alignments[record], mark, base));
}

fn u8 code(owners::Error error) {
    return switch (error) {
        case .Token: { 1 } case .Owners: { 2 } case .State: { 3 } case .Type: { 4 }
        case .Length: { 5 } case .Metadata: { 6 } case .Overflow: { 7 } case .Quota: { 8 }
        case .Bounds: { 9 } case .Alignment: { 10 } case .Value: { 11 }
    };
}
fn void same_table(ref owners::Table actual, ref owners::Table expected) {
    assert(actual.depth == expected.depth && actual.arena.used == expected.arena.used && actual.arena.limit == expected.arena.limit);
    var usize i = 0;
    while (i < 16) {
        let owners::Owner a = actual.slots[i]; let owners::Owner b = expected.slots[i];
        assert(actual.order[i] == expected.order[i] && a.generation == b.generation);
        assert(a.occupied == b.occupied && a.live == b.live && a.reading == b.reading && a.writing == b.writing);
        assert(a.read_generation == b.read_generation && a.mark == b.mark && a.base == b.base && a.end == b.end);
        assert(a.element == b.element && a.length == b.length && a.record == b.record && a.alignment == b.alignment);
        i += 1;
    }
}
fn records::Catalog catalog() {
    var records::Catalog c = records::empty(); c.count = 2;
    c.fields[0] = 3; c.types[0] = 10; c.kinds[1] = 1; c.types[1] = 1; c.kinds[2] = 1; c.types[2] = 1;
    c.fields[1] = 2; c.types[16] = 9; c.types[17] = 2;
    return c;
}
fn usize compare(ref records::Catalog c, usize record, ref i64[] fields,
    ref owners::Table initial, ref u8[] before) {
    assert(before.len == 256);
    var u8[256] expected_bytes = [0;256]; var u8[256] actual_bytes = [0;256];
    var usize i = 0;
    while (i < 256) { expected_bytes[i] = before[i]; actual_bytes[i] = before[i]; i += 1; }
    var owners::Table expected_table = owners::Table { .slots = initial.slots, .order = initial.order, .depth = initial.depth, .arena = initial.arena };
    var owners::Table actual_table = expected_table;
    let Result<owners::Token, owners::Error> expected = original(c,record,fields,ref mut expected_bytes,ref mut expected_table);
    let Result<owners::Token, owners::Error> actual = owners::create_record(c,record,fields,ref mut actual_bytes,ref mut actual_table);
    let bool failed = switch (expected) {
        case .ok(token): {
            let owners::Token result = switch (actual) { case .ok(value): { value } case .err(_): { assert(false); owners::Token { .slot = 0, .generation = 0 } } };
            assert(token.slot == result.slot && token.generation == result.generation);
            false
        }
        case .err(error): {
            let u8 result = switch (actual) { case .ok(_): { assert(false); 0 } case .err(other): { code(other) } };
            assert(code(error) == result); same_table(ref actual_table,initial); true
        }
    };
    same_table(ref actual_table,ref expected_table);
    i = 0;
    while (i < 256) {
        assert(actual_bytes[i] == expected_bytes[i]);
        if (failed) { assert(actual_bytes[i] == before[i]); }
        i += 1;
    }
    return 1;
}

@test
fn void checked_creation_matches_original_diagnostics_and_publication() {
    let records::Catalog base = catalog(); let i64[6] values = [255,-9223372036854775808,1,9223372036854775807,0,9];
    var u8[256] bytes = [85;256]; var owners::Table table = owners::empty(256);
    let arrays::Array prefix = arrays::Array { .element = 10, .length = 3, .stride = 1, .alignment = 1, .bytes = 3 };
    assert(owners::create(ref prefix,7,ref mut bytes,ref mut table).is_ok);
    var usize checked = compare(ref base,0,ref values[..5],ref table,ref bytes);
    var usize i = 0;
    while (i < 512) {
        var records::Catalog c = base; c.types[i] = 255;
        checked += compare(ref c,0,ref values[..5],ref table,ref bytes);
        c = base; c.kinds[i] = 2;
        checked += compare(ref c,0,ref values[..5],ref table,ref bytes); i += 1;
    }
    i = 0;
    while (i < 32) {
        var records::Catalog c = base; c.fields[i] = 17;
        checked += compare(ref c,0,ref values[..5],ref table,ref bytes); i += 1;
    }
    i = 0;
    while (i < 16) {
        var usize fault = 0;
        while (fault < 14) {
            var owners::Table t = table; let owners::Owner prior = t.slots[i];
            if (fault == 0) { t.slots[i].generation = 0; }
            else if (fault == 1) { t.slots[i].occupied = !prior.occupied; }
            else if (fault == 2) { t.slots[i].live = !prior.live; }
            else if (fault == 3) { t.slots[i].reading = true; }
            else if (fault == 4) { t.slots[i].writing = true; }
            else if (fault == 5) { t.slots[i].read_generation = 0; }
            else if (fault == 6) { t.slots[i].mark = 1; }
            else if (fault == 7) { t.slots[i].base = 1; }
            else if (fault == 8) { t.slots[i].end = 1; }
            else if (fault == 9) { t.slots[i].element = 0; }
            else if (fault == 10) { t.slots[i].length = 1000; }
            else if (fault == 11) { t.slots[i].record = 32; }
            else if (fault == 12) { t.slots[i].alignment = 3; }
            else { t.order[i] = 16; }
            checked += compare(ref base,0,ref values[..5],ref t,ref bytes);
            var records::Catalog bad = base; bad.kinds[511] = 2;
            checked += compare(ref bad,32,ref values[..0],ref t,ref bytes); fault += 1;
        }
        i += 1;
    }
    i = 0;
    while (i <= 6) { checked += compare(ref base,0,ref values[..i],ref table,ref bytes); i += 1; }
    let usize[5] ids = [0,1,2,31,18446744073709551615]; i = 0;
    while (i < 5) { checked += compare(ref base,ids[i],ref values[..5],ref table,ref bytes); i += 1; }
    checked += compare(ref base,1,ref values[1..3],ref table,ref bytes);
    let usize[9] limits = [0,2,3,7,47,48,255,256,257]; i = 0;
    while (i < 9) {
        var owners::Table t = table; t.arena.limit = limits[i];
        checked += compare(ref base,0,ref values[..5],ref t,ref bytes); i += 1;
    }
    var i64[6] invalid = values; invalid[0] = 256;
    checked += compare(ref base,0,ref invalid[..5],ref table,ref bytes);
    invalid = values; invalid[2] = 2;
    checked += compare(ref base,0,ref invalid[..5],ref table,ref bytes);
    invalid = values; invalid[4] = -1;
    checked += compare(ref base,0,ref invalid[..5],ref table,ref bytes);
    var records::Catalog c = base; c.count = 33;
    checked += compare(ref c,0,ref values[..5],ref table,ref bytes);
    c = base; c.kinds[16] = 1; c.types[16] = 1;
    checked += compare(ref c,0,ref values[..5],ref table,ref bytes);
    var owners::Table retired = owners::empty(256); i = 0;
    while (i < 16) { retired.slots[i].generation = 0; i += 1; }
    checked += compare(ref base,0,ref values[..5],ref retired,ref bytes);
    checked += compare(ref c,32,ref values[..0],ref retired,ref bytes);
    assert(checked == 1534);
}

@test
fn void initialization_receipts_depth_and_capacity_boundaries_are_checked() {
    let records::Catalog base = catalog(); let i64[5] values = [255,-9223372036854775808,1,9223372036854775807,0];
    var u8[256] bytes = [85;256]; var arenas::Arena arena = arenas::Arena { .used = 3, .limit = 48 };
    let storage::Initialized created = switch (storage::initialize_described(ref base,0,ref values,ref mut bytes,ref mut arena)) {
        case .ok(value): { value } case .err(_): { assert(false); storage::Initialized { .base = 0, .size = 0, .alignment = 0 } }
    };
    assert(created.base == 8 && created.size == 40 && created.alignment == 8 && arena.used == 48);
    assert(bytes[0] == 85 && bytes[2] == 85 && bytes[3] == 0 && bytes[7] == 0 && bytes[8] == 255 && bytes[9] == 0 && bytes[48] == 85);
    var records::Catalog bad = base; bad.kinds[511] = 2;
    let u8[256] saved = bytes;
    assert(!storage::initialize_described(ref bad,0,ref values,ref mut bytes,ref mut arena).is_ok);
    assert(arena.used == 48 && arena.limit == 48);
    var usize i = 0; while (i < 256) { assert(bytes[i] == saved[i]); i += 1; }
    let owners::Table empty = owners::empty(256); let i64[128] leaves = [255;128];
    var usize checked = 0; var usize depth = 1;
    while (depth <= 17) {
        var records::Catalog c = records::empty(); c.count = depth; i = 0; var u8 child = 1;
        while (i < depth) {
            c.fields[i] = 1; c.types[i*16] = 10;
            if (i+1 < depth) { c.kinds[i*16] = 1; c.types[i*16] = child; }
            i += 1; child += 1;
        }
        checked += compare(ref c,0,ref leaves[..1],ref empty,ref saved); depth += 1;
    }
    var records::Catalog wide = records::empty(); wide.count = 2; wide.fields[0] = 8; wide.fields[1] = 16; i = 0;
    while (i < 16) { wide.types[16+i] = 10; if (i < 8) { wide.kinds[i] = 1; wide.types[i] = 1; } i += 1; }
    checked += compare(ref wide,0,ref leaves,ref empty,ref saved);
    wide.fields[0] = 9; wide.kinds[8] = 1; wide.types[8] = 1;
    checked += compare(ref wide,0,ref leaves,ref empty,ref saved);
    var owners::Table full = owners::empty(256); var u8[256] data = [85;256]; i = 0;
    let arrays::Array scalar = arrays::Array { .element = 10, .length = 1, .stride = 1, .alignment = 1, .bytes = 1 };
    while (i < 16) { assert(owners::create(ref scalar,7,ref mut data,ref mut full).is_ok); i += 1; }
    checked += compare(ref base,0,ref values,ref full,ref data);
    checked += compare(ref bad,32,ref values[..0],ref full,ref data);
    assert(checked == 21);
}
