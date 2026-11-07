module place_ir;
import ir as ir;
import errors as errors;
import register_set as registers;
import slice_verifier as slices;
import slice_place_ir as slice_places;
import record_place_ir as record_places;
import struct_meta as records;
import aggregate_place_ir as aggregates;

// Place IDs are a separate sixteen-entry frame-local namespace, never values.
// SELECT 83: dst=place,a=array,b=usize index. READ 84: dst=value,a=place,b=array.
// STORE 85: dst=place,a=array,b=value. END 86: dst=place,a=b=0.
// Byte4 is 0 for arrays, 1 for exclusive slices, 2 for record scalar leaves.
// Kind 2 repeats its scalar ordinal in byte5 and SELECT b=0. END has zero tails.
// Analysis-only kinds3/4 and REPLACE87 use aggregate_place_ir's operand schema.
// Repeating the root/site operand permits ordinary scalar/owner typing; flow below
// independently ties it to the actual SELECT that dominates this use.
pub fn bool operation(u8 op) { return op >= 83 && op <= 87; }
pub fn bool present(ref ir::Program p) {
    var usize pc = 0;
    while (pc < p.count && pc < 256) { if (operation(p.code[pc*8])) { return true; } pc += 1; }
    return false;
}
fn errors::Error invalid(usize pc) { return errors::make(5, pc); }
fn bool value(ref ir::Program p, usize r, usize f, u8 tag) {
    return r >= p.register_starts[f] && r < p.register_ends[f] && !p.slots[r] &&
        p.array_parameters[r] == 0 && p.record_parameters[r] == 0 &&
        p.slice_parameters[r] == 0 && p.types[r] == tag;
}
// Structural checks also run for unreachable place instructions. The caller
// supplies already bounded function/catalog metadata, never compiler claims.
fn Result<usize, errors::Error> metadata(ref ir::Program p, ref records::Prepared shapes, usize pc, usize f) {
    let usize at = pc*8; let u8 op = p.code[at];
    let usize dst = p.code[at+1] as usize; let usize a = p.code[at+2] as usize;
    let usize b = p.code[at+3] as usize;
    let u8 kind=p.code[at+4];
    if(kind>=3){return aggregates::metadata(p,shapes,pc,f);}
    if(kind!=2 && p.code[at+5]!=0){return .err(invalid(pc));}
    var usize i = 6; while (i < 8) { if (p.code[at+i] != 0) { return .err(invalid(pc)); } i += 1; }
    if (op == 86) {
        if (dst >= 16 || a != 0 || b != 0 || kind!=0) { return .err(invalid(pc)); } return .ok(0);
    }
    let usize root = if (op == 84) { b } else { a };
    if(kind>2){return .err(invalid(pc));}
    var u8 element=0;
    if(kind==2){element=record_places::element(p,shapes,root,p.code[at+5] as usize,f,pc)?;}
    else if(kind==1){element=slice_places::element(p,root,f,pc)?;}
    else{
        if (root >= p.arrays.count || root >= 16 || p.array_functions[root] as usize != f ||
            !p.arrays.mutable[root]) { return .err(invalid(pc)); }
        element=p.arrays.elements[root];
    }
    if (op == 83) {
        if (dst >= 16 || pc+1 >= p.ends[f] || if(kind==2){b!=0}else{!value(p,b,f,12)}) { return .err(invalid(pc)); }
    } else if (op == 84) {
        if (a >= 16 || !value(p,dst,f,element)) { return .err(invalid(pc)); }
    } else if (op == 85) {
        if (dst >= 16 || !value(p,b,f,element)) { return .err(invalid(pc)); }
    } else { return .err(invalid(pc)); }
    return .ok(root);
}
// Part of canonical reachable scalar/owner/loan proof, not a substitute for the
// independent identity/lifetime graph. A place READ defines a fresh scalar.
pub fn Result<usize, errors::Error> step(ref ir::Program p, ref records::Prepared shapes, usize pc, usize f,
    ref mut registers::Set defined, ref mut registers::Set written, usize live) {
    if(p.code[pc*8+4]>=3){return aggregates::step(p,shapes,pc,f,defined,live);}
    let usize root = metadata(p,shapes,pc,f)?; let usize at = pc*8; let u8 op = p.code[at];
    if (op == 86) { return .ok(live); }
    let usize one = 1;
    if(p.code[at+4]==2){
        if((live&(one<<(16+root)))==0){return .err(invalid(pc));}
    }else if(p.code[at+4]==1){
        if((live&(one<<(32+root)))==0 || (live&(one<<(48+root)))!=0){return .err(invalid(pc));}
        let usize owner=p.slice_roots[root] as usize;
        if(owner!=0 && (live&(one<<(owner-1)))==0){return .err(invalid(pc));}
    }else if ((live & (one << root)) == 0 || slices::borrowed(p,root,live) ||
        slices::exclusive(p,root,live)) { return .err(invalid(pc)); }
    let usize operand = p.code[at+3] as usize;
    if (op == 85 || (op == 83 && p.code[at+4]!=2)) {
        if (!registers::contains(defined,operand)) { return .err(invalid(pc)); }
    } else if(op==84) {
        let usize dst = p.code[at+1] as usize;
        if (registers::contains(written,dst)) { return .err(invalid(pc)); }
        registers::insert(defined,dst); registers::insert(written,dst);
    }
    return .ok(live);
}

