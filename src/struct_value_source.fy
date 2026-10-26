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
// bounded declaration names; path resolution converts field indices to leaf ordinals.
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
pub struct Header { usize record; usize begin; usize end; bool mutable; }
pub fn Result<Header, errors::Error> header(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref locals::Table names, usize record, bool mutable, u8 terminator, u8 result_type) {
    let usize at = s.begin;
    if (names.function != p.entry || result_type == 0 || terminator != 59 || record >= p.records.layouts.count) { return .err(errors::make(3, at)); }
    let layouts::Plan plan = switch (layouts::plan(ref p.records.layouts, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(3, at)); }
    };
    if (plan.bytes[record] > 128) { return .err(errors::make(4, at)); }
    let usize type_name = lexer::next(source, s)?;
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, s.begin)); }
    let usize begin = s.begin; let usize end = s.end;
    if (locals::find(source, names, begin, end) != 64) { return .err(errors::make(3, begin)); }
    if (names.count >= 64 || p.records.count >= 16) { return .err(errors::make(4, begin)); }
    let usize name = lexer::next(source, s)?;
    let usize equals = lexer::punctuation(source, s, 61)?;
    return .ok(Header { .record = record, .begin = begin, .end = end,
        .mutable = mutable });
}
pub struct Leaf { usize ordinal; u8 tag; }
// Scalar ordinals are depth-first leaf positions, never field or byte offsets.
fn Result<Leaf, errors::Error> path(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, usize root, usize at) {
    var usize record = root; var usize ordinal = 0; var usize depth = 0;
    while (s.kind == 46) {
        if (depth >= 16) { return .err(errors::make(4, s.begin)); } depth += 1;
        let usize dot = lexer::next(source, s)?;
        if (s.kind != 2) { return .err(errors::make(2, s.begin)); }
        let usize selected = field(source, p, record, s.begin, s.end)?;
        var usize i = 0;
        while (i < selected) {
            let usize slot = record*16+i;
            if (p.records.layouts.kinds[slot] == 0) { ordinal += 1; }
            else { let Shape sibling = shape(p, p.records.layouts.types[slot] as usize, at)?; ordinal += sibling.count; }
            i += 1;
        }
        let usize slot = record*16+selected;
        let usize member = lexer::next(source, s)?;
        if (p.records.layouts.kinds[slot] == 0) {
            if (s.kind == 46) { return .err(errors::make(2, s.begin)); }
            return .ok(Leaf { .ordinal = ordinal, .tag = p.records.layouts.types[slot] });
        }
        record = p.records.layouts.types[slot] as usize;
    }
    return .err(errors::make(3, at));
}
pub fn Result<usize, errors::Error> read(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, usize id, usize at) {
    if (id >= p.records.count || s.kind != 46) { return .err(errors::make(3, at)); }
    let Leaf leaf = path(source, s, p, p.records.records[id] as usize, at)?;
    return ir::record_read(p, id, leaf.ordinal, at);
}
// Dotted final values remain expressions; only '=' after a bounded chain writes.
pub fn Result<bool, errors::Error> assigned(ref u8[] source, ref lexer::State state) {
    var lexer::State look = lexer::snapshot(state); var usize depth = 0;
    while (look.kind == 46) {
        if (depth >= 16) { return .err(errors::make(4, look.begin)); } depth += 1;
        let usize dot = lexer::next(source, ref mut look)?;
        if (look.kind != 2) { return .ok(false); }
        let usize member = lexer::next(source, ref mut look)?;
    }
    return .ok(depth != 0 && look.kind == 61);
}
pub fn Result<Leaf, errors::Error> writable(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, usize id, usize at) {
    if (id >= p.records.count || !p.records.mutable[id] || s.kind != 46) { return .err(errors::make(3, at)); }
    let Leaf leaf = path(source, s, p, p.records.records[id] as usize, at)?;
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

// Keep source staging at sixteen scalar leaves; private VM roots allow 128.
pub struct Shape { usize count; u8[16] tags; }
pub fn Result<Shape, errors::Error> shape(ref ir::Program p, usize root, usize at) {
    var Shape result = Shape { .count = 0, .tags = [0; 16] };
    var usize[16] records = [0; 16]; var usize[16] fields = [0; 16];
    records[0] = root; var usize depth = 1; var usize visits = 0;
    while (depth > 0) {
        if (visits >= 4096) { return .err(errors::make(4, at)); } visits += 1;
        let usize level = depth-1; let usize record = records[level];
        if (record >= p.records.layouts.count) { return .err(errors::make(3, at)); }
        if (fields[level] >= p.records.layouts.fields[record] as usize) { depth -= 1; }
        else {
            let usize slot = record*16+fields[level]; fields[level] += 1;
            if (p.records.layouts.kinds[slot] == 0) {
                if (result.count >= 16) { return .err(errors::make(4, at)); }
                let usize leaf = result.count; result.tags[leaf] = p.records.layouts.types[slot]; result.count += 1;
            } else {
                if (depth >= 16) { return .err(errors::make(4, at)); }
                records[depth] = p.records.layouts.types[slot] as usize; fields[depth] = 0; depth += 1;
            }
        }
    }
    return .ok(result);
}
pub struct Initializer { usize[16] records; usize[16] fields; usize depth; }
pub fn Initializer initializer(usize root) {
    var Initializer result = Initializer { .records = [0; 16], .fields = [0; 16], .depth = 1 };
    result.records[0] = root; return result;
}
// A completed scalar or child constructor advances exactly one enclosing field.
pub fn Result<usize, errors::Error> advance(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref mut Initializer state) {
    let usize level = state.depth-1; state.fields[level] += 1;
    if (state.fields[level] < p.records.layouts.fields[state.records[level]] as usize) {
        let usize comma = lexer::punctuation(source, s, 44)?;
    }
    return .ok(0);
}
// Iteratively enter child constructors or close completed records. The caller
// parses/records one scalar expression at a time in depth-first source order.
pub fn Result<u8, errors::Error> next_leaf(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref mut Initializer state, usize at) {
    while (state.depth > 0) {
        let usize level = state.depth-1; let usize record = state.records[level];
        let usize selected = state.fields[level];
        if (selected >= p.records.layouts.fields[record] as usize) {
            if (s.kind == 44) { let usize comma = lexer::next(source, s)?; }
            let usize close = lexer::punctuation(source, s, 125)?; state.depth -= 1;
            if (state.depth > 0) { let usize finished = advance(source,s,p,state)?; }
        } else {
            let usize dot = lexer::punctuation(source,s,46)?;
            let usize found = field(source,p,record,s.begin,s.end)?;
            if (s.kind != 2 || found != selected) { return .err(errors::make(3,s.begin)); }
            let usize name = lexer::next(source,s)?;
            let usize equals = lexer::punctuation(source,s,61)?;
            let usize slot = record*16+selected;
            if (p.records.layouts.kinds[slot] == 0) { return .ok(p.records.layouts.types[slot]); }
            let usize child = p.records.layouts.types[slot] as usize;
            if (!constructor(source,s,child)?) { return .err(errors::make(3,s.begin)); }
            if (state.depth >= 16) { return .err(errors::make(4,at)); }
            let usize depth = state.depth; state.records[depth] = child; state.fields[depth] = 0; state.depth += 1;
        }
    }
    return .ok(0);
}
