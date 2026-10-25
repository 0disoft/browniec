module compiler;

import errors as errors;
import lexer as lexer;
import ir as ir;
import locals as locals;
import functions as functions;
import types as types;
import loops as loops;
import patterns as patterns;
import propagation as propagation;
import casts as casts;
import array_source as arrays;
import array_call_source as array_calls;
import std::text as text;

fn u8 precedence(u8 kind) {
    if (kind == 133) { return 1; }
    if (kind == 132) { return 2; }
    if (kind == 124) { return 3; }
    if (kind == 94) { return 4; }
    if (kind == 38) { return 5; }
    if (kind == 128 || kind == 129) { return 6; }
    if (kind == 60 || kind == 62 || kind == 130 || kind == 131) { return 7; }
    if (kind == 134 || kind == 135) { return 8; }
    if (kind == 43 || kind == 45) { return 9; }
    if (kind == 42 || kind == 47 || kind == 37) { return 10; }
    return 0;
}
fn u8 opcode(u8 kind) {
    if (kind == 134) { return 31; }
    if (kind == 135) { return 32; }
    if (kind == 38) { return 28; }
    if (kind == 94) { return 29; }
    if (kind == 124) { return 30; }
    if (kind == 128) { return 11; }
    if (kind == 129) { return 12; }
    if (kind == 60) { return 13; }
    if (kind == 130) { return 14; }
    if (kind == 62) { return 15; }
    if (kind == 131) { return 16; }
    if (kind == 43) { return 2; }
    if (kind == 45) { return 3; }
    if (kind == 42) { return 4; }
    if (kind == 47) { return 5; }
    return 6;
}
fn Result<usize, errors::Error> operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    let usize at = s.begin;
    if(word_is(source,s,b"switch")) {
        return switch_value(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state);
    }
    if (s.kind == 46) {
        if (!types::tagged(expected)) {return .err(errors::make(3,at));}
        let usize dot=lexer::next(source,s)?;
        let bool positive=word_is(source,s,b"some") || word_is(source,s,b"ok");
        if (expected<=4) {
            if (!word_is(source,s,b"some") && !word_is(source,s,b"none")) {return .err(errors::make(3,at));}
        } else if (!word_is(source,s,b"ok") && !word_is(source,s,b"err")) {return .err(errors::make(3,at));}
        let u8 variant=if(positive) {1} else {0};
        let u8 payload_type=types::payload(expected,variant);
        let usize name=lexer::next(source,s)?;
        var usize value=0;
        if (payload_type!=0) {
            let usize open=lexer::punctuation(source,s,40)?;
            value=expression(source,s,p,table,signatures,1,depth+1,payload_type,result_type,structure,loop_state)?;
            if (p.types[value]!=payload_type) {return .err(errors::make(3,at));}
            let usize close=lexer::punctuation(source,s,41)?;
        }
        return ir::construct(p,expected,variant,value,at);
    }
    if (s.kind == 45 || s.kind == 33 || s.kind == 126) {
        let bool negative = s.kind == 45;
        let bool complement = s.kind == 126;
        if(negative && types::unsigned(expected)) {return .err(errors::make(3,at));}
        let usize advanced = lexer::next(source, s)?;
        // Admit a minimum signed literal without constructing its positive magnitude.
        if (negative && s.kind == 1 && s.min_magnitude) {
            if (expected!=9) {return .err(errors::make(3,at));}
            let usize advanced_min=lexer::next(source,s)?;
            return ir::integer(p,-9223372036854775808,9,at);
        }
        if (negative && s.kind == 1 && s.value == 2147483648 && expected!=9) {
            let usize advanced_min = lexer::next(source, s)?;
            return ir::literal(p, -2147483648, at);
        }
        let usize operand = primary(source,s,p,table,signatures,depth + 1,expected,result_type,structure,loop_state)?;
        if ((negative && !types::signed(p.types[operand])) || (complement && !types::integer(p.types[operand])) ||
            (!negative && !complement && p.types[operand]!=2)) { return .err(errors::make(3, at)); }
        return ir::emit(p, if (negative) { 7 } else if(complement) {27} else { 10 }, operand, 0, at);
    }
    if (s.kind == 1) {
        let u8 tag=if(types::integer(expected)) {expected} else {1};
        if(!types::unsigned(tag) && s.value<0) {return .err(errors::make(3,at));}
        let i64 value = s.value;
        let usize advanced = lexer::next(source, s)?;
        return ir::integer(p, value, tag, at);
    }
    if (s.kind == 2) {
        if (word_is(source, s, b"true") || word_is(source, s, b"false")) {
            let bool value = word_is(source, s, b"true");
            let usize advanced = lexer::next(source, s)?;
            return ir::boolean(p, value, at);
        }
        if (locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, at)); }
        let usize begin = s.begin;
        let usize end = s.end;
        let usize index = locals::find(source, table, begin, end);
        let usize advanced = lexer::next(source, s)?;
        if (s.kind == 40) {
            if (index != 64) { return .err(errors::make(3, at)); }
            let usize target = functions::find(source, signatures, begin, end);
            if (target == 16) { return .err(errors::make(3, at)); }
            let usize open = lexer::next(source, s)?;
            var usize[8] arguments = [0; 8];
            var locals::Table names = locals::snapshot(table);
            var usize arity = 0;
            while (s.kind != 41) {
                if (arity >= 8) { return .err(errors::make(4, s.begin)); }
                let u8 argument_type=if(arity<signatures.arities[target]) {signatures.param_types[target*8+arity]} else {0};
                let usize length=if(arity<signatures.arities[target]){signatures.param_lengths[target*8+arity]}else{0};
                if(length!=0) {
                    arguments[arity]=array_calls::capture(source,s,p,ref mut names,argument_type,length)?;
                } else {
                    arguments[arity] = expression(source,s,p,ref names,signatures,1,depth + 1,argument_type,result_type,structure,loop_state)?;
                    if (arity >= signatures.arities[target] || p.types[arguments[arity]] != signatures.param_types[target * 8 + arity]) { return .err(errors::make(3, at)); }
                }
                arity += 1;
                if (s.kind == 41) { break; }
                let usize comma = lexer::punctuation(source, s, 44)?;
                if (s.kind == 41) { return .err(errors::make(2, s.begin)); }
            }
            if (arity != signatures.arities[target]) { return .err(errors::make(3, at)); }
            let usize close = lexer::punctuation(source, s, 41)?;
            let ref usize[] view = ref arguments;
            let usize called=ir::call(p, target, view[..arity], at)?;
            let usize dropped=arrays::release_from(ref names,p,table.count,at)?;
            return .ok(called);
        }
        if (index == 64) { return .err(errors::make(3, at)); }
        let usize register = table.registers[index];
        if (arrays::binding(table, index)) {
            if (s.kind == 46) {
                let usize dot = lexer::next(source, s)?;
                if (!word_is(source, s, b"len")) { return .err(errors::make(3, s.begin)); }
                let usize member = lexer::next(source, s)?;
                return arrays::length_value(p, register - 128, at);
            }
            if (s.kind != 91) { return .err(errors::make(3, at)); }
            let usize open = lexer::punctuation(source, s, 91)?;
            let usize subscript = expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?;
            if (p.types[subscript] != 12) { return .err(errors::make(3, at)); }
            let usize close = lexer::punctuation(source, s, 93)?;
            return ir::array_read(p, register - 128, subscript, at);
        }
        if (s.kind == 91) { return .err(errors::make(3, at)); }
        if (p.slots[register]) { return ir::emit(p, 17, register, 0, at); }
        return .ok(register);
    }
    if (s.kind == 40) {
        let usize advanced = lexer::next(source, s)?;
        let usize result = expression(source,s,p,table,signatures,1,depth + 1,expected,result_type,structure,loop_state)?;
        let usize closed = lexer::punctuation(source, s, 41)?;
        return .ok(result);
    }
    return .err(errors::make(2, s.begin));
}
// Postfix propagation binds before unary and binary operators. The operand
// parser recurses through primary for unary operators, preserving that order.
fn Result<usize, errors::Error> primary(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    var usize value=operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state)?;
    while(s.kind==63) {
        let usize at=s.begin;
        let usize next=lexer::next(source,s)?;
        value=propagation::lower(p,table,value,result_type,at)?;
    }
    return .ok(value);
}
// Casts bind after unary/postfix work and before every binary operator.
fn Result<usize,errors::Error> converted(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,usize depth,u8 expected,u8 result_type, usize structure, ref mut loops::State loop_state) {
    let bool explicit=casts::follows(source,s)?;
    let u8 context=if(explicit) {0} else {expected};
    var usize value=primary(source,s,p,table,signatures,depth,context,result_type,structure,loop_state)?;
    while(word_is(source,s,b"as")) {
        let usize at=s.begin;
        let usize keyword=lexer::next(source,s)?;
        let u8 target=types::parse(source,s)?;
        value=ir::widen(p,value,target,at)?;
    }
    return .ok(value);
}
fn Result<usize, errors::Error> expression(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, u8 minimum, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    var usize left = converted(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state)?;
    while (precedence(s.kind) >= minimum) {
        let u8 kind = s.kind;
        let u8 level = precedence(s.kind);
        let u8 operation = opcode(s.kind);
        let usize at = s.begin;
        let usize advanced = lexer::next(source, s)?;
        if (kind == 132 || kind == 133) {
            if (p.types[left] != 2) { return .err(errors::make(3, at)); }
            let usize slot = ir::slot(p, 2, at)?;
            let usize initial = ir::raw(p, 18, slot, left, 0, at)?;
            let usize jump = ir::raw(p, if (kind == 132) { 20 } else { 21 }, 0, left, 0, at)?;
            let usize right = expression(source,s,p,table,signatures,level + 1,depth + 1,expected,result_type,structure,loop_state)?;
            if (p.types[right] != 2) { return .err(errors::make(3, at)); }
            let usize stored = ir::raw(p, 18, slot, right, 0, at)?;
            let usize target = p.count;
            let usize patched = ir::patch(p, jump, target, at)?;
            left = ir::emit(p, 17, slot, 0, at)?;
            continue;
        }
        let u8 context=p.types[left];
        let usize right = expression(source,s,p,table,signatures,level + 1,depth + 1,context,result_type,structure,loop_state)?;
        if (!types::scalar(p.types[left]) || p.types[left] != p.types[right] || ((operation < 11 || operation > 12) && !types::integer(p.types[left]))) { return .err(errors::make(3, at)); }
        left = ir::emit(p, operation, left, right, at)?;
    }
    return .ok(left);
}

