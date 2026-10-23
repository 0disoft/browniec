module lexer;

import errors as errors;

// 0 EOF, 1 integer, 2 identifier; punctuation uses its ASCII byte.
// 128 ==, 129 !=, 130 <=, 131 >=, 132 &&, 133 ||.
pub struct State { usize cursor; usize begin; usize end; usize tokens; u8 kind; i64 value; }
pub fn State empty() {
    return State { .cursor = 0, .begin = 0, .end = 0, .tokens = 0, .kind = 0, .value = 0 };
}
pub fn State snapshot(ref State s) {
    return State {.cursor=s.cursor,.begin=s.begin,.end=s.end,
        .tokens=s.tokens,.kind=s.kind,.value=s.value};
}
pub fn bool equal(ref u8[] a, ref u8[] b) {
    if (a.len != b.len) { return false; }
    var usize i = 0;
    while (i < a.len) { if (a[i] != b[i]) { return false; } i += 1; }
    return true;
}
fn bool letter(u8 ch) {
    return (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 95;
}
fn bool digit(u8 ch) { return ch >= 48 && ch <= 57; }

pub fn Result<usize, errors::Error> next(ref u8[] source, ref mut State s) {
    while (s.cursor < source.len) {
        let u8 ch = source[s.cursor];
        if (ch == 32 || ch == 9 || ch == 10 || ch == 13) { s.cursor += 1; continue; }
        if (ch == 47 && s.cursor + 1 < source.len && source[s.cursor + 1] == 47) {
            s.cursor += 2;
            while (s.cursor < source.len && source[s.cursor] != 10) { s.cursor += 1; }
            continue;
        }
        break;
    }
    s.begin = s.cursor;
    s.tokens += 1;
    if (s.tokens > 1024) { return .err(errors::make(4, s.begin)); }
    s.value = 0;
    if (s.cursor == source.len) { s.kind = 0; s.end = s.cursor; return .ok(0); }
    let u8 ch = source[s.cursor];
    if (digit(ch)) {
        s.kind = 1;
        while (s.cursor < source.len && digit(source[s.cursor])) {
            let i64 part = (source[s.cursor] - 48) as i64;
            if (s.value > 214748364 || (s.value == 214748364 && part > 8)) {
                return .err(errors::make(3, s.begin));
            }
            s.value = s.value * 10 + part;
            s.cursor += 1;
        }
    } else if (letter(ch)) {
        s.kind = 2;
        while (s.cursor < source.len && (letter(source[s.cursor]) || digit(source[s.cursor]))) { s.cursor += 1; }
    } else {
        if (s.cursor + 1 < source.len) {
            let u8 after = source[s.cursor + 1];
            var u8 pair = 0;
            if (ch == 61 && after == 61) { pair = 128; }
            else if (ch == 33 && after == 61) { pair = 129; }
            else if (ch == 60 && after == 61) { pair = 130; }
            else if (ch == 62 && after == 61) { pair = 131; }
            else if (ch == 38 && after == 38) { pair = 132; }
            else if (ch == 124 && after == 124) { pair = 133; }
            if (pair != 0) { s.kind = pair; s.cursor += 2; s.end = s.cursor; return .ok(0); }
        }
        if (ch != 40 && ch != 41 && ch != 123 && ch != 125 && ch != 59 &&
            ch != 43 && ch != 45 && ch != 42 && ch != 47 && ch != 37 && ch != 61 && ch != 44 &&
            ch != 33 && ch != 60 && ch != 62 && ch != 46 && ch != 58 && ch != 63) {
            return .err(errors::make(1, s.begin));
        }
        s.kind = ch;
        s.cursor += 1;
    }
    s.end = s.cursor;
    return .ok(0);
}

pub fn Result<usize, errors::Error> word(ref u8[] source, ref mut State s, ref u8[] expected) {
    if (s.kind != 2 || !equal(source[s.begin..s.end], expected)) {
        return .err(errors::make(2, s.begin));
    }
    return next(source, s);
}
pub fn Result<usize, errors::Error> punctuation(ref u8[] source, ref mut State s, u8 kind) {
    if (s.kind != kind) { return .err(errors::make(2, s.begin)); }
    return next(source, s);
}
