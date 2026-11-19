module verifier;

import errors as errors;
import ir as ir;
import types as types;
import array_meta as arrays;
import struct_meta as records;
import struct_verifier as struct_verifier;
import array_verifier as array_verifier;
import array_list_ir as lists;
import slice_parameters as slice_parameters;
import slice_reborrow_ir as reborrows;
import slice_reborrow_call_ir as reborrow_calls;
import slice_reborrow_admission_ir as executable;
import array_parameters as array_parameters;
import array_results as array_results;
import register_set as registers;
import struct_parameters as struct_parameters;
import struct_results as struct_results;
import static_ir as statics;
import static_image as images;
import static_call_ir as image_calls;
import static_call_sites as image_sites;
import reference_lifetimes as reference_lifetimes;
import place_ir as places;
import copy_ir as copying;
import value_ir as value_ir;
import value_flow as value_flow;
import value_view_flow as value_view_flow;
import output_ir as output_ir;

fn bool readable(ref ir::Program p, ref registers::Set defined, usize r, usize start, usize end) {
    return r >= start && r < end && p.types[r]!=0 && !p.slots[r] && p.array_parameters[r] == 0 && p.record_parameters[r] == 0 && p.slice_parameters[r] == 0 && registers::contains(defined, r);
}
fn bool merge(ref mut usize[] states, ref mut bool[] seen, ref registers::Set defined, usize target, ref mut usize[] array_states, usize live, ref mut usize[] static_states, usize static_live) {
    if (seen[target] && (array_states[target] != live || static_states[target] != static_live)) { return false; }
    array_states[target] = live;
    static_states[target] = static_live;
    let usize low = states[target * 2];
    let usize high = states[target * 2 + 1];
    states[target * 2] = if (seen[target]) { low & defined.low } else { defined.low };
    states[target * 2 + 1] = if (seen[target]) { high & defined.high } else { defined.high };
    seen[target] = true;
    return true;
}
fn Result<usize, errors::Error> function(ref ir::Program p, usize f, ref records::Prepared shapes, ref reborrows::Sites loans, ref statics::Sites static_sites, bool allow_reborrow_calls, u8 place_kind, ref mut bool[] used_calls,ref value_ir::Sites value_sites,bool host_profile) {
    let usize start = p.register_starts[f];
    let usize end = p.register_ends[f];
    let usize arity = p.arities[f];
    var usize[512] states = [0; 512];
    var bool[256] seen = [false; 256];
    var usize[256] array_states = [0; 256];
    var usize[256] static_states = [0; 256];
    var registers::Set written = registers::empty();
    var registers::Set defined = registers::empty();
    var usize i = start;
    while (i < end) {
        if (p.record_parameters[i] == 0 && p.slice_parameters[i] == 0 && static_sites.parameters[i]==0 && value_sites.parameters[i]==0 && !types::valid(p.types[i]) && !(host_profile && p.types[i]==14)) { return .err(errors::instruction(p.starts[f])); }
        if (i < start + arity) {
            if (p.slots[i]) { return .err(errors::instruction(p.starts[f])); }
            registers::insert(ref mut written, i);
            if (p.array_parameters[i] == 0 && p.record_parameters[i] == 0 && p.slice_parameters[i] == 0 && static_sites.parameters[i]==0 && value_sites.parameters[i]==0) { registers::insert(ref mut defined, i); }
        }
        i += 1;
    }
    let usize borrowed_entry = slice_parameters::initial(p, f)?;
    let bool entered = merge(ref mut states, ref mut seen, ref defined, p.starts[f], ref mut array_states, array_parameters::initial(p, f) | struct_parameters::initial(p, f) | borrowed_entry, ref mut static_states, 0);
    var usize pc = p.starts[f];
    // Solve the forward graph, then check each backedge preserves its target's
    // entry invariant. This bounded inductive proof needs no cyclic worklist.
    while (pc < p.ends[f]) {
        if (!seen[pc]) { return .err(errors::instruction(pc)); }
        defined = registers::Set { .low = states[pc * 2], .high = states[pc * 2 + 1] };
        var usize live = array_states[pc];
        var usize static_live = static_states[pc];
        let usize at = pc * 8;
        let u8 op = p.code[at];
        let usize dst = p.code[at + 1] as usize;
        let usize a = p.code[at + 2] as usize;
        let usize b = p.code[at + 3] as usize;
        if(host_profile && (op>=118 && op<=121)){
            if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written,dst) ||
                (op!=121 && p.code[at+6]!=0) || p.code[at+7]!=0){return .err(errors::instruction(pc));}
            if(op==119){
                let usize offset=a+256*b;
                let usize length=p.code[at+4] as usize+256*(p.code[at+5] as usize);
                if(p.types[dst]!=14 || offset>p.list_used || length>p.list_used-offset){return .err(errors::instruction(pc));}
            }else if(op==120){
                if(p.types[dst]!=1 || !readable(p,ref defined,a,start,end) || p.types[a]!=14 ||
                    b!=0 || p.code[at+4]!=0 || p.code[at+5]!=0){return .err(errors::instruction(pc));}
            }else{
            let usize count=p.code[at+4] as usize;
            if(count>32 || a>end || count>end-a || (count==0 && a!=0) ||
                (!types::scalar(p.types[dst]) && p.types[dst]!=14) || (op!=121 && p.code[at+5]!=0)){
                return .err(errors::instruction(pc));
            }
            var usize arg=a;
            while(arg<a+count){
                if(!readable(p,ref defined,arg,start,end)){return .err(errors::instruction(pc));}
                arg+=1;
            }
            if(op==121){
                let usize error_dst=p.code[at+5] as usize;
                let usize error_target=p.code[at+6] as usize;
                if(error_target<=pc+1 || error_target>=p.ends[f] || error_dst<start || error_dst>=end ||
                    p.types[error_dst]!=11 || p.slots[error_dst] || error_dst==dst ||
                    registers::contains(ref written,error_dst)){return .err(errors::instruction(pc));}
                var registers::Set error_defined=defined;
                registers::insert(ref mut error_defined,error_dst);registers::insert(ref mut written,error_dst);
                if(!merge(ref mut states,ref mut seen,ref error_defined,error_target,
                    ref mut array_states,live,ref mut static_states,static_live)){return .err(errors::instruction(pc));}
            }
            }
            registers::insert(ref mut defined,dst);registers::insert(ref mut written,dst);
            if(pc+1>=p.ends[f] || !merge(ref mut states,ref mut seen,ref defined,pc+1,
                ref mut array_states,live,ref mut static_states,static_live)){return .err(errors::instruction(pc));}
            pc+=1;continue;
        }
        if(op==116){
            let usize checked=output_ir::inspect(p,static_sites,pc,f,live,static_live)?;
            if(pc+1>=p.ends[f] || !merge(ref mut states,ref mut seen,ref defined,pc+1,
                ref mut array_states,live,ref mut static_states,static_live)){return .err(errors::instruction(pc));}
            pc+=1;continue;
        }
        if(op==78){
            if(!static_sites.call_profile){return .err(errors::instruction(pc));}
            if(a>=p.function_count || a==p.entry || b>=p.call_count || used_calls[b] ||
                p.call_arities[b] as usize!=p.arities[a]){return .err(errors::instruction(pc));}
            if((live>>48)!=0){let usize preserved=reborrow_calls::inspect(p,loans,pc,f,live)?;}
            let usize checked=array_parameters::arguments_static(p,a,b,f,ref defined,live,pc,ref static_sites.parameters)?;
            if(static_sites.results[a]!=0){let usize one=1;
                if(dst>=16 || static_sites.definitions[dst]!=pc || static_sites.functions[dst]!=f ||
                    static_sites.kinds[dst]!=static_sites.results[a] || (static_live&(one<<dst))!=0){return .err(errors::instruction(pc));}
                static_live|=one<<dst;
            }else if(p.array_results[a]!=0 || p.record_results[a]!=0){
                live=if(p.record_results[a]!=0){struct_results::call(p,a,dst,f,live,pc)?}else{array_results::call(p,a,dst,f,live,pc)?};
            }else if(p.return_types[a]==13){
                if(dst!=0){return .err(errors::instruction(pc));}
            }else{
                if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written,dst) ||
                    p.types[dst]!=p.return_types[a] || !types::valid(p.types[dst])){return .err(errors::instruction(pc));}
                registers::insert(ref mut defined,dst);registers::insert(ref mut written,dst);
            }
            used_calls[b]=true;
            if(pc+1>=p.ends[f] || !merge(ref mut states,ref mut seen,ref defined,pc+1,
                ref mut array_states,live,ref mut static_states,static_live)){return .err(errors::instruction(pc));}
            pc+=1;continue;
        }
        if(op==79){let usize one=1;
            if(static_sites.results[f]==0 || live!=0 || a>=16 || static_live!=(one<<a) ||
                static_sites.functions[a]!=f || (static_sites.kinds[a]!=static_sites.results[f] &&
                !(static_sites.results[f]==3 && static_sites.kinds[a]==1))){return .err(errors::instruction(pc));}
            pc+=1;continue;
        }
        if (statics::operation(op)) {
            static_live = statics::step(p, static_sites, pc, f, ref mut defined, ref mut written, static_live)?;
            if (pc + 1 >= p.ends[f] || !merge(ref mut states, ref mut seen, ref defined, pc + 1,
                ref mut array_states, live, ref mut static_states, static_live)) { return .err(errors::instruction(pc)); }
            pc += 1; continue;
        }
        if(value_ir::operation(op)){
            if(!value_sites.enabled){return .err(errors::instruction(pc));}
            if(op==94 || op==113){
                if(live!=0 || static_live!=0 || value_sites.results[f]==0 ||
                    (op==94 && value_sites.results[f]>16) || (op==113 && value_sites.results[f]<17)){return .err(errors::instruction(pc));}
                pc+=1;continue;
            }
            if(op==93 || op==114){
                if(a>=p.function_count || a==p.entry || b>=p.call_count || used_calls[b] ||
                    p.call_arities[b] as usize!=p.arities[a]){return .err(errors::instruction(pc));}
                if((live>>48)!=0){let usize preserved=reborrow_calls::inspect(p,loans,pc,f,live)?;}
                let usize checked=array_parameters::arguments_values(p,a,b,f,ref defined,live,pc,ref value_sites.parameters)?;
                if(value_sites.results[a]!=0){
                    // Independent owner/view CFGs prove the result's separate
                    // namespace. A view result never defines a scalar word.
                }else if(p.array_results[a]!=0 || p.record_results[a]!=0){
                    live=if(p.record_results[a]!=0){struct_results::call(p,a,dst,f,live,pc)?}else{array_results::call(p,a,dst,f,live,pc)?};
                }else if(p.return_types[a]==13){if(dst!=0){return .err(errors::instruction(pc));}}
                else{
                    if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written,dst) ||
                        p.types[dst]!=p.return_types[a] || !types::valid(p.types[dst])){return .err(errors::instruction(pc));}
                    registers::insert(ref mut defined,dst);registers::insert(ref mut written,dst);
                }
                used_calls[b]=true;
            }else if(op==105 || op==106){
                let usize hi=p.code[at+4] as usize;
                if(!readable(p,ref defined,b,start,end) || p.types[b]!=12 ||
                    !readable(p,ref defined,hi,start,end) || p.types[hi]!=12){return .err(errors::instruction(pc));}
            }else if(op==99 || op==100 || op==110 || op==111){
                if(dst<start || dst>=end || p.types[dst]!=if(op==99 || op==110){12}else{10} || p.slots[dst] ||
                    value_sites.parameters[dst]!=0 || p.array_parameters[dst]!=0 ||
                    p.record_parameters[dst]!=0 || p.slice_parameters[dst]!=0 ||
                    registers::contains(ref written,dst)){return .err(errors::instruction(pc));}
                if((op==100 || op==111) && (!readable(p,ref defined,b,start,end) || p.types[b]!=12)){return .err(errors::instruction(pc));}
                registers::insert(ref mut defined,dst);registers::insert(ref mut written,dst);
            }else if(op==101){
                if(!readable(p,ref defined,a,start,end) || p.types[a]!=12 ||
                    !readable(p,ref defined,b,start,end) || p.types[b]!=10){return .err(errors::instruction(pc));}
            }else if(op==102 || op==103){
                if(!readable(p,ref defined,b,start,end) || p.types[b]!=if(op==102){10}else{12}){return .err(errors::instruction(pc));}
            }else if(op==98){
                // The independent typed CFG proved the exact live wrapper and
                // canonical operands. Define one fresh ordinary bool here.
                if(dst<start || dst>=end || p.types[dst]!=2 || p.slots[dst] ||
                    value_sites.parameters[dst]!=0 || p.array_parameters[dst]!=0 ||
                    p.record_parameters[dst]!=0 || p.slice_parameters[dst]!=0 ||
                    registers::contains(ref written,dst)){return .err(errors::instruction(pc));}
                registers::insert(ref mut defined,dst);registers::insert(ref mut written,dst);
            }else if(op==96){
                if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written,dst) ||
                    a>=16 || value_sites.scalar_tags[a]==0 || p.types[dst]!=value_sites.scalar_tags[a]){return .err(errors::instruction(pc));}
                registers::insert(ref mut defined,dst);registers::insert(ref mut written,dst);
            }else if(op==97){
                if(dst>=16 || value_sites.scalar_tags[dst]==0 || !readable(p,ref defined,a,start,end) ||
                    p.types[a]!=value_sites.scalar_tags[dst]){return .err(errors::instruction(pc));}
            }else if(op==92){
                if(!merge(ref mut states,ref mut seen,ref defined,p.code[at+4] as usize,
                    ref mut array_states,live,ref mut static_states,static_live)){return .err(errors::instruction(pc));}
            }
            if(pc+1>=p.ends[f] || !merge(ref mut states,ref mut seen,ref defined,pc+1,
                ref mut array_states,live,ref mut static_states,static_live)){return .err(errors::instruction(pc));}
            pc+=1;continue;
        }
        if ((op == 8 || op == 39 || op == 50 || op==82) && static_live != 0) { return .err(errors::instruction(pc)); }
        if (op < 1 || (op > 62 && op!=80 && op!=81 && op!=82 && !places::operation(op)) || (!places::operation(op) && op != 52 && ((op!=24 && op!=47 && op!=49 && op!=53 && op!=59 && op!=61 && !(op>=83 && op<=85) && p.code[at + 4] != 0) ||
            (op!=47 && !(op>=83 && op<=85 && p.code[at+4]==2) && p.code[at + 5] != 0) || p.code[at + 6] != 0 || p.code[at + 7] != 0))) { return .err(errors::instruction(pc)); }
        // Strict analysis retains its gate; executable proof may admit this CALL.
        if(op==9 && (live>>48)!=0) {
            if(!allow_reborrow_calls){return .err(errors::instruction(pc));}
            let usize preserved=reborrow_calls::inspect(p,loans,pc,f,live)?;
        }
        if (op==25) {
            if(dst!=0 || a!=0 || b!=0) {return .err(errors::instruction(pc));}
            pc+=1; continue;
        }
        if (op==24) {
            let usize target=p.code[at+4] as usize;
            if(!readable(p,ref defined,a,start,end) || !types::tagged(p.types[a]) || b>1 || target<=pc || target>=p.ends[f]) {return .err(errors::instruction(pc));}
            let u8 tag=types::payload(p.types[a],p.code[at+3]);
            if(tag==0) {if(dst!=0) {return .err(errors::instruction(pc));}}
            else if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written, dst) || p.types[dst]!=tag) {return .err(errors::instruction(pc));}
            // The mismatch path receives no payload definition.
            if (!merge(ref mut states,ref mut seen,ref defined,target,ref mut array_states,live,ref mut static_states,static_live)) {return .err(errors::instruction(pc));}
            if(tag!=0) {registers::insert(ref mut defined, dst);registers::insert(ref mut written, dst);}
            if(pc+1>=p.ends[f]) {return .err(errors::instruction(pc));}
            if (!merge(ref mut states,ref mut seen,ref defined,pc+1,ref mut array_states,live,ref mut static_states,static_live)) {return .err(errors::instruction(pc));}
            pc+=1; continue;
        }
        if(op==50) {
            if(dst!=0 || b!=0) {return .err(errors::instruction(pc));}
            let usize returned=struct_results::returned(p,a,f,live,pc)?;
            pc+=1;continue;
        }
        if(op==39) {
            if(dst!=0 || b!=0) {return .err(errors::instruction(pc));}
            let usize returned=array_results::returned(p,a,f,live,pc)?;
            pc+=1;continue;
        }
        if(op==82){
            if(p.return_types[f]!=13 || p.array_results[f]!=0 || p.record_results[f]!=0 ||
                live!=0 || dst!=0 || a!=0 || b!=0){return .err(errors::instruction(pc));}
            pc+=1;continue;
        }
        if (op == 8) {
            if(p.array_results[f]!=0 || p.record_results[f]!=0) {return .err(errors::instruction(pc));}
            if (live != 0 || dst != 0 || b != 0 || !readable(p, ref defined, a, start, end)) { return .err(errors::instruction(pc)); }
            if (p.types[a] != p.return_types[f]) { return .err(errors::instruction(pc)); }
            pc += 1; continue;
        }
        if (op == 22) {
            if (dst != 0 || b != 0 || a < p.starts[f] || a >= pc || !seen[a] || live != array_states[a] || static_live != static_states[a]) { return .err(errors::instruction(pc)); }
            if ((states[a * 2] & defined.low) != states[a * 2] ||
                (states[a * 2 + 1] & defined.high) != states[a * 2 + 1]) { return .err(errors::instruction(pc)); }
            pc+=1; continue;
        }
        if(places::operation(op)){
            if(p.code[at+4]>place_kind){return .err(errors::instruction(pc));}
            let usize checked=places::step(p,shapes,pc,f,ref mut defined,ref mut written,live)?;
        }else if(op==80 || op==81){
            live=array_verifier::step(p,pc,f,ref mut defined,ref mut written,live)?;
        }else if (op >= 54) {
            live = reborrows::step(p, loans, pc, f, ref mut defined, ref mut written, live)?;
        } else if(op==9 && a<p.function_count && p.return_types[a]==13){
            if(dst!=0 || b>=p.call_count || used_calls[b] || a==p.entry || p.call_arities[b] as usize!=p.arities[a]){return .err(errors::instruction(pc));}
            let usize checked=array_parameters::arguments(p,a,b,f,ref defined,live,pc)?;used_calls[b]=true;
        } else if(op==9 && a<p.function_count && (p.array_results[a]!=0 || p.record_results[a]!=0)) {
            if(b>=p.call_count || used_calls[b] || a==p.entry || p.call_arities[b] as usize!=p.arities[a]) {return .err(errors::instruction(pc));}
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
            if (dst != 0 || target <= pc || target >= p.ends[f]) { return .err(errors::instruction(pc)); }
            if (op == 19) {
                if (b != 0) { return .err(errors::instruction(pc)); }
            } else {
                if (!readable(p, ref defined, a, start, end) || p.types[a] != 2) { return .err(errors::instruction(pc)); }
            }
            if (!merge(ref mut states, ref mut seen, ref defined, target, ref mut array_states, live, ref mut static_states, static_live)) {return .err(errors::instruction(pc));}
            if (op == 19) { pc += 1; continue; }
        } else if (op == 18) {
            if (dst < start || dst >= end || !p.slots[dst] || b != 0 || !readable(p, ref defined, a, start, end)) { return .err(errors::instruction(pc)); }
            if (p.types[dst] != p.types[a]) { return .err(errors::instruction(pc)); }
            registers::insert(ref mut defined, dst); registers::insert(ref mut written, dst);
        } else {
            if (dst < start || dst >= end || p.slots[dst] || registers::contains(ref written, dst)) { return .err(errors::instruction(pc)); }
            if (op == 1) {
                if (!types::scalar(p.types[dst])) { return .err(errors::instruction(pc)); }
                if (a >= p.constant_count || b != 0) { return .err(errors::instruction(pc)); }
                if (types::integer(p.types[dst]) && !types::fits(p.types[dst],p.constants[a])) { return .err(errors::instruction(pc)); }
                if (p.types[dst] == 2 && p.constants[a] != 0 && p.constants[a] != 1) { return .err(errors::instruction(pc)); }
            } else if (op == 26) {
                if(b!=0 || !readable(p,ref defined,a,start,end) || !types::widening(p.types[a],p.types[dst])) {return .err(errors::instruction(pc));}
            } else if (op == 23) {
                if (!types::tagged(p.types[dst]) || b>1) {return .err(errors::instruction(pc));}
                let u8 tag=types::payload(p.types[dst],p.code[at + 3]);
                if (tag==0) {if(a!=0) {return .err(errors::instruction(pc));}}
                else if (!readable(p,ref defined,a,start,end) || p.types[a]!=tag) {return .err(errors::instruction(pc));}
            } else if (op == 9) {
                if (a >= p.function_count || b >= p.call_count || used_calls[b] || ((p.arrays.count != 0 || p.records.count != 0) && a == p.entry)) { return .err(errors::instruction(pc)); }
                let usize count = p.call_arities[b] as usize;
                if (count != p.arities[a] || count > 8 || p.types[dst] != p.return_types[a]) { return .err(errors::instruction(pc)); }
                let usize checked = array_parameters::arguments(p, a, b, f, ref defined, live, pc)?;
                used_calls[b] = true;
            } else if (op == 17) {
                if (a < start || a >= end || !p.slots[a] || !registers::contains(ref defined, a) || b != 0) { return .err(errors::instruction(pc)); }
                if (p.types[dst] != p.types[a]) { return .err(errors::instruction(pc)); }
            } else {
                if (!readable(p, ref defined, a, start, end)) { return .err(errors::instruction(pc)); }
                if (op == 7 || op == 10 || op == 27) {
                    let u8 expected = if (op == 7 || op == 27) { p.types[a] } else { 2 };
                    if(op==7 && !types::signed(expected)) {return .err(errors::instruction(pc));}
                    if(op==27 && !types::integer(expected)) {return .err(errors::instruction(pc));}
                    if (b != 0 || p.types[a] != expected || p.types[dst] != expected) { return .err(errors::instruction(pc)); }
                } else {
                    if (!readable(p, ref defined, b, start, end)) { return .err(errors::instruction(pc)); }
                    if (!types::scalar(p.types[a]) || p.types[a] != p.types[b] || p.types[dst] != if (op >= 11 && op <= 16) { 2 } else { p.types[a] }) { return .err(errors::instruction(pc)); }
                    if (op != 11 && op != 12 && !types::integer(p.types[a])) { return .err(errors::instruction(pc)); }
                }
            }
            registers::insert(ref mut defined, dst); registers::insert(ref mut written, dst);
        }
        if (pc + 1 >= p.ends[f]) { return .err(errors::instruction(pc)); }
        if (!merge(ref mut states, ref mut seen, ref defined, pc + 1, ref mut array_states, live, ref mut static_states, static_live)) {return .err(errors::instruction(pc));}
        pc += 1;
    }
    i = start;
    while (i < end) { if (!registers::contains(ref written, i)) { return .err(errors::instruction(pc)); } i += 1; }
    return .ok(end - start);
}

