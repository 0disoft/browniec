module value_source_bindings;
import value_ir as values;
import value_properties as properties;
import locals as locals;
import lexer as lexer;
import errors as errors;
import value_view_bindings as views;

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
    views::State views; // Separate per-activation view IDs; shared lexical names.
    usize next; usize live; usize maybe; // Possible-only anonymous Buffers, disjoint from live.
    usize reads; usize writes; // Ephemeral Buffer argument loans, never guest handles.
    bool enforce_results; usize pending; // Direct Result obligations, independent of COPY ownership.
    // Compiler-only loop summary: F(p) = generated | (p & ~kills).
    // required records incoming obligations rejected by implicit cleanup.
    bool tracking; usize kills; usize generated; usize required;
}
// Checkpoints describe compile-time CFG entries/exits, never native owners.
// begin_alternative/select_path select separately reached blocks. merge compares
// exits and never restores saved liveness/cursors on a continuing path.
pub struct Snapshot { State state; }
pub fn State empty(){return State{.names=locals::empty(),.bindings=[0;64],.views=views::empty(),.next=0,.live=0,.maybe=0,.reads=0,.writes=0,
    .enforce_results=false,.pending=0,.tracking=false,.kills=0,.generated=0,.required=0};}
pub fn Snapshot snapshot(ref State state){return Snapshot{.state=State{
    .names=locals::snapshot(ref state.names),.bindings=state.bindings,.views=state.views,.next=state.next,.live=state.live,.maybe=state.maybe,.reads=state.reads,.writes=state.writes,
    .enforce_results=state.enforce_results,.pending=state.pending,.tracking=state.tracking,
    .kills=state.kills,.generated=state.generated,.required=state.required}};}
