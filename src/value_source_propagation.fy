module value_source_propagation;
import value_ir as values;
import value_source_bindings as bindings;
import value_source_control as branches;
import value_source_ops as ops;
import ir as ir;
import locals as locals;
import errors as errors;
import std::vec as vec;

pub struct Expanded { usize payload; usize exact; }
fn usize function(ref bindings::State state){let ref locals::Table names=ref state.names;return names.function;}

// Return cleanup includes anonymous captures/constructor children, not just
// lexical bindings. RETURN consumes even a copyable keep; 16 means no value.
// The caller discards the whole candidate on error, including partial cleanup.
pub fn Result<usize,errors::Error> finish_function(ref mut values::Program unit,
    ref mut bindings::State state,usize keep,usize at){
    if(state.next>16){return .err(errors::make(3,at));}
    let usize checked=bindings::require_handled(unit,state,keep,at)?;
    let usize f=function(state);
    var usize id=state.next;while(id!=0){id-=1;
        if(id!=keep && unit.functions[id] as usize==f){
            let usize dropped=bindings::drop(unit,state,id,at)?;
        }
    }
    if(keep!=16){let usize consumed=bindings::consume(unit,state,keep,at)?;}
    return bindings::leave_scope(unit,state,0,at);
}
fn usize position(ref values::Program unit){let ref ir::Program body=ref unit.body;return body.count;}

fn Result<Expanded,errors::Error> expand(ref mut values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,usize subject,usize result_type,usize exact,usize at){
    let usize entry=branches::save(paths,state,at)?;
    let ops::Case success=ops::case_value(unit,state,subject,1,at)?;
    // A whole-copyable anonymous subject survives CASE. A moved one is already
    // Dead, so the same idempotent DROP handles both ownership classes.
    let usize dropped=bindings::drop(unit,state,subject,at)?;
    let usize continuing=branches::save(paths,state,at)?;
    let usize jump=ir::raw(ref mut unit.body,19,0,0,0,at)?;

    let usize reset=branches::select(unit,state,paths,entry,at)?;
    let usize failure_start=position(unit);
    let usize patched=ops::patch_case(unit,success.instruction,failure_start,at)?;
    let ops::Case failure=ops::case_value(unit,state,subject,0,at)?;
    let usize released=bindings::drop(unit,state,subject,at)?;
    let usize returned=ops::tag(unit,state,result_type,failure.payload,0,at)?;
    let usize cleaned=finish_function(unit,state,returned,at)?;
    let usize terminal=ir::raw(ref mut unit.body,94,0,returned,0,at)?;
    let usize fail=ir::raw(ref mut unit.body,25,0,0,0,at)?;
    let usize canonical=ops::patch_case(unit,failure.instruction,fail,at)?;

    // Only CASE's separately reached successful edge can restore these names
    // and live bits. select keeps the global allocation high-water mark.
    let usize selected=branches::select(unit,state,paths,continuing,at)?;
    let usize continuation=position(unit);
    let usize skipped=ir::patch(ref mut unit.body,jump,continuation,at)?;
    return .ok(Expanded{.payload=success.payload,.exact=exact});
}

// subject is an already captured, once-evaluated anonymous value. result_type
// is the enclosing declared canonical zero-based wrapper node; 64 is invalid.
// Success types may differ, but Result errors must have the identical node ID.
// This emits existing instructions only; publication is not multi-op atomic.
pub fn Result<Expanded,errors::Error> lower(ref mut values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,usize subject,usize result_type,usize at){
    let usize f=function(state);
    if(f>=16 || f>=unit.body.function_count || unit.body.function_count>16 ||
        state.next>16 || subject>=state.next || !values::slot(unit,subject,f) ||
        unit.catalog.count>64 || result_type>=unit.catalog.count){return .err(errors::make(3,at));}
    let usize anchor=unit.results[f] as usize;
    if(anchor==0 || anchor>state.next || !values::slot(unit,anchor-1,f) ||
        values::type_id(unit,anchor-1)!=result_type || unit.body.return_types[f]!=0){
        return .err(errors::make(3,at));
    }
    let usize one=1;
    if((state.live&(one<<subject))==0){return .err(errors::make(3,at));}
    let usize operand=values::type_id(unit,subject);
    if(operand>=unit.catalog.count){return .err(errors::make(3,at));}
    let u8 family=unit.catalog.nodes[operand].kind;
    if((family!=5 && family!=6) || unit.catalog.nodes[result_type].kind!=family ||
        (family==6 && unit.catalog.nodes[operand].second!=unit.catalog.nodes[result_type].second)){
        return .err(errors::make(3,at));
    }
    let usize exact=unit.catalog.nodes[operand].first as usize;
    let usize mark=branches::mark(paths);
    // Scoped snapshots are released on either outcome; callers still discard
    // the whole Program/State candidate if any instruction emission failed.
    return switch(expand(unit,state,paths,subject,result_type,exact,at)){
        case .ok(value):{let usize freed=branches::release(paths,mark,at)?;.ok(value)}
        case .err(error):{let usize freed=branches::release(paths,mark,at)?;.err(error)}
    };
}
