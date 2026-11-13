module value_view_bindings;
import value_ir as values;
import ir as ir;
import errors as errors;
import metadata_budget as budget;

// Compiler metadata, never runtime authority. Dead IDs are reusable within an
// activation; the independent CFG verifier proves every destination is Dead.
// Origins1..16 identify local Buffer slots; 17..24 identify formal ordinals.
// Encoding25 carries a normalized multi-root mask in sets; singleton/dead sets
// are zero. These conservative dependencies never grant native authority.
// retained marks CALL results whose anonymous actual may acquire a name.
// retained_sets holds only a union's partial retention; full retention uses the
// legacy retained bit and zero retained_sets, including for singleton origins.
pub struct State { u8[16] origins; usize[16] sets; usize[16] retained_sets; u8[64] names; usize function; usize retained; usize reserved; }
pub fn State empty(){return State{.origins=[0;16],.sets=[0;16],.retained_sets=[0;16],.names=[0;64],.function=0,.retained=0,.reserved=0};}
fn errors::Error invalid(usize at){return errors::make(3,at);}
fn u8 byte(usize n){var u8 result=0;var usize i=0;while(i<n){result+=1;i+=1;}return result;}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn bool descriptor(ref State state,usize id){
    let usize encoded=state.origins[id] as usize;let usize mask=state.sets[id];
    if(encoded<=24){return mask==0;}
    return encoded==25 && mask>0 && mask<=16777215 && (mask&(mask-1))!=0;
}
// Read only after descriptor validation. All shifts are bounded to 0..23.
fn usize mask_of(ref State state,usize id){
    let usize encoded=state.origins[id] as usize;
    if(encoded==25){return state.sets[id];}
    if(encoded==0){return 0;}return bit(encoded-1);
}
// Only validated nonzero low24 masks reach publication. Normalize singletons so
// existing singleton consumers cannot mistake a union for an individual root.
fn void represent(ref mut State state,usize id,usize mask){
    if((mask&(mask-1))==0){var usize root=0;while(root<24){
        if((mask&bit(root))!=0){state.origins[id]=byte(root+1);state.sets[id]=0;return;}root+=1;}
    }
    state.origins[id]=25;state.sets[id]=mask;
}
fn usize retained_mask_of(ref State state,usize id){
    if((state.retained&bit(id))!=0){return mask_of(state,id);}return state.retained_sets[id];
}
fn bool retention_descriptor(ref State state,usize id){
    let usize partial=state.retained_sets[id];let usize mask=mask_of(state,id);
    if(state.origins[id]==0 && (state.retained&bit(id))!=0){return false;}
    if(state.origins[id]!=25){return partial==0;}
    return (partial&mask)==partial && partial!=mask &&
        ((state.retained&bit(id))==0 || partial==0);
}
fn void represent_retention(ref mut State state,usize id,usize possible,usize retained){
    state.retained^=state.retained&bit(id);state.retained_sets[id]=0;
    if(retained==possible){state.retained|=bit(id);}
    else{if(state.origins[id]==25){state.retained_sets[id]=retained;}}
}
pub fn bool live(ref State state,usize id){return id<16 && descriptor(state,id) && state.origins[id]!=0;}
pub fn bool retainable(ref State state,usize id){return live(state,id) && (state.retained&bit(id))!=0;}
pub fn bool pinned(ref State state,usize owner){
    if(owner>=16){return false;}var usize i=0;
    while(i<16){if(live(state,i) && (mask_of(state,i)&bit(owner))!=0){return true;}i+=1;}return false;
}
pub fn usize count(ref State state){var usize n=0;var usize i=0;
    while(i<16){if(state.origins[i]!=0){n+=1;}i+=1;}return n;}