fn bool word_is(ref u8[] source, ref lexer::State s, ref u8[] word) {
    return s.kind == 2 && lexer::equal(source[s.begin..s.end], word);
}

fn Result<usize, errors::Error> statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    if (word_is(source, s, b"let") || word_is(source, s, b"var")) {
        let bool mutable = word_is(source, s, b"var");
        let usize keyword = lexer::next(source, s)?;
        let u8 tag = types::parse(source, s)?;
        let usize length = if (s.kind == 91) { arrays::length(source, s)? } else { 0 };
        if (length != 0 && (result_type == 0 ||
            terminator != 59 || !types::scalar(tag))) { return .err(errors::make(3, s.begin)); }
        if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) {
            return .err(errors::make(2, s.begin));
        }
        let usize begin = s.begin;
        let usize end = s.end;
        if (locals::find(source, table, begin, end) != 64) { return .err(errors::make(3, begin)); }
        if (table.count >= 64) { return .err(errors::make(4, begin)); }
        let usize name = lexer::next(source, s)?;
        let usize equals = lexer::punctuation(source, s, 61)?;
        if (length != 0 && s.kind == 2) {
            let usize source_index = locals::find(source, table, s.begin, s.end);
            if (!arrays::binding(table, source_index)) { return .err(errors::make(3, s.begin)); }
            let usize source_id = table.registers[source_index] - 128;
            let usize next = lexer::next(source, s)?;
            let usize finished = lexer::punctuation(source, s, terminator)?;
            let usize id = arrays::copy(p, table.function, source_id, tag, length, mutable, begin)?;
            return locals::declare(table, begin, end, 128 + id, mutable);
        }
        if (length != 0) { let usize open = lexer::punctuation(source, s, 91)?; }
        // The new name is not visible until its initializer has been checked.
        let usize value = expression(source,s,p,table,signatures,1,expr_depth,tag,result_type,structure,loop_state)?;
        if (p.types[value] != tag) { return .err(errors::make(3, begin)); }
        if (length != 0) {
            let usize separator = lexer::punctuation(source, s, 59)?;
            let usize repeated = arrays::count(source, s)?;
            if (repeated != length) { return .err(errors::make(3, begin)); }
            let usize close = lexer::punctuation(source, s, 93)?;
            let usize finished = lexer::punctuation(source, s, terminator)?;
            let usize id = ir::array_in(p, table.function, tag, length, mutable, begin)?;
            let usize init = ir::array_init(p, id, value, begin)?;
            return locals::declare(table, begin, end, 128 + id, mutable);
        }
        let usize end_statement = lexer::punctuation(source, s, terminator)?;
        var usize binding = value;
        if (mutable) {
            binding = ir::slot(p, tag, begin)?;
            let usize stored = ir::raw(p, 18, binding, value, 0, begin)?;
        }
        return locals::declare(table, begin, end, binding, mutable);
    }
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) {
        return .err(errors::make(2, s.begin));
    }
    let usize at = s.begin;
    let usize index = locals::find(source, table, s.begin, s.end);
    if (index == 64 || !table.mutable[index]) { return .err(errors::make(3, at)); }
    let usize target = lexer::next(source, s)?;
    if (arrays::binding(table, index)) {
        // For headers remain scalar-only; never use an array binding as a
        // scalar register in the header/post validation paths.
        if (result_type == 0) { return .err(errors::make(3, at)); }
        let usize id = table.registers[index] - 128;
        if (s.kind == 61) {
            let usize equals = lexer::next(source, s)?;
            if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
            let usize origin = locals::find(source, table, s.begin, s.end);
            if (!arrays::binding(table, origin)) { return .err(errors::make(3, s.begin)); }
            let usize source_id = table.registers[origin] - 128;
            let usize next = lexer::next(source, s)?;
            let usize end_statement = lexer::punctuation(source, s, terminator)?;
            let usize assigned = arrays::assign(p, id, source_id, at)?;
            return .ok(index);
        }
        if (s.kind != 91) { return .err(errors::make(3, at)); }
        let usize open = lexer::punctuation(source, s, 91)?;
        let usize subscript = expression(source,s,p,table,signatures,1,expr_depth+1,12,result_type,structure,loop_state)?;
        if (p.types[subscript] != 12) { return .err(errors::make(3, at)); }
        let usize close = lexer::punctuation(source, s, 93)?;
        let usize equals = lexer::punctuation(source, s, 61)?;
        let u8 element = p.arrays.elements[id];
        let usize value = expression(source,s,p,table,signatures,1,expr_depth,element,result_type,structure,loop_state)?;
        if (p.types[value] != element) { return .err(errors::make(3, at)); }
        let usize end_statement = lexer::punctuation(source, s, terminator)?;
        let usize written = ir::array_write(p, id, subscript, value, at)?;
        return .ok(index);
    }
    let usize equals = lexer::punctuation(source, s, 61)?;
    let u8 target_type=p.types[table.registers[index]];
    let usize value = expression(source,s,p,table,signatures,1,expr_depth,target_type,result_type,structure,loop_state)?;
    if (p.types[value] != target_type) { return .err(errors::make(3, at)); }
    let usize end_statement = lexer::punctuation(source, s, terminator)?;
    let usize stored = ir::raw(p, 18, table.registers[index], value, 0, at)?;
    return .ok(index);
}

