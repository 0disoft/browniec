module struct_range;
import struct_layout as layouts;
import errors as errors;

// Resolve a nominal record node by its first depth-first scalar ordinal.
// Scalar lookalikes are not record nodes. Replan even for direct private callers.
pub fn Result<usize, errors::Error> offset(ref layouts::Catalog catalog,
    usize root, usize nominal, usize ordinal) {
    let layouts::Plan plan = switch(layouts::plan(catalog,18446744073709551615)) {
        case .ok(p): { p } case .err(_): { return .err(errors::make(5,0)); }
    };
    if (root >= plan.count || nominal >= plan.count || ordinal >= 128) { return .err(errors::make(5,0)); }
    if (plan.bytes[root] > 128 || plan.bytes[nominal] > 128) { return .err(errors::make(5,0)); }
    if (root == nominal && ordinal == 0) { return .ok(0); }
    var usize[16] records = [0;16]; var usize[16] fields = [0;16]; var usize[16] bases = [0;16];
    records[0] = root; var usize depth = 1; var usize leaf = 0; var usize visits = 0;
    while (depth > 0) {
        if (visits >= 4096) { return .err(errors::make(5,0)); } visits += 1;
        let usize level = depth-1; let usize record = records[level];
        if (fields[level] >= catalog.fields[record] as usize) { depth -= 1; }
        else {
            let usize slot = record*16+fields[level]; fields[level] += 1;
            if (catalog.kinds[slot] == 0) { leaf += 1; }
            else {
                if (plan.offsets[slot] > 128-bases[level]) { return .err(errors::make(5,0)); }
                let usize base = bases[level]+plan.offsets[slot];
                let usize child = catalog.types[slot] as usize;
                if (child == nominal && leaf == ordinal) {
                    if (base > plan.bytes[root] || plan.bytes[nominal] > plan.bytes[root]-base) { return .err(errors::make(5,0)); }
                    return .ok(base);
                }
                if (depth >= 16) { return .err(errors::make(5,0)); }
                records[depth] = child; fields[depth] = 0; bases[depth] = base; depth += 1;
            }
        }
    }
    return .err(errors::make(5,0));
}

// Count a complete nominal subtree independently of any binding catalog. Direct
// callers revalidate the full layout; private bytecode accepts up to 128 leaves.
pub fn Result<usize, errors::Error> leaves(ref layouts::Catalog catalog, usize nominal) {
    let layouts::Plan plan = switch(layouts::plan(catalog,18446744073709551615)) {
        case .ok(p): { p } case .err(_): { return .err(errors::make(5,0)); }
    };
    if (nominal >= plan.count || plan.bytes[nominal] > 128) { return .err(errors::make(5,0)); }
    var usize[16] records = [0;16]; var usize[16] fields = [0;16];
    records[0] = nominal; var usize depth = 1; var usize count = 0; var usize visits = 0;
    while (depth > 0) {
        if (visits >= 4096) { return .err(errors::make(5,0)); } visits += 1;
        let usize level = depth-1; let usize record = records[level];
        if (fields[level] >= catalog.fields[record] as usize) { depth -= 1; }
        else {
            let usize slot = record*16+fields[level]; fields[level] += 1;
            if (catalog.kinds[slot] == 0) {
                if (count >= 128) { return .err(errors::make(5,0)); } count += 1;
            } else {
                if (depth >= 16) { return .err(errors::make(5,0)); }
                records[depth] = catalog.types[slot] as usize; fields[depth] = 0; depth += 1;
            }
        }
    }
    return .ok(count);
}
