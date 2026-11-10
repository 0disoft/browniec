module output_verifier_flow_work;
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

import metadata_budget as budget;

// Canonical output CFG heart. Metadata/catalog proof precedes begin. Heavy
// operand/copy/place/subtree checks yield explicit tasks; the owning proof
// coordinator must complete their independent staged kernels before provide.
// A task request does not advance the PC or publish scalar/owner/loan state.
pub struct State {
    usize[512] states; bool[256] seen; usize[256] arrays; usize[256] statics; bool[32] calls;
    registers::Set written; registers::Set entry; registers::Set defined;
    usize function; usize pc; usize index; usize live; usize static_live; usize resolved;
    u8 phase; u8 task; bool approved; bool active; bool done;
}
pub fn State empty(){return State{.states=[0;512],.seen=[false;256],.arrays=[0;256],.statics=[0;256],.calls=[false;32],
    .written=registers::empty(),.entry=registers::empty(),.defined=registers::empty(),
    .function=0,.pc=0,.index=0,.live=0,.static_live=0,.resolved=0,.phase=0,.task=0,.approved=false,.active=false,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<usize,errors::Error> begin(ref mut State w,usize function){
    if(w.active){return .err(invalid(w.pc));}
    w.function=function;w.phase=0;w.task=0;w.approved=false;w.active=true;w.done=false;return .ok(0);
}
fn bool merge(ref mut State w,ref registers::Set defined,usize target,usize live,usize static_live){
    if(w.seen[target] && (w.arrays[target]!=live || w.statics[target]!=static_live)){return false;}
    w.arrays[target]=live;w.statics[target]=static_live;
    let usize low=w.states[target*2];let usize high=w.states[target*2+1];
    let usize next_low=if(w.seen[target]){low&defined.low}else{defined.low};
    let usize next_high=if(w.seen[target]){high&defined.high}else{defined.high};
    w.states[target*2]=next_low;w.states[target*2+1]=next_high;w.seen[target]=true;return true;
}
fn bool readable(ref ir::Program p, ref registers::Set defined, usize r, usize start, usize end) {
    return r >= start && r < end && p.types[r]!=0 && !p.slots[r] && p.array_parameters[r] == 0 && p.record_parameters[r] == 0 && p.slice_parameters[r] == 0 && registers::contains(defined, r);
}

fn Result<bool,errors::Error> next(ref mut State w,ref registers::Set written,usize pc){
    w.written=*written;w.pc=pc+1;w.task=0;w.approved=false;return .ok(false);
}
fn Result<bool,errors::Error> need(ref mut State w,u8 task,ref registers::Set defined,usize live,usize static_live){
    w.task=task;w.defined=*defined;w.live=live;w.static_live=static_live;return .ok(false);
}
// Analysis plumbing only. No Program/admission API accepts a supplied task result.
pub fn Result<usize,errors::Error> provide(ref mut State w,usize live){
    if(!w.active || w.phase!=3 || w.task==0 || w.approved){return .err(invalid(w.pc));}
    w.resolved=live;w.approved=true;return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref records::Prepared shapes,ref reborrows::Sites loans,
    ref statics::Sites static_sites,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(w.task!=0 && !w.approved){return .ok(false);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    let usize f=w.function;
    if(!w.active || f>=p.function_count || f>=16 || p.ends[f]>p.count || p.count>256 || p.register_ends[f]>128){return .err(invalid(0));}
    let usize start=p.register_starts[f];let usize end=p.register_ends[f];let usize arity=p.arities[f];
    if(w.phase==0){
        w.states=[0;512];w.seen=[false;256];w.arrays=[0;256];w.statics=[0;256];
        w.written=registers::empty();w.entry=registers::empty();w.index=start;w.pc=p.starts[f];w.phase=1;return .ok(false);
    }
    if(w.phase==1){
        var registers::Set written=w.written;var registers::Set defined=w.entry;
        var usize i=w.index;var usize stop=i+16;if(stop>end){stop=end;}
        while(i<stop){
            if(p.record_parameters[i]==0 && p.slice_parameters[i]==0 && static_sites.parameters[i]==0 && !types::valid(p.types[i])){return .err(invalid(p.starts[f]));}
            if(i<start+arity){if(p.slots[i]){return .err(invalid(p.starts[f]));}
                registers::insert(ref mut written,i);
                if(p.array_parameters[i]==0 && p.record_parameters[i]==0 && p.slice_parameters[i]==0 && static_sites.parameters[i]==0){registers::insert(ref mut defined,i);}
            }i+=1;
        }
        w.written=written;w.entry=defined;w.index=i;if(i==end){w.phase=2;}return .ok(false);
    }
    if(w.phase==2){
        let usize borrowed=slice_parameters::initial(p,f)?;
        let registers::Set defined=w.entry;
        let bool entered=merge(w,ref defined,p.starts[f],array_parameters::initial(p,f)|struct_parameters::initial(p,f)|borrowed,0);
        w.phase=3;return .ok(false);
    }
    if(w.phase==4){
        var usize i=w.index;var usize stop=i+16;if(stop>end){stop=end;}
        while(i<stop){if(!registers::contains(ref w.written,i)){return .err(invalid(w.pc));}i+=1;}
        w.index=i;if(i==end){w.active=false;w.done=true;}return .ok(w.done);
    }
    if(w.phase!=3){return .err(invalid(w.pc));}
    if(w.pc==p.ends[f]){w.phase=4;w.index=start;return .ok(false);}
    let usize pc=w.pc;var registers::Set written=w.written;
    let bool allow_reborrow_calls=true;let u8 place_kind=4;
    if (!w.seen[pc]) { return .err(errors::make(5, pc)); }
    var registers::Set defined = registers::Set { .low = w.states[pc * 2], .high = w.states[pc * 2 + 1] };
    var usize live = w.arrays[pc];
    var usize static_live = w.statics[pc];
    let usize at = pc * 8;
    let u8 op = p.code[at];
    let usize dst = p.code[at + 1] as usize;
    let usize a = p.code[at + 2] as usize;
    let usize b = p.code[at + 3] as usize;
    if(op==116){
        let usize checked=output_ir::inspect(p,static_sites,pc,f,live,static_live)?;
        if(pc+1>=p.ends[f] || !merge(w,ref defined,pc+1,live,static_live)){return .err(errors::make(5,pc));}
        return next(w,ref written,pc);
    }
    if(op==78){
        if(!static_sites.call_profile){return .err(errors::make(5,pc));}
        if(a>=p.function_count || a==p.entry || b>=p.call_count || w.calls[b] ||
            p.call_arities[b] as usize!=p.arities[a]){return .err(errors::make(5,pc));}
        if((live>>48)!=0){let usize preserved=reborrow_calls::inspect(p,loans,pc,f,live)?;}
        if(!w.approved){return need(w,2,ref defined,live,static_live);}
        if(static_sites.results[a]!=0){let usize one=1;
            if(dst>=16 || static_sites.definitions[dst]!=pc || static_sites.functions[dst]!=f ||
                static_sites.kinds[dst]!=static_sites.results[a] || (static_live&(one<<dst))!=0){return .err(errors::make(5,pc));}
            static_live|=one<<dst;
        }else if(p.array_results[a]!=0 || p.record_results[a]!=0){
            live=if(p.record_results[a]!=0){struct_results::call(p,a,dst,f,live,pc)?}else{array_results::call(p,a,dst,f,live,pc)?};
        }else if(p.return_types[a]==13){
            if(dst!=0){return .err(errors::make(5,pc));}
        }else{
            if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written,dst) ||
                p.types[dst]!=p.return_types[a] || !types::valid(p.types[dst])){return .err(errors::make(5,pc));}
            registers::insert(ref mut defined,dst);registers::insert(ref mut written,dst);
        }
        w.calls[b]=true;
        if(pc+1>=p.ends[f] || !merge(w,ref defined,pc+1,live,static_live)){return .err(errors::make(5,pc));}
        return next(w,ref written,pc);
    }
    if(op==79){let usize one=1;
        if(static_sites.results[f]==0 || live!=0 || a>=16 || static_live!=(one<<a) ||
            static_sites.functions[a]!=f || (static_sites.kinds[a]!=static_sites.results[f] &&
            !(static_sites.results[f]==3 && static_sites.kinds[a]==1))){return .err(errors::make(5,pc));}
        return next(w,ref written,pc);
    }
    if (statics::operation(op)) {
        static_live = statics::step(p, static_sites, pc, f, ref mut defined, ref mut written, static_live)?;
        if (pc + 1 >= p.ends[f] || !merge(w,ref defined,pc + 1,live,static_live)) { return .err(errors::make(5, pc)); }
        return next(w,ref written,pc);
    }
    if(value_ir::operation(op)){return .err(errors::make(5,pc));}

    if ((op == 8 || op == 39 || op == 50 || op==82) && static_live != 0) { return .err(errors::make(5, pc)); }
    if (op < 1 || (op > 62 && op!=80 && op!=81 && op!=82 && !places::operation(op)) || (!places::operation(op) && op != 52 && ((op!=24 && op!=47 && op!=49 && op!=53 && op!=59 && op!=61 && !(op>=83 && op<=85) && p.code[at + 4] != 0) ||
        (op!=47 && !(op>=83 && op<=85 && p.code[at+4]==2) && p.code[at + 5] != 0) || p.code[at + 6] != 0 || p.code[at + 7] != 0))) { return .err(errors::make(5, pc)); }
    // Strict analysis retains its gate; executable proof may admit this CALL.
    if(op==9 && (live>>48)!=0) {
        if(!allow_reborrow_calls){return .err(errors::make(5,pc));}
        let usize preserved=reborrow_calls::inspect(p,loans,pc,f,live)?;
    }
    if (op==25) {
        if(dst!=0 || a!=0 || b!=0) {return .err(errors::make(5,pc));}
        return next(w,ref written,pc);
    }
    if (op==24) {
        let usize target=p.code[at+4] as usize;
        if(!readable(p,ref defined,a,start,end) || !types::tagged(p.types[a]) || b>1 || target<=pc || target>=p.ends[f]) {return .err(errors::make(5,pc));}
        let u8 tag=types::payload(p.types[a],p.code[at+3]);
        if(tag==0) {if(dst!=0) {return .err(errors::make(5,pc));}}
        else if(dst<start || dst>=end || p.slots[dst] || registers::contains(ref written, dst) || p.types[dst]!=tag) {return .err(errors::make(5,pc));}
        // The mismatch path receives no payload definition.
        if (!merge(w,ref defined,target,live,static_live)) {return .err(errors::make(5,pc));}
        if(tag!=0) {registers::insert(ref mut defined, dst);registers::insert(ref mut written, dst);}
        if(pc+1>=p.ends[f]) {return .err(errors::make(5,pc));}
        if (!merge(w,ref defined,pc+1,live,static_live)) {return .err(errors::make(5,pc));}
        return next(w,ref written,pc);
    }
    if(op==50) {
        if(dst!=0 || b!=0) {return .err(errors::make(5,pc));}
        let usize returned=struct_results::returned(p,a,f,live,pc)?;
        return next(w,ref written,pc);
    }
    if(op==39) {
        if(dst!=0 || b!=0) {return .err(errors::make(5,pc));}
        let usize returned=array_results::returned(p,a,f,live,pc)?;
        return next(w,ref written,pc);
    }
    if(op==82){
        if(p.return_types[f]!=13 || p.array_results[f]!=0 || p.record_results[f]!=0 ||
            live!=0 || dst!=0 || a!=0 || b!=0){return .err(errors::make(5,pc));}
        return next(w,ref written,pc);
    }
    if (op == 8) {
        if(p.array_results[f]!=0 || p.record_results[f]!=0) {return .err(errors::make(5,pc));}
        if (live != 0 || dst != 0 || b != 0 || !readable(p, ref defined, a, start, end)) { return .err(errors::make(5, pc)); }
        if (p.types[a] != p.return_types[f]) { return .err(errors::make(5, pc)); }
        return next(w,ref written,pc);
    }
    if (op == 22) {
        if (dst != 0 || b != 0 || a < p.starts[f] || a >= pc || !w.seen[a] || live != w.arrays[a] || static_live != w.statics[a]) { return .err(errors::make(5, pc)); }
        if ((w.states[a * 2] & defined.low) != w.states[a * 2] ||
            (w.states[a * 2 + 1] & defined.high) != w.states[a * 2 + 1]) { return .err(errors::make(5, pc)); }
        return next(w,ref written,pc);
    }
    if(places::operation(op)){
        if(p.code[at+4]>place_kind){return .err(errors::make(5,pc));}
        if(p.code[at+4]>=3){if(!w.approved){return need(w,6,ref defined,live,static_live);}}
        else{let usize checked=places::step(p,shapes,pc,f,ref mut defined,ref mut written,live)?;}
    }else if(op==80 || op==81){
        if(!w.approved){return need(w,3,ref defined,live,static_live);}live=w.resolved;
    }else if (op >= 54) {
        live = reborrows::step(p, loans, pc, f, ref mut defined, ref mut written, live)?;
    } else if(op==9 && a<p.function_count && p.return_types[a]==13){
        if(dst!=0 || b>=p.call_count || w.calls[b] || a==p.entry || p.call_arities[b] as usize!=p.arities[a]){return .err(errors::make(5,pc));}
        if(!w.approved){return need(w,1,ref defined,live,static_live);}w.calls[b]=true;
    } else if(op==9 && a<p.function_count && (p.array_results[a]!=0 || p.record_results[a]!=0)) {
        if(b>=p.call_count || w.calls[b] || a==p.entry || p.call_arities[b] as usize!=p.arities[a]) {return .err(errors::make(5,pc));}
        if(!w.approved){return need(w,1,ref defined,live,static_live);}
        live=if(p.record_results[a]!=0){struct_results::call(p,a,dst,f,live,pc)?}
            else{array_results::call(p,a,dst,f,live,pc)?};
        w.calls[b]=true;
    } else if(op==42 || op==46 || op==47){
        if(!w.approved){return need(w,4,ref defined,live,static_live);}live=w.resolved;
    } else if(op==49){
        if(!w.approved){return need(w,5,ref defined,live,static_live);}
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
        if (!merge(w,ref defined,target,live,static_live)) {return .err(errors::make(5,pc));}
        if (op == 19) { return next(w,ref written,pc); }
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
            if (a >= p.function_count || b >= p.call_count || w.calls[b] || ((p.arrays.count != 0 || p.records.count != 0) && a == p.entry)) { return .err(errors::make(5, pc)); }
            let usize count = p.call_arities[b] as usize;
            if (count != p.arities[a] || count > 8 || p.types[dst] != p.return_types[a]) { return .err(errors::make(5, pc)); }
            if(!w.approved){return need(w,1,ref defined,live,static_live);}
            w.calls[b] = true;
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
    if (!merge(w,ref defined,pc + 1,live,static_live)) {return .err(errors::make(5,pc));}
    return next(w,ref written,pc);

}