// Value arms have a private binding table; assignments still address the
// original outer var slots. Their final expression has no trailing semicolon.
struct Yield {usize value; bool terminal;}
fn Result<Yield,errors::Error> value_arm(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,usize depth,u8 expected,u8 result_type, usize structure, ref mut loops::State loop_state) {
    if(depth>32 || structure>32) {return .err(errors::make(4,s.begin));}
    let usize brace=lexer::punctuation(source,s,123)?;
    let usize outer=table.count;
    while(true) {
        var bool regular=word_is(source,s,b"let") || word_is(source,s,b"var");
        if(!regular && s.kind==2 && !locals::reserved(source[s.begin..s.end])) {
            var lexer::State look=lexer::snapshot(s);
            let usize next=lexer::next(source,ref mut look)?;
            regular=look.kind==61 || (look.kind==91 && arrays::indexed_assignment(source, ref look)?);
        }
        // A leading switch remains the final expression. Wrap a statement
        // switch in a standalone block to make that statement intent explicit.
        let bool structured=s.kind==123 || word_is(source,s,b"if") || word_is(source,s,b"while") ||
            word_is(source,s,b"for") || word_is(source,s,b"return") ||
            word_is(source,s,b"break") || word_is(source,s,b"continue");
        if(!regular && !structured) {break;}
        let bool terminal=control(source,s,p,table,signatures,result_type,structure,depth,loop_state)?;
        if(terminal) {
            let usize close=lexer::punctuation(source,s,125)?;
            return .ok(Yield {.value=0,.terminal=true});
        }
    }
    let usize value=expression(source,s,p,table,signatures,1,depth,expected,result_type,structure,loop_state)?;
    let usize dropped=arrays::release_from(table,p,outer,s.begin)?;
    let usize close=lexer::punctuation(source,s,125)?;
    return .ok(Yield {.value=value,.terminal=false});
}
fn Result<usize,errors::Error> switch_value(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,usize depth,u8 expected,u8 result_type, usize structure, ref mut loops::State loop_state) {
    let usize at=s.begin;
    if(depth>30 || structure>30) {return .err(errors::make(4,at));}
    // Statement-bearing arms are excluded from the pure for-header subset.
    if(result_type==0) {return .err(errors::make(3,at));}
    let usize keyword=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;
    let usize subject=expression(source,s,p,table,signatures,1,depth+1,0,result_type,structure+1,loop_state)?;
    let u8 tag=p.types[subject];
    if(!types::tagged(tag)) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize brace=lexer::punctuation(source,s,123)?;
    var usize slot=128;
    var usize[2] skips=[256;2];
    var usize previous=256;
    var u8 first_variant=2;
    var usize arm=0;
    while(arm<2) {
        if(s.kind==125) {return .err(errors::make(3,at));}
        let patterns::Pattern pattern=patterns::parse(source,s,tag)?;
        if(arm==1 && pattern.variant==first_variant) {return .err(errors::make(3,at));}
        if(arm==0) {first_variant=pattern.variant;}
        else {
            let usize target=p.count;
            let usize next=ir::patch(p,previous,target,at)?;
        }
        let ir::Case branch=ir::branch_case(p,subject,pattern.variant,at)?;
        var locals::Table names=locals::snapshot(table);
        if(pattern.binding) {
            if(locals::find(source,ref names,pattern.begin,pattern.end)!=64) {return .err(errors::make(3,pattern.begin));}
            let usize binding=locals::declare(ref mut names,pattern.begin,pattern.end,branch.payload,false)?;
        }
        let u8 context=if(slot==128) {expected} else {p.types[slot]};
        let Yield yield=value_arm(source,s,p,ref mut names,signatures,depth+2,context,result_type,structure+2,loop_state)?;
        if(!yield.terminal) {
            if(slot==128) {
                let u8 tag=p.types[yield.value];
                slot=ir::slot(p,tag,at)?;
            }
            else if(p.types[yield.value]!=p.types[slot]) {return .err(errors::make(3,at));}
            let usize stored=ir::raw(p,18,slot,yield.value,0,at)?;
            skips[arm]=ir::raw(p,19,0,0,0,at)?;
        }
        previous=branch.instruction;
        arm+=1;
    }
    let usize end=lexer::punctuation(source,s,125)?;
    if(slot==128) {return .err(errors::make(3,at));}
    let usize failure=ir::raw(p,25,0,0,0,at)?;
    let usize guarded=ir::patch(p,previous,failure,at)?;
    let usize target=p.count;
    arm=0;
    while(arm<2) {
        if(skips[arm]!=256) {let usize skip=ir::patch(p,skips[arm],target,at)?;}
        arm+=1;
    }
    return ir::emit(p,17,slot,0,at);
}

