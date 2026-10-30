module slice_source;
import locals as locals;
import lexer as lexer;
import ir as ir;
import errors as errors;

// Lexical-only read handles: 160..175 are not scalar registers or array owners.
pub fn bool binding(ref locals::Table names, usize index) {
    return index < names.count && names.registers[index] >= 160 && names.registers[index] < 176;
}
pub fn bool borrowed(ref locals::Table names, ref ir::Program p, usize root) {
    var usize i = 0;
    while (i < names.count) {
        if (binding(names, i) && p.slice_roots[names.registers[i] - 160] as usize == root + 1) { return true; }
        i += 1;
    }
    return false;
}
pub struct Header { usize begin; usize end; }
// Called after let/var. Only immutable local ref u8[] bindings are admitted.
pub fn Result<Header, errors::Error> header(ref u8[] source, ref mut lexer::State s,
    ref locals::Table names, bool mutable, u8 terminator, u8 result_type) {
    if (mutable || terminator != 59 || result_type == 0) { return .err(errors::make(3, s.begin)); }
    let usize keyword = lexer::word(source, s, b"ref")?;
    if (s.kind != 2 || !lexer::equal(source[s.begin..s.end], b"u8")) { return .err(errors::make(3, s.begin)); }
    let usize tag = lexer::next(source, s)?;
    let usize open = lexer::punctuation(source, s, 91)?;
    let usize close = lexer::punctuation(source, s, 93)?;
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, s.begin)); }
    let usize begin = s.begin;
    let usize end = s.end;
    if (locals::find(source, names, begin, end) != 64) { return .err(errors::make(3, begin)); }
    if (names.count >= 64) { return .err(errors::make(4, begin)); }
    let usize name = lexer::next(source, s)?;
    let usize equals = lexer::punctuation(source, s, 61)?;
    let usize reference = lexer::word(source, s, b"ref")?;
    return .ok(Header { .begin = begin, .end = end });
}
pub fn Result<usize, errors::Error> predicate(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, usize index, usize at) {
    if (!binding(names, index)) { return .err(errors::make(3, s.begin)); }
    let usize name = lexer::next(source, s)?;
    // A slice is already a selected range; no implicit reslicing or copying.
    if (s.kind != 41) { return .err(errors::make(3, s.begin)); }
    let usize close = lexer::next(source, s)?;
    return ir::slice_utf8(p, names.registers[index] - 160, at);
}
