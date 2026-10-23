module verifier;

import errors as errors;
import ir as ir;
import types as types;

fn bool readable(ref ir::Program p, ref bool[] defined, usize r, usize start, usize end) {
    return r >= start && r < end && !p.slots[r] && defined[r];
}
fn void merge(ref mut usize[] states, ref mut bool[] seen, ref bool[] defined, usize target, usize start, usize end) {
    var usize r = start;
    while (r < end) {
        let usize cell = target * 2 + r / 64;
        let usize one = 1;
        let usize mask = one << (r % 64);
        let usize old = states[cell];
        let bool initialized = defined[r] && (!seen[target] || (old & mask) != 0);
        states[cell] = if (initialized) { old | mask } else { old & (18446744073709551615 ^ mask) };
        r += 1;
    }
    seen[target] = true;
}
fn Result<usize, errors::Error> function(ref ir::Program p, usize f, ref mut bool[] used_calls) {
    let usize start = p.register_starts[f];
    let usize end = p.register_ends[f];
    let usize arity = p.arities[f];
    var usize[512] states = [0; 512];
    var bool[256] seen = [false; 256];
    var bool[128] written = [false; 128];
    var bool[128] defined = [false; 128];
    var usize i = start;
    while (i < end) {
        if (!types::valid(p.types[i])) { return .err(errors::make(5, p.starts[f])); }
        if (i < start + arity) {
            if (p.slots[i]) { return .err(errors::make(5, p.starts[f])); }
            written[i] = true; defined[i] = true;
        }
        i += 1;
    }
    merge(ref mut states, ref mut seen, ref defined, p.starts[f], start, end);
    var usize pc = p.starts[f];
    // Solve the forward graph, then check each backedge preserves its target's
    // entry invariant. This bounded inductive proof needs no cyclic worklist.
    while (pc < p.ends[f]) {
        if (!seen[pc]) { return .err(errors::make(5, pc)); }
        i = start;
        while (i < end) {
            let usize one = 1;
            let usize mask = one << (i % 64);
            defined[i] = (states[pc * 2 + i / 64] & mask) != 0;
            i += 1;
        }
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if (op < 1 || op > 32 || (op!=24 && p.code[at + 4] != 0) || p.code[at + 5] != 0 || p.code[at + 6] != 0 || p.code[at + 7] != 0) { return .err(errors::make(5, pc)); }
        if (op==25) {
            if(dst!=0 || a!=0 || b!=0) {return .err(errors::make(5,pc));}
            pc+=1; continue;
        }
        if (op==24) {
            let usize target=p.code[at+4] as usize;
            if(!readable(p,ref defined,a,start,end) || !types::tagged(p.types[a]) || b>1 || target<=pc || target>=p.ends[f]) {return .err(errors::make(5,pc));}
            let u8 tag=types::payload(p.types[a],p.code[at+3]);
            if(tag==0) {if(dst!=0) {return .err(errors::make(5,pc));}}
            else if(dst<start || dst>=end || p.slots[dst] || written[dst] || p.types[dst]!=tag) {return .err(errors::make(5,pc));}
            // The mismatch path receives no payload definition.
            merge(ref mut states,ref mut seen,ref defined,target,start,end);
            if(tag!=0) {defined[dst]=true;written[dst]=true;}
            if(pc+1>=p.ends[f]) {return .err(errors::make(5,pc));}
            merge(ref mut states,ref mut seen,ref defined,pc+1,start,end);
            pc+=1; continue;
        }
        if (op == 8) {
            if (dst != 0 || b != 0 || !readable(p, ref defined, a, start, end)) { return .err(errors::make(5, pc)); }
            if (p.types[a] != p.return_types[f]) { return .err(errors::make(5, pc)); }
            pc += 1; continue;
        }
        if (op == 22) {
            if (dst != 0 || b != 0 || a < p.starts[f] || a >= pc || !seen[a]) { return .err(errors::make(5, pc)); }
            i=start;
            while (i<end) {
                let usize one=1;
                let usize mask=one << (i % 64);
                if ((states[a*2+i/64] & mask)!=0 && !defined[i]) { return .err(errors::make(5,pc)); }
                i+=1;
            }
            pc+=1; continue;
        }
        if (op >= 19 && op <= 21) {
            let usize target = if (op == 19) { a } else { b };
            if (dst != 0 || target <= pc || target >= p.ends[f]) { return .err(errors::make(5, pc)); }
            if (op == 19) {
                if (b != 0) { return .err(errors::make(5, pc)); }
            } else {
                if (!readable(p, ref defined, a, start, end) || p.types[a] != 2) { return .err(errors::make(5, pc)); }
            }
            merge(ref mut states, ref mut seen, ref defined, target, start, end);
            if (op == 19) { pc += 1; continue; }
        } else if (op == 18) {
            if (dst < start || dst >= end || !p.slots[dst] || b != 0 || !readable(p, ref defined, a, start, end)) { return .err(errors::make(5, pc)); }
            if (p.types[dst] != p.types[a]) { return .err(errors::make(5, pc)); }
            defined[dst] = true; written[dst] = true;
        } else {
            if (dst < start || dst >= end || p.slots[dst] || written[dst]) { return .err(errors::make(5, pc)); }
            if (op == 1) {
                if (!types::scalar(p.types[dst])) { return .err(errors::make(5,pc)); }
                if (a >= p.constant_count || b != 0) { return .err(errors::make(5, pc)); }
                if (types::integer(p.types[dst]) && !types::fits(p.types[dst],p.constants[a])) { return .err(errors::make(5, pc)); }
                if (p.types[dst] == 2 && p.constants[a] != 0 && p.constants[a] != 1) { return .err(errors::make(5, pc)); }
            } else if (op == 26) {
                if(b!=0 || !readable(p,ref defined,a,start,end) || !types::widening(p.types[a],p.types[dst])) {return .err(errors::make(5,pc));}
            } else if (op == 23) {
                if (!types::tagged(p.types[dst]) || b>1) {return .err(errors::make(5,pc));}
                let u8 tag=types::payload(p.types[dst],p.code[at + 3]);
                if (tag==0) {if(a!=0) {return .err(errors::make(5,pc));}}
                else if (!readable(p,ref defined,a,start,end) || p.types[a]!=tag) {return .err(errors::make(5,pc));}
            } else if (op == 9) {
                if (a >= p.function_count || b >= p.call_count || used_calls[b]) { return .err(errors::make(5, pc)); }
                let usize count = p.call_arities[b] as usize;
                if (count != p.arities[a] || count > 8 || p.types[dst] != p.return_types[a]) { return .err(errors::make(5, pc)); }
                var usize arg = 0;
                while (arg < 8) {
                    let usize r = p.call_args[b * 8 + arg] as usize;
                    if (arg < count) {
                        if (!readable(p, ref defined, r, start, end)) { return .err(errors::make(5, pc)); }
                        if (p.types[r] != p.types[p.register_starts[a] + arg]) { return .err(errors::make(5, pc)); }
                    } else if (r != 0) { return .err(errors::make(5, pc)); }
                    arg += 1;
                }
                used_calls[b] = true;
            } else if (op == 17) {
                if (a < start || a >= end || !p.slots[a] || !defined[a] || b != 0) { return .err(errors::make(5, pc)); }
                if (p.types[dst] != p.types[a]) { return .err(errors::make(5, pc)); }
            } else {
                if (!readable(p, ref defined, a, start, end)) { return .err(errors::make(5, pc)); }
                if (op == 7 || op == 10 || op == 27) {
                    let u8 expected = if (op == 7 || op == 27) { p.types[a] } else { 2 };
                    if(op==7 && !types::signed(expected)) {return .err(errors::make(5,pc));}
                    if(op==27 && !types::integer(expected)) {return .err(errors::make(5,pc));}
                    if (b != 0 || p.types[a] != expected || p.types[dst] != expected) { return .err(errors::make(5, pc)); }
                } else {
                    if (!readable(p, ref defined, b, start, end)) { return .err(errors::make(5, pc)); }
                    if (!types::scalar(p.types[a]) || p.types[a] != p.types[b] || p.types[dst] != if (op >= 11 && op <= 16) { 2 } else { p.types[a] }) { return .err(errors::make(5, pc)); }
                    if (op != 11 && op != 12 && !types::integer(p.types[a])) { return .err(errors::make(5, pc)); }
                }
            }
            defined[dst] = true; written[dst] = true;
        }
        if (pc + 1 >= p.ends[f]) { return .err(errors::make(5, pc)); }
        merge(ref mut states, ref mut seen, ref defined, pc + 1, start, end);
        pc += 1;
    }
    i = start;
    while (i < end) { if (!written[i]) { return .err(errors::make(5, pc)); } i += 1; }
    return .ok(end - start);
}

