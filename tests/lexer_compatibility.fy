module tests::lexer_compatibility;

import lexer as lexer;
import errors as errors;

fn usize advance(ref u8[] source, ref mut lexer::State s) {
    return switch (lexer::next(source, s)) {
        case .ok(value): { value }
        case .err(_): { assert(false); 0 }
    };
}

fn errors::Error failure(ref u8[] source, ref mut lexer::State s) {
    return switch (lexer::next(source, s)) {
        case .ok(_): { assert(false); errors::make(0, 0) }
        case .err(error): { error }
    };
}

fn void token(ref u8[] source, ref mut lexer::State s, u8 kind, usize begin, usize end) {
    assert(advance(source, s) == 0);
    assert(s.kind == kind && s.begin == begin && s.end == end);
}

fn void lexical_error(ref u8[] source, ref mut lexer::State s, usize offset) {
    let errors::Error error = failure(source, s);
    assert(error.kind == 1 && error.offset == offset);
}

@test
fn void leading_bom_is_trivia_only_at_source_offset_zero() {
    var lexer::State s = lexer::empty();
    token(b"\xef\xbb\xbfmodule main", ref mut s, 2, 3, 9);
    token(b"\xef\xbb\xbfmodule main", ref mut s, 2, 10, 14);
    token(b"\xef\xbb\xbfmodule main", ref mut s, 0, 14, 14);
    assert(s.tokens == 3);

    var lexer::State bom_only = lexer::empty();
    token(b"\xef\xbb\xbf", ref mut bom_only, 0, 3, 3);

    var lexer::State misplaced = lexer::empty();
    token(b"a\xef\xbb\xbfb", ref mut misplaced, 2, 0, 1);
    lexical_error(b"a\xef\xbb\xbfb", ref mut misplaced, 1);

    var lexer::State commented = lexer::empty();
    lexical_error(b"/*\xef\xbb\xbf*/a", ref mut commented, 2);
}

@test
fn void lf_and_crlf_keep_raw_source_offsets_while_lone_cr_is_rejected() {
    var lexer::State s = lexer::empty();
    token(b"a\nb\r\nc", ref mut s, 2, 0, 1);
    token(b"a\nb\r\nc", ref mut s, 2, 2, 3);
    token(b"a\nb\r\nc", ref mut s, 2, 5, 6);

    var lexer::State outside = lexer::empty();
    token(b"a\rb", ref mut outside, 2, 0, 1);
    lexical_error(b"a\rb", ref mut outside, 1);

    var lexer::State line = lexer::empty();
    lexical_error(b"//a\rb", ref mut line, 3);

    var lexer::State block = lexer::empty();
    lexical_error(b"/*a\rb*/", ref mut block, 3);

    var lexer::State comments = lexer::empty();
    token(b"// x\r\n/* y\r\n */module", ref mut comments, 2, 15, 21);
}

@test
fn void raw_nul_is_rejected_inside_and_outside_comments_at_the_original_byte() {
    var lexer::State root = lexer::empty();
    lexical_error(b"\x00a", ref mut root, 0);

    var lexer::State line = lexer::empty();
    lexical_error(b"//a\x00b", ref mut line, 3);

    var lexer::State block = lexer::empty();
    lexical_error(b"/*a\x00b*/", ref mut block, 3);
}

@test
fn void nested_block_comments_skip_only_their_complete_byte_spans() {
    var lexer::State s = lexer::empty();
    token(b"/* outer /* inner */ tail */a/*/**/*/b", ref mut s, 2, 28, 29);
    token(b"/* outer /* inner */ tail */a/*/**/*/b", ref mut s, 2, 37, 38);

    var lexer::State line_first = lexer::empty();
    token(b"// /*\nmodule", ref mut line_first, 2, 6, 12);

    var lexer::State unterminated = lexer::empty();
    token(b"a /* outer /* inner", ref mut unterminated, 2, 0, 1);
    lexical_error(b"a /* outer /* inner", ref mut unterminated, 2);
}

@test
fn void existing_token_limit_still_stops_the_1025th_token() {
    var u8[1025] source = [59; 1025];
    var lexer::State s = lexer::empty();
    var usize count = 0;
    while (count < 1024) {
        assert(advance(ref source, ref mut s) == 0 && s.kind == 59);
        count += 1;
    }
    let errors::Error error = failure(ref source, ref mut s);
    assert(error.kind == 4 && error.offset == 1024);
}
