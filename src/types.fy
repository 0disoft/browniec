module types;

import lexer as lexer;
import errors as errors;

// 1 i32, 2 bool, 9 i64; 3/4 Option<i32/bool>; 5..8 Result<i32/i32,
// i32/bool, bool/i32, bool/bool>. Payloads are scalar, never nested wrappers.
pub fn bool integer(u8 tag) { return tag == 1 || tag == 9; }
pub fn bool scalar(u8 tag) { return integer(tag) || tag == 2; }
pub fn bool valid(u8 tag) { return tag >= 1 && tag <= 9; }
pub fn bool tagged(u8 tag) { return tag >= 3 && tag <= 8; }
pub fn u8 payload(u8 tag, u8 variant) {
    if (tag == 3 || tag == 4) { return if (variant == 0) { 0 } else if (tag == 3) { 1 } else { 2 }; }
    if (tag >= 5 && tag <= 8) {
        if (variant == 1) { return if (tag <= 6) { 1 } else { 2 }; }
        return if (tag == 5 || tag == 7) { 1 } else { 2 };
    }
    return 0;
}
fn Result<u8, errors::Error> base(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 2) { return .err(errors::make(2, s.begin)); }
    let u8 tag = if (lexer::equal(source[s.begin..s.end], b"i32")) { 1 }
        else if (lexer::equal(source[s.begin..s.end], b"bool")) { 2 }
        else if (lexer::equal(source[s.begin..s.end], b"i64")) { 9 } else { 0 };
    if (tag == 0) { return .err(errors::make(3, s.begin)); }
    let usize next = lexer::next(source, s)?;
    return .ok(tag);
}
pub fn Result<u8, errors::Error> parse(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 2) { return .err(errors::make(2,s.begin)); }
    let bool option=lexer::equal(source[s.begin..s.end],b"Option");
    let bool result=lexer::equal(source[s.begin..s.end],b"Result");
    if (!option && !result) { return base(source,s); }
    let usize name=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,60)?;
    let u8 first=base(source,s)?;
    if(first!=1 && first!=2) {return .err(errors::make(3,s.begin));}
    var u8 tag=if (first==1) {3} else {4};
    if (result) {
        let usize comma=lexer::punctuation(source,s,44)?;
        let u8 second=base(source,s)?;
        if(second!=1 && second!=2) {return .err(errors::make(3,s.begin));}
        tag=if (first==1) {if(second==1) {5} else {6}} else {if(second==1) {7} else {8}};
    }
    let usize close=lexer::punctuation(source,s,62)?;
    return .ok(tag);
}
