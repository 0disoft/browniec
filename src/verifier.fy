module verifier;

import errors as errors;
import ir as ir;
import types as types;
import array_meta as arrays;
import struct_meta as records;
import struct_verifier as struct_verifier;
import array_verifier as array_verifier;
import slice_verifier as slice_verifier;
import slice_parameters as slice_parameters;
import array_parameters as array_parameters;
import array_results as array_results;
import register_set as registers;
import struct_parameters as struct_parameters;
import struct_results as struct_results;

fn bool readable(ref ir::Program p, ref registers::Set defined, usize r, usize start, usize end) {
    return r >= start && r < end && !p.slots[r] && p.array_parameters[r] == 0 && p.record_parameters[r] == 0 && p.slice_parameters[r] == 0 && registers::contains(defined, r);
}
fn bool merge(ref mut usize[] states, ref mut bool[] seen, ref registers::Set defined, usize target, ref mut usize[] array_states, usize live) {
    if (seen[target] && array_states[target] != live) { return false; }
    array_states[target] = live;
    let usize low = states[target * 2];
    let usize high = states[target * 2 + 1];
    states[target * 2] = if (seen[target]) { low & defined.low } else { defined.low };
    states[target * 2 + 1] = if (seen[target]) { high & defined.high } else { defined.high };
    seen[target] = true;
    return true;
}
fn Result<usize, errors::Error> function(ref ir::Program p, usize f, ref records::Prepared shapes, ref mut bool[] used_calls) {
    let usize start = p.register_starts[f];
    let usize end = p.register_ends[f];
    let usize arity = p.arities[f];
    var usize[512] states = [0; 512];
    var bool[256] seen = [false; 256];
    var usize[256] array_states = [0; 256];
    var registers::Set written = registers::empty();
    var registers::Set defined = registers::empty();
    var usize i = start;
    while (i < end) {
        if (p.record_parameters[i] == 0 && p.slice_parameters[i] == 0 && !types::valid(p.types[i])) { return .err(errors::make(5, p.starts[f])); }
        if (i < start + arity) {
            if (p.slots[i]) { return .err(errors::make(5, p.starts[f])); }
            registers::insert(ref mut written, i);
            if (p.array_parameters[i] == 0 && p.record_parameters[i] == 0 && p.slice_parameters[i] == 0) { registers::insert(ref mut defined, i); }
        }
        i += 1;
    }
    let usize borrowed_entry = slice_parameters::initial(p, f)?;
    let bool entered = merge(ref mut states, ref mut seen, ref defined, p.starts[f], ref mut array_states, array_parameters::initial(p, f) | struct_parameters::initial(p, f) | borrowed_entry);
    var usize pc = p.starts[f];
    // Solve the forward graph, then check each backedge preserves its target's
    // entry invariant. This bounded inductive proof needs no cyclic worklist.
    while (pc < p.ends[f]) {
        if (!seen[pc]) { return .err(errors::make(5, pc)); }
        defined = registers::Set { .low = states[pc * 2], .high = states[pc * 2 + 1] };
        var usize live = array_states[pc];
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if (op < 1 || op > 60 || (op != 52 && ((op!=24 && op!=47 && op!=49 && op!=53 && op!=59 && p.code[at + 4] != 0) ||
            (op!=47 && p.code[at + 5] != 0) || p.code[at + 6] != 0 || p.code[at + 7] != 0))) { return .err(errors::make(5, pc)); }
        if (op==25) {
            if(dst!=0 || a!=0 || b!=0) {return .err(errors::make(5,pc));}
            pc+=1; continue;
        }
        if (op==24) {
            let usize target=p.code[at+4] as usize;
            if(!readable(p,ref defined,a,start,end) || !types::tagged(p.types[a]) || b>1 || target<=pc || target>=p.ends[f]) {return .err(errors::make(5,pc));}
            let u8 tag=types::payload(p.types[a],p.code[at+3]);
            if(tag==0) {if(dst!=0) {return .err(errors::make(5,pc));}}
            else if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written, dst) || p.types[dst]!=tag) {return .err(errors::make(5,pc));}
            // The mismatch path receives no payload definition.
            if (!merge(ref mut states,ref mut seen,ref defined,target,ref mut array_states,live)) {return .err(errors::make(5,pc));}
            if(tag!=0) {registers::insert(ref mut defined, dst);registers::insert(ref mut written, dst);}
            if(pc+1>=p.ends[f]) {return .err(errors::make(5,pc));}
            if (!merge(ref mut states,ref mut seen,ref defined,pc+1,ref mut array_states,live)) {return .err(errors::make(5,pc));}
            pc+=1; continue;
        }
        if(op==50) {
            if(dst!=0 || b!=0) {return .err(errors::make(5,pc));}
            let usize returned=struct_results::returned(p,a,f,live,pc)?;
            pc+=1;continue;
        }
        if(op==39) {
            if(dst!=0 || b!=0) {return .err(errors::make(5,pc));}
            let usize returned=array_results::returned(p,a,f,live,pc)?;
            pc+=1;continue;
        }
        if (op == 8) {
            if(p.array_results[f]!=0 || p.record_results[f]!=0) {return .err(errors::make(5,pc));}
            if (live != 0 || dst != 0 || b != 0 || !readable(p, ref defined, a, start, end)) { return .err(errors::make(5, pc)); }
            if (p.types[a] != p.return_types[f]) { return .err(errors::make(5, pc)); }
            pc += 1; continue;
        }
        if (op == 22) {
            if (dst != 0 || b != 0 || a < p.starts[f] || a >= pc || !seen[a] || live != array_states[a]) { return .err(errors::make(5, pc)); }
            if ((states[a * 2] & defined.low) != states[a * 2] ||
                (states[a * 2 + 1] & defined.high) != states[a * 2 + 1]) { return .err(errors::make(5, pc)); }
            pc+=1; continue;
        }
        if (op >= 54) {
            live = slice_verifier::step(p, pc, f, ref mut defined, ref mut written, live)?;
        } else if(op==9 && a<p.function_count && (p.array_results[a]!=0 || p.record_results[a]!=0)) {
            if(b>=p.call_count || used_calls[b] || a==p.entry || p.call_arities[b] as usize!=p.arities[a]) {return .err(errors::make(5,pc));}
            let usize checked=array_parameters::arguments(p,a,b,f,ref defined,live,pc)?;
            live=if(p.record_results[a]!=0){struct_results::call(p,a,dst,f,live,pc)?}
                else{array_results::call(p,a,dst,f,live,pc)?};
            used_calls[b]=true;
        } else if (op >= 41 && op!=51 && op!=52 && op!=53) {
            live = struct_verifier::step(p, shapes, pc, f, ref mut defined, ref mut written, live)?;
        } else if (op >= 33) {
            live = array_verifier::step(p, pc, f, ref mut defined, ref mut written, live)?;
        } else if (op >= 19 && op <= 21) {
            let usize target = if (op == 19) { a } else { b };
            if (dst != 0 || target <= pc || target >= p.ends[f]) { return .err(errors::make(5, pc)); }
            if (op == 19) {
                if (b != 0) { return .err(errors::make(5, pc)); }
            } else {
                if (!readable(p, ref defined, a, start, end) || p.types[a] != 2) { return .err(errors::make(5, pc)); }
            }
            if (!merge(ref mut states, ref mut seen, ref defined, target, ref mut array_states, live)) {return .err(errors::make(5,pc));}
            if (op == 19) { pc += 1; continue; }
        } else if (op == 18) {
            if (dst < start || dst >= end || !p.slots[dst] || b != 0 || !readable(p, ref defined, a, start, end)) { return .err(errors::make(5, pc)); }
            if (p.types[dst] != p.types[a]) { return .err(errors::make(5, pc)); }
            registers::insert(ref mut defined, dst); registers::insert(ref mut written, dst);
        } else {
            if (dst < start || dst >= end || p.slots[dst] || registers::contains(ref written, dst)) { return .err(errors::make(5, pc)); }
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
                if (a >= p.function_count || b >= p.call_count || used_calls[b] || ((p.arrays.count != 0 || p.records.count != 0) && a == p.entry)) { return .err(errors::make(5, pc)); }
                let usize count = p.call_arities[b] as usize;
                if (count != p.arities[a] || count > 8 || p.types[dst] != p.return_types[a]) { return .err(errors::make(5, pc)); }
                let usize checked = array_parameters::arguments(p, a, b, f, ref defined, live, pc)?;
                used_calls[b] = true;
            } else if (op == 17) {
                if (a < start || a >= end || !p.slots[a] || !registers::contains(ref defined, a) || b != 0) { return .err(errors::make(5, pc)); }
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
            registers::insert(ref mut defined, dst); registers::insert(ref mut written, dst);
        }
        if (pc + 1 >= p.ends[f]) { return .err(errors::make(5, pc)); }
        if (!merge(ref mut states, ref mut seen, ref defined, pc + 1, ref mut array_states, live)) {return .err(errors::make(5,pc));}
        pc += 1;
    }
    i = start;
    while (i < end) { if (!registers::contains(ref written, i)) { return .err(errors::make(5, pc)); } i += 1; }
    return .ok(end - start);
}

