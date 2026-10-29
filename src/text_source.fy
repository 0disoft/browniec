module text_source;

import lexer as lexer;
import locals as locals;
import array_source as arrays;
import ir as ir;
import errors as errors;
import cells as cells;

// No guest expression may run between publication, scan and temporary cleanup.
pub fn Result<usize, errors::Error> temporary(ref mut ir::Program p, usize id, usize at) {
    let usize value = ir::array_utf8(p, id, at)?;
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
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    let usize index = locals::find(source, table, s.begin, s.end);
    if (!arrays::binding(table, index)) { return .err(errors::make(3, s.begin)); }
    let usize id = table.registers[index] - 128;
    if (id >= p.arrays.count || id >= 16 || p.arrays.elements[id] != 10 ||
        p.array_functions[id] as usize != table.function) { return .err(errors::make(3, s.begin)); }
    let usize argument = lexer::next(source, s)?;
    if (s.kind == 91) {
        let usize open = lexer::next(source, s)?;
        let usize start = endpoint(source, s)?;
        let usize first = lexer::punctuation(source, s, 46)?;
        let usize second = lexer::punctuation(source, s, 46)?;
        let usize end = endpoint(source, s)?;
        let usize bracket = lexer::punctuation(source, s, 93)?;
        let usize close = lexer::punctuation(source, s, 41)?;
        return ir::array_range_utf8(p, id, start, end, at);
    }
    let usize close = lexer::punctuation(source, s, 41)?;
    return ir::array_utf8(p, id, at);
}
// Literal endpoints permit zero but never the scanner's wrapped unsigned cells.
fn Result<usize, errors::Error> endpoint(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 1 || s.value < 0 || s.value > 4096) { return .err(errors::make(3, s.begin)); }
    let usize value = cells::unpack(s.value, s.begin)?;
    let usize advanced = lexer::next(source, s)?;
    return .ok(value);
}
