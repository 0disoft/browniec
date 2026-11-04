module functions;

import errors as errors;
import lexer as lexer;
import locals as locals;
import types as types;
import array_source as array_source;
import struct_source as structs;
import cells as cells;
import std::num as num;
import literal_collection as literal_collection;

// Bounded signature pass enables forward calls without trusting unparsed bodies.
pub struct Table {
    literal_collection::Index literals;
    usize[16] begins;
    usize[16] ends;
    usize[16] bodies;
    usize[16] body_ends;
    usize[16] arities;
    usize[128] param_begins;
    usize[128] param_ends;
    u8[16] return_types;
    // Zero denotes a scalar/wrapper result; arrays retain exact element/length.
    usize[16] return_lengths;
    // Zero scalar/array/wrapper; otherwise nominal record ID + 1, not a VM site.
    u8[16] return_records;
    // Nonzero encodes a scalar[] result; bit128 is exclusive access. These
    // declarations are analysis-only until body-origin proof and VM handoff.
    u8[16] return_slice_elements;
    // Advisory body-derived origin hints; independently recomputed at IR admission.
    u8[16] return_slice_inputs;
    // Upper bound on exact-mode input origins, one bit per argument position.
    // Multiple candidates are not a multi-origin return or an origin proof.
    u8[16] return_slice_candidates;
    u8[128] param_types;
    // Zero denotes a scalar/wrapper; 1..4096 is an exact scalar-array shape.
    usize[128] param_lengths;
    // Filled by source lowering before bodies: immutable catalog ID + 1.
    u8[128] param_arrays;
    // Zero scalar/array; otherwise nominal source record ID + 1. No runtime site.
    u8[128] param_records;
    // Scalar[] borrow; element bit128 denotes exclusive access, as in IR.
    bool[128] param_slices;
    u8[128] param_slice_elements;
    usize count;
    usize entry;
}
pub fn Table empty() {
    return Table { .literals=literal_collection::empty(), .begins = [0; 16], .ends = [0; 16], .bodies = [0; 16],
        .body_ends = [0; 16], .arities = [0; 16], .return_lengths = [0; 16], .return_records = [0; 16],
        .return_slice_elements = [0; 16], .return_slice_inputs = [0; 16], .return_slice_candidates = [0; 16], .param_begins = [0; 128],
        .param_ends = [0; 128], .return_types = [0; 16], .param_types = [0; 128],
        .param_lengths = [0; 128], .param_arrays = [0; 128], .param_records = [0; 128], .param_slices = [false; 128], .param_slice_elements = [0; 128], .count = 0, .entry = 16 };
}
pub fn usize find(ref u8[] source, ref Table t, usize begin, usize end) {
    var usize i = 0;
    while (i < t.count) {
        if (lexer::equal(source[begin..end], source[t.begins[i]..t.ends[i]])) { return i; }
        i += 1;
    }
    return 16;
}
// Primitive/wrapper spellings keep the existing parser and do not rescan source.
// Only nominal names need the bounded declaration lookup, including forward types.
fn Result<u8, errors::Error> record_type(ref u8[] source, ref lexer::State s) {
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .ok(0); }
    let structs::Location found = structs::locate(source, s.begin, s.end, 32)?;
    if (found.record >= 32) { return .err(errors::make(3, s.begin)); }
    let i64 encoded = cells::pack(found.record + 1, s.begin)?;
    return switch (num::u8_from_i64(encoded)) {
        case .ok(value): { .ok(value) } case .err(_): { .err(errors::make(4, s.begin)) }
    };
}
fn Result<usize, errors::Error> signature(ref u8[] source, ref mut lexer::State s, ref mut Table t) {
    if (t.count >= 16) { return .err(errors::make(4, s.begin)); }
    let usize fn_word = lexer::word(source, s, b"fn")?;
    let bool result_slice = s.kind == 2 && lexer::equal(source[s.begin..s.end], b"ref");
    var u8 result_element = 0;
    if (result_slice) {
        let usize reference = lexer::next(source, s)?;
        let bool exclusive = s.kind == 2 && lexer::equal(source[s.begin..s.end], b"mut");
        if (exclusive) { let usize access = lexer::next(source, s)?; }
        result_element = types::parse(source, s)?;
        if (!types::scalar(result_element)) { return .err(errors::make(3, s.begin)); }
        if (exclusive) { result_element |= 128; }
        let usize open_slice = lexer::punctuation(source, s, 91)?;
        let usize close_slice = lexer::punctuation(source, s, 93)?;
    }
    let u8 result_record = if (result_slice) { 0 } else { record_type(source, s)? };
    let u8 result_type = if (result_slice) { 0 } else if (result_record == 0) { types::parse(source, s)? }
        else { let usize named = lexer::next(source, s)?; 0 };
    if (result_record != 0 && s.kind == 60) { return .err(errors::make(3, s.begin)); }
    var usize result_length = 0;
    if (s.kind == 91) {
        if (!types::scalar(result_type)) { return .err(errors::make(3, s.begin)); }
        result_length = array_source::length(source, s)?;
    }
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, s.begin)); }
    if (find(source, t, s.begin, s.end) != 16) { return .err(errors::make(3, s.begin)); }
    let usize f = t.count;
    t.return_types[f] = result_type;
    t.return_lengths[f] = result_length;
    t.return_records[f] = result_record;
    t.return_slice_elements[f] = result_element;
    t.begins[f] = s.begin;
    t.ends[f] = s.end;
    let bool main = lexer::equal(source[s.begin..s.end], b"main");
    let usize name = lexer::next(source, s)?;
    let usize open = lexer::punctuation(source, s, 40)?;
    var usize arity = 0;
    var locals::Table parameters = locals::empty();
    while (s.kind != 41) {
        if (arity >= 8) { return .err(errors::make(4, s.begin)); }
        let bool parameter_slice = s.kind == 2 && lexer::equal(source[s.begin..s.end], b"ref");
        var u8 slice_element = 0;
        if (parameter_slice) {
            let usize reference = lexer::next(source, s)?;
            let bool exclusive = s.kind == 2 && lexer::equal(source[s.begin..s.end], b"mut");
            if (exclusive) { let usize access = lexer::next(source, s)?; }
            slice_element = types::parse(source, s)?;
            if (!types::scalar(slice_element)) { return .err(errors::make(3, s.begin)); }
            if (exclusive) { slice_element |= 128; }
            let usize open_slice = lexer::punctuation(source, s, 91)?;
            let usize close_slice = lexer::punctuation(source, s, 93)?;
        }
        let u8 parameter_record = if (parameter_slice) { 0 } else { record_type(source, s)? };
        let u8 parameter_type = if (parameter_slice) { 0 } else if (parameter_record == 0) { types::parse(source, s)? }
            else { let usize named = lexer::next(source, s)?; 0 };
        if (parameter_record != 0 && s.kind == 60) { return .err(errors::make(3, s.begin)); }
        var usize parameter_length = 0;
        if (s.kind == 91) {
            if (!types::scalar(parameter_type)) { return .err(errors::make(3, s.begin)); }
            parameter_length = array_source::length(source, s)?;
        }
        if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, s.begin)); }
        let usize begin = s.begin;
        let usize end = s.end;
        if (locals::find(source, ref parameters, begin, end) != 64) { return .err(errors::make(3, begin)); }
        let usize parameter = locals::declare(ref mut parameters, begin, end, arity, false)?;
        let usize at = f * 8 + arity;
        t.param_begins[at] = begin;
        t.param_ends[at] = end;
        t.param_types[at] = parameter_type;
        t.param_lengths[at] = parameter_length;
        t.param_records[at] = parameter_record;
        t.param_slices[at] = parameter_slice;
        t.param_slice_elements[at] = slice_element;
        if (result_slice && parameter_slice && slice_element == result_element) {
            let usize one = 1;
            let i64 candidate = cells::pack(one << arity, begin)?;
            let u8 bit = switch (num::u8_from_i64(candidate)) {
                case .ok(value): { value } case .err(_): { return .err(errors::make(4, begin)); }
            };
            t.return_slice_candidates[f] |= bit;
        }
        arity += 1;
        let usize next = lexer::next(source, s)?;
        if (s.kind == 41) { break; }
        let usize comma = lexer::punctuation(source, s, 44)?;
        if (s.kind == 41) { return .err(errors::make(2, s.begin)); }
    }
    if (result_slice && t.return_slice_candidates[f] == 0) { return .err(errors::make(3, t.begins[f])); }
    if (main && (arity != 0 || result_type != 1 || result_length != 0 || result_record != 0 || result_slice)) { return .err(errors::make(3, t.begins[f])); }
    if (main) { t.entry = f; }
    t.arities[f] = arity;
    let usize close = lexer::punctuation(source, s, 41)?;
    let usize body = lexer::punctuation(source, s, 123)?;
    t.bodies[f] = s.begin;
    var usize depth = 1;
    while (depth != 0) {
        if (s.kind == 0) { return .err(errors::make(2, s.begin)); }
        if (s.kind == 123) { depth += 1; if (depth > 33) { return .err(errors::make(4, s.begin)); } }
        if (s.kind == 125) { depth -= 1; if (depth == 0) { break; } }
        let usize token = lexer::next(source, s)?;
    }
    t.body_ends[f] = s.begin;
    let usize end_body = lexer::next(source, s)?;
    t.count += 1;
    return .ok(f);
}
pub fn Result<Table, errors::Error> scan(ref u8[] source) {
    var Table t = empty();
    var lexer::State s = lexer::empty();
    let usize first = lexer::next(source, ref mut s)?;
    let usize module_word = lexer::word(source, ref mut s, b"module")?;
    let usize module_name = lexer::word(source, ref mut s, b"main")?;
    let usize module_end = lexer::punctuation(source, ref mut s, 59)?;
    while (s.kind != 0) {
        if (s.kind == 2 && lexer::equal(source[s.begin..s.end], b"struct")) {
            let usize skipped = structs::skip(source, ref mut s)?;
        } else { let usize declared = signature(source, ref mut s, ref mut t)?; }
    }
    if (t.entry == 16) { return .err(errors::make(3, source.len)); }
    return .ok(t);
}
