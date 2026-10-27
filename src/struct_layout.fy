module struct_layout;

import array_layout as arrays;

// Private declarative layouts only. No guest values, pointers, or native C ABI.
// kind 0: scalar tag; kind 1: record ID. Each record owns sixteen field slots.
pub enum Error { Limit; Fields; Type; Metadata; Cycle; Depth; Overflow; Quota; }
pub struct Catalog { usize count; u8[32] fields; u8[512] kinds; u8[512] types; }
pub struct Plan {
    usize count;
    usize[32] bytes;
    usize[32] alignments;
    usize[32] depths;
    usize[512] offsets;
}
struct Cursor { usize[32] records; u8[32] fields; bool[32] active; }

pub fn Catalog empty() {
    return Catalog { .count = 0, .fields = [0; 32], .kinds = [0; 512], .types = [0; 512] };
}
fn Plan blank(usize count) {
    return Plan { .count = count, .bytes = [0; 32], .alignments = [0; 32],
        .depths = [0; 32], .offsets = [0; 512] };
}
fn usize width(u8 tag) {
    return switch (arrays::scalar(tag, 1)) {
        case .ok(layout): { layout.bytes } case .err(_): { 0 }
    };
}
fn Result<usize, Error> validate(ref Catalog catalog) {
    if (catalog.count > 32) { return .err(.Limit); }
    var usize record = 0;
    while (record < 32) {
        let usize fields = catalog.fields[record] as usize;
        if (record < catalog.count) {
            if (fields == 0 || fields > 16) { return .err(.Fields); }
        } else if (fields != 0) { return .err(.Metadata); }
        var usize field = 0;
        while (field < 16) {
            let usize slot = record * 16 + field;
            let u8 kind = catalog.kinds[slot];
            let u8 tag = catalog.types[slot];
            if (record >= catalog.count || field >= fields) {
                if (kind != 0 || tag != 0) { return .err(.Metadata); }
            } else if (kind == 0) {
                if (width(tag) == 0) { return .err(.Type); }
            } else if (kind != 1 || tag as usize >= catalog.count) { return .err(.Type); }
            field += 1;
        }
        record += 1;
    }
    return .ok(catalog.count);
}
fn Result<usize, Error> aligned(usize value, usize alignment) {
    let usize remainder = value % alignment;
    let usize padding = if (remainder == 0) { 0 } else { alignment - remainder };
    if (padding > 18446744073709551615 - value) { return .err(.Overflow); }
    return .ok(value + padding);
}
fn Result<usize, Error> record_layout(ref Catalog catalog, ref mut Plan plan, usize record, usize limit) {
    var usize size = 0;
    var usize alignment = 1;
    var usize depth = 1;
    var usize field = 0;
    while (field < catalog.fields[record] as usize) {
        let usize slot = record * 16 + field;
        let usize tag = catalog.types[slot] as usize;
        var usize bytes = 0;
        var usize field_alignment = 1;
        if (catalog.kinds[slot] == 1) {
            bytes = plan.bytes[tag];
            field_alignment = plan.alignments[tag];
            if (plan.depths[tag] >= 16) { return .err(.Depth); }
            if (depth <= plan.depths[tag]) { depth = plan.depths[tag] + 1; }
        } else {
            bytes = width(catalog.types[slot]);
            field_alignment = bytes;
        }
        let usize offset = aligned(size, field_alignment)?;
        if (bytes > 18446744073709551615 - offset) { return .err(.Overflow); }
        size = offset + bytes;
        if (size > limit) { return .err(.Quota); }
        if (alignment < field_alignment) { alignment = field_alignment; }
        plan.offsets[slot] = offset;
        field += 1;
    }
    let usize padded = aligned(size, alignment)?;
    if (padded > limit) { return .err(.Quota); }
    plan.bytes[record] = padded;
    plan.alignments[record] = alignment;
    plan.depths[record] = depth;
    return .ok(padded);
}

// Resume each parent's field cursor after completing a child. Each field is
// inspected once for dependencies, regardless of declaration order or sharing.
// Active nodes detect cycles; completed nodes have a nonzero planned depth.
fn Result<usize, Error> resolve(ref Catalog catalog, ref mut Plan result,
    ref mut Cursor cursor, usize root, usize limit) {
    cursor.records[0] = root; cursor.fields[0] = 0; cursor.active[root] = true;
    var usize depth = 1;
    while (depth > 0) {
        let usize level = depth - 1;
        let usize record = cursor.records[level];
        let usize field = cursor.fields[level] as usize;
        if (field == catalog.fields[record] as usize) {
            let usize size = record_layout(catalog, result, record, limit)?;
            cursor.active[record] = false;
            depth -= 1;
        } else {
            cursor.fields[level] += 1;
            let usize slot = record * 16 + field;
            if (catalog.kinds[slot] == 1) {
                let usize child = catalog.types[slot] as usize;
                if (result.depths[child] == 0) {
                    if (cursor.active[child] || depth >= 32) { return .err(.Cycle); }
                    cursor.records[depth] = child; cursor.fields[depth] = 0; cursor.active[child] = true;
                    depth += 1;
                }
            }
        }
    }
    return .ok(result.bytes[root]);
}

// Validate the whole catalog before iterative dependency resolution. No native
// recursion, shared-subgraph expansion or partial plan publication on failure.
pub fn Result<Plan, Error> plan(ref Catalog catalog, usize limit) {
    let usize count = validate(catalog)?;
    var Plan result = blank(count);
    // Allocate/zero scratch once per plan, including catalogs of flat records.
    var Cursor cursor = Cursor { .records = [0; 32], .fields = [0; 32], .active = [false; 32] };
    var usize record = 0;
    while (record < count) {
        if (result.depths[record] == 0) {
            let usize size = resolve(catalog, ref mut result, ref mut cursor, record, limit)?;
        }
        record += 1;
    }
    return .ok(result);
}
