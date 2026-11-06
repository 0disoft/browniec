module value_source_boolean;
import value_ir as values;
import value_source_bindings as bindings;
import value_source_control as branches;
import value_source_loops as looping;
import ir as ir;
import errors as errors;
import std::vec as vec;

// Short-circuit edges preserve argument loans and normalize conditional moves
// through the same independently verified joins as if/switch expressions.
pub struct Pending { usize slot; usize guard; usize entry; usize pool; }
pub fn Result<Pending,errors::Error> begin(ref mut values::Program unit,ref bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,u8 operation,usize left,usize at){
    if((operation!=132 && operation!=133) || left>=unit.body.registers ||
        unit.body.types[left]!=2){return .err(errors::make(3,at));}
    let usize slot=ir::slot(ref mut unit.body,2,at)?;
    let usize stored=ir::raw(ref mut unit.body,18,slot,left,0,at)?;
    let usize guard=ir::raw(ref mut unit.body,if(operation==132){20}else{21},0,left,0,at)?;
    let usize pool=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;
    return .ok(Pending{.slot=slot,.guard=guard,.entry=entry,.pool=pool});
}
pub fn Result<usize,errors::Error> finish(ref mut values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,Pending pending,
    usize right,usize at){
    if(right>=unit.body.registers || unit.body.types[right]!=2){return .err(errors::make(3,at));}
    let usize stored=ir::raw(ref mut unit.body,18,pending.slot,right,0,at)?;
    let usize jump=ir::raw(ref mut unit.body,19,0,0,0,at)?;
    let branches::Exit evaluated=branches::capture(paths,state,false,jump,at)?;
    let usize selected=branches::select(unit,state,paths,pending.entry,at)?;
    let usize target=unit.body.count;let usize patched=ir::patch(ref mut unit.body,pending.guard,target,at)?;
    let usize skip=ir::raw(ref mut unit.body,19,0,0,0,at)?;
    let branches::Exit skipped=branches::capture(paths,state,false,skip,at)?;
    let bool joined=branches::join(unit,state,paths,ref evaluated,ref skipped,at)?;
    let usize freed=looping::release(paths,flow,pending.pool,at)?;
    return ir::emit(ref mut unit.body,17,pending.slot,0,at);
}
