module compiler;

import errors as errors;
import lexer as lexer;
import ir as ir;
import locals as locals;
import functions as functions;
import std::text as text;

fn u8 precedence(u8 kind) {
    if (kind == 43 || kind == 45) { return 1; }
    if (kind == 42 || kind == 47 || kind == 37) { return 2; }
    return 0;
}
fn u8 opcode(u8 kind) {
    if (kind == 43) { return 2; }
    if (kind == 45) { return 3; }
    if (kind == 42) { return 4; }
    if (kind == 47) { return 5; }
    return 6;
}
fn Result<usize, errors::Error> primary(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    let usize at = s.begin;
    if (s.kind == 45) {
        let usize advanced = lexer::next(source, s)?;
        // The minimum signed literal is admitted without constructing positive i32 MIN.
        if (s.kind == 1 && s.value == 2147483648) {
            let usize advanced_min = lexer::next(source, s)?;
            return ir::literal(p, -2147483648, at);
        }
        let usize operand = primary(source, s, p, table, signatures, depth + 1)?;
        return ir::emit(p, 7, operand, 0, at);
    }
    if (s.kind == 1) {
        let i64 value = s.value;
        let usize advanced = lexer::next(source, s)?;
        return ir::literal(p, value, at);
    }
    if (s.kind == 2) {
        if (locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, at)); }
        let usize begin = s.begin;
        let usize end = s.end;
        let usize index = locals::find(source, table, begin, end);
        let usize advanced = lexer::next(source, s)?;
        if (s.kind == 40) {
            if (index != 64) { return .err(errors::make(3, at)); }
            let usize target = functions::find(source, signatures, begin, end);
            if (target == 16) { return .err(errors::make(3, at)); }
            let usize open = lexer::next(source, s)?;
            var usize[8] arguments = [0; 8];
            var usize arity = 0;
            while (s.kind != 41) {
                if (arity >= 8) { return .err(errors::make(4, s.begin)); }
                arguments[arity] = expression(source, s, p, table, signatures, 1, depth + 1)?;
                arity += 1;
                if (s.kind == 41) { break; }
                let usize comma = lexer::punctuation(source, s, 44)?;
                if (s.kind == 41) { return .err(errors::make(2, s.begin)); }
            }
            if (arity != signatures.arities[target]) { return .err(errors::make(3, at)); }
            let usize close = lexer::punctuation(source, s, 41)?;
            let ref usize[] view = ref arguments;
            return ir::call(p, target, view[..arity], at);
        }
        if (index == 64) { return .err(errors::make(3, at)); }
        return .ok(table.registers[index]);
    }
    if (s.kind == 40) {
        let usize advanced = lexer::next(source, s)?;
        let usize result = expression(source, s, p, table, signatures, 1, depth + 1)?;
        let usize closed = lexer::punctuation(source, s, 41)?;
        return .ok(result);
    }
    return .err(errors::make(2, s.begin));
}
fn Result<usize, errors::Error> expression(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, u8 minimum, usize depth) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    var usize left = primary(source, s, p, table, signatures, depth)?;
    while (precedence(s.kind) >= minimum) {
        let u8 level = precedence(s.kind);
        let u8 operation = opcode(s.kind);
        let usize at = s.begin;
        let usize advanced = lexer::next(source, s)?;
        let usize right = expression(source, s, p, table, signatures, level + 1, depth + 1)?;
        left = ir::emit(p, operation, left, right, at)?;
    }
    return .ok(left);
}

fn bool word_is(ref u8[] source, ref lexer::State s, ref u8[] word) {
    return s.kind == 2 && lexer::equal(source[s.begin..s.end], word);
}

fn Result<usize, errors::Error> statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures) {
    if (word_is(source, s, b"let") || word_is(source, s, b"var")) {
        let bool mutable = word_is(source, s, b"var");
        let usize keyword = lexer::next(source, s)?;
        if (s.kind == 2 && !word_is(source, s, b"i32")) { return .err(errors::make(3, s.begin)); }
        let usize type_word = lexer::word(source, s, b"i32")?;
        if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) {
            return .err(errors::make(2, s.begin));
        }
        let usize begin = s.begin;
        let usize end = s.end;
        if (locals::find(source, table, begin, end) != 64) { return .err(errors::make(3, begin)); }
        if (table.count >= 64) { return .err(errors::make(4, begin)); }
        let usize name = lexer::next(source, s)?;
        let usize equals = lexer::punctuation(source, s, 61)?;
        // The new name is not visible until its initializer has been checked.
        let usize value = expression(source, s, p, table, signatures, 1, 0)?;
        let usize end_statement = lexer::punctuation(source, s, 59)?;
        return locals::declare(table, begin, end, value, mutable);
    }
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) {
        return .err(errors::make(2, s.begin));
    }
    let usize at = s.begin;
    let usize index = locals::find(source, table, s.begin, s.end);
    if (index == 64 || !table.mutable[index]) { return .err(errors::make(3, at)); }
    let usize target = lexer::next(source, s)?;
    let usize equals = lexer::punctuation(source, s, 61)?;
    let usize value = expression(source, s, p, table, signatures, 1, 0)?;
    let usize end_statement = lexer::punctuation(source, s, 59)?;
    // Registers never mutate: copies retain their earlier value after rebinding.
    table.registers[index] = value;
    return .ok(index);
}

fn Result<usize, errors::Error> body(ref u8[] source, ref functions::Table signatures, usize f, ref mut ir::Program p) {
    var locals::Table table = locals::empty();
    let usize arity = signatures.arities[f];
    if (p.registers + arity > 128) { return .err(errors::make(4, signatures.begins[f])); }
    let usize start = p.count;
    let usize registers_start = p.registers;
    p.starts[f] = start;
    p.register_starts[f] = registers_start;
    p.arities[f] = arity;
    var usize i = 0;
    while (i < arity) {
        let usize at = f * 8 + i;
        let usize parameter = locals::declare(ref mut table, signatures.param_begins[at], signatures.param_ends[at], p.registers, false)?;
        p.registers += 1;
        i += 1;
    }
    var lexer::State s = lexer::empty();
    s.cursor = signatures.bodies[f];
    let usize first = lexer::next(source, ref mut s)?;
    while (!word_is(source, ref s, b"return")) {
        let usize compiled_statement = statement(source, ref mut s, p, ref mut table, signatures)?;
    }
    let usize return_word = lexer::word(source, ref mut s, b"return")?;
    let usize value = expression(source, ref mut s, p, ref table, signatures, 1, 0)?;
    let usize return_end = lexer::punctuation(source, ref mut s, 59)?;
    if (s.kind != 125 || s.begin != signatures.body_ends[f]) { return .err(errors::make(2, s.begin)); }
    let usize returned = ir::emit(p, 8, value, 0, s.begin)?;
    let usize end = p.count;
    let usize registers_end = p.registers;
    p.ends[f] = end;
    p.register_ends[f] = registers_end;
    return .ok(f);
}

pub fn Result<ir::Program, errors::Error> compile(ref u8[] source) {
    if (source.len > 4096) { return .err(errors::make(4, 4096)); }
    let ref str valid = switch (text::validate_utf8(source)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(1, 0)); }
    };
    let functions::Table signatures = functions::scan(source)?;
    var ir::Program p = ir::empty();
    p.function_count = signatures.count;
    p.entry = signatures.entry;
    var usize f = 0;
    while (f < signatures.count) {
        let usize emitted = body(source, ref signatures, f, ref mut p)?;
        f += 1;
    }
    return .ok(p);
}
