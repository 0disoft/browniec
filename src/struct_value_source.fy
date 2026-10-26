module struct_value_source;
import struct_source as source_types;
import struct_layout as layouts;
import lexer as lexer;
import locals as locals;
import ir as ir;
import errors as errors;

// 144..159 are entry-owned struct sites, disjoint from scalars and arrays.
pub fn bool binding(ref locals::Table names, usize index) {
    return index < names.count && names.registers[index] >= 144 && names.registers[index] < 160;
}
pub fn Result<usize, errors::Error> named(ref u8[] source, ref lexer::State s) {
    let source_types::Location found = source_types::locate(source, s.begin, s.end, 32)?;
    return .ok(found.record);
}
// The immutable catalog has already passed struct_source::scan. Reparse only
// bounded declaration names; scalar field ordinals coincide with leaf ordinals.
pub fn Result<usize, errors::Error> field(ref u8[] source, ref ir::Program p, usize record, usize begin, usize end) {
    let source_types::Location found = source_types::locate(source, begin, end, record)?;
    if (record >= p.records.layouts.count || found.record != record) { return .err(errors::make(3, begin)); }
    var lexer::State s = lexer::empty(); s.cursor = found.body;
    let usize first = lexer::next(source, ref mut s)?;
    var usize i = 0;
    while (i < p.records.layouts.fields[record] as usize) {
        let usize tag = lexer::next(source, ref mut s)?;
        if (lexer::equal(source[begin..end], source[s.begin..s.end])) { return .ok(i); }
        let usize name = lexer::next(source, ref mut s)?;
        let usize end_field = lexer::punctuation(source, ref mut s, 59)?; i += 1;
    }
    return .err(errors::make(3, begin));
}
pub struct Header { usize record; usize begin; usize end; usize fields; bool mutable; }
pub fn Result<Header, errors::Error> header(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref locals::Table names, usize record, bool mutable, u8 terminator, u8 result_type) {
    let usize at = s.begin;
    if (names.function != p.entry || result_type == 0 || terminator != 59 || record >= p.records.layouts.count) { return .err(errors::make(3, at)); }
    let layouts::Plan plan = switch (layouts::plan(ref p.records.layouts, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(3, at)); }
    };
    if (plan.bytes[record] > 128) { return .err(errors::make(4, at)); }
    var usize i = 0;
    while (i < p.records.layouts.fields[record] as usize) {
        if (p.records.layouts.kinds[record*16+i] != 0) { return .err(errors::make(3, at)); } i += 1;
    }
    let usize type_name = lexer::next(source, s)?;
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, s.begin)); }
    let usize begin = s.begin; let usize end = s.end;
    if (locals::find(source, names, begin, end) != 64) { return .err(errors::make(3, begin)); }
    if (names.count >= 64 || p.records.count >= 16) { return .err(errors::make(4, begin)); }
    let usize name = lexer::next(source, s)?;
    let usize equals = lexer::punctuation(source, s, 61)?;
    return .ok(Header { .record = record, .begin = begin, .end = end,
        .fields = p.records.layouts.fields[record] as usize, .mutable = mutable });
}
pub fn Result<usize, errors::Error> read(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, usize id, usize at) {
    if (id >= p.records.count || s.kind != 46) { return .err(errors::make(3, at)); }
    let usize dot = lexer::next(source, s)?;
    if (s.kind != 2) { return .err(errors::make(2, s.begin)); }
    let usize leaf = field(source, p, p.records.records[id] as usize, s.begin, s.end)?;
    let usize member = lexer::next(source, s)?;
    return ir::record_read(p, id, leaf, at);
}

// A dotted final value in a switch arm must remain an expression. Only the
// complete one-level NAME.FIELD = prefix selects a field-write statement.
pub fn Result<bool, errors::Error> assigned(ref u8[] source, ref lexer::State state) {
    var lexer::State look = lexer::snapshot(state);
    if (look.kind != 46) { return .ok(false); }
    let usize dot = lexer::next(source, ref mut look)?;
    if (look.kind != 2) { return .ok(false); }
    let usize member = lexer::next(source, ref mut look)?;
    return .ok(look.kind == 61);
}
pub fn Result<usize, errors::Error> writable(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, usize id, usize at) {
    if (id >= p.records.count || !p.records.mutable[id] || s.kind != 46) { return .err(errors::make(3, at)); }
    let usize dot = lexer::next(source, s)?;
    if (s.kind != 2) { return .err(errors::make(2, s.begin)); }
    let usize leaf = field(source, p, p.records.records[id] as usize, s.begin, s.end)?;
    let usize member = lexer::next(source, s)?;
    let usize equals = lexer::punctuation(source, s, 61)?;
    return .ok(leaf);
}

// Constructor syntax and bare-name copies are separate initializer forms.
// Inspect the following token so a local sharing a type name stays unambiguous.
pub fn Result<bool, errors::Error> constructor(ref u8[] source, ref mut lexer::State s, usize record) {
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    var lexer::State look = lexer::snapshot(s);
    let usize next = lexer::next(source, ref mut look)?;
    if (look.kind != 123) { return .ok(false); }
    if (named(source, s)? != record) { return .err(errors::make(3, s.begin)); }
    let usize name = lexer::next(source, s)?;
    let usize open = lexer::punctuation(source, s, 123)?;
    return .ok(true);
}
fn Result<usize, errors::Error> copy_source(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref locals::Table names, usize record) {
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    let usize at = s.begin;
    let usize index = locals::find(source, names, s.begin, s.end);
    if (!binding(names, index)) { return .err(errors::make(3, at)); }
    let usize id = names.registers[index] - 144;
    if (id >= p.records.count || p.records.records[id] as usize != record) { return .err(errors::make(3, at)); }
    let usize name = lexer::next(source, s)?;
    let usize end = lexer::punctuation(source, s, 59)?;
    return .ok(id);
}
pub fn Result<usize, errors::Error> copy(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref mut locals::Table names, Header header) {
    let usize from = copy_source(source, s, p, names, header.record)?;
    let usize id = ir::record(p, header.record, header.mutable, header.begin)?;
    let usize copied = ir::record_copy(p, id, from, header.begin)?;
    // The new binding becomes visible only after its complete initializer.
    return locals::declare(names, header.begin, header.end, 144 + id, header.mutable);
}
pub fn Result<usize, errors::Error> assign(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, usize id, usize at) {
    if (id >= p.records.count || !p.records.mutable[id]) { return .err(errors::make(3, at)); }
    let usize equals = lexer::punctuation(source, s, 61)?;
    let usize from = copy_source(source, s, p, names, p.records.records[id] as usize)?;
    return ir::record_assign(p, id, from, at);
}