fn usize bit(usize id){let usize one=1;return one<<id;}
// Callers admit <=64; the pinned language has no unchecked narrowing cast.
fn u8 byte(usize value){var u8 result=0;var usize i=0;while(i<value){result+=1;i+=1;}return result;}
fn errors::Error invalid(usize at){return errors::make(3,at);}
fn Result<usize,errors::Error> header(ref values::Program unit,ref State state,usize at){
    let usize view_count=views::validate(ref state.views,at)?;
    if(state.next>16 || state.names.count>64 || state.names.function>=16 ||
        state.names.function>=unit.body.function_count || unit.body.function_count>16 || state.views.function!=state.names.function ||
        unit.catalog.count>64 || state.live>=65536 || state.maybe>=65536 ||
        (state.live&state.maybe)!=0 || state.pending>=65536 ||
        state.reads>=65536 || state.writes>=65536 || (state.reads&state.writes)!=0 ||
        ((state.reads|state.writes)&state.live)!=(state.reads|state.writes) ||
        state.kills>=65536 || state.generated>=65536 || state.required>=65536 ||
        (!state.tracking && (state.kills!=0 || state.generated!=0 || state.required!=0)) ||
        (state.pending&state.live)!=state.pending || (!state.enforce_results && state.pending!=0)){
        return .err(invalid(at));}
    var usize i=0;while(i<16){
        if(i<state.next){if(unit.types[i]==0 || unit.types[i] as usize>unit.catalog.count ||
            unit.functions[i] as usize>=unit.body.function_count){return .err(invalid(at));}}
        else if(unit.types[i]!=0 || unit.functions[i]!=0 || ((state.live|state.maybe)&bit(i))!=0){return .err(invalid(at));}
        if(((state.live|state.maybe)&bit(i))!=0 && unit.functions[i] as usize!=state.names.function){return .err(invalid(at));}
        if((state.maybe&bit(i))!=0 && (unit.catalog.nodes[values::type_id(unit,i)].kind!=4 ||
            named_owner(state,i))){return .err(invalid(at));}
        if((state.pending&bit(i))!=0 && unit.catalog.nodes[values::type_id(unit,i)].kind!=6){return .err(invalid(at));}
        if(((state.reads|state.writes)&bit(i))!=0 && unit.catalog.nodes[values::type_id(unit,i)].kind!=4){return .err(invalid(at));}
        i+=1;
    }
    let usize view_function=views::authenticate(unit,ref state.views,at)?;
    i=0;while(i<16){let usize roots=views::local_roots(ref state.views,i);var usize owner=0;
        while(owner<16){if((roots&bit(owner))!=0 && (owner>=state.next || ((state.live|state.maybe)&bit(owner))==0 ||
            unit.catalog.nodes[values::type_id(unit,owner)].kind!=4)){return .err(invalid(at));}owner+=1;}
        i+=1;}
    i=0;while(i<64){if(state.views.names[i]!=0){let usize id=(state.views.names[i] as usize)-1;
        if(i>=state.names.count || state.bindings[i]!=0 || state.names.registers[i]!=224+id){return .err(invalid(at));}
    }i+=1;}return .ok(state.next);
}
// Shared full-state authentication for operation helpers, with no emission.
pub fn Result<usize,errors::Error> authenticate(ref values::Program unit,ref State state,usize at){
    return header(unit,state,at);
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
// Opt-in belongs to the private source compiler; explicit IR helpers keep their
// original cleanup behavior. Enabling cannot retroactively exempt live values.
pub fn Result<usize,errors::Error> enable_results(ref values::Program unit,ref mut State state,usize at){
    let usize checked=header(unit,state,at)?;
    if(state.next!=0 || (state.live|state.maybe)!=0 || state.reads!=0 || state.writes!=0 || state.names.count!=0 || state.names.pending_places!=0){return .err(invalid(at));}
    state.enforce_results=true;return .ok(0);
}
fn void result_pending(ref values::Program unit,ref mut State state,usize id){
    if(unit.catalog.nodes[values::type_id(unit,id)].kind==6){
        if(state.enforce_results){state.pending|=bit(id);}
        if(state.tracking){state.kills|=bit(id);state.generated|=bit(id);}
    }
}
fn void result_handled(ref values::Program unit,ref mut State state,usize id){
    state.pending^=state.pending&bit(id);
    if(state.tracking && unit.catalog.nodes[values::type_id(unit,id)].kind==6){
        state.generated^=state.generated&bit(id);state.kills|=bit(id);
    }
}
// Call only after the entire operation's preflight, before killing this value.
fn void result_required(ref values::Program unit,ref mut State state,usize id){
    if(state.tracking && unit.catalog.nodes[values::type_id(unit,id)].kind==6){
        state.required|=bit(id)^(bit(id)&state.kills);
    }
}
// Handling is compile-time only, including explicit discard and non-consuming
// predicates. Non-Result values have no obligation; their ownership is untouched.
pub fn Result<usize,errors::Error> handle(ref values::Program unit,ref mut State state,usize id,usize at){
    let usize checked=slot(unit,state,id,at)?;
    if(((state.reads|state.writes)&bit(id))!=0 || (state.live&bit(id))==0){return .err(invalid(at));}
    result_handled(unit,state,id);return .ok(id);
}
// keep16 denotes an ordinary return; otherwise exempt only the retained typed
// return slot. Preflight precedes all function cleanup and emits no instructions.
pub fn Result<usize,errors::Error> require_handled(ref values::Program unit,ref State state,usize keep,usize at){
    let usize checked=header(unit,state,at)?;
    if(keep>16){return .err(invalid(at));}
    var usize allowed=0;
    if(keep!=16){let usize valid=slot(unit,state,keep,at)?;
        if((state.live&bit(keep))==0){return .err(invalid(at));}allowed=state.pending&bit(keep);}
    if(state.pending!=allowed){return .err(errors::make(18,at));}return .ok(keep);
}
// Mutable exit preflight adds requirements even for currently handled Results.
// Returning keep transfers its obligation and is never implicit cleanup.
pub fn Result<usize,errors::Error> check_exit(ref values::Program unit,ref mut State state,usize keep,usize at){
    let usize checked=require_handled(unit,state,keep,at)?;
    var usize id=0;while(id<state.next){
        if(id!=keep && (state.live&bit(id))!=0){result_required(unit,state,id);}id+=1;
    }return .ok(checked);
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
    if(((state.live|state.maybe)&bit(id))!=0){return .err(invalid(at));}
    state.live|=bit(id);result_pending(unit,state,id);return .ok(id);
}
pub fn Result<usize,errors::Error> enter_function(ref values::Program unit,ref mut State state,usize function,usize at){
    let usize checked=header(unit,state,at)?;
    if(function>=unit.body.function_count || state.names.count!=0 || (state.live|state.maybe)!=0 || views::count(ref state.views)!=0){return .err(invalid(at));}
    state.views=views::empty();state.views.function=function;
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
// Views share the ordinary/owned name namespace, but never own a value slot.
pub fn Result<usize,errors::Error> declare_view(ref values::Program unit,ref mut State state,
    ref u8[] source,usize begin,usize end,usize id,bool mutable){
    let usize checked=header(unit,state,begin)?;let usize roots=views::roots(ref state.views,id,begin)?;
    if(!lexer::simple(source,begin,end) || locals::reserved(source[begin..end])){return .err(errors::make(2,begin));}
    let usize valid=spans(source,state,begin)?;
    if(locals::find(source,ref state.names,begin,end)!=64){return .err(invalid(begin));}
    var usize i=0;while(i<state.names.count){if(state.views.names[i] as usize==id+1){return .err(invalid(begin));}i+=1;}
    var locals::Table staged=locals::snapshot(ref state.names);
    let usize index=locals::declare(ref mut staged,begin,end,224+id,mutable)?;
    state.names=staged;state.bindings[index]=0;state.views.names[index]=byte(id+1);return .ok(index);
}
pub fn Result<usize,errors::Error> lookup_view(ref u8[] source,ref State state,usize begin,usize end){
    if(state.names.count>64 || !lexer::simple(source,begin,end)){return .err(errors::make(2,begin));}
    let usize checked=spans(source,state,begin)?;let usize valid=views::validate(ref state.views,begin)?;
    let usize index=locals::find(source,ref state.names,begin,end);
    if(index==64 || state.views.names[index]==0 || state.bindings[index]!=0 ||
        state.names.registers[index]!=223+state.views.names[index] as usize){return .err(invalid(begin));}
    return .ok(index);
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
    if(views::pinned(ref state.views,source) || views::pinned(ref state.views,destination)){return .err(invalid(at));}
    if(((state.reads|state.writes)&(bit(source)|bit(destination)))!=0 ||
        (state.live&bit(source))==0 || ((state.live|state.maybe)&bit(destination))!=0 ||
        unit.types[source]!=unit.types[destination]){return .err(invalid(at));}
    let bool copied=copyable(unit,source,at)?;
    if(unit.body.count>=256){return .err(errors::make(4,at));}
    append(unit,if(copied){89}else{88},destination,source,at);
    if(!copied){state.live^=bit(source);}state.live|=bit(destination);
    result_handled(unit,state,source);result_pending(unit,state,destination);return .ok(destination);
}
// Publish an anonymous branch result into a preallocated Dead join slot. Each
// independently selected CFG edge may use that same destination. Unlike a named
// read, this always consumes the source, including whole-copyable values.
pub fn Result<usize,errors::Error> move_value(ref mut values::Program unit,ref mut State state,
    usize destination,usize source,usize at){
    let usize checked=slot(unit,state,source,at)?;
    let usize valid=slot(unit,state,destination,at)?;
    if(views::pinned(ref state.views,source) || views::pinned(ref state.views,destination)){return .err(invalid(at));}
    if(((state.reads|state.writes)&(bit(source)|bit(destination)))!=0 ||
        (state.live&bit(source))==0 || ((state.live|state.maybe)&bit(destination))!=0 ||
        unit.types[source]!=unit.types[destination]){return .err(invalid(at));}
    let properties::Plan plan=switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(invalid(at));}
    };
    if(unit.body.count>=256){return .err(errors::make(4,at));}
    append(unit,88,destination,source,at);
    state.live^=bit(source);state.live|=bit(destination);
    result_handled(unit,state,source);result_pending(unit,state,destination);return .ok(destination);
}
// Replace the fixed lexical slot, or reinitialize it after a move. The RHS is
// an already captured value: MOVE consumes it even when its type is copyable.
// Admit every binding, the catalog and the ENTIRE DROP+MOVE before any write.
pub fn Result<usize,errors::Error> assign(ref mut values::Program unit,ref mut State state,
    usize index,usize source,usize at){
    let usize destination=binding(unit,state,index,at)?;
    let usize checked=slot(unit,state,source,at)?;
    if(views::pinned(ref state.views,source) || views::pinned(ref state.views,destination)){return .err(invalid(at));}
    if(((state.reads|state.writes)&(bit(source)|bit(destination)))!=0 ||
        !state.names.mutable[index] || (state.live&bit(source))==0 || (state.maybe&bit(destination))!=0 ||
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
    if(source!=destination && (state.pending&bit(destination))!=0){return .err(errors::make(18,at));}
    if(source!=destination){needed=1;if((state.live&bit(destination))!=0){needed+=1;}}
    if(unit.body.count>256 || needed>256-unit.body.count){return .err(errors::make(4,at));}
    if(source==destination){return .ok(destination);}
    if((state.live&bit(destination))!=0){
        result_required(unit,state,destination);result_handled(unit,state,destination);
        append(unit,90,destination,0,at);
    }
    append(unit,88,destination,source,at);
    state.live^=bit(source);state.live|=bit(destination);
    result_handled(unit,state,source);result_pending(unit,state,destination);return .ok(destination);
}
// Trusted return/call handoff hook, after ALL surrounding admission succeeds.
// For CALL copyable actuals the caller leaves them live instead of calling this.
// RETURN consumes even copyable sources. No instruction is emitted here.
pub fn Result<usize,errors::Error> consume(ref values::Program unit,ref mut State state,usize id,usize at){
    let usize checked=slot(unit,state,id,at)?;
    if(views::pinned(ref state.views,id)){return .err(invalid(at));}
    if(((state.reads|state.writes)&bit(id))!=0 || (state.live&bit(id))==0){return .err(invalid(at));}
    state.live^=bit(id);result_handled(unit,state,id);return .ok(id);
}
// Idempotent cleanup. Possible-only anonymous Buffers use DROP_IF_LIVE115;
// definite values retain DROP90. Neither path changes operation prices.
pub fn Result<usize,errors::Error> drop(ref mut values::Program unit,ref mut State state,usize id,usize at){
    let usize checked=slot(unit,state,id,at)?;
    if(views::pinned(ref state.views,id)){return .err(invalid(at));}
    if(((state.reads|state.writes)&bit(id))!=0){return .err(invalid(at));}
    if(((state.live|state.maybe)&bit(id))==0){return .ok(id);}
    if((state.pending&bit(id))!=0){return .err(errors::make(18,at));}
    if(unit.body.count>=256){return .err(errors::make(4,at));}
    result_required(unit,state,id);result_handled(unit,state,id);
    append(unit,if((state.maybe&bit(id))!=0){115}else{90},id,0,at);
    state.live^=state.live&bit(id);state.maybe^=state.maybe&bit(id);return .ok(id);
}
fn bool named_owner(ref State state,usize owner){var usize i=0;
    while(i<state.names.count){if(state.bindings[i] as usize==owner+1){return true;}i+=1;}return false;}
fn Result<usize,errors::Error> anonymous_drop(ref State state,usize owner,usize at){
    if(owner>=16){return .ok(0);}
    if(named_owner(state,owner) || ((state.live|state.maybe)&bit(owner))==0){return .ok(0);}
    if(((state.reads|state.writes)&bit(owner))!=0){return .err(invalid(at));}
    if((state.pending&bit(owner))!=0){return .err(errors::make(18,at));}return .ok(1);
}
fn usize other_roots(ref State state,usize except){
    var usize roots=0;var usize i=0;while(i<16){
        if(i!=except){roots|=views::local_roots(ref state.views,i);}i+=1;
    }return roots;
}
fn Result<usize,errors::Error> anonymous_drops(ref State state,usize roots,usize at){
    var usize drops=0;var usize i=0;while(i<16){
        if((roots&bit(i))!=0){drops+=anonymous_drop(state,i,at)?;}i+=1;
    }return .ok(drops);
}
fn Result<usize,errors::Error> drop_anonymous(ref mut values::Program unit,ref mut State state,usize roots,usize at){
    var usize i=16;while(i>0){i-=1;if((roots&bit(i))!=0 && !named_owner(state,i)){
        let usize dropped=drop(unit,state,i,at)?;
    }}return .ok(roots);
}
// Close one descriptor and the anonymous owner only when its last lease ends.
// Admit the entire CLOSE+optional DROP before touching either state plane.
pub fn Result<usize,errors::Error> close_view(ref mut values::Program unit,ref mut State state,usize id,usize at){
    let usize checked=header(unit,state,at)?;let usize valid=views::roots(ref state.views,id,at)?;
    let usize owners=views::local_roots(ref state.views,id);
    let usize kept=other_roots(state,id);let usize departing=owners^(owners&kept);
    let usize drops=anonymous_drops(state,departing,at)?;
    if(unit.body.count>256 || 1+drops>256-unit.body.count){return .err(errors::make(4,at));}
    let usize closed=views::close(unit,ref mut state.views,id,at)?;
    let usize dropped=drop_anonymous(unit,state,departing,at)?;return .ok(closed);
}
// All descriptors close before any owner drops. Named owners stay for ordinary
// lexical cleanup; an immediate view over an anonymous Buffer owns its cleanup.
pub fn Result<usize,errors::Error> close_views(ref mut values::Program unit,ref mut State state,usize at){
    let usize checked=header(unit,state,at)?;var usize owners=0;var usize i=0;
    while(i<16){owners|=views::local_roots(ref state.views,i);i+=1;}
    let usize drops=anonymous_drops(state,owners,at)?;
    let usize closes=views::count(ref state.views);
    if(unit.body.count>256 || closes+drops>256-unit.body.count){return .err(errors::make(4,at));}
    let usize closed=views::close_all(unit,ref mut state.views,at)?;
    let usize dropped=drop_anonymous(unit,state,owners,at)?;
    return .ok(closed);
}
// Preserve baseline descriptors and close only newer anonymous temporaries.
// Dropping their last anonymous root is part of the same atomic admission.
pub fn Result<usize,errors::Error> close_views_since(ref mut values::Program unit,ref mut State state,
    ref views::State baseline,usize at){
    let usize checked=header(unit,state,at)?;
    let usize closing=views::anonymous_since(ref state.views,baseline,at)?;
    var usize owners=0;var usize kept=0;var usize closes=0;var usize i=0;
    while(i<16){if(state.views.origins[i]!=0){let usize roots=views::local_roots(ref state.views,i);
        if((closing&bit(i))!=0){closes+=1;owners|=roots;}
        else{kept|=roots;}
    }i+=1;}
    owners^=owners&kept;let usize drops=anonymous_drops(state,owners,at)?;
    if(unit.body.count>256 || closes+drops>256-unit.body.count){return .err(errors::make(4,at));}
    let usize closed=views::close_since(unit,ref mut state.views,baseline,at)?;
    let usize dropped=drop_anonymous(unit,state,owners,at)?;
    return .ok(closed);
}
// RHS is an already captured anonymous view. Preserve the lexical destination
// ID/mutability while replacing its descriptor; payload remains read-only.
pub fn Result<usize,errors::Error> assign_view(ref mut values::Program unit,ref mut State state,
    usize index,usize source,usize at){
    let usize checked=header(unit,state,at)?;
    if(index>=state.names.count || state.views.names[index]==0 || !state.names.mutable[index]){return .err(invalid(at));}
    let usize destination=(state.views.names[index] as usize)-1;
    let usize old_roots=views::roots(ref state.views,destination,at)?;
    let usize new_roots=views::roots(ref state.views,source,at)?;
    var usize i=0;while(i<state.names.count){if(state.views.names[i] as usize==source+1){return .err(invalid(at));}i+=1;}
    let usize owners=views::local_roots(ref state.views,destination);
    let usize kept=other_roots(state,destination);let usize departing=owners^(owners&kept);
    let usize drops=anonymous_drops(state,departing,at)?;
    if(unit.body.count>256 || 2+drops>256-unit.body.count){return .err(errors::make(4,at));}
    let usize closed=views::close(unit,ref mut state.views,destination,at)?;
    let usize moved=views::move_to(unit,ref mut state.views,source,destination,at)?;
    state.views.names[index]=byte(destination+1);
    let usize dropped=drop_anonymous(unit,state,departing,at)?;return .ok(destination);
}
// mark is names.count at scope entry. Admit the ENTIRE reverse cleanup before
// any DROP/name removal, including late malformed bindings or full instruction IR.
// Ordinary locals share the Table but require their parent's separate cleanup.
pub fn Result<usize,errors::Error> leave_scope(ref mut values::Program unit,ref mut State state,usize mark,usize at){
    let usize checked=header(unit,state,at)?;
    if(mark>state.names.count){return .err(invalid(at));}
    var usize drops=0;var usize roots=0;var usize seen=0;var usize i=0;
    while(i<state.names.count){if(state.bindings[i]!=0){
        let usize id=binding(unit,state,i,at)?;
        if((seen&bit(id))!=0){return .err(invalid(at));}seen|=bit(id);
        if(i>=mark && (state.live&bit(id))!=0){
            if(((state.reads|state.writes)&bit(id))!=0){return .err(invalid(at));}
            if((state.pending&bit(id))!=0){return .err(errors::make(18,at));}drops+=1;roots|=bit(id);}
    }i+=1;}
    var usize closes=0;var usize closing=0;i=mark;while(i<state.names.count){
        if(state.views.names[i]!=0){let usize id=(state.views.names[i] as usize)-1;closing|=bit(id);closes+=1;}i+=1;
    }
    var usize anonymous=0;var usize kept=0;
    i=0;while(i<16){if(state.views.origins[i]!=0){let usize owners=views::local_roots(ref state.views,i);
        if((closing&bit(i))==0){
            kept|=owners;if((roots&owners)!=0){return .err(invalid(at));}
        }else{anonymous|=owners;}
    }i+=1;}
    // Named CALL results can retain anonymous actuals. Their last lexical view
    // owns root cleanup, unless another (including anonymous) descriptor survives.
    anonymous^=anonymous&kept;i=0;while(i<16){if((anonymous&bit(i))!=0){
        if(named_owner(state,i)){anonymous^=bit(i);}else{drops+=anonymous_drop(state,i,at)?;}
    }i+=1;}
    if(unit.body.count>256 || drops+closes>256-unit.body.count){return .err(errors::make(4,at));}
    // CLOSE every departing alias/range before dropping any referenced root.
    i=state.names.count;while(i>mark){i-=1;if(state.views.names[i]!=0){
        let usize id=(state.views.names[i] as usize)-1;
        let usize closed=views::close(unit,ref mut state.views,id,at)?;}}
    i=16;while(i>0){i-=1;if((anonymous&bit(i))!=0){let usize dropped=drop(unit,state,i,at)?;}}
    i=state.names.count;while(i>mark){i-=1;
        if(state.bindings[i]!=0){let usize id=(state.bindings[i] as usize)-1;
            if((state.live&bit(id))!=0){
                result_required(unit,state,id);result_handled(unit,state,id);
                append(unit,90,id,0,at);state.live^=bit(id);
            }}
        state.bindings[i]=0;state.views.names[i]=0;state.names.begins[i]=0;state.names.ends[i]=0;
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
        prior.names.function!=current.names.function || prior.names.pending_places!=current.names.pending_places ||
        prior.enforce_results!=current.enforce_results || prior.tracking!=current.tracking){
        return .err(invalid(at));}
    // Stage only the small metadata state, rebased onto the current global
    // high-water mark. The stale entry must not pass header with its old next.
    var State staged=State{.names=locals::snapshot(ref prior.names),.bindings=prior.bindings,.views=prior.views,
        .next=current.next,.live=prior.live,.maybe=prior.maybe,.reads=prior.reads,.writes=prior.writes,.enforce_results=prior.enforce_results,.pending=prior.pending,
        .tracking=prior.tracking,.kills=prior.kills,.generated=prior.generated,.required=prior.required};
    staged.views.reserved=current.views.reserved;
    let usize valid=header(unit,ref staged,at)?;
    var usize i=prior.next;while(i<16){if(((prior.live|prior.maybe)&bit(i))!=0){return .err(invalid(at));}i+=1;}
    var usize seen=0;i=0;while(i<current.names.count){
        if(prior.bindings[i]!=current.bindings[i] || prior.views.names[i]!=current.views.names[i] || prior.names.begins[i]!=current.names.begins[i] ||
            prior.names.ends[i]!=current.names.ends[i] || prior.names.registers[i]!=current.names.registers[i] ||
            prior.names.mutable[i]!=current.names.mutable[i] || prior.names.begins[i]>prior.names.ends[i]){
            return .err(invalid(at));}
        if(prior.bindings[i]!=0){
            let usize id=binding(unit,ref staged,i,at)?;
            if(id>=prior.next || (seen&bit(id))!=0){return .err(invalid(at));}seen|=bit(id);
        }i+=1;
    }
    current.names=staged.names;current.bindings=staged.bindings;current.views=staged.views;current.live=staged.live;current.maybe=staged.maybe;current.reads=staged.reads;current.writes=staged.writes;
    current.enforce_results=staged.enforce_results;current.pending=staged.pending;
    current.kills=staged.kills;current.generated=staged.generated;current.required|=staged.required;
    return .ok(current.live);
}
// Trusted compile-only selection of an independently reached CFG block, including
// cleanup/alternative entries after a terminal return removed all current names.
// This does NOT restore runtime ownership. The complete independent value CFG
// verifier remains the executable authority. Keep code/type allocations intact.
pub fn Result<usize,errors::Error> select_path(ref values::Program unit,ref mut State current,
    ref Snapshot entry,usize at){
    let usize checked=header(unit,current,at)?;let ref State prior=ref entry.state;
    if(prior.next>current.next || prior.names.function!=current.names.function ||
        prior.enforce_results!=current.enforce_results || prior.tracking!=current.tracking){return .err(invalid(at));}
    var usize i=prior.next;while(i<16){if(((prior.live|prior.maybe)&bit(i))!=0){return .err(invalid(at));}i+=1;}
    var State staged=State{.names=locals::snapshot(ref prior.names),.bindings=prior.bindings,.views=prior.views,
        .next=current.next,.live=prior.live,.maybe=prior.maybe,.reads=prior.reads,.writes=prior.writes,.enforce_results=prior.enforce_results,.pending=prior.pending,
        .tracking=prior.tracking,.kills=prior.kills,.generated=prior.generated,.required=prior.required};
    staged.views.reserved=current.views.reserved;
    let usize valid=header(unit,ref staged,at)?;
    var usize seen=0;i=0;while(i<staged.names.count){
        if(staged.names.begins[i]>staged.names.ends[i]){return .err(invalid(at));}
        if(staged.bindings[i]!=0){let usize id=binding(unit,ref staged,i,at)?;
            if(id>=prior.next || (seen&bit(id))!=0){return .err(invalid(at));}seen|=bit(id);}
        i+=1;
    }
    current.names=staged.names;current.bindings=staged.bindings;current.views=staged.views;current.live=staged.live;current.maybe=staged.maybe;current.reads=staged.reads;current.writes=staged.writes;
    current.enforce_results=staged.enforce_results;current.pending=staged.pending;
    current.kills=staged.kills;current.generated=staged.generated;current.required|=staged.required;
    return .ok(current.live);
}
// A join preserves differing anonymous Buffer roots needed by surviving views.
// Definite liveness meets; possible liveness unions. Other conditional moves
// are normalized by the control layer. Retention governs lexical extension at
// the frontend, not immediate full-expression view dependencies at this join.
pub fn Result<usize,errors::Error> merge(ref values::Program unit,ref mut State state,ref Snapshot other,usize at){
    let usize checked=header(unit,state,at)?;let ref State prior=ref other.state;
    if(prior.next>state.next || prior.names.count!=state.names.count || prior.names.function!=state.names.function ||
        prior.names.pending_places!=state.names.pending_places ||
        prior.reads!=state.reads || prior.writes!=state.writes ||
        prior.enforce_results!=state.enforce_results || prior.tracking!=state.tracking){return .err(invalid(at));}
    var State staged=State{.names=locals::snapshot(ref prior.names),.bindings=prior.bindings,.views=prior.views,
        .next=state.next,.live=prior.live,.maybe=prior.maybe,.reads=prior.reads,.writes=prior.writes,.enforce_results=prior.enforce_results,.pending=prior.pending,
        .tracking=prior.tracking,.kills=prior.kills,.generated=prior.generated,.required=prior.required};
    let usize valid=header(unit,ref staged,at)?;
    var usize slot_id=prior.next;while(slot_id<16){
        if(((prior.live|prior.maybe)&bit(slot_id))!=0){return .err(invalid(at));}slot_id+=1;
    }
    var usize i=0;while(i<state.names.count){
        if(prior.bindings[i]!=state.bindings[i] || prior.names.begins[i]!=state.names.begins[i] ||
            prior.names.ends[i]!=state.names.ends[i] || prior.names.registers[i]!=state.names.registers[i] ||
            prior.names.mutable[i]!=state.names.mutable[i]){return .err(invalid(at));}i+=1;
    }
    // Merge descriptors into scratch so every late rejection is atomic.
    var views::State joined=state.views;
    let usize merged_views=views::merge(ref mut joined,ref prior.views,at)?;
    var usize roots=0;i=0;while(i<16){roots|=views::local_roots(ref joined,i);i+=1;}
    let usize changed=(state.live^prior.live)|(state.maybe^prior.maybe);
    if((changed&roots)!=changed){return .err(invalid(at));}
    i=0;while(i<16){if((changed&bit(i))!=0 &&
        (named_owner(state,i) || named_owner(ref staged,i) ||
        unit.catalog.nodes[values::type_id(unit,i)].kind!=4)){return .err(invalid(at));}i+=1;}
    let usize definite=state.live&prior.live;
    staged.live=definite;staged.maybe=(state.live|state.maybe|prior.live|prior.maybe)^definite;
    staged.views=joined;staged.pending|=state.pending;
    staged.kills&=state.kills;staged.generated|=state.generated;staged.required|=state.required;
    let usize authenticated=header(unit,ref staged,at)?;
    state.views=staged.views;state.live=staged.live;state.maybe=staged.maybe;
    state.pending=staged.pending;state.kills=staged.kills;
    state.generated=staged.generated;state.required=staged.required;return .ok(state.live);
}
