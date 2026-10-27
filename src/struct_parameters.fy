module struct_parameters;
import ir as ir;
import errors as errors;

// Catalogs and function/register partitions have already been independently checked.
pub fn Result<usize, errors::Error> metadata(ref ir::Program p) {
    var usize seen = 0; var usize r = 0;
    while (r < 128) {
        let usize encoded = p.record_parameters[r] as usize;
        if (encoded != 0) {
            if (r >= p.registers || encoded > p.records.count || p.slots[r] ||
                p.array_parameters[r] != 0 || p.types[r] != 0) { return .err(errors::make(5, 0)); }
            let usize id = encoded - 1; let usize one = 1;
            if ((seen & (one << id)) != 0 || p.records.mutable[id]) { return .err(errors::make(5, 0)); }
            let usize f = p.record_functions[id] as usize;
            if (r < p.register_starts[f] || r >= p.register_starts[f] + p.arities[f]) { return .err(errors::make(5, 0)); }
            seen |= one << id;
        }
        r += 1;
    }
    return .ok(seen);
}
pub fn usize initial(ref ir::Program p, usize f) {
    var usize live = 0; var usize arg = 0;
    while (arg < p.arities[f]) {
        let usize encoded = p.record_parameters[p.register_starts[f] + arg] as usize;
        if (encoded != 0) { let usize one = 1; live |= one << (15 + encoded); }
        arg += 1;
    }
    return live;
}
pub fn Result<usize, errors::Error> argument(ref ir::Program p, usize encoded,
    usize source, usize caller, usize live, usize pc) {
    if (encoded == 0 || encoded > p.records.count || source < 144) { return .err(errors::make(5, pc)); }
    let usize id = source - 144; let usize one = 1;
    if (id >= p.records.count || p.record_functions[id] as usize != caller ||
        p.records.mutable[id] || (live & (one << (16 + id))) == 0 ||
        p.records.records[id] != p.records.records[encoded - 1]) { return .err(errors::make(5, pc)); }
    return .ok(id);
}
