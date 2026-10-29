module text_source;

import lexer as lexer;
import locals as locals;
import array_source as arrays;
import ir as ir;
import errors as errors;

// This qualified intrinsic reads one named u8 array without copying or moving it.
// A bare `text` binding or function retains its ordinary name lookup behavior.
pub fn Result<usize, errors::Error> valid_utf8(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table) {
    let usize at = s.begin;
    let usize module_name = lexer::word(source, s, b"text")?;
    let usize first = lexer::punctuation(source, s, 58)?;
    let usize second = lexer::punctuation(source, s, 58)?;
    let usize name = lexer::word(source, s, b"valid_utf8")?;
    let usize open = lexer::punctuation(source, s, 40)?;
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    let usize index = locals::find(source, table, s.begin, s.end);
    if (!arrays::binding(table, index)) { return .err(errors::make(3, s.begin)); }
    let usize id = table.registers[index] - 128;
    if (id >= p.arrays.count || id >= 16 || p.arrays.elements[id] != 10 ||
        p.array_functions[id] as usize != table.function) { return .err(errors::make(3, s.begin)); }
    let usize argument = lexer::next(source, s)?;
    let usize close = lexer::punctuation(source, s, 41)?;
    return ir::array_utf8(p, id, at);
}
