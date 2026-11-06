module value_source_bindings;
import value_ir as values;
import value_properties as properties;
import locals as locals;
import lexer as lexer;
import errors as errors;

// Compiler metadata only; no executable authority or complete source integration.
// Keep one State with one Program for the entire lowering operation. Never reset
// its allocation cursor; use begin_alternative/select_path for separate CFG paths.
// Names refer to the caller's immutable source snapshot. Existing locals::find
// forbids ALL active shadowing.
// Static IDs are globally monotonic, including across scopes/functions/branches.
// Recursive activations still require the existing value-frame runtime; a static
// ID is not storage and must never alias another independent lexical value.
pub struct State {
    locals::Table names;
    u8[64] bindings; // 0 ordinary local, otherwise typed slot + 1
    usize next; usize live;
}
// Checkpoints describe compile-time CFG entries/exits, never native owners.
// begin_alternative/select_path select separately reached blocks. merge compares
// exits and never restores saved liveness/cursors on a continuing path.
pub struct Snapshot { State state; }
pub fn State empty(){return State{.names=locals::empty(),.bindings=[0;64],.next=0,.live=0};}
pub fn Snapshot snapshot(ref State state){return Snapshot{.state=State{
    .names=locals::snapshot(ref state.names),.bindings=state.bindings,.next=state.next,.live=state.live}};}
