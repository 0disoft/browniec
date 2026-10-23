module compiler;

import errors as errors;
import lexer as lexer;
import ir as ir;
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
fn Result<usize, errors::Error> primary(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, usize depth) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    let usize at = s.begin;
    if (s.kind == 45) {
        let usize advanced = lexer::next(source, s)?;
        // The minimum signed literal is admitted without constructing positive i32 MIN.
        if (s.kind == 1 && s.value == 2147483648) {
            let usize advanced_min = lexer::next(source, s)?;
            return ir::literal(p, -2147483648, at);
        }
        let usize operand = primary(source, s, p, depth + 1)?;
        return ir::emit(p, 7, operand, 0, at);
    }
    if (s.kind == 1) {
        let i64 value = s.value;
        let usize advanced = lexer::next(source, s)?;
        return ir::literal(p, value, at);
    }
    if (s.kind == 40) {
        let usize advanced = lexer::next(source, s)?;
        let usize result = expression(source, s, p, 1, depth + 1)?;
        let usize closed = lexer::punctuation(source, s, 41)?;
        return .ok(result);
    }
    return .err(errors::make(2, s.begin));
}
fn Result<usize, errors::Error> expression(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, u8 minimum, usize depth) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    var usize left = primary(source, s, p, depth)?;
    while (precedence(s.kind) >= minimum) {
        let u8 level = precedence(s.kind);
        let u8 operation = opcode(s.kind);
        let usize at = s.begin;
        let usize advanced = lexer::next(source, s)?;
        let usize right = expression(source, s, p, level + 1, depth + 1)?;
        left = ir::emit(p, operation, left, right, at)?;
    }
    return .ok(left);
}

pub fn Result<ir::Program, errors::Error> compile(ref u8[] source) {
    if (source.len > 4096) { return .err(errors::make(4, 4096)); }
    let ref str valid = switch (text::validate_utf8(source)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(1, 0)); }
    };
    var lexer::State s = lexer::empty();
    var ir::Program p = ir::empty();
    let usize first = lexer::next(source, ref mut s)?;
    let usize module_word = lexer::word(source, ref mut s, b"module")?;
    let usize module_name = lexer::word(source, ref mut s, b"main")?;
    let usize module_end = lexer::punctuation(source, ref mut s, 59)?;
    let usize function_word = lexer::word(source, ref mut s, b"fn")?;
    if (s.kind == 2 && !lexer::equal(source[s.begin..s.end], b"i32")) {
        return .err(errors::make(3, s.begin));
    }
    let usize type_word = lexer::word(source, ref mut s, b"i32")?;
    let usize function_name = lexer::word(source, ref mut s, b"main")?;
    let usize open_args = lexer::punctuation(source, ref mut s, 40)?;
    let usize close_args = lexer::punctuation(source, ref mut s, 41)?;
    let usize open_body = lexer::punctuation(source, ref mut s, 123)?;
    let usize return_word = lexer::word(source, ref mut s, b"return")?;
    let usize value = expression(source, ref mut s, ref mut p, 1, 0)?;
    let usize return_end = lexer::punctuation(source, ref mut s, 59)?;
    let usize body_end = lexer::punctuation(source, ref mut s, 125)?;
    if (s.kind != 0) { return .err(errors::make(2, s.begin)); }
    let usize returned = ir::emit(ref mut p, 8, value, 0, source.len)?;
    return .ok(p);
}