fn Result<reborrows::Sites, errors::Error> validate(ref ir::Program p,bool allow_reborrow_calls, u8 place_kind, ref statics::Sites static_sites) {
    let value_ir::Sites values=value_ir::empty();return validate_values(p,allow_reborrow_calls,place_kind,static_sites,ref values);
}
fn Result<reborrows::Sites,errors::Error> validate_values(ref ir::Program p,bool allow_reborrow_calls,
    u8 place_kind,ref statics::Sites static_sites,ref value_ir::Sites value_sites){
    return validate_values_mode(p,allow_reborrow_calls,place_kind,static_sites,value_sites,false,false);
}
fn Result<reborrows::Sites,errors::Error> validate_values_mode(ref ir::Program p,bool allow_reborrow_calls,
    u8 place_kind,ref statics::Sites static_sites,ref value_ir::Sites value_sites,bool input,bool host_profile){
    if (p.count == 0 || p.count > 256 || p.registers == 0 || p.registers > 128 || p.constant_count > 128 ||
        p.function_count == 0 || p.function_count > 16 || p.entry >= p.function_count || p.call_count > 32) { return .err(errors::absent(5,0)); }
    if (!arrays::valid(ref p.arrays)) { return .err(errors::absent(5,0)); }
    if(host_profile){if(p.list_used>4096){return .err(errors::absent(5,0));}}
    else{let usize list_metadata=lists::metadata(p)?;}
    let records::Prepared shapes = records::prepare(ref p.records)?;
    var usize id = 0;
    while (id < 16) {
        if ((id < p.arrays.count && p.array_functions[id] as usize >= p.function_count) ||
            (id >= p.arrays.count && p.array_functions[id] != 0) ||
            (id < p.records.count && p.record_functions[id] as usize >= p.function_count) ||
            (id >= p.records.count && p.record_functions[id] != 0)) { return .err(errors::absent(5,0)); }
        if (p.slice_roots[id] as usize > p.arrays.count) { return .err(errors::absent(5,0)); }
        id += 1;
    }
    if(p.return_types[p.entry]!=1){return .err(errors::absent(5,0));}
    if(input){if(p.arities[p.entry]!=1 || p.register_starts[p.entry]>=128 || static_sites.parameters[p.register_starts[p.entry]]!=3){return .err(errors::absent(5,0));}}
    else if(p.arities[p.entry]!=0){return .err(errors::absent(5,0));}
    var usize f = 0;
    var usize code_end = 0;
    var usize register_end = 0;
    while (f < p.function_count) {
        if (p.record_results[f]==0 && static_sites.results[f]==0 && value_sites.results[f]==0 && p.return_types[f]!=13 && !types::valid(p.return_types[f])) { return .err(errors::instruction(code_end)); }
        if (p.starts[f] != code_end || p.ends[f] <= code_end || p.ends[f] > p.count ||
            p.register_starts[f] != register_end || p.register_ends[f] < register_end ||
            p.register_ends[f] > p.registers || p.arities[f] > 8 ||
            p.arities[f] > p.register_ends[f] - register_end) { return .err(errors::instruction(code_end)); }
        code_end = p.ends[f]; register_end = p.register_ends[f]; f += 1;
    }
    if (code_end != p.count || register_end != p.registers) { return .err(errors::absent(5,0)); }
    let usize copy_metadata=copying::metadata(p)?;
    let usize borrowed_parameters = if(input){slice_parameters::metadata_input(p)?}else{slice_parameters::metadata(p)?};
    let reborrows::Sites loans = reborrows::metadata(p)?;
    let usize parameters = array_parameters::metadata(p)?;
    let usize record_parameters = struct_parameters::metadata(p)?;
    let usize results = array_results::metadata(p)?;
    let usize record_results = struct_results::metadata(p)?;
    var bool[32] used_calls = [false; 32];
    f = 0;
    while (f < p.function_count) { let usize checked = function(p, f, ref shapes, ref loans, static_sites, allow_reborrow_calls, place_kind, ref mut used_calls,value_sites,host_profile)?; f += 1; }
    let usize selected_places=places::inspect_prepared(p,ref shapes)?;
    var usize call = 0;
    while (call < p.call_count) { if (!used_calls[call]) { return .err(errors::absent(5,0)); } call += 1; }
    return .ok(loans);
}

