module value_view_bindings;
import value_ir as values;
import ir as ir;
import errors as errors;

// Compiler metadata, never runtime authority. Dead IDs are reusable within an
// activation; the independent CFG verifier proves every destination is Dead.
pub struct State { u8[16] origins; u8[64] names; }
pub fn State empty(){return State{.origins=[0;16],.names=[0;64]};}
fn errors::Error invalid(usize at){return errors::make(3,at);}
fn u8 byte(usize n){var u8 result=0;var usize i=0;while(i<n){result+=1;i+=1;}return result;}
pub fn bool live(ref State state,usize id){return id<16 && state.origins[id]!=0 && state.origins[id]<=16;}
pub fn bool pinned(ref State state,usize owner){
    if(owner>=16){return false;}var usize i=0;
    while(i<16){if(state.origins[i] as usize==owner+1){return true;}i+=1;}return false;
}
pub fn usize count(ref State state){var usize n=0;var usize i=0;
    while(i<16){if(state.origins[i]!=0){n+=1;}i+=1;}return n;}
pub fn bool same(ref State a,ref State b){var usize i=0;
    while(i<16){if(a.origins[i]!=b.origins[i]){return false;}i+=1;}i=0;
    while(i<64){if(a.names[i]!=b.names[i]){return false;}i+=1;}return true;
}
pub fn Result<usize,errors::Error> validate(ref State state,usize at){
    var usize i=0;while(i<16){if(state.origins[i]>16){return .err(invalid(at));}i+=1;}
    var usize seen=0;let usize one=1;i=0;while(i<64){let usize encoded=state.names[i] as usize;
        if(encoded!=0){if(encoded>16){return .err(invalid(at));}let usize id=encoded-1;
            if(!live(state,id) || (seen&(one<<id))!=0){return .err(invalid(at));}seen|=one<<id;}
        i+=1;
    }return .ok(count(state));
}
pub fn Result<usize,errors::Error> origin(ref State state,usize id,usize at){
    let usize checked=validate(state,at)?;if(!live(state,id)){return .err(invalid(at));}
    return .ok((state.origins[id] as usize)-1);
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
fn Result<usize,errors::Error> preflight(ref values::Program unit,ref State state,usize owner,usize at){
    let usize checked=validate(state,at)?;let usize f=owner_function(unit,owner,at)?;
    if(unit.body.registers>128 || unit.body.register_starts[f]>unit.body.registers){return .err(invalid(at));}
    var usize i=0;while(i<16){if(state.origins[i]!=0){
        let usize other=owner_function(unit,(state.origins[i] as usize)-1,at)?;
        if(other!=f){return .err(invalid(at));}
    }i+=1;}return .ok(f);
}
fn Result<usize,errors::Error> capacity(ref values::Program unit,usize needed,usize at){
    if(unit.body.count>256 || needed>256-unit.body.count){return .err(errors::make(4,at));}
    return .ok(needed);
}
fn Result<usize,errors::Error> free(ref State state,usize at){
    var usize i=0;while(i<16){if(state.origins[i]==0){return .ok(i);}i+=1;}
    return .err(errors::make(4,at));
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
    let usize f=preflight(unit,state,owner,at)?;
    let usize low=scalar_register(unit,f,lo,at)?;let usize high=scalar_register(unit,f,hi,at)?;
    let usize dst=free(state,at)?;let usize room=capacity(unit,1,at)?;
    append(unit,105,dst,owner,lo,hi,at);state.origins[dst]=byte(owner+1);return .ok(dst);
}
pub fn Result<usize,errors::Error> range(ref mut values::Program unit,ref mut State state,
    usize parent,usize lo,usize hi,usize at){
    let usize owner=origin(state,parent,at)?;let usize f=preflight(unit,state,owner,at)?;
    let usize low=scalar_register(unit,f,lo,at)?;let usize high=scalar_register(unit,f,hi,at)?;
    let usize dst=free(state,at)?;let usize room=capacity(unit,1,at)?;
    let u8 encoded=state.origins[parent];
    append(unit,106,dst,parent,lo,hi,at);state.origins[dst]=encoded;return .ok(dst);
}
pub fn Result<usize,errors::Error> alias(ref mut values::Program unit,ref mut State state,usize source,usize at){
    let usize owner=origin(state,source,at)?;let usize f=preflight(unit,state,owner,at)?;
    let usize dst=free(state,at)?;let usize room=capacity(unit,1,at)?;
    let u8 encoded=state.origins[source];
    append(unit,107,dst,source,0,0,at);state.origins[dst]=encoded;return .ok(dst);
}
pub fn Result<usize,errors::Error> move_to(ref mut values::Program unit,ref mut State state,
    usize source,usize destination,usize at){
    let usize owner=origin(state,source,at)?;let usize f=preflight(unit,state,owner,at)?;
    if(destination>=16 || state.origins[destination]!=0){return .err(invalid(at));}
    let usize room=capacity(unit,1,at)?;
    let u8 encoded=state.origins[source];append(unit,108,destination,source,0,0,at);
    state.origins[destination]=encoded;state.origins[source]=0;
    var usize i=0;while(i<64){if(state.names[i] as usize==source+1){state.names[i]=byte(destination+1);}i+=1;}
    return .ok(destination);
}
// Detach names on CLOSE so a reused Dead ID cannot revive a stale lexical name.
// The owning layer retains the shared Table entry until lexical scope removal.
fn void forget(ref mut State state,usize id){state.origins[id]=0;var usize i=0;
    while(i<64){if(state.names[i] as usize==id+1){state.names[i]=0;}i+=1;}}
pub fn Result<usize,errors::Error> close(ref mut values::Program unit,ref mut State state,usize id,usize at){
    let usize owner=origin(state,id,at)?;let usize f=preflight(unit,state,owner,at)?;
    let usize room=capacity(unit,1,at)?;append(unit,109,id,0,0,0,at);forget(state,id);return .ok(id);
}
pub fn Result<usize,errors::Error> scalar(ref mut values::Program unit,ref State state,
    u8 op,usize source,usize index,usize at){
    if(op!=110 && op!=111){return .err(invalid(at));}
    let usize owner=origin(state,source,at)?;let usize f=preflight(unit,state,owner,at)?;
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
    let usize checked=validate(state,at)?;var usize i=0;
    while(i<16){if(state.origins[i]!=0){let usize f=preflight(unit,state,(state.origins[i] as usize)-1,at)?;}i+=1;}
    let usize room=capacity(unit,checked,at)?;i=16;while(i>0){i-=1;
        if(state.origins[i]!=0){append(unit,109,i,0,0,0,at);forget(state,i);}}
    return .ok(checked);
}
// Close newly introduced anonymous descriptors, preserving the baseline's exact
// live origins/names. Named inner views belong to leave_scope's ordered cleanup.
pub fn Result<usize,errors::Error> anonymous_since(ref State state,ref State baseline,usize at){
    let usize checked=validate(state,at)?;let usize prior=validate(baseline,at)?;
    var usize mask=0;let usize one=1;var usize i=0;while(i<64){
        if(baseline.names[i]!=0 && baseline.names[i]!=state.names[i]){return .err(invalid(at));}i+=1;}
    var bool[16] named=[false;16];i=0;while(i<64){if(state.names[i]!=0){named[(state.names[i] as usize)-1]=true;}i+=1;}
    i=0;while(i<16){
        if(baseline.origins[i]!=0 && baseline.origins[i]!=state.origins[i]){return .err(invalid(at));}
        if(state.origins[i]!=0 && baseline.origins[i]==0 && !named[i]){mask|=one<<i;}
        i+=1;
    }
    return .ok(mask);
}
pub fn Result<usize,errors::Error> close_since(ref mut values::Program unit,ref mut State state,
    ref State baseline,usize at){
    let usize mask=anonymous_since(state,baseline,at)?;let usize one=1;var usize needed=0;var usize i=0;
    while(i<16){if(state.origins[i]!=0){let usize f=preflight(unit,state,(state.origins[i] as usize)-1,at)?;}
        if((mask&(one<<i))!=0){needed+=1;}i+=1;}
    let usize room=capacity(unit,needed,at)?;i=16;while(i>0){i-=1;
        if((mask&(one<<i))!=0){append(unit,109,i,0,0,0,at);forget(state,i);}}
    return .ok(needed);
}