// Validate the post clause before the body (body locals are not visible), then
// rewind only its appended IR. Re-emission after the body preserves source order.
// A dead post is still type checked, but consumes no runtime registers or Fuel.
fn Result<usize, errors::Error> checked_post(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    let usize at=s.begin;
    if (word_is(source,s,b"let") || word_is(source,s,b"var")) {return .err(errors::make(2,at));}
    let usize code=p.count;
    let usize registers=p.registers;
    let usize constants=p.constant_count;
    let usize calls=p.call_count;
    let usize post=statement(source,s,p,table,signatures,41,0,expr_depth,structure,loop_state)?;
    if (p.call_count!=calls || !types::scalar(p.types[table.registers[post]])) {return .err(errors::make(3,at));}
    var usize r=registers;
    while(r<p.registers) {p.slots[r]=false; p.types[r]=0; r+=1;}
    p.count=code; p.registers=registers; p.constant_count=constants;
    return .ok(post);
}

fn Result<bool, errors::Error> block(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    let usize open = lexer::punctuation(source, s, 123)?;
    let usize outer = table.count;
    var bool terminal = false;
    while (s.kind != 125) {
        if (s.kind == 0 || terminal) { return .err(errors::make(2, s.begin)); }
        terminal = control(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state)?;
    }
    if (!terminal) { let usize dropped = arrays::release_from(table, p, outer, s.begin)?; }
    table.count = outer;
    let usize close = lexer::next(source, s)?;
    return .ok(terminal);
}
fn Result<bool, errors::Error> control(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    let usize at = s.begin;
    if (word_is(source,s,b"break") || word_is(source,s,b"continue")) {
        let bool leave=word_is(source,s,b"break");
        let usize keyword=lexer::next(source,s)?;
        let usize end=lexer::punctuation(source,s,59)?;
        if (loop_state.depth == 0) { return .err(errors::make(2,at)); }
        let usize dropped=arrays::release_from(table,p,loop_state.bindings[loop_state.depth-1],at)?;
        let usize jump=loops::transfer(loop_state,p,leave,at)?;
        return .ok(true);
    }
    if (word_is(source,s,b"switch")) {
        let usize keyword=lexer::next(source,s)?;
        let usize open=lexer::punctuation(source,s,40)?;
        let usize subject=expression(source,s,p,table,signatures,1,expr_depth,0,result_type,depth,loop_state)?;
        let u8 tag=p.types[subject];
        if(!types::tagged(tag)) {return .err(errors::make(3,at));}
        let usize close=lexer::punctuation(source,s,41)?;
        let usize brace=lexer::punctuation(source,s,123)?;
        var usize[2] skips=[256;2];
        var usize previous=256;
        var u8 first_variant=2;
        var bool terminal=true;
        var usize arm=0;
        while(arm<2) {
            if(s.kind==125) {return .err(errors::make(3,at));}
            let patterns::Pattern pattern=patterns::parse(source,s,tag)?;
            if(arm==1 && pattern.variant==first_variant) {return .err(errors::make(3,at));}
            if(arm==0) {first_variant=pattern.variant;}
            else {
                let usize next=p.count;
                let usize patched=ir::patch(p,previous,next,at)?;
            }
            let ir::Case branch=ir::branch_case(p,subject,pattern.variant,at)?;
            let usize outer=table.count;
            if(pattern.binding) {
                if(locals::find(source,table,pattern.begin,pattern.end)!=64) {return .err(errors::make(3,pattern.begin));}
                let usize binding=locals::declare(table,pattern.begin,pattern.end,branch.payload,false)?;
            }
            let bool stopped=block(source,s,p,table,signatures,result_type,depth+2,expr_depth,loop_state)?;
            table.count=outer;
            terminal=terminal && stopped;
            if(!stopped) {skips[arm]=ir::raw(p,19,0,0,0,at)?;}
            previous=branch.instruction;
            arm+=1;
        }
        let usize end=lexer::punctuation(source,s,125)?;
        let usize failure=p.count;
        let usize trap=ir::raw(p,25,0,0,0,at)?;
        let usize patched=ir::patch(p,previous,failure,at)?;
        let usize target=p.count;
        arm=0;
        while(arm<2) {
            if(skips[arm]!=256) {let usize skip=ir::patch(p,skips[arm],target,at)?;}
            arm+=1;
        }
        return .ok(terminal);
    }
    if (word_is(source,s,b"for")) {
        let usize outer=table.count;
        let usize keyword=lexer::next(source,s)?;
        let usize open=lexer::punctuation(source,s,40)?;
        let usize calls=p.call_count;
        if (s.kind==59) {let usize empty=lexer::next(source,s)?;}
        else {
            let usize init=statement(source,s,p,table,signatures,59,0,expr_depth,depth,loop_state)?;
            if (!types::scalar(p.types[table.registers[init]])) {return .err(errors::make(3,at));}
        }
        let usize head=p.count;
        let usize condition=if (s.kind==59) {ir::boolean(p,true,at)?}
            else {expression(source,s,p,table,signatures,1,expr_depth,2,0,depth,loop_state)?};
        if (p.types[condition]!=2 || p.call_count!=calls) {return .err(errors::make(3,at));}
        let usize separator=lexer::punctuation(source,s,59)?;
        let usize exit=ir::raw(p,20,0,condition,0,at)?;
        let bool has_post=s.kind!=41;
        let usize post_start=s.begin;
        if (has_post) {let usize validated=checked_post(source,s,p,table,signatures,expr_depth,depth,loop_state)?;}
        else {let usize empty=lexer::next(source,s)?;}
        let usize level=loops::enter(loop_state,head,true,at)?;
        loop_state.bindings[level]=table.count;
        let bool stopped=block(source,s,p,table,signatures,result_type,depth+1,expr_depth,loop_state)?;
        let usize post_target=p.count;
        let usize continues=loops::resolve(loop_state,p,false,post_target,at)?;
        if (!stopped || continues!=0) {
            if (has_post) {
                var lexer::State post=lexer::empty();
                post.cursor=post_start;
                let usize first=lexer::next(source,ref mut post)?;
                let usize emitted=statement(source,ref mut post,p,table,signatures,41,0,expr_depth,depth,loop_state)?;
            }
            let usize back=ir::raw(p,22,0,head,0,at)?;
        }
        let usize target=p.count;
        let usize branch=ir::patch(p,exit,target,at)?;
        let usize breaks=loops::resolve(loop_state,p,true,target,at)?;
        loop_state.depth-=1; table.count=outer;
        return .ok(false);
    }
    if (word_is(source,s,b"while")) {
        let usize keyword=lexer::next(source,s)?;
        let usize open=lexer::punctuation(source,s,40)?;
        let usize head=p.count;
        let usize level=loops::enter(loop_state,head,false,at)?;
        loop_state.bindings[level]=table.count;
        let usize condition=expression(source,s,p,table,signatures,1,expr_depth,2,result_type,depth,loop_state)?;
        if (p.types[condition]!=2) {return .err(errors::make(3,at));}
        let usize close=lexer::punctuation(source,s,41)?;
        let usize exit=ir::raw(p,20,0,condition,0,at)?;
        let bool stopped=block(source,s,p,table,signatures,result_type,depth+1,expr_depth,loop_state)?;
        if (!stopped) {let usize back=ir::raw(p,22,0,head,0,at)?;}
        let usize target=p.count;
        let usize branch=ir::patch(p,exit,target,at)?;
        let usize breaks=loops::resolve(loop_state,p,true,target,at)?;
        loop_state.depth-=1;
        return .ok(false);
    }
    if (word_is(source, s, b"return")) {
        let usize keyword = lexer::next(source, s)?;
        let usize value = expression(source,s,p,table,signatures,1,expr_depth,result_type,result_type,depth,loop_state)?;
        if (p.types[value] != result_type) { return .err(errors::make(3, at)); }
        let usize end = lexer::punctuation(source, s, 59)?;
        let usize dropped = arrays::release_visible(table, p, at)?;
        let usize returned = ir::emit(p, 8, value, 0, at)?;
        return .ok(true);
    }
    if (word_is(source, s, b"if")) {
        let usize keyword = lexer::next(source, s)?;
        let usize open = lexer::punctuation(source, s, 40)?;
        let usize condition = expression(source,s,p,table,signatures,1,expr_depth,2,result_type,depth,loop_state)?;
        if (p.types[condition] != 2) { return .err(errors::make(3, at)); }
        let usize close = lexer::punctuation(source, s, 41)?;
        let usize branch = ir::raw(p, 20, 0, condition, 0, at)?;
        let bool then_returns = block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state)?;
        if (word_is(source, s, b"else")) {
            var usize skip = 256;
            if (!then_returns) { skip = ir::raw(p, 19, 0, 0, 0, at)?; }
            let usize else_start = p.count;
            let usize patched = ir::patch(p, branch, else_start, at)?;
            let usize else_word = lexer::next(source, s)?;
            let bool else_returns = if (word_is(source, s, b"if")) {
                control(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state)?
            } else { block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state)? };
            if (skip != 256) {
                let usize continuation = p.count;
                let usize skipped = ir::patch(p, skip, continuation, at)?;
            }
            return .ok(then_returns && else_returns);
        }
        let usize continuation = p.count;
        let usize patched = ir::patch(p, branch, continuation, at)?;
        return .ok(false);
    }
    if (s.kind == 123) { return block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state); }
    let usize regular = statement(source,s,p,table,signatures,59,result_type,expr_depth,depth,loop_state)?;
    return .ok(false);
}

