module slice_builders;
import ir as ir;
import errors as errors;
import slice_parameters as parameters;
import std::num as num;

fn Result<u8, errors::Error> encoded(usize n, usize offset) {
    // Callers bound n to 1..16 before conversion.
    let i64 wide = switch(num::i64_from_usize(n)) { case .ok(v): { v } case .err(_): { return .err(errors::make(4, offset)); } };
    return switch(num::u8_from_i64(wide)) { case .ok(v): { .ok(v) } case .err(_): { .err(errors::make(4, offset)) } };
}

// The function's start and arity are declared before its formal positions.
// Like owned aggregate builders, this reserves one position, not a scalar cell.
pub fn Result<usize, errors::Error> parameter(ref mut ir::Program p, usize function, usize offset) {
    if (p.registers >= 128) { return .err(errors::make(4, offset)); }
    if (p.function_count == 0 || p.function_count > 16 || function >= p.function_count ||
        function == p.entry || p.arities[function] == 0 || p.arities[function] > 8 ||
        p.register_starts[function] > p.registers ||
        p.registers - p.register_starts[function] >= p.arities[function]) { return .err(errors::make(3, offset)); }
    let usize r = p.registers;
    if (p.types[r] != 0 || p.slots[r] || p.array_parameters[r] != 0 ||
        p.record_parameters[r] != 0 || p.slice_parameters[r] != 0) { return .err(errors::make(3, offset)); }
    let usize site = ir::slice_site(p, offset)?;
    let u8 origin = encoded(site + 1, offset)?;
    let u8 owner = encoded(function + 1, offset)?;
    p.slice_parameters[r] = origin; p.slice_origins[site] = origin;
    p.slice_functions[site] = owner; p.registers += 1;
    return .ok(site);
}

// Reserve a rootless derived site, flattening its origin to a declared formal.
// No borrow instruction, register, live ticket or CALL frame is published.
pub fn Result<usize, errors::Error> derived(ref mut ir::Program p, usize parent, usize function, usize offset) {
    if (p.function_count == 0 || p.function_count > 16 || function >= p.function_count ||
        parent >= 16 || p.registers > 128 || p.arities[function] > 8 ||
        p.register_starts[function] > p.registers ||
        p.arities[function] > p.registers - p.register_starts[function]) { return .err(errors::make(3, offset)); }
    let usize origin = p.slice_origins[parent] as usize;
    if (origin == 0 || origin > 16 || p.slice_roots[parent] != 0 ||
        p.slice_functions[parent] as usize != function + 1) { return .err(errors::make(3, offset)); }
    let usize anchor = origin - 1;
    if (p.slice_roots[anchor] != 0 || p.slice_origins[anchor] as usize != origin ||
        p.slice_functions[anchor] as usize != function + 1) { return .err(errors::make(3, offset)); }
    var usize i = 0; var usize matches = 0;
    while (i < p.arities[function]) {
        let usize r = p.register_starts[function] + i;
        if (p.slice_parameters[r] as usize == origin) {
            if (p.types[r] != 0 || p.slots[r] || p.array_parameters[r] != 0 ||
                p.record_parameters[r] != 0) { return .err(errors::make(3, offset)); }
            matches += 1;
        }
        i += 1;
    }
    if (matches != 1) { return .err(errors::make(3, offset)); }
    let usize site = ir::slice_site(p, offset)?;
    let u8 source = encoded(origin, offset)?; let u8 owner = encoded(function + 1, offset)?;
    p.slice_origins[site] = source; p.slice_functions[site] = owner;
    return .ok(site);
}

// After whole-Program metadata validation, encode one checked live source for
// the existing CALL builders. This does not enable borrowed CALL execution.
pub fn Result<usize, errors::Error> argument(ref ir::Program p, usize parameter,
    usize site, usize caller, usize live, usize offset) {
    if (site >= 16) { return .err(errors::make(5, offset)); }
    let usize checked = parameters::argument(p, parameter, 160 + site, caller, live, offset)?;
    return .ok(160 + checked);
}
