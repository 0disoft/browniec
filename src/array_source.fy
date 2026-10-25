module array_source;

import lexer as lexer;
import locals as locals;
import ir as ir;
import cells as cells;
import errors as errors;

// Local binding values 128..143 denote private array catalog IDs, never scalar
// registers. Arrays are confined to the entry function's lexical scopes.
pub fn bool binding(ref locals::Table table, usize index) {
    return index < table.count && table.registers[index] >= 128;
}
// Fixed shape is part of the binding's type, not mutable payload state.
pub fn Result<usize, errors::Error> length_value(ref mut ir::Program p, usize id, usize offset) {
    if (id >= 16 || id >= p.arrays.count || p.arrays.lengths[id] < 1 || p.arrays.lengths[id] > 4096) {
        return .err(errors::make(3, offset));
    }
    let i64 length = cells::pack(p.arrays.lengths[id], offset)?;
    return ir::integer(p, length, 12, offset);
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
    var usize pc = 0;
    while (pc < p.count && pc < 256) {
        if (p.code[pc * 8] == 34 || p.code[pc * 8] == 38) { return 3; }
        pc += 1;
    }
    var usize i = 0;
    while (i < p.arrays.count && i < 16) {
        if (p.arrays.mutable[i]) { return 2; }
        i += 1;
    }
    return if (p.arrays.count != 0) { 1 } else { 0 };
}
pub fn Result<usize, errors::Error> copy(ref mut ir::Program p, usize source, u8 tag, usize length, bool mutable, usize offset) {
    if (source >= 16 || source >= p.arrays.count || p.arrays.elements[source] != tag ||
        p.arrays.lengths[source] != length) { return .err(errors::make(3, offset)); }
    let usize id = ir::array(p, tag, length, mutable, offset)?;
    let usize copied = ir::array_copy(p, id, source, offset)?;
    return .ok(id);
}
pub fn Result<usize, errors::Error> count(ref u8[] source, ref mut lexer::State s) {
    if (s.kind != 1 || s.value < 1 || s.value > 4096) { return .err(errors::make(3, s.begin)); }
    let usize value = cells::unpack(s.value, s.begin)?;
    let usize next = lexer::next(source, s)?;
    return .ok(value);
}
pub fn Result<usize, errors::Error> assign(ref mut ir::Program p, usize destination, usize source, usize offset) {
    if (destination >= 16 || source >= 16 || destination >= p.arrays.count || source >= p.arrays.count ||
        !p.arrays.mutable[destination] || p.arrays.elements[destination] != p.arrays.elements[source] ||
        p.arrays.lengths[destination] != p.arrays.lengths[source]) { return .err(errors::make(3, offset)); }
    return ir::array_assign(p, destination, source, offset);
}
pub fn Result<usize, errors::Error> length(ref u8[] source, ref mut lexer::State s) {
    let usize open = lexer::punctuation(source, s, 91)?;
    let usize size = count(source, s)?;
    let usize close = lexer::punctuation(source, s, 93)?;
    return .ok(size);
}
pub fn Result<usize, errors::Error> release_visible(ref locals::Table table, ref mut ir::Program p, usize offset) {
    return release_from(table, p, 0, offset);
}
// A transfer releases exactly the suffix whose lexical scopes it exits.
pub fn Result<usize, errors::Error> release_from(ref locals::Table table, ref mut ir::Program p, usize first, usize offset) {
    var usize i = table.count;
    var usize dropped = 0;
    while (i > first) {
        i -= 1;
        if (binding(table, i)) {
            let usize drop = ir::array_drop(p, table.registers[i] - 128, offset)?;
            dropped += 1;
        }
    }
    return .ok(dropped);
}