fn Result<usize, errors::Error> validate(ref ir::Program p) {
    if (p.count == 0 || p.count > 256 || p.registers == 0 || p.registers > 128 || p.constant_count > 128 ||
        p.function_count == 0 || p.function_count > 16 || p.entry >= p.function_count || p.call_count > 32) { return .err(errors::make(5, 0)); }
    if (!arrays::valid(ref p.arrays)) { return .err(errors::make(5, 0)); }
    let records::Prepared shapes = records::prepare(ref p.records)?;
    var usize id = 0;
    while (id < 16) {
        if ((id < p.arrays.count && p.array_functions[id] as usize >= p.function_count) ||
            (id >= p.arrays.count && p.array_functions[id] != 0) ||
            (id < p.records.count && p.record_functions[id] as usize >= p.function_count) ||
            (id >= p.records.count && p.record_functions[id] != 0)) { return .err(errors::make(5, 0)); }
        if (p.slice_roots[id] as usize > p.arrays.count) { return .err(errors::make(5, 0)); }
        id += 1;
    }
    if (p.arities[p.entry] != 0 || p.return_types[p.entry] != 1) { return .err(errors::make(5, 0)); }
    var usize f = 0;
    var usize code_end = 0;
    var usize register_end = 0;
    while (f < p.function_count) {
        if (p.record_results[f]==0 && !types::valid(p.return_types[f])) { return .err(errors::make(5, code_end)); }
        if (p.starts[f] != code_end || p.ends[f] <= code_end || p.ends[f] > p.count ||
            p.register_starts[f] != register_end || p.register_ends[f] < register_end ||
            p.register_ends[f] > p.registers || p.arities[f] > 8 ||
            p.arities[f] > p.register_ends[f] - register_end) { return .err(errors::make(5, code_end)); }
        code_end = p.ends[f]; register_end = p.register_ends[f]; f += 1;
    }
    if (code_end != p.count || register_end != p.registers) { return .err(errors::make(5, 0)); }
    let usize borrowed_parameters = slice_parameters::metadata(p)?;
    let usize parameters = array_parameters::metadata(p)?;
    let usize record_parameters = struct_parameters::metadata(p)?;
    let usize results = array_results::metadata(p)?;
    let usize record_results = struct_results::metadata(p)?;
    var bool[32] used_calls = [false; 32];
    f = 0;
    while (f < p.function_count) { let usize checked = function(p, f, ref shapes, ref mut used_calls)?; f += 1; }
    var usize call = 0;
    while (call < p.call_count) { if (!used_calls[call]) { return .err(errors::make(5, 0)); } call += 1; }
    return .ok(p.count);
}

// Inspection and public admission share the complete IR/dataflow proof for
// every supported readonly and owned exclusive scalar slice element.
pub fn Result<usize, errors::Error> inspect(ref ir::Program p) {
    return validate(p);
}
pub fn Result<usize, errors::Error> verify(ref ir::Program p) {
    let usize checked=validate(p)?;
    // Owned mutable slices stay public. Rootless mutable formals still require
    // a checked CALL handoff/restore protocol before VM allocation or dispatch.
    var usize site=0;
    while(site<16) {
        if(p.slice_roots[site]==0 && ir::exclusive(p,site)) { return .err(errors::make(5,0)); }
        site+=1;
    }
    return .ok(checked);
}