fn bool same_shape(ref State a,ref State b){if(a.function!=b.function || a.reserved!=b.reserved){return false;}var usize i=0;
    while(i<16){if((a.origins[i]==0)!=(b.origins[i]==0)){return false;}i+=1;}i=0;
    while(i<64){if(a.names[i]!=b.names[i]){return false;}i+=1;}return true;
}
pub fn bool same(ref State a,ref State b){
    if(a.retained!=b.retained || !same_shape(a,b)){return false;}var usize i=0;
    while(i<16){if(a.origins[i]!=b.origins[i] || a.sets[i]!=b.sets[i] ||
        a.retained_sets[i]!=b.retained_sets[i]){return false;}i+=1;}return true;
}
// A loop may replace a live header descriptor, but cannot change its identity,
// name, reservation or Live/Dead shape. Project the reached roots onto that
// exact header before ordinary temporary/scope cleanup. General expression
// cleanup keeps anonymous_since's stricter origin equality.
pub fn Result<State,errors::Error> loop_baseline(ref State state,ref State entry,usize at){
    let usize current=validate(state,at)?;let usize prior=validate(entry,at)?;
    if(state.function!=entry.function || state.reserved!=entry.reserved){return .err(invalid(at));}
    var State projected=State{.origins=entry.origins,.sets=entry.sets,.retained_sets=entry.retained_sets,
        .names=entry.names,.function=entry.function,.retained=entry.retained,.reserved=entry.reserved};var usize i=0;
    while(i<64){if(entry.names[i]!=0 && state.names[i]!=entry.names[i]){return .err(invalid(at));}i+=1;}
    i=0;while(i<16){if(entry.origins[i]!=0){
        if(state.origins[i]==0){return .err(invalid(at));}
        let usize mask=mask_of(state,i);represent(ref mut projected,i,mask);
        represent_retention(ref mut projected,i,mask,retained_mask_of(state,i));
    }i+=1;}return .ok(projected);
}
// Compiler CFG inference publishes only roots/retention. It never changes
// descriptors' exact shape/names, emits IR, or changes owner initialization.
// Missing-retention masks join monotonically alongside possible origins.
pub fn Result<usize,errors::Error> inferred(ref mut State state,ref usize[] possible,
    ref usize[] unretained,usize at){
    let usize checked=validate(state,at)?;
    if(possible.len!=16 || unretained.len!=16){return .err(invalid(at));}
    var usize i=0;while(i<16){
        let usize mask=possible[i];let usize missing=unretained[i];
        let usize prior_missing=mask_of(state,i)^retained_mask_of(state,i);
        if(mask>16777215 || (mask&missing)!=missing ||
            (state.origins[i]==0)!=(mask==0) || (mask&mask_of(state,i))!=mask_of(state,i) ||
            (missing&prior_missing)!=prior_missing){
            return .err(invalid(at));}i+=1;
    }
    i=0;while(i<16){if(possible[i]!=0){
        represent(state,i,possible[i]);represent_retention(state,i,possible[i],possible[i]^unretained[i]);
    }i+=1;}return .ok(checked);
}
// Retention meets only on paths where a dependency is possible. A root absent
// on one path loses no permission; an unretained occurrence on any path wins.
// Names, reservations and the live pattern stay exact.
pub fn Result<usize,errors::Error> merge(ref mut State state,ref State other,usize at){
    let usize a=validate(state,at)?;let usize b=validate(other,at)?;
    if(!same_shape(state,other)){return .err(invalid(at));}
    var usize i=0;while(i<16){if(state.origins[i]!=0){
        let usize left=mask_of(state,i);let usize right=mask_of(other,i);
        let usize ra=retained_mask_of(state,i);let usize rb=retained_mask_of(other,i);
        let usize retained=(ra&rb)|(ra^(ra&right))|(rb^(rb&left));
        let usize mask=left|right;represent(state,i,mask);represent_retention(state,i,mask,retained);
    }i+=1;}return .ok(a);
}
pub fn Result<usize,errors::Error> validate_raw(ref State state,usize at){
    if(state.function>=16 || state.retained>=65536 || state.reserved>=65536){return .err(invalid(at));}
    var usize i=0;while(i<16){if(!descriptor(state,i) || !retention_descriptor(state,i)){
            return .err(invalid(at));}
        i+=1;}
    var usize seen=0;let usize one=1;i=0;while(i<64){let usize encoded=state.names[i] as usize;
        if(encoded!=0){if(encoded>16){return .err(invalid(at));}let usize id=encoded-1;
            if(!live(state,id) || (seen&(one<<id))!=0){return .err(invalid(at));}seen|=one<<id;}
        i+=1;
    }return .ok(count(state));
}
pub fn Result<usize,errors::Error> origin(ref State state,usize id,usize at){
    let usize checked=roots(state,id,at)?;if(state.origins[id]==25){return .err(invalid(at));}
    return .ok((state.origins[id] as usize)-1);
}
// Structurally authenticated nonzero dependency mask. Program namespace and
// function ownership are additionally proved by authenticate before any append.
pub fn Result<usize,errors::Error> roots(ref State state,usize id,usize at){
    let usize checked=validate(state,at)?;if(!live(state,id)){return .err(invalid(at));}
    return .ok(mask_of(state,id));
}
// O(1) local accessors, not whole-state or Program authentication. Consumers
// first validate their header/roots; these guard only this descriptor's encoding.
pub fn usize local_roots(ref State state,usize id){
    if(id>=16 || !descriptor(state,id) || !retention_descriptor(state,id)){return 0;}
    return mask_of(state,id)&65535;
}
pub fn usize retained_roots(ref State state,usize id){
    if(id>=16 || !descriptor(state,id) || !retention_descriptor(state,id)){return 0;}
    return retained_mask_of(state,id);
}
// Static authentication only. The owning binding layer/caller admits liveness
// and argument loans; this module deliberately has no dependency on that layer.
fn Result<usize,errors::Error> owner_function(ref values::Program unit,usize owner,usize at){
    if(owner>=16 || unit.catalog.count>64 || unit.types[owner]==0 ||
        unit.types[owner] as usize>unit.catalog.count || unit.body.function_count==0 ||
        unit.body.function_count>16){return .err(invalid(at));}
    let usize f=unit.functions[owner] as usize;
    if(f>=unit.body.function_count || unit.catalog.nodes[values::type_id(unit,owner)].kind!=4){return .err(invalid(at));}
    return .ok(f);
}
fn Result<usize,errors::Error> function(ref values::Program unit,ref State state,usize at){
    let usize f=state.function;
    if(unit.body.function_count==0 || unit.body.function_count>16 || f>=unit.body.function_count ||
        unit.body.registers>128 || unit.body.register_starts[f]>unit.body.registers ||
        unit.body.arities[f]>8 || unit.body.arities[f]>unit.body.registers-unit.body.register_starts[f]){
        return .err(invalid(at));}return .ok(f);
}
fn Result<usize,errors::Error> formal_register(ref values::Program unit,usize f,usize ordinal,usize at){
    if(ordinal>=8 || ordinal>=unit.body.arities[f]){return .err(invalid(at));}
    let usize r=unit.body.register_starts[f]+ordinal;
    if(r>=unit.body.registers || unit.body.types[r]!=0 || unit.body.slots[r] ||
        unit.body.array_parameters[r]!=0 || unit.body.record_parameters[r]!=0 ||
        unit.body.slice_parameters[r]!=0){return .err(invalid(at));}return .ok(r);
}
fn Result<usize,errors::Error> origin_function(ref values::Program unit,usize f,usize owner,usize at){
    if(owner<16){let usize other=owner_function(unit,owner,at)?;
        if(other!=f){return .err(invalid(at));}
    }else{
        let usize r=formal_register(unit,f,owner-16,at)?;
        if(unit.parameters[r]<17 || unit.parameters[r]>32){return .err(invalid(at));}
    }return .ok(f);
}
// Authenticate the whole compile-only view state against its current function.
// Closed/reused entry IDs need not still describe the original formal itself.
pub fn Result<usize,errors::Error> authenticate_raw(ref values::Program unit,ref State state,usize at){
    let usize checked=validate_raw(state,at)?;let usize f=function(unit,state,at)?;
    var usize dependencies=0;var usize i=0;
    while(i<16){dependencies|=mask_of(state,i);i+=1;}
    i=0;while(i<24){if((dependencies&bit(i))!=0){
        let usize other=origin_function(unit,f,i,at)?;
    }i+=1;}return .ok(f);
}
fn Result<usize,errors::Error> preflight(ref values::Program unit,ref State state,usize owner,usize at){
    let usize f=authenticate(unit,state,at)?;return origin_function(unit,f,owner,at);
}
fn Result<usize,errors::Error> capacity(ref values::Program unit,usize needed,usize at){
    if(unit.body.count>256 || needed>256-unit.body.count){return .err(errors::make(4,at));}
    return .ok(needed);
}
fn Result<usize,errors::Error> free(ref State state,usize at){
    var usize i=0;while(i<16){if(state.origins[i]==0 && (state.reserved&bit(i))==0){return .ok(i);}i+=1;}
    return .err(errors::make(4,at));
}
// Active value joins reserve a destination across compiler alternative selection.
// This does not create a live descriptor, emit IR or grant runtime authority.
pub fn Result<usize,errors::Error> reserve(ref values::Program unit,ref mut State state,usize at){
    let usize f=authenticate(unit,state,at)?;let usize id=free(state,at)?;
    state.reserved|=bit(id);return .ok(id);
}
pub fn Result<usize,errors::Error> unreserve(ref mut State state,usize id,usize at){
    let usize checked=validate(state,at)?;
    if(id>=16 || (state.reserved&bit(id))==0){return .err(invalid(at));}
    state.reserved^=bit(id);return .ok(id);
}
fn Result<usize,errors::Error> scalar_register(ref values::Program unit,usize f,usize id,usize at){
    let ref ir::Program p=ref unit.body;
    if(id>=p.registers || id<p.register_starts[f] || p.types[id]!=12 || p.slots[id] ||
        unit.parameters[id]!=0 || p.array_parameters[id]!=0 || p.record_parameters[id]!=0 ||
        p.slice_parameters[id]!=0){return .err(invalid(at));}return .ok(id);
}
// All callers preflight operands/capacity before this infallible append.
fn void append(ref mut values::Program unit,u8 op,usize dst,usize a,usize b,usize hi,usize at){
    let usize pc=unit.body.count;let usize start=pc*8;
    unit.body.code[start]=op;unit.body.code[start+1]=byte(dst);unit.body.code[start+2]=byte(a);
    unit.body.code[start+3]=byte(b);unit.body.code[start+4]=byte(hi);
    unit.body.code[start+5]=0;unit.body.code[start+6]=0;unit.body.code[start+7]=0;
    unit.body.offsets[pc]=at;unit.body.count=pc+1;
}
pub fn Result<usize,errors::Error> begin(ref mut values::Program unit,ref mut State state,
    usize owner,usize lo,usize hi,usize at){
    if(owner>=16){return .err(invalid(at));}
    let usize f=preflight(unit,state,owner,at)?;
    let usize low=scalar_register(unit,f,lo,at)?;let usize high=scalar_register(unit,f,hi,at)?;
    let usize dst=free(state,at)?;let usize room=capacity(unit,1,at)?;
    append(unit,105,dst,owner,lo,hi,at);represent(state,dst,bit(owner));return .ok(dst);
}
pub fn Result<usize,errors::Error> range(ref mut values::Program unit,ref mut State state,
    usize parent,usize lo,usize hi,usize at){
    let usize mask=roots(state,parent,at)?;let usize f=authenticate(unit,state,at)?;
    let usize retained=retained_mask_of(state,parent);
    let usize low=scalar_register(unit,f,lo,at)?;let usize high=scalar_register(unit,f,hi,at)?;
    let usize dst=free(state,at)?;let usize room=capacity(unit,1,at)?;
    append(unit,106,dst,parent,lo,hi,at);represent(state,dst,mask);
    represent_retention(state,dst,mask,retained);return .ok(dst);
}
pub fn Result<usize,errors::Error> alias(ref mut values::Program unit,ref mut State state,usize source,usize at){
    let usize mask=roots(state,source,at)?;let usize f=authenticate(unit,state,at)?;
    let usize retained=retained_mask_of(state,source);
    let usize dst=free(state,at)?;let usize room=capacity(unit,1,at)?;
    append(unit,107,dst,source,0,0,at);represent(state,dst,mask);
    represent_retention(state,dst,mask,retained);return .ok(dst);
}
pub fn Result<usize,errors::Error> move_to(ref mut values::Program unit,ref mut State state,
    usize source,usize destination,usize at){
    let usize mask=roots(state,source,at)?;let usize f=authenticate(unit,state,at)?;
    let usize retained=retained_mask_of(state,source);
    if(destination>=16 || state.origins[destination]!=0){return .err(invalid(at));}
    let usize room=capacity(unit,1,at)?;
    append(unit,108,destination,source,0,0,at);
    represent(state,destination,mask);represent_retention(state,destination,mask,retained);
    state.retained^=state.retained&bit(source);
    state.origins[source]=0;state.sets[source]=0;state.retained_sets[source]=0;
    var usize i=0;while(i<64){if(state.names[i] as usize==source+1){state.names[i]=byte(destination+1);}i+=1;}
    return .ok(destination);
}
// Detach names on CLOSE so a reused Dead ID cannot revive a stale lexical name.
// The owning layer retains the shared Table entry until lexical scope removal.
fn void forget(ref mut State state,usize id){state.origins[id]=0;state.sets[id]=0;state.retained_sets[id]=0;state.retained^=state.retained&bit(id);var usize i=0;
    while(i<64){if(state.names[i] as usize==id+1){state.names[i]=0;}i+=1;}}
