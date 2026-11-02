module tests::m2::struct_vm_paths;

import struct_vm as records;
import struct_meta as meta;
import array_vm as arrays;
import errors as errors;
import std::bytes as bytes;

fn usize value(Result<usize, errors::Error> result) {
    return switch (result) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn void step(u8 op, usize dst, usize a, usize b, ref meta::Catalog catalog,
    ref mut records::State state, ref mut arrays::State shared,
    ref mut bytes::Buffer payload, ref mut i64[] cells) {
    let usize fuel = value(records::cost(op, 123));
    assert(value(records::step(op, dst, a, b, 0, catalog, state, shared,
        payload, cells, fuel, 123)) == 0);
}

fn void exercise(bool nested) {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let i64[6] edges = [-2147483648, 1, -9223372036854775808, 255, 4294967295, -1];
    var meta::Catalog catalog = meta::empty();
    catalog.count = 1; catalog.mutable[0] = true;
    catalog.layouts.count = if (nested) { 2 } else { 1 };
    let usize child = if (nested) { 1 } else { 0 };
    catalog.layouts.fields[child] = 6;
    var i64[10] cells = [0; 10]; var i64[8] expected = [0; 8];
    let usize prefix = if (nested) { 1 } else { 0 };
    let usize count = if (nested) { 8 } else { 6 };
    if (nested) {
        catalog.layouts.fields[0] = 3;
        catalog.layouts.types[0] = 10;
        catalog.layouts.kinds[1] = 1; catalog.layouts.types[1] = 1;
        catalog.layouts.types[2] = 9;
        cells[0] = 17; expected[0] = 17;
        cells[7] = -257; expected[7] = -257;
    }
    var usize i = 0;
    while (i < 6) {
        catalog.layouts.types[child * 16 + i] = tags[i];
        cells[prefix + i] = edges[i]; expected[prefix + i] = edges[i]; i += 1;
    }
    var records::State state = records::empty();
    var arrays::State shared = arrays::empty(128);
    var bytes::Buffer payload = switch (arrays::prepare(128)) {
        case .ok(data): { data } case .err(_): { assert(false); bytes::empty() }
    };
    step(41, 0, 0, 0, ref catalog, ref mut state, ref mut shared, ref mut payload, ref mut cells);
    i = 0;
    while (i < count) {
        step(43, 8, 0, i, ref catalog, ref mut state, ref mut shared, ref mut payload, ref mut cells);
        assert(cells[8] == expected[i]); i += 1;
    }
    i = 0;
    while (i < count) {
        cells[9] = if (i == prefix + 1) { 0 } else { 42 };
        expected[i] = cells[9];
        step(44, 0, i, 9, ref catalog, ref mut state, ref mut shared, ref mut payload, ref mut cells);
        var usize j = 0;
        while (j < count) {
            step(43, 8, 0, j, ref catalog, ref mut state, ref mut shared, ref mut payload, ref mut cells);
            assert(cells[8] == expected[j]); j += 1;
        }
        i += 1;
    }
    step(45, 0, 0, 0, ref catalog, ref mut state, ref mut shared, ref mut payload, ref mut cells);
    assert(shared.owners.depth == 0 && shared.owners.arena.used == 0);
}

@test
fn void flat_mixed_width_ordinals_preserve_neighbors() { exercise(false); }

@test
fn void nested_mixed_width_ordinals_preserve_prefix_and_suffix() { exercise(true); }