pub fn Result<usize, errors::Error> verify(ref ir::Program p) {
    if (p.count == 0 || p.count > 256 || p.registers == 0 || p.registers > 128 || p.constant_count > 128 ||
        p.function_count == 0 || p.function_count > 16 || p.entry >= p.function_count || p.call_count > 32) { return .err(errors::make(5, 0)); }
    if (p.arities[p.entry] != 0 || p.return_types[p.entry] != 1) { return .err(errors::make(5, 0)); }
    var usize f = 0;
    var usize code_end = 0;
    var usize register_end = 0;
    while (f < p.function_count) {
        if (!types::valid(p.return_types[f])) { return .err(errors::make(5, code_end)); }
        if (p.starts[f] != code_end || p.ends[f] <= code_end || p.ends[f] > p.count ||
            p.register_starts[f] != register_end || p.register_ends[f] < register_end ||
            p.register_ends[f] > p.registers || p.arities[f] > 8 ||
            p.arities[f] > p.register_ends[f] - register_end) { return .err(errors::make(5, code_end)); }
        code_end = p.ends[f]; register_end = p.register_ends[f]; f += 1;
    }
    if (code_end != p.count || register_end != p.registers) { return .err(errors::make(5, 0)); }
    var bool[32] used_calls = [false; 32];
    f = 0;
    while (f < p.function_count) { let usize checked = function(p, f, ref mut used_calls)?; f += 1; }
    var usize call = 0;
    while (call < p.call_count) { if (!used_calls[call]) { return .err(errors::make(5, 0)); } call += 1; }
    return .ok(p.count);
}
