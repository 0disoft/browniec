module slice_call_source;
import functions as functions;
import locals as locals;
import lexer as lexer;
import ir as ir;
import slice_source as slices;
import slice_builders as builders;
import errors as errors;

// Signature kinds are known before bodies; site/register IDs are assigned in
// body order. Forward calls need only the signature, never a future ticket.
pub fn Result<usize, errors::Error> bind(ref functions::Table signatures, usize at,
    ref mut ir::Program p, ref mut locals::Table names) {
    if (at >= 128 || !signatures.param_slices[at] || names.count >= 64) { return .err(errors::make(4, 0)); }
    let usize site = builders::parameter_typed(p, names.function, signatures.param_slice_elements[at], signatures.param_begins[at])?;
    return locals::declare(names, signatures.param_begins[at], signatures.param_ends[at], 160 + site, false);
}

// Initial source form: explicit ref followed by one existing lexical slice.
// No array/temporary coercion, new handle, payload copy or caller-side close.
// Keep signature-array indexing scratch off the recursive scalar CALL path.
pub fn Result<usize, errors::Error> capture(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref locals::Table names, ref functions::Table signatures, usize parameter) {
    let usize at = s.begin;
    if (parameter >= 128 || !signatures.param_slices[parameter]) { return .err(errors::make(3, at)); }
    let u8 element = signatures.param_slice_elements[parameter];
    if (s.kind != 2 || !lexer::equal(source[s.begin..s.end], b"ref")) { return .err(errors::make(3, at)); }
    let usize reference = lexer::next(source, s)?;
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    let usize index = locals::find(source, names, s.begin, s.end);
    if (!slices::binding(names, index)) { return .err(errors::make(3, s.begin)); }
    let usize site = names.registers[index] - 160;
    if (ir::exclusive(p,site)) { return .err(errors::make(3,at)); }
    let usize root = p.slice_roots[site] as usize;
    let usize origin = p.slice_origins[site] as usize;
    if (root != 0) {
        if (root > 16 || root > p.arrays.count || p.arrays.elements[root - 1] != element ||
            p.array_functions[root - 1] as usize != names.function || origin != 0 ||
            p.slice_functions[site] != 0) { return .err(errors::make(3, at)); }
    } else {
        if (origin == 0 || origin > 16 || p.slice_functions[site] as usize != names.function + 1 ||
            p.slice_roots[origin - 1] != 0 || p.slice_origins[origin - 1] as usize != origin ||
            p.slice_functions[origin - 1] != p.slice_functions[site]) { return .err(errors::make(3, at)); }
    }
    let u8 actual = ir::slice_element(p, site, at)?;
    if (actual != element) { return .err(errors::make(3, at)); }
    let usize name = lexer::next(source, s)?;
    if (s.kind != 44 && s.kind != 41) { return .err(errors::make(3, s.begin)); }
    return .ok(160 + site);
}
