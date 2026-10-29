module text_source;

import lexer as lexer;
import locals as locals;
import array_source as arrays;
import ir as ir;
import errors as errors;
import cells as cells;

// No guest expression may run between publication, scan and temporary cleanup.
pub fn Result<usize, errors::Error> temporary(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, usize id, usize at) {
    let usize value = predicate(source, s, p, table, id, at)?;
    let usize dropped = ir::array_drop(p, id, at)?;
    return .ok(value);
}

// Split the qualified prefix from argument lowering so the compiler can reuse
// its ordinary CALL/ARET path. Bare `text` names keep ordinary lookup behavior.
pub fn Result<usize, errors::Error> begin(ref u8[] source, ref mut lexer::State s) {
    let usize at = s.begin;
    let usize module_name = lexer::word(source, s, b"text")?;
    let usize first = lexer::punctuation(source, s, 58)?;
    let usize second = lexer::punctuation(source, s, 58)?;
    let usize name = lexer::word(source, s, b"valid_utf8")?;
    let usize open = lexer::punctuation(source, s, 40)?;
    return .ok(at);
}
// Named arguments retain their owner and require no call or payload copy.
pub fn Result<usize, errors::Error> named(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, usize at) {
    let usize id = argument(source, s, p, table)?;
    return predicate(source, s, p, table, id, at);
}
pub fn Result<usize, errors::Error> argument(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref locals::Table table) {
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    let usize index = locals::find(source, table, s.begin, s.end);
    if (!arrays::binding(table, index)) { return .err(errors::make(3, s.begin)); }
    let usize id = table.registers[index] - 128;
    if (id >= p.arrays.count || id >= 16 || p.arrays.elements[id] != 10 ||
        p.array_functions[id] as usize != table.function) { return .err(errors::make(3, s.begin)); }
    let usize argument = lexer::next(source, s)?;
    return .ok(id);
}
// Bounded token lookahead preserves the immediate/static lowering exactly.
// Complex bounds are delegated to the ordinary expression parser.
pub fn Result<bool, errors::Error> simple(ref u8[] source, ref lexer::State s) {
    if (s.kind != 91) { return .ok(true); }
    var lexer::State look = lexer::snapshot(s);
    let usize open = lexer::next(source, ref mut look)?;
    if (look.kind == 1 || look.kind == 2) { let usize value = lexer::next(source, ref mut look)?; }
    if (look.kind != 46) { return .ok(false); }
    let usize first = lexer::next(source, ref mut look)?;
    if (look.kind != 46) { return .ok(false); }
    let usize second = lexer::next(source, ref mut look)?;
    if (look.kind == 1 || look.kind == 2) { let usize value = lexer::next(source, ref mut look)?; }
    return .ok(look.kind == 93);
}
// Fast suffix parsing for names/literals. Computed bounds use compiler-owned
// expression parsing with lexical cleanup for temporary owners.
pub fn Result<usize, errors::Error> predicate(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, usize id, usize at) {
    if (s.kind != 91) {
        let usize close = lexer::punctuation(source, s, 41)?;
        return ir::array_utf8(p, id, at);
    }
    if (id >= 16 || id >= p.arrays.count) { return .err(errors::make(3, at)); }
    let usize open = lexer::next(source, s)?;
    let Endpoint start = if (s.kind == 46) { Endpoint { .value = 0, .dynamic = false } }
        else { named_endpoint(source, s, p, table)? };
    let usize first = lexer::punctuation(source, s, 46)?;
    let usize second = lexer::punctuation(source, s, 46)?;
    let Endpoint end = if (s.kind == 93) { Endpoint { .value = p.arrays.lengths[id], .dynamic = false } }
        else { named_endpoint(source, s, p, table)? };
    let usize bracket = lexer::punctuation(source, s, 93)?;
    let usize close = lexer::punctuation(source, s, 41)?;
    if (!start.dynamic && !end.dynamic) { return ir::array_range_utf8(p, id, start.value, end.value, at); }
    let usize lo = endpoint_register(p, start, at)?;
    let usize hi = endpoint_register(p, end, at)?;
    return ir::array_dynamic_utf8(p, id, lo, hi, at);
}

struct Endpoint { usize value; bool dynamic; }
// Only scalar names may be dynamic. No calls, casts or expressions execute here.
fn Result<Endpoint, errors::Error> named_endpoint(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table) {
    if (s.kind != 2) {
        let usize value = endpoint(source, s)?;
        return .ok(Endpoint { .value = value, .dynamic = false });
    }
    let usize at = s.begin;
    let usize index = locals::find(source, table, s.begin, s.end);
    if (index >= table.count) { return .err(errors::make(3, at)); }
    let usize register = table.registers[index];
    if (register >= 128 || register >= p.registers || p.types[register] != 12 ||
        p.array_parameters[register] != 0 || p.record_parameters[register] != 0) {
        return .err(errors::make(3, at));
    }
    let usize advanced = lexer::next(source, s)?;
    let usize value = if (p.slots[register]) { ir::emit(p, 17, register, 0, at)? } else { register };
    return .ok(Endpoint { .value = value, .dynamic = true });
}
fn Result<usize, errors::Error> endpoint_register(ref mut ir::Program p, Endpoint endpoint, usize at) {
    if (endpoint.dynamic) { return .ok(endpoint.value); }
    let i64 value = cells::pack(endpoint.value, at)?;
    return ir::integer(p, value, 12, at);
}
// Literal endpoints permit zero but never the scanner's wrapped unsigned cells.
fn Result<usize, errors::Error> endpoint(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 1 || s.value < 0 || s.value > 4096) { return .err(errors::make(3, s.begin)); }
    let usize value = cells::unpack(s.value, s.begin)?;
    let usize advanced = lexer::next(source, s)?;
    return .ok(value);
}
