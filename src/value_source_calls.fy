module value_source_calls;
import value_ir as values;
import value_properties as properties;
import value_source_bindings as bindings;
import value_source_functions as functions;
import value_source_context as context;
import functions as signatures;
import ir as ir;
import errors as errors;
fn errors::Error wrong(usize at){return errors::make(3,at);}
fn usize register_count(ref values::Program unit){return unit.body.registers;}
fn usize position(ref values::Program unit){return unit.body.count;}
fn usize call_count(ref values::Program unit){return unit.body.call_count;}
// Finalize once-evaluated argument captures without a recursive parser frame.
pub fn Result<context::Value,errors::Error> finish(ref mut values::Program unit,ref mut bindings::State state,
    ref signatures::Table table,ref functions::Plan plan,usize target,ref usize[] arguments,
    ref usize[] captures,usize count,bool has_values,usize at){
    let usize i=count;var bool extended=has_values;
    let usize result=plan.results[target];var context::Value returned=context::nothing();
    if(result!=0 && unit.catalog.nodes[result-1].kind!=1){extended=true;
        returned=context::owned(result-1,bindings::allocate(unit,state,result-1,at)?);
    }else if(result!=0){
        if(register_count(unit)>=128){return .err(errors::make(4,at));}
        let usize reg=register_count(unit);unit.body.registers=reg+1;
        let u8 tag=unit.catalog.nodes[result-1].first;unit.body.types[reg]=tag;returned=context::scalar(result-1,reg);
    }
    if(call_count(unit)>=32 || position(unit)>=256){return .err(errors::make(4,at));}
    let usize map=call_count(unit);unit.body.call_count=map+1;unit.body.call_arities[map]=context::byte(i);
    var usize j=0;while(j<i){unit.body.call_args[map*8+j]=context::byte(arguments[j]);j+=1;}
    let usize emitted=ir::raw(ref mut unit.body,if(extended){93}else{9},if(returned.nothing){0}else{returned.value},target,map,at)?;
    let properties::Plan properties= switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(wrong(at));}
    };
    j=0;while(j<i){if(captures[j]!=16){let usize id=captures[j];
        // A later argument can exit before CALL; transfer the obligation only
        // after this CALL is published, never while evaluating its arguments.
        let usize handled=bindings::handle(unit,state,id,at)?;
        if(properties.properties[values::type_id(unit,id)].copyable){let usize dropped=bindings::drop(unit,state,id,at)?;}
        else{let usize consumed=bindings::consume(unit,state,id,at)?;}
    }j+=1;}
    if(returned.typed){let usize initialized=bindings::initialize(unit,state,returned.value,at)?;}
    return .ok(returned);
}
