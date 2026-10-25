module struct_meta;

import struct_layout as layouts;
import errors as errors;

// Entry-owned bindings. Scalar leaf indices follow nested declaration order.
pub struct Catalog { layouts::Catalog layouts; usize count; u8[16] records; bool[16] mutable; }
pub struct Prepared { usize[16] leaves; u8[2048] tags; }
pub fn Catalog empty() {
    return Catalog { .layouts = layouts::empty(), .count = 0, .records = [0; 16], .mutable = [false; 16] };
}
pub fn Result<Prepared, errors::Error> prepare(ref Catalog catalog) {
    if (catalog.count > 16) { return .err(errors::make(5, 0)); }
    let layouts::Plan plan = switch (layouts::plan(ref catalog.layouts, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(5, 0)); }
    };
    var Prepared result = Prepared { .leaves = [0; 16], .tags = [0; 2048] };
    var usize id = 0;
    while (id < 16) {
        let usize root = catalog.records[id] as usize;
        if (id >= catalog.count) {
            if (root != 0 || catalog.mutable[id]) { return .err(errors::make(5, 0)); }
        } else {
            if (root >= plan.count || plan.bytes[root] > 128) { return .err(errors::make(5, 0)); }
            var usize[16] records = [0; 16];
            var usize[16] fields = [0; 16];
            records[0] = root;
            var usize depth = 1;
            while (depth > 0) {
                let usize level = depth - 1;
                let usize record = records[level];
                let usize field = fields[level];
                if (field >= catalog.layouts.fields[record] as usize) { depth -= 1; }
                else {
                    fields[level] += 1;
                    let usize slot = record * 16 + field;
                    if (catalog.layouts.kinds[slot] == 0) {
                        let usize leaf = result.leaves[id];
                        if (leaf >= 128) { return .err(errors::make(5, 0)); }
                        result.tags[id * 128 + leaf] = catalog.layouts.types[slot];
                        result.leaves[id] += 1;
                    } else {
                        if (depth >= 16) { return .err(errors::make(5, 0)); }
                        records[depth] = catalog.layouts.types[slot] as usize;
                        fields[depth] = 0; depth += 1;
                    }
                }
            }
        }
        id += 1;
    }
    return .ok(result);
}
