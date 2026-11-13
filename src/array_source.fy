module array_source;
import aggregate_copy_source_work as copies;

import lexer as lexer;
import locals as locals;
import ir as ir;
import cells as cells;
import errors as errors;
import place_source as places;
import slice_cleanup_source as slice_cleanup;
import static_source as statics;
import static_builders as static_builders;

// Local binding values 128..143 denote private array catalog IDs, never scalar
// registers. Each binding belongs to its function's lexical scopes.
pub fn bool binding(ref locals::Table table, usize index) {
    return index < table.count && table.registers[index] >= 128 && table.registers[index] < 144;
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
// expressions may contain brackets, switches, and semicolons; an assignment after
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
                return .ok(lexer::assignment(look.kind));
            }
        }
        let usize next = lexer::next(source, ref mut look)?;
    }
    return .ok(false);
}
pub fn u8 profile(ref ir::Program p) {
    if (p.records.count != 0) {
        var usize id = 0;
        while (id < p.records.count && id < 16) {
            let usize record = p.records.records[id] as usize; var usize field = 0;
            while (field < p.records.layouts.fields[record] as usize && field < 16) {
                if (p.records.layouts.kinds[record*16+field] == 1) { return 7; }
                field += 1;
            }
            id += 1;
        }
        var usize at = 0; var bool written = false;
        while (at < p.count && at < 256) {
            let u8 op = p.code[at*8];
            if (op == 42 || op == 46 || op == 48 || op == 49 || ((op==85 || op==87) && p.code[at*8+4]==4)) { return 6; }
            if (op == 44 || (op==85 && p.code[at*8+4]==2)) { written = true; }
            at += 1;
        }
        return if (written) { 5 } else { 4 };
    }
    var usize pc = 0;
    while (pc < p.count && pc < 256) {
        if (p.code[pc * 8] == 34 || p.code[pc * 8] == 38 || (p.code[pc*8]==85 && p.code[pc*8+4]==3)) { return 3; }
        pc += 1;
    }
    var usize i = 0;
    while (i < p.arrays.count && i < 16) {
        if (p.arrays.mutable[i]) { return 2; }
        i += 1;
    }
    return if (p.arrays.count != 0) { 1 } else { 0 };
}
pub fn Result<usize, errors::Error> copy_raw(ref mut ir::Program p, usize function, usize source, u8 tag, usize length, bool mutable, usize offset) {
    if (source >= 16 || source >= p.arrays.count || p.arrays.elements[source] != tag ||
        p.arrays.lengths[source] != length || p.array_functions[source] as usize != function) { return .err(errors::make(3, offset)); }
    let usize id = ir::array_in(p, function, tag, length, mutable, offset)?;
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
pub fn Result<usize,errors::Error> refill(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    usize function,usize id,usize value,usize at) {
    if(id>=p.arrays.count || p.array_functions[id] as usize!=function || !p.arrays.mutable[id] ||
        value>=p.registers || p.types[value]!=p.arrays.elements[id]) {return .err(errors::make(3,at));}
    let usize separator=lexer::punctuation(source,s,59)?;
    let usize repeated=count(source,s)?;
    if(repeated!=p.arrays.lengths[id]) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,93)?;
    let usize end=lexer::punctuation(source,s,59)?;
    return ir::array_fill(p,id,value,at);
}
pub fn Result<usize, errors::Error> length(ref u8[] source, ref mut lexer::State s) {
    let usize open = lexer::punctuation(source, s, 91)?;
    let usize size = count(source, s)?;
    let usize close = lexer::punctuation(source, s, 93)?;
    return .ok(size);
}
pub fn Result<usize, errors::Error> release_visible(ref locals::Table table, ref mut ir::Program p, usize offset) {
    let usize ended=places::release(table,p,0,offset)?;
    return .ok(ended+release_from(table,p,0,offset)?);
}
// A transfer releases exactly the suffix whose lexical scopes it exits.
pub fn Result<usize, errors::Error> release_from(ref locals::Table table, ref mut ir::Program p, usize first, usize offset) {
    var usize i = table.count;
    var usize dropped = 0;
    while (i > first) {
        i -= 1;
        dropped+=release_at(table,p,i,offset)?;
    }
    return .ok(dropped);
}

// Selective capture retention uses the same canonical lexical finalizers.
pub fn Result<usize,errors::Error> release_at(ref locals::Table table,ref mut ir::Program p,usize i,usize offset){
    if(i>=table.count){return .err(errors::make(4,offset));}
    if(statics::binding(table,i)){let usize closed=static_builders::close(p,statics::site(table.registers[i]),offset)?;return .ok(1);}
    if(binding(table,i)){let usize dropped=ir::array_drop(p,table.registers[i]-128,offset)?;return .ok(1);}
    if(table.registers[i]>=160 && table.registers[i]<176){let usize closed=slice_cleanup::close(p,table.registers[i]-160,offset)?;return .ok(1);}
    if(table.registers[i]>=144 && table.registers[i]<160){let usize dropped=ir::record_drop(p,table.registers[i]-144,offset)?;return .ok(1);}
    return .ok(0);
}

pub fn Result<usize,errors::Error> copy(ref mut ir::Program p,usize function,usize source,u8 tag,usize length,bool mutable,usize offset){
    var copies::State w=copies::begin(5,source,0,0,0,function,mutable,false,offset,offset);w.element=tag;w.length=length;
    return copies::clone(p,ref mut w);
}