fn usize bit(usize id){let usize one=1;return one<<id;}
// Callers admit <=64; the pinned language has no unchecked narrowing cast.
fn u8 byte(usize value){var u8 result=0;var usize i=0;while(i<value){result+=1;i+=1;}return result;}
fn errors::Error invalid(usize at){return errors::make(3,at);}
fn Result<usize,errors::Error> header(ref values::Program unit,ref State state,usize at){
    if(state.next>16 || state.names.count>64 || state.names.function>=16 ||
        state.names.function>=unit.body.function_count || unit.body.function_count>16 ||
        state.live>=65536){return .err(invalid(at));}
    var usize i=0;while(i<16){
        if(i<state.next){if(unit.types[i]==0 || unit.types[i] as usize>unit.catalog.count ||
            unit.functions[i] as usize>=unit.body.function_count){return .err(invalid(at));}}
        else if(unit.types[i]!=0 || unit.functions[i]!=0 || (state.live&bit(i))!=0){return .err(invalid(at));}
        if((state.live&bit(i))!=0 && unit.functions[i] as usize!=state.names.function){return .err(invalid(at));}
        i+=1;
    }return .ok(state.next);
}
fn Result<usize,errors::Error> slot(ref values::Program unit,ref State state,usize id,usize at){
    let usize checked=header(unit,state,at)?;
    if(id>=state.next || !values::slot(unit,id,state.names.function)){return .err(invalid(at));}
    return .ok(id);
}
fn Result<bool,errors::Error> copyable(ref values::Program unit,usize id,usize at){
    let properties::Plan plan=switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(invalid(at));}
    };return .ok(plan.properties[values::type_id(unit,id)].copyable);
}
// All operands and instruction capacity are admitted before this infallible
// append. ir::raw itself writes op before fallible operand conversions.
fn void append(ref mut values::Program unit,u8 op,usize dst,usize source,usize at){
    let usize pc=unit.body.count;let usize start=pc*8;
    unit.body.code[start]=op;unit.body.code[start+1]=byte(dst);
    unit.body.code[start+2]=byte(source);unit.body.code[start+3]=0;
    unit.body.code[start+4]=0;unit.body.code[start+5]=0;
    unit.body.code[start+6]=0;unit.body.code[start+7]=0;
    unit.body.offsets[pc]=at;unit.body.count=pc+1;
}
// type is a ZERO-BASED exact catalog node, not an active payload or shape class.
// Allocation yields Dead. No slot is reclaimed, even after function completion.
pub fn Result<usize,errors::Error> allocate(ref mut values::Program unit,ref mut State state,usize exact_type,usize at){
    let usize checked=header(unit,state,at)?;
    if(state.next==16){return .err(errors::make(4,at));}
    let properties::Plan plan=switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(invalid(at));}
    };
    if(exact_type>=plan.count){return .err(invalid(at));}
    let usize id=state.next;
    unit.types[id]=byte(exact_type+1);unit.functions[id]=byte(state.names.function);
    state.next=id+1;return .ok(id);
}
// Trusted lowering hook for an already admitted initializer/formal. It emits no
// instruction. The parent must preflight its own operation before publishing it.
pub fn Result<usize,errors::Error> initialize(ref values::Program unit,ref mut State state,usize id,usize at){
    let usize checked=slot(unit,state,id,at)?;
    if((state.live&bit(id))!=0){return .err(invalid(at));}
    state.live|=bit(id);return .ok(id);
}
pub fn Result<usize,errors::Error> enter_function(ref values::Program unit,ref mut State state,usize function,usize at){
    let usize checked=header(unit,state,at)?;
    if(function>=unit.body.function_count || state.names.count!=0 || state.live!=0){return .err(invalid(at));}
    state.names.function=function;return .ok(function);
}
// Bind an already initialized exact-type slot. Staging just the small names
// header ensures even locals::declare failure cannot expose a partial binding.
pub fn Result<usize,errors::Error> declare(ref values::Program unit,ref mut State state,
    ref u8[] source,usize begin,usize end,usize id,usize exact_type){
    let usize checked=slot(unit,state,id,begin)?;
    if(!lexer::simple(source,begin,end) || locals::reserved(source[begin..end])){return .err(errors::make(2,begin));}
    if(exact_type>=unit.catalog.count || values::type_id(unit,id)!=exact_type || (state.live&bit(id))==0){return .err(invalid(begin));}
    // Ordinary and typed names share one Table and one uniqueness rule.
    let usize valid=spans(source,state,begin)?;
    if(locals::find(source,ref state.names,begin,end)!=64){return .err(invalid(begin));}
    var usize i=0;while(i<state.names.count){if(state.bindings[i] as usize==id+1){return .err(invalid(begin));}i+=1;}
    var locals::Table staged=locals::snapshot(ref state.names);
    let usize index=locals::declare(ref mut staged,begin,end,208+id,false)?;
    state.names=staged;state.bindings[index]=byte(id+1);return .ok(index);
}
// Same atomic declaration/uniqueness rules; mutability changes only after success.
pub fn Result<usize,errors::Error> declare_mut(ref values::Program unit,ref mut State state,
    ref u8[] source,usize begin,usize end,usize id,usize exact_type){
    let usize index=declare(unit,state,source,begin,end,id,exact_type)?;
    state.names.mutable[index]=true;return .ok(index);
}
fn Result<usize,errors::Error> spans(ref u8[] source,ref State state,usize at){
    var usize i=0;while(i<state.names.count){
        if(state.names.begins[i]>state.names.ends[i] || state.names.ends[i]>source.len){return .err(invalid(at));}i+=1;
    }return .ok(state.names.count);
}
// Returns the lexical index (not slot). Missing/ordinary names are type errors;
// a moved binding remains discoverable and subsequent use rejects as Dead.
pub fn Result<usize,errors::Error> lookup(ref u8[] source,ref State state,usize begin,usize end){
    if(state.names.count>64 || !lexer::simple(source,begin,end)){return .err(errors::make(2,begin));}
    let usize checked=spans(source,state,begin)?;
    let usize index=locals::find(source,ref state.names,begin,end);
    if(index==64 || state.bindings[index]==0){return .err(invalid(begin));}return .ok(index);
}
fn Result<usize,errors::Error> binding(ref values::Program unit,ref State state,usize index,usize at){
    let usize checked=header(unit,state,at)?;
    if(index>=state.names.count || state.bindings[index]==0){return .err(invalid(at));}
    let usize id=(state.bindings[index] as usize)-1;
    let usize valid=slot(unit,state,id,at)?;
    if(state.names.registers[index]!=208+id){return .err(invalid(at));}
    return .ok(id);
}
// Emits COPY89 for whole-copyable types, otherwise MOVE88, into an exact-type
// supplied Dead destination. Every rejection leaves code/count/offsets/state intact.
pub fn Result<usize,errors::Error> use_binding(ref mut values::Program unit,ref mut State state,
    usize index,usize destination,usize at){
    let usize source=binding(unit,state,index,at)?;
    let usize checked=slot(unit,state,destination,at)?;
    if((state.live&bit(source))==0 || (state.live&bit(destination))!=0 ||
        unit.types[source]!=unit.types[destination]){return .err(invalid(at));}
    let bool copied=copyable(unit,source,at)?;
    if(unit.body.count>=256){return .err(errors::make(4,at));}
    append(unit,if(copied){89}else{88},destination,source,at);
    if(!copied){state.live^=bit(source);}state.live|=bit(destination);return .ok(destination);
}
// Replace the fixed lexical slot, or reinitialize it after a move. The RHS is
// an already captured value: MOVE consumes it even when its type is copyable.
// Admit every binding, the catalog and the ENTIRE DROP+MOVE before any write.
pub fn Result<usize,errors::Error> assign(ref mut values::Program unit,ref mut State state,
    usize index,usize source,usize at){
    let usize destination=binding(unit,state,index,at)?;
    let usize checked=slot(unit,state,source,at)?;
    if(!state.names.mutable[index] || (state.live&bit(source))==0 ||
        unit.types[source]!=unit.types[destination]){return .err(invalid(at));}
    let properties::Plan plan=switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(invalid(at));}
    };
    var usize seen=0;var usize i=0;while(i<state.names.count){
        if(state.names.begins[i]>state.names.ends[i]){return .err(invalid(at));}
        if(state.bindings[i]!=0){let usize id=binding(unit,state,i,at)?;
            if((seen&bit(id))!=0){return .err(invalid(at));}seen|=bit(id);}
        i+=1;
    }
    var usize needed=0;
    if(source!=destination){needed=1;if((state.live&bit(destination))!=0){needed+=1;}}
    if(unit.body.count>256 || needed>256-unit.body.count){return .err(errors::make(4,at));}
    if(source==destination){return .ok(destination);}
    if((state.live&bit(destination))!=0){append(unit,90,destination,0,at);}
    append(unit,88,destination,source,at);
    state.live^=bit(source);state.live|=bit(destination);return .ok(destination);
}
// Trusted return/call handoff hook, after ALL surrounding admission succeeds.
// For CALL copyable actuals the caller leaves them live instead of calling this.
// RETURN consumes even copyable sources. No instruction is emitted here.
pub fn Result<usize,errors::Error> consume(ref values::Program unit,ref mut State state,usize id,usize at){
    let usize checked=slot(unit,state,id,at)?;
    if((state.live&bit(id))==0){return .err(invalid(at));}
    state.live^=bit(id);return .ok(id);
}
// Idempotent explicit drop, including anonymous temporaries. Dead emits nothing.
pub fn Result<usize,errors::Error> drop(ref mut values::Program unit,ref mut State state,usize id,usize at){
    let usize checked=slot(unit,state,id,at)?;
    if((state.live&bit(id))==0){return .ok(id);}
    if(unit.body.count>=256){return .err(errors::make(4,at));}
    append(unit,90,id,0,at);state.live^=bit(id);return .ok(id);
}
// mark is names.count at scope entry. Admit the ENTIRE reverse cleanup before
// any DROP/name removal, including late malformed bindings or full instruction IR.
// Ordinary locals share the Table but require their parent's separate cleanup.
pub fn Result<usize,errors::Error> leave_scope(ref mut values::Program unit,ref mut State state,usize mark,usize at){
    let usize checked=header(unit,state,at)?;
    if(mark>state.names.count){return .err(invalid(at));}
    var usize drops=0;var usize seen=0;var usize i=0;
    while(i<state.names.count){if(state.bindings[i]!=0){
        let usize id=binding(unit,state,i,at)?;
        if((seen&bit(id))!=0){return .err(invalid(at));}seen|=bit(id);
        if(i>=mark && (state.live&bit(id))!=0){drops+=1;}
    }i+=1;}
    if(unit.body.count>256 || drops>256-unit.body.count){return .err(errors::make(4,at));}
    i=state.names.count;while(i>mark){i-=1;
        if(state.bindings[i]!=0){let usize id=(state.bindings[i] as usize)-1;
            if((state.live&bit(id))!=0){append(unit,90,id,0,at);state.live^=bit(id);}}
        state.bindings[i]=0;state.names.begins[i]=0;state.names.ends[i]=0;
        state.names.registers[i]=0;state.names.mutable[i]=false;
    }state.names.count=mark;return .ok(drops);
}
// Trusted compile-only switch to a separate, unexecuted CFG alternative. Save
// the preceding arm's exit first and clean up its lexical declarations. Entry
// bindings must still match; only liveness may differ. Preserve ALL static slot
// allocations, including private slots introduced by the preceding arm. This
// emits/rewinds no IR and grants no executable proof: the independent source CFG
// verifier must establish that the restored entry is reached on another path.
pub fn Result<usize,errors::Error> begin_alternative(ref values::Program unit,ref mut State current,
    ref Snapshot entry,usize at){
    let usize checked=header(unit,current,at)?;let ref State prior=ref entry.state;
    if(prior.next>current.next || prior.names.count!=current.names.count ||
        prior.names.function!=current.names.function || prior.names.pending_places!=current.names.pending_places){
        return .err(invalid(at));}
    // Stage only the small metadata state, rebased onto the current global
    // high-water mark. The stale entry must not pass header with its old next.
    var State staged=State{.names=locals::snapshot(ref prior.names),.bindings=prior.bindings,
        .next=current.next,.live=prior.live};
    let usize valid=header(unit,ref staged,at)?;
    var usize i=prior.next;while(i<16){if((prior.live&bit(i))!=0){return .err(invalid(at));}i+=1;}
    var usize seen=0;i=0;while(i<current.names.count){
        if(prior.bindings[i]!=current.bindings[i] || prior.names.begins[i]!=current.names.begins[i] ||
            prior.names.ends[i]!=current.names.ends[i] || prior.names.registers[i]!=current.names.registers[i] ||
            prior.names.mutable[i]!=current.names.mutable[i] || prior.names.begins[i]>prior.names.ends[i]){
            return .err(invalid(at));}
        if(prior.bindings[i]!=0){
            let usize id=binding(unit,ref staged,i,at)?;
            if(id>=prior.next || (seen&bit(id))!=0){return .err(invalid(at));}seen|=bit(id);
        }i+=1;
    }
    current.names=staged.names;current.bindings=staged.bindings;current.live=staged.live;
    return .ok(current.live);
}
// Trusted compile-only selection of an independently reached CFG block, including
// cleanup/alternative entries after a terminal return removed all current names.
// This does NOT restore runtime ownership. The complete independent value CFG
// verifier remains the executable authority. Keep code/type allocations intact.
pub fn Result<usize,errors::Error> select_path(ref values::Program unit,ref mut State current,
    ref Snapshot entry,usize at){
    let usize checked=header(unit,current,at)?;let ref State prior=ref entry.state;
    if(prior.next>current.next || prior.names.function!=current.names.function){return .err(invalid(at));}
    var usize i=prior.next;while(i<16){if((prior.live&bit(i))!=0){return .err(invalid(at));}i+=1;}
    var State staged=State{.names=locals::snapshot(ref prior.names),.bindings=prior.bindings,
        .next=current.next,.live=prior.live};
    let usize valid=header(unit,ref staged,at)?;
    var usize seen=0;i=0;while(i<staged.names.count){
        if(staged.names.begins[i]>staged.names.ends[i]){return .err(invalid(at));}
        if(staged.bindings[i]!=0){let usize id=binding(unit,ref staged,i,at)?;
            if(id>=prior.next || (seen&bit(id))!=0){return .err(invalid(at));}seen|=bit(id);}
        i+=1;
    }
    current.names=staged.names;current.bindings=staged.bindings;current.live=staged.live;
    return .ok(current.live);
}
// Exact-live merge with identical surviving lexical bindings. Additional static
// allocations are allowed ONLY when Dead; the global cursor is never rewound.
pub fn Result<usize,errors::Error> merge(ref values::Program unit,ref mut State state,ref Snapshot other,usize at){
    let usize checked=header(unit,state,at)?;let ref State prior=ref other.state;
    if(prior.next>state.next || prior.names.count!=state.names.count || prior.names.function!=state.names.function ||
        prior.names.pending_places!=state.names.pending_places || prior.live!=state.live){return .err(invalid(at));}
    var usize i=0;while(i<state.names.count){
        if(prior.bindings[i]!=state.bindings[i] || prior.names.begins[i]!=state.names.begins[i] ||
            prior.names.ends[i]!=state.names.ends[i] || prior.names.registers[i]!=state.names.registers[i] ||
            prior.names.mutable[i]!=state.names.mutable[i]){return .err(invalid(at));}i+=1;
    }return .ok(state.live);
}
