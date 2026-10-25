module tests::m2::struct_layout;
import struct_layout as records;

fn records::Catalog singles(usize count) {
    var records::Catalog result = records::empty();
    result.count = count;
    var usize i = 0;
    while (i < count) { result.fields[i] = 1; result.types[i * 16] = 10; i += 1; }
    return result;
}
fn records::Plan planned(ref records::Catalog catalog, usize limit) {
    return switch (records::plan(catalog, limit)) {
        case .ok(value): { value }
        case .err(_): {
            assert(false);
            records::Plan { .count = 0, .bytes = [0; 32], .alignments = [0; 32],
                .depths = [0; 32], .offsets = [0; 512] }
        }
    };
}
fn u8 error_code(records::Error error) {
    return switch (error) {
        case .Limit: { 1 } case .Fields: { 2 } case .Type: { 3 } case .Metadata: { 4 }
        case .Cycle: { 5 } case .Depth: { 6 } case .Overflow: { 7 } case .Quota: { 8 }
    };
}
fn bool rejected(ref records::Catalog catalog, usize limit, records::Error expected) {
    return switch (records::plan(catalog, limit)) {
        case .ok(_): { false } case .err(error): { error_code(error) == error_code(expected) }
    };
}

@test
fn void all_scalar_fields_use_compact_widths_and_empty_catalog_is_canonical() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let usize[6] widths = [4, 1, 8, 1, 4, 8];
    var records::Catalog catalog = singles(1);
    var usize i = 0;
    while (i < 6) {
        catalog.types[0] = tags[i];
        let records::Plan result = planned(ref catalog, widths[i]);
        assert(result.bytes[0] == widths[i] && result.alignments[0] == widths[i]);
        assert(result.depths[0] == 1 && result.offsets[0] == 0);
        assert(result.bytes[31] == 0 && result.offsets[511] == 0);
        i += 1;
    }
    let records::Catalog empty = records::empty();
    let records::Plan zero = planned(ref empty, 0);
    assert(zero.count == 0 && zero.depths[0] == 0 && zero.alignments[31] == 0);
}

@test
fn void declaration_order_and_tail_padding_define_the_layout() {
    var records::Catalog catalog = singles(1);
    catalog.fields[0] = 4;
    catalog.types[0] = 10; catalog.types[1] = 9; catalog.types[2] = 2; catalog.types[3] = 11;
    let records::Plan result = planned(ref catalog, 24);
    assert(result.offsets[0] == 0 && result.offsets[1] == 8);
    assert(result.offsets[2] == 16 && result.offsets[3] == 20);
    assert(result.bytes[0] == 24 && result.alignments[0] == 8 && result.depths[0] == 1);
    catalog.fields[0] = 2; catalog.types[2] = 0; catalog.types[3] = 0;
    catalog.types[0] = 9; catalog.types[1] = 10;
    let records::Plan reversed = planned(ref catalog, 16);
    assert(reversed.offsets[1] == 8 && reversed.bytes[0] == 16);
}

@test
fn void forward_dependencies_and_repeated_children_are_resolved_by_value() {
    var records::Catalog catalog = singles(3);
    catalog.fields[0] = 3;
    catalog.kinds[0] = 1; catalog.types[0] = 1;
    catalog.kinds[1] = 1; catalog.types[1] = 1; catalog.types[2] = 2;
    catalog.fields[1] = 2; catalog.kinds[17] = 1; catalog.types[17] = 2;
    catalog.types[32] = 1;
    let records::Plan result = planned(ref catalog, 20);
    assert(result.bytes[2] == 4 && result.bytes[1] == 8 && result.bytes[0] == 20);
    assert(result.offsets[17] == 4 && result.offsets[1] == 8 && result.offsets[2] == 16);
    assert(result.alignments[0] == 4 && result.depths[0] == 3);
    assert(catalog.kinds[0] == 1 && catalog.fields[0] == 3 && catalog.types[32] == 1);
}