// Analysis only: full typed-value/Dead CFG plus the canonical scalar, ordinary
// owner/loan/CALL and pending-place proof. No retained or executable admission.
pub struct ValueProof { value_ir::Prepared values; reborrows::Sites loans; }
pub fn Result<ValueProof,errors::Error> inspect_values(ref value_ir::Program unit){
    let value_ir::Prepared values=value_ir::prepare(unit)?;
    let usize flow=value_flow::inspect(unit,ref values)?;
    let statics::Sites statics=statics::empty();
    let reborrows::Sites loans=validate_values(ref unit.body,true,4,ref statics,ref values.sites)?;
    let usize views=value_view_flow::inspect(unit,ref values)?;
    return .ok(ValueProof{.values=values,.loans=loans});
}

// Ordinary entry points carry no Static authority and keep rejecting 69-79.
fn Result<reborrows::Sites,errors::Error> plain(ref ir::Program p,bool calls) {
    let statics::Sites sites = statics::empty(); return validate(p,calls,4,ref sites);
}
// Analysis-only slice-place proof carries no executable receipt, image or
// retained result authority. Executable entry points additionally prove CALL
// admission and use the metered coordinator-bound dispatch in both drivers.
pub fn Result<usize,errors::Error> inspect_slice_places(ref ir::Program p){
    let statics::Sites sites=statics::empty();
    let reborrows::Sites loans=validate(p,true,1,ref sites)?;return .ok(p.count);
}