// Parent installs register starts/arities first; this emits no executable IR.
pub fn Result<usize,errors::Error> formal(ref mut values::Program unit,ref mut State state,
    usize f,usize ordinal,usize at){
    let usize checked=authenticate(unit,state,at)?;
    if(f!=checked){return .err(invalid(at));}
    let usize r=formal_register(unit,f,ordinal,at)?;
    if(unit.parameters[r]!=0){return .err(invalid(at));}
    let usize dst=free(state,at)?;
    represent(state,dst,bit(16+ordinal));unit.parameters[r]=byte(17+dst);return .ok(dst);
}
// Parent emits CALL114 before closing actual captures. Retaining this extra
// descriptor pins even an anonymous actual until the last returned alias closes.
pub fn Result<usize,errors::Error> call_result(ref mut values::Program unit,ref mut State state,
    usize actual_view,usize at){
    let usize mask=roots(state,actual_view,at)?;let usize f=authenticate(unit,state,at)?;
    let usize dst=free(state,at)?;represent(state,dst,mask);
    represent_retention(state,dst,mask,mask);return .ok(dst);
}
// Detach only the compile-time descriptor. No allocation may occur between this
// handoff and terminal RETURN113; cleanup must leave the runtime view untouched.
pub fn Result<usize,errors::Error> take_return(ref values::Program unit,ref mut State state,
    usize id,usize at){
    let usize mask=roots(state,id,at)?;let usize f=authenticate(unit,state,at)?;
    let usize selected=unit.results[f] as usize;
    if(selected<17 || selected>24){return .err(invalid(at));}
    if(mask!=bit(selected-1)){return .err(invalid(at));}
    forget(state,id);return .ok(id);
}
pub fn Result<usize,errors::Error> close(ref mut values::Program unit,ref mut State state,usize id,usize at){
    let usize mask=roots(state,id,at)?;let usize f=authenticate(unit,state,at)?;
    let usize room=capacity(unit,1,at)?;append(unit,109,id,0,0,0,at);forget(state,id);return .ok(id);
}
pub fn Result<usize,errors::Error> scalar(ref mut values::Program unit,ref State state,
    u8 op,usize source,usize index,usize at){
    if(op!=110 && op!=111){return .err(invalid(at));}
    let usize mask=roots(state,source,at)?;let usize f=authenticate(unit,state,at)?;
    if(op==110){if(index!=0){return .err(invalid(at));}}
    else{let usize checked=scalar_register(unit,f,index,at)?;}
    let usize room=capacity(unit,1,at)?;let usize dst=unit.body.registers;
    if(dst==128){return .err(errors::make(4,at));}
    if(unit.body.types[dst]!=0 || unit.body.slots[dst] || unit.parameters[dst]!=0 ||
        unit.body.array_parameters[dst]!=0 || unit.body.record_parameters[dst]!=0 ||
        unit.body.slice_parameters[dst]!=0){return .err(invalid(at));}
    append(unit,op,dst,source,index,0,at);unit.body.types[dst]=if(op==110){12}else{10};
    unit.body.registers=dst+1;return .ok(dst);
}
pub fn Result<usize,errors::Error> close_all(ref mut values::Program unit,ref mut State state,usize at){
    let usize f=authenticate(unit,state,at)?;let usize checked=count(state);var usize i=0;
    let usize room=capacity(unit,checked,at)?;i=16;while(i>0){i-=1;
        if(state.origins[i]!=0){append(unit,109,i,0,0,0,at);forget(state,i);}}
    return .ok(checked);
}
// Close newly introduced anonymous descriptors, preserving the baseline's exact
// live origins/names. Named inner views belong to leave_scope's ordered cleanup.
pub fn Result<usize,errors::Error> anonymous_since(ref State state,ref State baseline,usize at){
    let usize checked=validate(state,at)?;let usize prior=validate(baseline,at)?;
    if(state.function!=baseline.function){return .err(invalid(at));}
    var usize mask=0;let usize one=1;var usize i=0;while(i<64){
        if(baseline.names[i]!=0 && baseline.names[i]!=state.names[i]){return .err(invalid(at));}i+=1;}
    var bool[16] named=[false;16];i=0;while(i<64){if(state.names[i]!=0){named[(state.names[i] as usize)-1]=true;}i+=1;}
    i=0;while(i<16){
        if(baseline.origins[i]!=0 && (baseline.origins[i]!=state.origins[i] || baseline.sets[i]!=state.sets[i])){
            return .err(invalid(at));}
        if(baseline.origins[i]!=0 && retained_mask_of(state,i)!=retained_mask_of(baseline,i)){return .err(invalid(at));}
        if(state.origins[i]!=0 && baseline.origins[i]==0 && !named[i]){mask|=one<<i;}
        i+=1;
    }
    return .ok(mask);
}
pub fn Result<usize,errors::Error> close_since(ref mut values::Program unit,ref mut State state,
    ref State baseline,usize at){
    let usize mask=anonymous_since(state,baseline,at)?;let usize f=authenticate(unit,state,at)?;
    let usize one=1;var usize needed=0;var usize i=0;
    while(i<16){
        if((mask&(one<<i))!=0){needed+=1;}i+=1;}
    let usize room=capacity(unit,needed,at)?;i=16;while(i>0){i-=1;
        if((mask&(one<<i))!=0){append(unit,109,i,0,0,0,at);forget(state,i);}}
    return .ok(needed);
}