fn Result<usize, errors::Error> body(ref u8[] source, ref functions::Table signatures, usize f, ref mut ir::Program p) {
    var locals::Table table = locals::empty();
    table.function = f;
    let usize arity = signatures.arities[f];
    if (p.registers + arity > 128) { return .err(errors::make(4, signatures.begins[f])); }
    let usize start = p.count;
    let usize registers_start = p.registers;
    p.starts[f] = start;
    p.register_starts[f] = registers_start;
    p.arities[f] = arity;
    var usize i = 0;
    while (i < arity) {
        let usize at = f * 8 + i;
        let usize parameter = array_calls::bind(signatures,at,p,ref mut table)?;
        i += 1;
    }
    var lexer::State s = lexer::empty();
    s.cursor = signatures.bodies[f];
    let usize first = lexer::next(source, ref mut s)?;
    var loops::State loop_state=loops::empty();
    var bool terminal = false;
    while (s.kind != 125) {
        if (terminal || s.kind == 0) { return .err(errors::make(2, s.begin)); }
        terminal = control(source,ref mut s,p,ref mut table,signatures,signatures.return_types[f],0,0,ref mut loop_state)?;
    }
    if (!terminal) { return .err(errors::make(2, s.begin)); }
    if (s.kind != 125 || s.begin != signatures.body_ends[f]) { return .err(errors::make(2, s.begin)); }
    let usize end = p.count;
    let usize registers_end = p.registers;
    p.ends[f] = end;
    p.register_ends[f] = registers_end;
    return .ok(f);
}

