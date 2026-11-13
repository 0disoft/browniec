module value_source_ops;
import value_ir as values;
import value_source_bindings as bindings;
import value_properties as properties;
import value_source_properties as source_properties;
import errors as errors;

pub struct Case { usize instruction; usize payload; }

fn errors::Error invalid(usize at){return errors::make(3,at);}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn u8 byte(usize value){var u8 result=0;var usize i=0;while(i<value){result+=1;i+=1;}return result;}
// Validate the same monotonic ledger as bindings before any allocation/emission.
// Function ends are finalized by the caller after lowering the complete body.
pub fn Result<properties::Plan,errors::Error> preflight(ref values::Program unit,ref bindings::State state,usize at){
    let usize checked=bindings::authenticate(unit,state,at)?;
    let properties::Plan plan=switch(source_properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(invalid(at));}
    };
    if(unit.body.count>=256 || unit.body.registers>128){return .err(errors::make(4,at));}
    let usize f=state.names.function;
    if(unit.body.register_starts[f]>unit.body.registers){
        return .err(invalid(at));}
    return .ok(plan);
}
fn Result<usize,errors::Error> live(ref values::Program unit,ref bindings::State state,usize id,usize at){
    if(id>=state.next || !values::slot(unit,id,state.names.function) || (state.live&bit(id))==0){
        return .err(invalid(at));}return .ok(id);
}
fn Result<usize,errors::Error> destination(ref properties::Plan plan,ref bindings::State state,usize exact_type,usize at){
    if(exact_type>=plan.count){return .err(invalid(at));}
    if(state.next==16){return .err(errors::make(4,at));}return .ok(state.next);
}
// ir::raw writes op before fallible byte conversions, and does not clear the
// reserved bytes. Here all operands/counts are admitted first; append cannot fail.
fn void append(ref mut values::Program unit,u8 op,usize dst,usize a,u8 b,usize at){
    let usize pc=unit.body.count;let usize start=pc*8;
    unit.body.code[start]=op;unit.body.code[start+1]=byte(dst);
    unit.body.code[start+2]=byte(a);unit.body.code[start+3]=b;
    unit.body.code[start+4]=0;unit.body.code[start+5]=0;
    unit.body.code[start+6]=0;unit.body.code[start+7]=0;
    unit.body.offsets[pc]=at;unit.body.count=pc+1;
}
pub fn Result<usize,errors::Error> empty_buffer(ref mut values::Program unit,ref mut bindings::State state,usize exact_type,usize at){
    let properties::Plan plan=preflight(unit,state,at)?;
    let usize checked=destination(ref plan,state,exact_type,at)?;
    if(unit.catalog.nodes[exact_type].kind!=4){return .err(invalid(at));}
    let usize dst=bindings::allocate(unit,state,exact_type,at)?;
    append(unit,95,dst,0,0,at);return bindings::initialize(unit,state,dst,at);
}
pub fn Result<usize,errors::Error> scalar_value(ref mut values::Program unit,ref mut bindings::State state,
    usize register,usize exact_type,usize at){
    let properties::Plan plan=preflight(unit,state,at)?;
    let usize checked=destination(ref plan,state,exact_type,at)?;
    let properties::Node node=unit.catalog.nodes[exact_type];let usize f=state.names.function;
    if(node.kind!=1 || register>=unit.body.registers || register<unit.body.register_starts[f] ||
        unit.body.types[register]!=node.first || unit.body.slots[register] || unit.parameters[register]!=0 ||
        unit.body.array_parameters[register]!=0 || unit.body.record_parameters[register]!=0 ||
        unit.body.slice_parameters[register]!=0){return .err(invalid(at));}
    let usize dst=bindings::allocate(unit,state,exact_type,at)?;
    append(unit,97,dst,register,0,at);return bindings::initialize(unit,state,dst,at);
}
pub fn Result<usize,errors::Error> scalar_read(ref mut values::Program unit,ref mut bindings::State state,usize source,usize at){
    let properties::Plan plan=preflight(unit,state,at)?;
    let usize checked=live(unit,state,source,at)?;
    let properties::Node node=unit.catalog.nodes[values::type_id(unit,source)];
    if(node.kind!=1){return .err(invalid(at));}
    if(unit.body.registers==128){return .err(errors::make(4,at));}
    let usize dst=unit.body.registers;
    if(unit.body.types[dst]!=0 || unit.body.slots[dst] || unit.parameters[dst]!=0 ||
        unit.body.array_parameters[dst]!=0 || unit.body.record_parameters[dst]!=0 ||
        unit.body.slice_parameters[dst]!=0){return .err(invalid(at));}
    append(unit,96,dst,source,0,at);unit.body.types[dst]=node.first;unit.body.registers=dst+1;
    return .ok(dst);
}
// A predicate allocates only an ordinary bool register. Whole-wrapper liveness,
// including active/inactive Buffer alternatives, is unchanged on every path.
pub fn Result<usize,errors::Error> tag_test(ref mut values::Program unit,ref mut bindings::State state,
    usize source,u8 variant,usize at){
    let properties::Plan plan=preflight(unit,state,at)?;
    let usize checked=live(unit,state,source,at)?;
    let properties::Node node=unit.catalog.nodes[values::type_id(unit,source)];
    if((node.kind!=5 && node.kind!=6) || variant>1){return .err(invalid(at));}
    if(unit.body.registers==128){return .err(errors::make(4,at));}
    let usize dst=unit.body.registers;
    if(unit.body.types[dst]!=0 || unit.body.slots[dst] || unit.parameters[dst]!=0 ||
        unit.body.array_parameters[dst]!=0 || unit.body.record_parameters[dst]!=0 ||
        unit.body.slice_parameters[dst]!=0){return .err(invalid(at));}
    let usize handled=bindings::handle(unit,state,source,at)?;
    append(unit,98,dst,source,variant,at);unit.body.types[dst]=2;unit.body.registers=dst+1;
    return .ok(dst);
}
// Shared admission for fresh and preallocated wrappers. All fallible payload
// checks, including handle/consume loan checks, precede allocation or emission.
fn Result<bool,errors::Error> tag_payload(ref values::Program unit,ref bindings::State state,
    ref properties::Plan plan,usize exact_type,usize payload,u8 variant,usize at){
    let properties::Node node=unit.catalog.nodes[exact_type];
    if((node.kind!=5 && node.kind!=6) || variant>1){return .err(invalid(at));}
    let bool none=node.kind==5 && variant==0;var bool moved=false;
    if(none){if(payload!=16){return .err(invalid(at));}}
    else{
        let usize admitted=live(unit,state,payload,at)?;
        let usize child=if(variant==1){node.first as usize}else{node.second as usize};
        if(values::type_id(unit,payload)!=child || ((state.reads|state.writes)&bit(payload))!=0){
            return .err(invalid(at));}
        moved=!plan.properties[child].copyable;
    }
    return .ok(moved);
}
// Called only with an admitted Dead destination and payload. Metadata hooks
// cannot reject after this preflight; no slot or register cursor changes here.
fn Result<usize,errors::Error> publish_tag(ref mut values::Program unit,ref mut bindings::State state,
    usize dst,usize payload,u8 variant,bool moved,usize at){
    let bool none=payload==16;
    if(!none){let usize handled=bindings::handle(unit,state,payload,at)?;}
    append(unit,91,dst,if(none){0}else{payload},variant,at);
    if(moved){let usize consumed=bindings::consume(unit,state,payload,at)?;}
    return bindings::initialize(unit,state,dst,at);
}
// exact_type and child IDs are canonical zero-based catalog nodes. Option.none
// requires payload16 (never a real slot), encoded as a0. Copyable children stay
// live: the parent explicitly drops anonymous children after successful wrapping.
pub fn Result<usize,errors::Error> tag(ref mut values::Program unit,ref mut bindings::State state,
    usize exact_type,usize payload,u8 variant,usize at){
    let properties::Plan plan=preflight(unit,state,at)?;
    let usize checked=destination(ref plan,state,exact_type,at)?;
    let bool moved=tag_payload(unit,state,ref plan,exact_type,payload,variant,at)?;
    let usize dst=bindings::allocate(unit,state,exact_type,at)?;
    return publish_tag(unit,state,dst,payload,variant,moved,at);
}
// Initialize an existing exact Option/Result slot on this CFG path. Unlike tag,
// this remains usable at the sixteen-slot high-water mark and never allocates.
pub fn Result<usize,errors::Error> tag_into(ref mut values::Program unit,ref mut bindings::State state,
    usize destination,usize payload,u8 variant,usize at){
    let properties::Plan plan=preflight(unit,state,at)?;
    if(destination>=state.next || !values::slot(unit,destination,state.names.function) ||
        ((state.live|state.maybe)&bit(destination))!=0){return .err(invalid(at));}
    let bool moved=tag_payload(unit,state,ref plan,values::type_id(unit,destination),payload,variant,at)?;
    return publish_tag(unit,state,destination,payload,variant,moved,at);
}
// Select the matching compiler path only. The caller keeps the entry snapshot
// for the mismatch block and selects it with bindings::select_path; snapshots
// describe compiler metadata and never transfer native ownership. Copyable
// subjects remain live and require the caller's explicit anonymous-value DROP.
// Option.none has payload16 (no allocation), encoded with the canonical dst0.
pub fn Result<Case,errors::Error> case_value(ref mut values::Program unit,ref mut bindings::State state,
    usize source,u8 variant,usize at){
    let properties::Plan plan=preflight(unit,state,at)?;
    let usize checked=live(unit,state,source,at)?;
    let usize exact_type=values::type_id(unit,source);
    let properties::Node node=unit.catalog.nodes[exact_type];
    if((node.kind!=5 && node.kind!=6) || variant>1){return .err(invalid(at));}
    let bool none=node.kind==5 && variant==0;var usize payload=16;
    if(!none){
        let usize child=if(variant==1){node.first as usize}else{node.second as usize};
        let usize admitted=destination(ref plan,state,child,at)?;
        payload=admitted;
    }
    let usize handled=bindings::handle(unit,state,source,at)?;
    if(!none){let usize allocated=bindings::allocate(unit,state,
        if(variant==1){node.first as usize}else{node.second as usize},at)?;}
    let usize instruction=unit.body.count;
    append(unit,92,if(none){0}else{payload},source,variant,at);
    if(!plan.properties[exact_type].copyable){let usize consumed=bindings::consume(unit,state,source,at)?;}
    if(!none){let usize initialized=bindings::initialize(unit,state,payload,at)?;}
    return .ok(Case{.instruction=instruction,.payload=payload});
}
// A forward block may not have been emitted yet (including target == count).
// Final independent admission still requires an in-function instruction target.
pub fn Result<usize,errors::Error> patch_case(ref mut values::Program unit,usize instruction,usize target,usize at){
    if(unit.body.count>256 || instruction>=unit.body.count || target<=instruction || target>=256){
        return .err(invalid(at));}
    if(unit.body.code[instruction*8]!=92){return .err(invalid(at));}
    unit.body.code[instruction*8+4]=byte(target);return .ok(instruction);
}
