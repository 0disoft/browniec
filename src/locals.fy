module locals;

import lexer as lexer;
import errors as errors;

// Active lexical bindings. Names are spans in the immutable source snapshot.
// Immutable bindings refer to values; var bindings refer to stable typed slots.
pub struct Table {
    usize[64] begins;
    usize[64] ends;
    usize[64] registers;
    bool[64] mutable;
    usize count;
}
pub fn Table empty() {
    return Table { .begins = [0; 64], .ends = [0; 64], .registers = [0; 64],
        .mutable = [false; 64], .count = 0 };
}
pub fn bool reserved(ref u8[] name) {
    return lexer::equal(name, b"module") || lexer::equal(name, b"import") ||
        lexer::equal(name, b"fn") || lexer::equal(name, b"return") ||
        lexer::equal(name, b"let") || lexer::equal(name, b"var") ||
        lexer::equal(name, b"if") || lexer::equal(name, b"else") ||
        lexer::equal(name, b"while") || lexer::equal(name, b"for") ||
        lexer::equal(name, b"switch") || lexer::equal(name, b"case") ||
        lexer::equal(name, b"break") || lexer::equal(name, b"continue") ||
        lexer::equal(name, b"ref") || lexer::equal(name, b"mut") ||
        lexer::equal(name, b"true") || lexer::equal(name, b"false") ||
        lexer::equal(name, b"null") || lexer::equal(name, b"pub") ||
        lexer::equal(name, b"struct") || lexer::equal(name, b"enum") ||
        lexer::equal(name, b"resource") || lexer::equal(name, b"unsafe") ||
        lexer::equal(name, b"extern") || lexer::equal(name, b"as") ||
        lexer::equal(name, b"i32") || lexer::equal(name, b"i64") ||
        lexer::equal(name, b"u8") || lexer::equal(name, b"u32") ||
        lexer::equal(name, b"usize") || lexer::equal(name, b"bool") ||
        lexer::equal(name, b"_");
}
pub fn usize find(ref u8[] source, ref Table table, usize begin, usize end) {
    var usize i = 0;
    while (i < table.count) {
        if (lexer::equal(source[begin..end], source[table.begins[i]..table.ends[i]])) { return i; }
        i += 1;
    }
    return 64;
}
pub fn Result<usize, errors::Error> declare(ref mut Table table, usize begin, usize end, usize register, bool mutable) {
    if (table.count >= 64) { return .err(errors::make(4, begin)); }
    let usize index = table.count;
    table.begins[index] = begin;
    table.ends[index] = end;
    table.registers[index] = register;
    table.mutable[index] = mutable;
    table.count += 1;
    return .ok(index);
}