// One byte holds SELECT PC+1 (SELECT cannot be the last instruction, so <=255).
// Two phase bits per place: 0 dead, 1 selected, 2 old scalar read, 3 stored.
pub struct State { u8[16] origins; usize phases; }
fn State empty() { return State { .origins = [0;16], .phases = 0 }; }
fn Result<usize, errors::Error> merge(ref mut u8[] origins, ref mut usize[] phases,
    ref mut bool[] seen, usize target, ref State state, usize pc, bool backedge) {
    if (target >= 256 || (backedge && !seen[target])) { return .err(invalid(pc)); }
    if (seen[target] && phases[target] != state.phases) { return .err(invalid(pc)); }
    var usize i = 0;
    while (i < 16) {
        if (seen[target] && origins[target*16+i] != state.origins[i]) { return .err(invalid(pc)); }
        if (!backedge) { origins[target*16+i] = state.origins[i]; } i += 1;
    }
    if (!backedge) { phases[target] = state.phases; seen[target] = true; }
    return .ok(target);
}
fn Result<usize, errors::Error> function(ref ir::Program p, ref records::Prepared shapes, usize f) {
    var u8[4096] origins = [0;4096]; var usize[256] phases = [0;256];
    var bool[256] seen = [false;256]; seen[p.starts[f]] = true;
    var usize pc = p.starts[f]; var usize count = 0;
    while (pc < p.ends[f]) {
        let usize at = pc*8; let u8 op = p.code[at];
        let usize dst = p.code[at+1] as usize; let usize a = p.code[at+2] as usize;
        let usize b = p.code[at+3] as usize;
        if (operation(op)) { let usize checked = metadata(p,shapes,pc,f)?; }
        if (!seen[pc]) { pc += 1; continue; }
        var State state = empty(); state.phases = phases[pc];
        var usize i = 0; while (i < 16) { state.origins[i] = origins[pc*16+i]; i += 1; }
        if (operation(op)) {
            let usize site = if (op == 84) { a } else { dst };
            let usize phase = (state.phases >> (2*site)) & 3;
            let usize three = 3; let usize mask = three << (2*site);
            if (op == 83) {
                if (phase != 0 || state.origins[site] != 0) { return .err(invalid(pc)); }
                var u8 encoded = 1; var usize n = 0; while (n < pc) { encoded += 1; n += 1; }
                state.origins[site] = encoded; state.phases |= (three-2) << (2*site); count += 1;
            } else {
                if (phase == 0 || state.origins[site] == 0) { return .err(invalid(pc)); }
                let usize selected = (state.origins[site] as usize)-1;
                if(selected>=pc || p.code[selected*8]!=83 || p.code[selected*8+1] as usize!=site){return .err(invalid(pc));}
                if(op!=86){
                    if(p.code[selected*8+4]>=3){if(!aggregates::same_selection(p,selected,pc)){return .err(invalid(pc));}}
                    else if(p.code[selected*8+2] as usize!=if(op==84){b}else{a} ||
                        p.code[selected*8+4]!=p.code[at+4] || p.code[selected*8+5]!=p.code[at+5]){return .err(invalid(pc));}
                }
                if(op==84 && phase!=1){return .err(invalid(pc));}
                if((op==85 || op==87) && phase==3){return .err(invalid(pc));}
                state.phases &= ~mask;
                if (op == 86) { state.origins[site] = 0; }
                else { let usize next = if (op == 84) { 2 } else { 3 }; state.phases |= next << (2*site); }
            }
        } else if (op == 37 || op==45 || op==56 || op==62) {
            i = 0; while (i < 16) {
                if (state.origins[i] != 0){let usize selected=((state.origins[i] as usize)-1)*8;
                    let u8 kind=p.code[selected+4];
                    if(p.code[selected+2] as usize==dst && if(op==37){kind==0 || kind==3}else if(op==45){kind==2 || kind==4}else{kind==1}){return .err(invalid(pc));}
                } i += 1;
            }
        }
        if (op == 8 || op == 39 || op == 50 || op == 65 || op == 79 || op == 82 || op==94 || op==113) {
            if (state.phases != 0) { return .err(invalid(pc)); } pc += 1; continue;
        }
        if (op == 25) { pc += 1; continue; } // Runtime abort drains obligations.
        if (op == 22) {
            let usize checked = merge(ref mut origins,ref mut phases,ref mut seen,a,ref state,pc,true)?;
            pc += 1; continue;
        }
        if (op == 19 || op == 20 || op == 21 || op == 24 || op==92) {
            let usize target = if (op == 19) { a } else if (op == 24 || op==92) { p.code[at+4] as usize } else { b };
            let usize checked = merge(ref mut origins,ref mut phases,ref mut seen,target,ref state,pc,false)?;
            if (op == 19) { pc += 1; continue; }
        }
        if (pc+1 >= p.ends[f]) { return .err(invalid(pc)); }
        let usize checked = merge(ref mut origins,ref mut phases,ref mut seen,pc+1,ref state,pc,false)?;
        pc += 1;
    }
    return .ok(count);
}
// Run after canonical bounds/type/owner proof. Keep the extra graph stack frame
// absent for every pre-existing program that has no place instructions.
pub fn Result<usize, errors::Error> inspect(ref ir::Program p) {
    if (!present(p)) { return .ok(0); }
    return inspect_records(p);
}
fn Result<usize,errors::Error> inspect_records(ref ir::Program p){
    let records::Prepared shapes=records::prepare(ref p.records)?;
    return inspect_prepared(p,ref shapes);
}
// The canonical caller reuses its independently prepared record catalog. This
// graph is analysis only and cannot issue executable admission on its own.
pub fn Result<usize, errors::Error> inspect_prepared(ref ir::Program p,ref records::Prepared shapes) {
    if (!present(p)) { return .ok(0); }
    if (p.count == 0 || p.count > 256 || p.function_count == 0 || p.function_count > 16 ||
        p.arrays.count > 16 || p.records.count>16 || p.registers > 128) { return .err(invalid(0)); }
    var usize f = 0; var usize count = 0;
    while (f < p.function_count) {
        if (p.starts[f] >= p.ends[f] || p.ends[f] > p.count || p.register_starts[f] > p.register_ends[f] ||
            p.register_ends[f] > p.registers) { return .err(invalid(0)); }
        count += function(p,shapes,f)?; f += 1;
    }
    return .ok(count);
}