@test
fn void malformed_counts_fields_and_inactive_metadata_are_rejected_first() {
    var records::Catalog catalog = singles(1);
    catalog.count = 33; assert(rejected(ref catalog, 100, .Limit));
    catalog.count = 1; catalog.fields[0] = 0; assert(rejected(ref catalog, 100, .Fields));
    catalog.fields[0] = 17; assert(rejected(ref catalog, 100, .Fields));
    catalog.fields[0] = 1; catalog.types[1] = 10; assert(rejected(ref catalog, 100, .Metadata));
    catalog.types[1] = 0; catalog.kinds[511] = 1; assert(rejected(ref catalog, 100, .Metadata));
    catalog.kinds[511] = 0; catalog.fields[31] = 1; assert(rejected(ref catalog, 100, .Metadata));
    catalog.fields[31] = 0; assert(records::plan(ref catalog, 100).is_ok);
}

@test
fn void only_scalar_tags_and_in_catalog_record_references_are_admitted() {
    var records::Catalog catalog = singles(1);
    var u8 tag = 0;
    while (true) {
        catalog.types[0] = tag;
        if (tag != 1 && tag != 2 && tag != 9 && tag != 10 && tag != 11 && tag != 12) {
            assert(rejected(ref catalog, 100, .Type));
        }
        if (tag == 255) { break; }
        tag += 1;
    }
    catalog.kinds[0] = 1; catalog.types[0] = 1; assert(rejected(ref catalog, 100, .Type));
    catalog.types[0] = 255; assert(rejected(ref catalog, 100, .Type));
    catalog.kinds[0] = 2; catalog.types[0] = 0; assert(rejected(ref catalog, 100, .Type));
}

@test
fn void self_mutual_and_disconnected_cycles_do_not_publish_partial_plans() {
    var records::Catalog catalog = singles(1);
    catalog.kinds[0] = 1; catalog.types[0] = 0;
    assert(rejected(ref catalog, 100, .Cycle));
    catalog = singles(3);
    catalog.kinds[16] = 1; catalog.types[16] = 2;
    catalog.kinds[32] = 1; catalog.types[32] = 1;
    assert(rejected(ref catalog, 100, .Cycle));
    assert(catalog.count == 3 && catalog.types[16] == 2 && catalog.types[32] == 1);
    catalog.kinds[32] = 0; catalog.types[32] = 10;
    let records::Plan retry = planned(ref catalog, 100);
    assert(retry.depths[0] == 1 && retry.depths[1] == 2 && retry.depths[2] == 1);
}

@test
fn void structural_depth_is_independent_of_catalog_capacity_and_fanout() {
    var records::Catalog catalog = singles(32);
    var usize i = 0;
    var u8 child = 1;
    while (i < 15) {
        catalog.kinds[i * 16] = 1; catalog.types[i * 16] = child;
        i += 1;
        child += 1;
    }
    let records::Plan result = planned(ref catalog, 1);
    assert(result.count == 32 && result.depths[0] == 16 && result.bytes[0] == 1);
    catalog.kinds[15 * 16] = 1; catalog.types[15 * 16] = 16;
    assert(rejected(ref catalog, 1, .Depth));
    catalog = singles(32);
    i = 0;
    while (i < 32) {
        catalog.fields[i] = 16;
        var usize field = 0;
        while (field < 16) { catalog.types[i * 16 + field] = 12; field += 1; }
        i += 1;
    }
    let records::Plan full = planned(ref catalog, 128);
    assert(full.bytes[31] == 128 && full.offsets[511] == 120 && full.depths[31] == 1);
}

@test
fn void padding_quota_and_symbolic_size_overflow_fail_without_native_traps() {
    var records::Catalog catalog = singles(1);
    catalog.fields[0] = 3; catalog.types[0] = 10; catalog.types[1] = 9; catalog.types[2] = 2;
    assert(rejected(ref catalog, 23, .Quota));
    let records::Plan exact = planned(ref catalog, 24);
    assert(exact.bytes[0] == 24 && exact.offsets[2] == 16);
    catalog = singles(1); assert(rejected(ref catalog, 0, .Quota));
    catalog = singles(16);
    var usize i = 0;
    var u8 child = 1;
    while (i < 16) {
        catalog.fields[i] = 16;
        var usize field = 0;
        while (field < 16) {
            let usize slot = i * 16 + field;
            catalog.kinds[slot] = if (i == 15) { 0 } else { 1 };
            catalog.types[slot] = if (i == 15) { 9 } else { child };
            field += 1;
        }
        i += 1;
        child += 1;
    }
    assert(rejected(ref catalog, 18446744073709551615, .Overflow));
    assert(rejected(ref catalog, 65536, .Quota));
    assert(catalog.count == 16 && catalog.fields[0] == 16 && catalog.types[0] == 1);
}