// Analysis-only complete proof for aggregate SELECT/STORE/REPLACE. No image,
// retained Program, metered adapter or executable authority is returned.
pub fn Result<usize,errors::Error> inspect_aggregate_places(ref ir::Program p){
    let statics::Sites sites=statics::empty();
    let reborrows::Sites loans=validate(p,true,4,ref sites)?;return .ok(p.count);
}

// Record-place analysis uses the same complete proof as executable admission.
// Storage adapters alone still confer no execution or image authority.
pub fn Result<usize,errors::Error> inspect_record_places(ref ir::Program p){
    let statics::Sites sites=statics::empty();
    let reborrows::Sites loans=validate(p,true,2,ref sites)?;return .ok(p.count);
}

// Analysis-only preparation: exact image bytes plus ordinary metadata, scalar
// definitions, owners/loans and CFG proof. Static joins/backedges use their own
// live-state plane. This neither pins an image nor admits Static VM execution.
pub fn Result<statics::Sites,errors::Error> inspect_statics(ref ir::Program p,ref images::Image image) {
    let statics::Sites sites = statics::definitions(p,image)?;
    let reborrows::Sites loans = validate(p,true,4,ref sites)?; return .ok(sites);
}

// Strict inspection keeps its historical suspended-CALL analysis gate.
pub fn Result<usize, errors::Error> inspect(ref ir::Program p) {
    let reborrows::Sites sites=plain(p,false)?;return .ok(p.count);
}
// Public admission returns the exact forest produced by the complete proof.
// Unsupported derived CALL shapes reject in every function before guest effects.
fn Result<usize,errors::Error> executable_calls(ref ir::Program p,ref reborrows::Sites sites){
    if(sites.count!=0){var usize pc=0;while(pc<p.count){
        if(p.code[pc*8]==9 || p.code[pc*8]==78){let usize allowed=executable::call(p,sites,pc)?;}
        pc+=1;
    }}
    return .ok(p.count);
}
// Complete executable shape proof tied to actual immutable image bytes.
pub fn Result<statics::Sites,errors::Error> verify_statics(ref ir::Program p,ref images::Image image){
    let statics::Sites sites=statics::definitions(p,image)?;
    let reborrows::Sites loans=validate(p,reborrows::present(p),4,ref sites)?;
    let usize calls=executable_calls(p,ref loans)?;return .ok(sites);
}
pub fn Result<reborrows::Sites,errors::Error> verify_sites(ref ir::Program p){
    let reborrows::Sites sites=plain(p,reborrows::present(p))?;
    let usize calls=executable_calls(p,ref sites)?;
    return .ok(sites);
}
pub fn Result<usize, errors::Error> verify(ref ir::Program p) {
    let reborrows::Sites sites=verify_sites(p)?;return .ok(p.count);
}
// Scalar host admission checks catalog types before invoking this CFG proof.
pub fn Result<usize,errors::Error> inspect_host(ref ir::Program p){
    let statics::Sites static_sites=statics::empty();
    let value_ir::Sites values=value_ir::empty();
    let reborrows::Sites loans=validate_values_mode(p,false,4,ref static_sites,ref values,false,true)?;
    return .ok(p.count);
}
// Analysis-only proof does not impose the executable derived CALL subset.
pub fn Result<usize, errors::Error> inspect_reborrow_calls(ref ir::Program p) {
    let reborrows::Sites sites=plain(p,true)?;return .ok(p.count);
}

