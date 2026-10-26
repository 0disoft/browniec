module struct_source;

import lexer as lexer;
import locals as locals;
import types as types;
import struct_layout as layouts;
import errors as errors;
import std::num as num;

// Names are spans in the immutable source. No object bindings or guest values.
pub struct Table { layouts::Catalog layouts; usize[32] begins; usize[32] ends; usize[32] bodies; }
fn Table empty() {
    return Table { .layouts = layouts::empty(), .begins = [0; 32], .ends = [0; 32], .bodies = [0; 32] };
}
pub fn usize find(ref u8[] source, ref Table table, usize begin, usize end) {
    var usize i = 0;
    while (i < table.layouts.count) {
        if (lexer::equal(source[begin..end], source[table.begins[i]..table.ends[i]])) { return i; }
        i += 1;
    }
    return 32;
}
fn bool word(ref u8[] source, ref lexer::State s, ref u8[] value) {
    return s.kind == 2 && lexer::equal(source[s.begin..s.end], value);
}
fn Result<usize, errors::Error> name(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, s.begin)); }
    return lexer::next(source, s);
}
// The function signature pass validates declaration syntax through this
// same parser. Aggregate/wrapper fields are rejected, not silently skipped.
pub fn Result<usize, errors::Error> skip(ref u8[] source, ref mut lexer::State s) {
    let usize keyword = lexer::word(source, s, b"struct")?;
    let usize named = name(source, s)?;
    let usize open = lexer::punctuation(source, s, 123)?;
    var usize count = 0;
    while (s.kind != 125) {
        if (s.kind != 2) { return .err(errors::make(2, s.begin)); }
        if (count >= 16) { return .err(errors::make(4, s.begin)); }
        let usize type_name = lexer::next(source, s)?;
        if (s.kind == 60 || s.kind == 91) { return .err(errors::make(3, s.begin)); }
        let usize field = name(source, s)?;
        let usize end = lexer::punctuation(source, s, 59)?;
        count += 1;
    }
    if (count == 0) { return .err(errors::make(3, s.begin)); }
    let usize close = lexer::next(source, s)?;
    return .ok(count);
}
fn Result<usize, errors::Error> function_body(ref u8[] source, ref mut lexer::State s) {
    let usize keyword = lexer::word(source, s, b"fn")?;
    while (s.kind != 123) {
        if (s.kind == 0 || s.kind == 125) { return .err(errors::make(2, s.begin)); }
        let usize next = lexer::next(source, s)?;
    }
    var usize depth = 1;
    let usize open = lexer::next(source, s)?;
    while (depth > 0) {
        if (s.kind == 0) { return .err(errors::make(2, s.begin)); }
        if (s.kind == 123) { depth += 1; if (depth > 33) { return .err(errors::make(4, s.begin)); } }
        if (s.kind == 125) { depth -= 1; }
        let usize next = lexer::next(source, s)?;
    }
    return .ok(0);
}
fn Result<u8, errors::Error> code(usize id, usize offset) {
    let i64 wide = switch (num::i64_from_usize(id)) {
        case .ok(n): { n } case .err(_): { return .err(errors::make(4, offset)); }
    };
    return switch (num::u8_from_i64(wide)) {
        case .ok(n): { .ok(n) } case .err(_): { .err(errors::make(4, offset)) }
    };
}
fn Result<usize, errors::Error> resolve(ref u8[] source, ref mut Table table, usize record) {
    var lexer::State s = lexer::empty(); s.cursor = table.bodies[record];
    let usize first = lexer::next(source, ref mut s)?;
    var usize[16] begins = [0; 16]; var usize[16] ends = [0; 16];
    var usize field = 0;
    while (s.kind != 125) {
        let usize slot = record * 16 + field;
        let usize id = find(source, table, s.begin, s.end);
        if (id < 32) {
            table.layouts.kinds[slot] = 1; table.layouts.types[slot] = code(id, s.begin)?;
            let usize named = lexer::next(source, ref mut s)?;
        } else {
            let u8 tag = types::parse(source, ref mut s)?;
            if (!types::scalar(tag)) { return .err(errors::make(3, s.begin)); }
            table.layouts.types[slot] = tag;
        }
        var usize prior = 0;
        while (prior < field) {
            if (lexer::equal(source[s.begin..s.end], source[begins[prior]..ends[prior]])) { return .err(errors::make(3, s.begin)); }
            prior += 1;
        }
        begins[field] = s.begin; ends[field] = s.end;
        let usize named = name(source, ref mut s)?;
        let usize end = lexer::punctuation(source, ref mut s, 59)?;
        field += 1;
    }
    table.layouts.fields[record] = code(field, s.begin)?;
    return .ok(field);
}
pub fn Result<Table, errors::Error> scan(ref u8[] source) {
    if (source.len > 4096) { return .err(errors::make(4, 4096)); }
    var Table table = empty(); var lexer::State s = lexer::empty();
    let usize first = lexer::next(source, ref mut s)?;
    let usize module_word = lexer::word(source, ref mut s, b"module")?;
    let usize module_name = lexer::word(source, ref mut s, b"main")?;
    let usize module_end = lexer::punctuation(source, ref mut s, 59)?;
    while (s.kind != 0) {
        if (word(source, ref s, b"struct")) {
            let usize id = table.layouts.count;
            if (id >= 32) { return .err(errors::make(4, s.begin)); }
            var lexer::State look = lexer::snapshot(ref s);
            let usize keyword = lexer::next(source, ref mut look)?;
            if (look.kind != 2 || locals::reserved(source[look.begin..look.end])) { return .err(errors::make(2, look.begin)); }
            if (find(source, ref table, look.begin, look.end) != 32) { return .err(errors::make(3, look.begin)); }
            table.begins[id] = look.begin; table.ends[id] = look.end;
            let usize named = lexer::next(source, ref mut look)?;
            let usize open = lexer::punctuation(source, ref mut look, 123)?;
            table.bodies[id] = look.begin;
            let usize fields = skip(source, ref mut s)?;
            table.layouts.count += 1;
        } else { let usize skipped = function_body(source, ref mut s)?; }
    }
    var usize record = 0;
    while (record < table.layouts.count) { let usize fields = resolve(source, ref mut table, record)?; record += 1; }
    let layouts::Plan plan = switch (layouts::plan(ref table.layouts, 18446744073709551615)) {
        case .ok(value): { value }
        case .err(error): {
            let u8 kind = switch (error) { case .Depth: { 4 } case .Overflow: { 4 } case .Quota: { 4 } case .Limit: { 4 } case .Fields: { 3 } case .Type: { 3 } case .Metadata: { 3 } case .Cycle: { 3 } };
            return .err(errors::make(kind, table.begins[0]));
        }
    };
    return .ok(table);
}
