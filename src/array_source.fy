module array_source;

import lexer as lexer;
import locals as locals;
import ir as ir;
import cells as cells;
import errors as errors;

// Local binding values 128..143 denote private array catalog IDs, never scalar
// registers. Arrays are currently confined to the entry function's outer scope.
pub fn bool binding(ref locals::Table table, usize index) {
    return index < table.count && table.registers[index] >= 128;
}
// Called with the opening '[' after a possible statement target. Nested index
// expressions may contain brackets, switches, and semicolons; only '=' after
// the matching ']' distinguishes an assignment from a final value-arm read.
pub fn Result<bool, errors::Error> indexed_assignment(ref u8[] source, ref lexer::State state) {
    var lexer::State look = lexer::snapshot(state);
    var usize depth = 0;
    while (look.kind != 0) {
        if (look.kind == 91) { depth += 1; }
        else if (look.kind == 93) {
            if (depth == 0) { return .ok(false); }
            depth -= 1;
            if (depth == 0) {
                let usize next = lexer::next(source, ref mut look)?;
                return .ok(look.kind == 61);
            }
        }
        let usize next = lexer::next(source, ref mut look)?;
    }
    return .ok(false);
}
pub fn u8 profile(ref ir::Program p) {
    var usize i = 0;
    while (i < p.arrays.count) {
        if (p.arrays.mutable[i]) { return 2; }
        i += 1;
    }
    return if (p.arrays.count != 0) { 1 } else { 0 };
}
pub fn Result<usize, errors::Error> count(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 1 || s.value < 1 || s.value > 4096) { return .err(errors::make(3, s.begin)); }
    let usize value = cells::unpack(s.value, s.begin)?;
    let usize next = lexer::next(source, s)?;
    return .ok(value);
}
pub fn Result<usize, errors::Error> length(ref u8[] source, ref mut lexer::State s) {
    let usize open = lexer::punctuation(source, s, 91)?;
    let usize size = count(source, s)?;
    let usize close = lexer::punctuation(source, s, 93)?;
    return .ok(size);
}
pub fn Result<usize, errors::Error> release_visible(ref locals::Table table, ref mut ir::Program p, usize offset) {
    var usize i = table.count;
    var usize dropped = 0;
    while (i > 0) {
        i -= 1;
        if (binding(table, i)) {
            let usize drop = ir::array_drop(p, table.registers[i] - 128, offset)?;
            dropped += 1;
        }
    }
    return .ok(dropped);
}
