module types;

import lexer as lexer;
import errors as errors;

// Private scalar tags: 1 i32, 2 bool. No implicit conversions.
pub fn bool valid(u8 tag) { return tag == 1 || tag == 2; }
pub fn Result<u8, errors::Error> parse(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 2) { return .err(errors::make(2, s.begin)); }
    let u8 tag = if (lexer::equal(source[s.begin..s.end], b"i32")) { 1 }
        else if (lexer::equal(source[s.begin..s.end], b"bool")) { 2 } else { 0 };
    if (tag == 0) { return .err(errors::make(3, s.begin)); }
    let usize next = lexer::next(source, s)?;
    return .ok(tag);
}