// This combines actual recipe/image origins with the canonical whole-program
// scalar/aggregate/loan proof. It does not retain an image or enable dispatch.
pub struct StaticCallProof { image_calls::Proof recipes; statics::Sites statics; reborrows::Sites loans; }
pub fn Result<StaticCallProof,errors::Error> verify_static_calls(ref image_calls::Program unit,ref images::Image image){
    let image_calls::Proof recipes=image_calls::inspect(unit,image)?;
    let statics::Sites sites=image_sites::prepare(unit,ref recipes,image)?;
    let ref ir::Program p=ref unit.body;
    let reborrows::Sites loans=validate(p,true,4,ref sites)?;
    let usize executable=executable_calls(p,ref loans)?;
    return .ok(StaticCallProof{.recipes=recipes,.statics=sites,.loans=loans});
}

// Shared byte formals may accept image or runtime-loan actuals in one signature.
// Kind 3 cannot return/escape yet. This analysis receipt deliberately has a
// separate type and does not grant retained Program or executable VM authority.
pub struct ReferenceCallProof { image_calls::Proof recipes; statics::Sites statics; reborrows::Sites loans; }
pub fn Result<ReferenceCallProof,errors::Error> inspect_reference_calls(ref image_calls::Program unit,ref images::Image image){
    let image_calls::Proof recipes=image_calls::inspect_references(unit,image)?;
    let statics::Sites sites=image_sites::prepare(unit,ref recipes,image)?;
    let ref ir::Program p=ref unit.body;
    let reborrows::Sites loans=validate(p,true,4,ref sites)?;
    let usize executable=executable_calls(p,ref loans)?;
    return .ok(ReferenceCallProof{.recipes=recipes,.statics=sites,.loans=loans});
}