// Compiler-only counterpart of a same-activation Buffer MOVE. Every descriptor
// keeps its lease/range/identity; only the canonical owning slot is renamed.
pub fn Result<usize,errors::Error> relocate(ref mut State state,usize source,usize destination,usize at){
    let usize checked=validate(state,at)?;
    if(source>=16 || destination>=16 || source==destination || pinned(state,destination)){return .err(invalid(at));}
    var usize i=0;while(i<16){if(live(state,i)){
        let usize roots=mask_of(state,i);let usize retained=retained_mask_of(state,i);
        if((roots&bit(source))!=0){
            let usize next=(roots^bit(source))|bit(destination);
            let usize keep=if((retained&bit(source))!=0){(retained^bit(source))|bit(destination)}else{retained};
            represent(state,i,next);represent_retention(state,i,next,keep);
        }
    }i+=1;}return .ok(destination);
}

// Read-only cursor: one descriptor/name/dependency per stage, no authority.
pub struct Auth { usize at; usize row; usize seen; usize count; usize dependencies; usize function; u8 phase; bool program; bool done; }
pub fn Auth auth(usize at,bool program){return Auth{.at=at,.row=0,.seen=0,.count=0,.dependencies=0,.function=0,.phase=0,.program=program,.done=false};}
pub fn Result<usize,errors::Error> auth_result(ref Auth w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(if(w.program){w.function}else{w.count});}
pub fn Result<bool,errors::Error> advance_auth(ref State state,ref mut Auth w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    let usize i=w.row;let usize at=w.at;
    if(w.phase==0){if(state.function>=16 || state.retained>=65536 || state.reserved>=65536){return .err(invalid(at));}w.phase=1;return .ok(false);}
    if(w.phase==1){if(i==16){w.row=0;w.phase=2;return .ok(false);}if(!descriptor(state,i) || !retention_descriptor(state,i)){return .err(invalid(at));}w.row+=1;return .ok(false);}
    if(w.phase==2){if(i==64){w.row=0;w.phase=3;return .ok(false);}let usize encoded=state.names[i] as usize;
        if(encoded!=0){if(encoded>16){return .err(invalid(at));}let usize id=encoded-1;
            if(!live(state,id) || (w.seen&bit(id))!=0){return .err(invalid(at));}w.seen|=bit(id);}w.row+=1;return .ok(false);}
    if(w.phase==3){if(i==16){w.row=0;if(w.program){w.phase=4;}else{w.done=true;}return .ok(w.done);}
        if(state.origins[i]!=0){w.count+=1;}w.row+=1;return .ok(false);}
    return .err(errors::make(5,at));
}
pub fn Result<bool,errors::Error> advance_program_auth(ref values::Program unit,ref State state,ref mut Auth w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}if(w.phase<4){return advance_auth(state,w,meter);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}let usize i=w.row;
    if(w.phase==4){w.function=function(unit,state,w.at)?;w.phase=5;return .ok(false);}
    if(w.phase==5){if(i==16){w.row=0;w.phase=6;return .ok(false);}w.dependencies|=mask_of(state,i);w.row+=1;return .ok(false);}
    if(w.phase==6){if(i==24){w.done=true;return .ok(true);}if((w.dependencies&bit(i))!=0){let usize checked=origin_function(unit,w.function,i,w.at)?;}w.row+=1;return .ok(false);}
    return .err(errors::make(5,w.at));
}
pub fn Result<usize,errors::Error> validate(ref State state,usize at){var Auth w=auth(at,false);var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,at)?;let bool done=advance_auth(state,ref mut w,ref mut meter)?;}return auth_result(ref w);}
pub fn Result<usize,errors::Error> authenticate(ref values::Program unit,ref State state,usize at){var Auth w=auth(at,true);var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,at)?;let bool done=advance_program_auth(unit,state,ref mut w,ref mut meter)?;}return auth_result(ref w);}
