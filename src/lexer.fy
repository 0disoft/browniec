module lexer;

import errors as errors;
import cells as cells;
import literal_source as literals;

// 0 EOF, 1 integer, 2 identifier, 3 byte literal, 4 text literal.
// Literal spans retain raw spelling; decoded storage belongs to the compiler.
// Other punctuation uses its ASCII byte.
// 128 ==, 129 !=, 130 <=, 131 >=, 132 &&, 133 ||, 134 <<, 135 >>.
pub struct State { usize cursor; usize begin; usize end; usize tokens; u8 kind; i64 value; bool min_magnitude; }
pub fn State empty() {
    return State { .cursor = 0, .begin = 0, .end = 0, .tokens = 0, .kind = 0, .value = 0, .min_magnitude = false };
}
pub fn State snapshot(ref State s) {
    return State {.cursor=s.cursor,.begin=s.begin,.end=s.end,
        .tokens=s.tokens,.kind=s.kind,.value=s.value,.min_magnitude=s.min_magnitude};
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
fn bool bom(ref u8[] source, usize at) {
    return at + 2 < source.len && source[at] == 239 && source[at + 1] == 187 && source[at + 2] == 191;
}

fn Result<usize, errors::Error> block_comment(ref u8[] source, usize cursor, usize begin) {
    var usize depth = 1;
    var usize at = cursor + 2;
    while (at < source.len && depth != 0) {
        let u8 ch = source[at];
        if (ch == 0) { return .err(errors::make(1, at)); }
        if (bom(source, at)) { return .err(errors::make(1, at)); }
        if (ch == 13) {
            if (at + 1 < source.len && source[at + 1] == 10) {
                at += 2;
                continue;
            }
            return .err(errors::make(1, at));
        }
        if (ch == 47 && at + 1 < source.len && source[at + 1] == 42) {
            if (depth == 2048) { return .err(errors::make(4, at)); }
            depth += 1;
            at += 2;
            continue;
        }
        if (ch == 42 && at + 1 < source.len && source[at + 1] == 47) {
            depth -= 1;
            at += 2;
            continue;
        }
        at += 1;
    }
    if (depth != 0) { return .err(errors::make(1, begin)); }
    return .ok(at);
}

fn Result<usize, errors::Error> line_comment(ref u8[] source, usize cursor) {
    var usize at = cursor + 2;
    while (at < source.len) {
        let u8 ch = source[at];
        if (ch == 0) { return .err(errors::make(1, at)); }
        if (bom(source, at)) { return .err(errors::make(1, at)); }
        if (ch == 10) { return .ok(at + 1); }
        if (ch == 13) {
            if (at + 1 < source.len && source[at + 1] == 10) {
                return .ok(at + 2);
            }
            return .err(errors::make(1, at));
        }
        at += 1;
    }
    return .ok(at);
}

pub fn Result<usize, errors::Error> next(ref u8[] source, ref mut State s) {
    while (s.cursor < source.len) {
        if (s.cursor == 0 && bom(source, 0)) { s.cursor = 3; continue; }
        let u8 ch = source[s.cursor];
        if (bom(source, s.cursor)) { return .err(errors::make(1, s.cursor)); }
        if (ch == 0) { return .err(errors::make(1, s.cursor)); }
        if (ch == 32 || ch == 9 || ch == 10) { s.cursor += 1; continue; }
        if (ch == 13) {
            if (s.cursor + 1 < source.len && source[s.cursor + 1] == 10) {
                s.cursor += 2;
                continue;
            }
            return .err(errors::make(1, s.cursor));
        }
        if (ch == 47 && s.cursor + 1 < source.len && source[s.cursor + 1] == 47) {
            let usize closed = line_comment(source, s.cursor)?;
            s.cursor = closed;
            continue;
        }
        if (ch == 47 && s.cursor + 1 < source.len && source[s.cursor + 1] == 42) {
            let usize opener = s.cursor;
            let usize closed = block_comment(source, s.cursor, opener)?;
            s.cursor = closed;
            continue;
        }
        break;
    }
    s.begin = s.cursor;
    s.tokens += 1;
    if (s.tokens > 1024) { return .err(errors::make(4, s.begin)); }
    s.value = 0;
    s.min_magnitude = false;
    if (s.cursor == source.len) { s.kind = 0; s.end = s.cursor; return .ok(0); }
    let u8 ch = source[s.cursor];
    let u8 literal=literals::kind(source,s.cursor);
    if(literal!=0){
        let usize end=literals::scan(source,s.cursor)?;
        s.kind=literal;s.cursor=end;s.end=end;return .ok(0);
    }
    // C string ownership/FFI is outside the accepted guest profile.
    if(ch==99 && s.cursor+1<source.len && source[s.cursor+1]==34){return .err(errors::make(1,s.begin));}
    if (digit(ch)) {
        s.kind = 1;
        var usize magnitude=0;
        while (s.cursor < source.len && digit(source[s.cursor])) {
            let usize part = (source[s.cursor] - 48) as usize;
            // Accept the full unsigned domain without wrapping the scanner.
            if (magnitude > 1844674407370955161 || (magnitude == 1844674407370955161 && part > 5)) {
                return .err(errors::make(3, s.begin));
            }
            magnitude = magnitude * 10 + part;
            s.cursor += 1;
        }
        s.min_magnitude = magnitude == 9223372036854775808;
        s.value = cells::pack(magnitude,s.begin)?;
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
            else if (ch == 60 && after == 60) { pair = 134; }
            else if (ch == 62 && after == 62) { pair = 135; }
            if (pair != 0) { s.kind = pair; s.cursor += 2; s.end = s.cursor; return .ok(0); }
        }
        if (ch != 40 && ch != 41 && ch != 123 && ch != 125 && ch != 59 &&
            ch != 43 && ch != 45 && ch != 42 && ch != 47 && ch != 37 && ch != 61 && ch != 44 &&
            ch != 33 && ch != 60 && ch != 62 && ch != 46 && ch != 58 && ch != 63 &&
            ch != 38 && ch != 94 && ch != 124 && ch != 126 && ch != 91 && ch != 93) {
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