// Complete analysis of generic byte results is still separate from retained
// executable admission. Local owner dependencies survive all returned aliases.
pub struct ReferenceReturnProof { image_calls::Proof recipes; statics::Sites statics; reborrows::Sites loans; usize[16] owner_roots; }
pub fn Result<ReferenceReturnProof,errors::Error> inspect_reference_returns(ref image_calls::Program unit,ref images::Image image){
    let image_calls::Proof recipes=image_calls::inspect_reference_returns(unit,image)?;
    let statics::Sites sites=image_sites::prepare(unit,ref recipes,image)?;
    let ref ir::Program p=ref unit.body;
    let reborrows::Sites loans=validate(p,true,4,ref sites)?;
    let usize executable=executable_calls(p,ref loans)?;
    let usize[16] roots=reference_lifetimes::prepare(p,ref sites)?;
    let usize checked=reference_lifetimes::inspect(p,ref sites,ref roots)?;
    return .ok(ReferenceReturnProof{.recipes=recipes,.statics=sites,.loans=loans,.owner_roots=roots});
}

// Complete canonical proof for the separate single shared-byte external input
// ABI. The ordinary/reference entry points still require zero entry arguments.
pub fn Result<ReferenceReturnProof,errors::Error> inspect_input_returns(ref image_calls::Program unit,ref images::Image image){
    let image_calls::Proof recipes=image_calls::inspect_input_returns(unit,image)?;
    let statics::Sites sites=image_sites::prepare(unit,ref recipes,image)?;
    let ref ir::Program p=ref unit.body;let value_ir::Sites no_values=value_ir::empty();
    let reborrows::Sites loans=validate_values_mode(p,true,4,ref sites,ref no_values,true,false)?;
    let usize executable=executable_calls(p,ref loans)?;
    let usize[16] roots=reference_lifetimes::prepare(p,ref sites)?;
    let usize checked=reference_lifetimes::inspect(p,ref sites,ref roots)?;
    return .ok(ReferenceReturnProof{.recipes=recipes,.statics=sites,.loans=loans,.owner_roots=roots});
}

// Explicit private output authority, exactly zero arguments or one shared-byte
// input ABI. No opcode rewriting: canonical validation sees every EMIT directly.
pub fn Result<ReferenceReturnProof,errors::Error> inspect_output_returns(ref image_calls::Program unit,ref images::Image image,bool input){
    let image_calls::Proof recipes=image_calls::inspect_output_returns(unit,image,input)?;
    var statics::Sites sites=image_sites::prepare(unit,ref recipes,image)?;sites.output=true;
    let ref ir::Program p=ref unit.body;let value_ir::Sites no_values=value_ir::empty();
    let reborrows::Sites loans=validate_values_mode(p,true,4,ref sites,ref no_values,input,false)?;
    let usize executable=executable_calls(p,ref loans)?;
    let usize[16] roots=reference_lifetimes::prepare(p,ref sites)?;
    let usize checked=reference_lifetimes::inspect(p,ref sites,ref roots)?;
    return .ok(ReferenceReturnProof{.recipes=recipes,.statics=sites,.loans=loans,.owner_roots=roots});
}
