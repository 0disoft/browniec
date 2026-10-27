module tests::m2::struct_layout_order;
import struct_layout as records;

fn u8 error_code(records::Error error) {
    return switch (error) {
        case .Limit: { 1 } case .Fields: { 2 } case .Type: { 3 } case .Metadata: { 4 }
        case .Cycle: { 5 } case .Depth: { 6 } case .Overflow: { 7 } case .Quota: { 8 }
    };
}

// Two independent depth-16 chains fill all 32 records and all 512 fields.
// Forward references put the dependency last, the old readiness scan's worst
// position. Reversing IDs must preserve every size, alignment and field offset.
fn records::Catalog dense(bool reversed) {
    var records::Catalog catalog = records::empty();
    catalog.count = 32;
    var usize record = 0;
    while (record < 32) {
        let usize id = if (reversed) { 31-record } else { record };
        catalog.fields[id] = 16;
        var usize field = 0;
        while (field < 16) { catalog.types[id*16+field] = 2; field += 1; }
        if (record % 16 != 15) {
            catalog.kinds[id*16+15] = 1;
            let usize target = if (reversed) { 30-record } else { record+1 };
            var u8 child = 0;
            while ((child as usize) < target) { child += 1; }
            catalog.types[id*16+15] = child;
        }
        record += 1;
    }
    return catalog;
}

@test
fn void dense_dependency_orders_produce_identical_complete_layouts() {
    let records::Catalog forward = dense(false);
    let records::Catalog backward = dense(true);
    let records::Plan a = switch (records::plan(ref forward, 241)) {
        case .ok(p): { p } case .err(_): { assert(false); return; }
    };
    let records::Plan b = switch (records::plan(ref backward, 241)) {
        case .ok(p): { p } case .err(_): { assert(false); return; }
    };
    assert(a.count == 32 && b.count == 32);
    var usize id = 0;
    while (id < 32) {
        assert(a.bytes[id] == 16+(15-id%16)*15 && a.bytes[id] == b.bytes[31-id]);
        assert(a.depths[id] == 16-id%16 && a.depths[id] == b.depths[31-id]);
        assert(a.alignments[id] == 1 && b.alignments[31-id] == 1);
        var usize field = 0;
        while (field < 16) {
            assert(a.offsets[id*16+field] == field && b.offsets[(31-id)*16+field] == field);
            field += 1;
        }
        id += 1;
    }
    assert(!records::plan(ref forward, 240).is_ok);
}

@test
fn void full_capacity_cycle_and_deep_chain_fail_without_stack_overflow() {
    var records::Catalog catalog = records::empty();
    catalog.count = 32;
    var usize id = 0;
    var u8 next = 1;
    while (id < 32) {
        catalog.fields[id] = 1; catalog.kinds[id*16] = 1;
        catalog.types[id*16] = if (id == 31) { 0 } else { next };
        id += 1; next += 1;
    }
    assert(switch (records::plan(ref catalog, 1024)) {
        case .ok(_): { false } case .err(e): { error_code(e) == 5 }
    });
    catalog.kinds[31*16] = 0; catalog.types[31*16] = 2;
    assert(switch (records::plan(ref catalog, 1024)) {
        case .ok(_): { false } case .err(e): { error_code(e) == 6 }
    });
}