pub fn Result<ir::Program, errors::Error> compile(ref u8[] source) {
    if (source.len > 4096) { return .err(errors::make(4, 4096)); }
    let ref str valid = switch (text::validate_utf8(source)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(1, 0)); }
    };
    var functions::Table signatures = functions::scan(source)?;
    // Result shape metadata must never be mistaken for an executable scalar.
    // Reject every array result before lowering any body or parameter catalog.
    var usize result = 0;
    while (result < signatures.count) {
        if (signatures.return_lengths[result] != 0) {
            return .err(errors::make(3, signatures.begins[result]));
        }
        result += 1;
    }
    var ir::Program p = ir::empty();
    p.function_count = signatures.count;
    p.entry = signatures.entry;
    p.return_types = signatures.return_types;
    let usize parameters=array_calls::prepare(ref mut signatures,ref mut p)?;
    var usize f = 0;
    while (f < signatures.count) {
        let usize emitted = body(source, ref signatures, f, ref mut p)?;
        f += 1;
    }
    // Preserve the current source/IR restriction on entry calls in array programs.
    if (p.arrays.count != 0) {
        var usize pc = 0;
        while (pc < p.count) {
            if (p.code[pc * 8] == 9 && p.code[pc * 8 + 2] as usize == p.entry) {
                return .err(errors::make(3, p.offsets[pc]));
            }
            pc += 1;
        }
    }
    return .ok(p);
}
