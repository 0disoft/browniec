module value_source_calls;
import value_ir as values;
import value_properties as properties;
import value_source_properties as source_properties;
import value_source_bindings as bindings;
import value_source_functions as functions;
import value_source_context as context;
import value_view_bindings as views;
import value_view_source as view_source;
import functions as signatures;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
fn errors::Error wrong(usize at){return errors::make(3,at);}
fn usize register_count(ref values::Program unit){return unit.body.registers;}
fn usize position(ref values::Program unit){return unit.body.count;}
fn usize call_count(ref values::Program unit){return unit.body.call_count;}
// Finalize once-evaluated argument captures without a recursive parser frame.
pub fn Result<context::Value,errors::Error> finish_raw(ref mut values::Program unit,ref mut bindings::State state,
    ref signatures::Table table,ref functions::Plan plan,usize target,ref usize[] arguments,
    ref usize[] captures,usize count,bool has_values,usize at){
    let usize i=count;var bool extended=has_values;
    let usize result=plan.results[target];var context::Value returned=context::nothing();
    if(result==66){extended=true;
        let usize input=table.return_slice_inputs[target] as usize;
        if(input==0 || input>count){return .err(wrong(at));}let usize selected=input-1;
        if(selected>=count || arguments[selected]<224 || arguments[selected]>=240){return .err(wrong(at));}
        let usize view=views::call_result(unit,ref mut state.views,arguments[selected]-224,at)?;
        returned=view_source::value(view,64);
    }else if(result!=0 && unit.catalog.nodes[result-1].kind!=1){extended=true;
        returned=context::owned(result-1,bindings::allocate(unit,state,result-1,at)?);
    }else if(result!=0){
        if(register_count(unit)>=128){return .err(errors::make(4,at));}
        let usize reg=register_count(unit);unit.body.registers=reg+1;
        let u8 tag=unit.catalog.nodes[result-1].first;unit.body.types[reg]=tag;returned=context::scalar(result-1,reg);
    }
    if(call_count(unit)>=32 || position(unit)>=256){return .err(errors::make(4,at));}
    let usize map=call_count(unit);unit.body.call_count=map+1;unit.body.call_arities[map]=context::byte(i);
    var usize j=0;while(j<i){unit.body.call_args[map*8+j]=context::byte(arguments[j]);j+=1;}
    let usize emitted=ir::raw(ref mut unit.body,if(result==66){114}else if(extended){93}else{9},if(returned.nothing){0}else{returned.value},target,map,at)?;
    let properties::Plan properties= switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(wrong(at));}
    };
    j=0;while(j<i){if(captures[j]>=17){
        let usize closed=bindings::close_view(unit,state,captures[j]-17,at)?;
    }else if(captures[j]!=16){let usize id=captures[j];
        // A later argument can exit before CALL; transfer the obligation only
        // after this CALL is published, never while evaluating its arguments.
        let usize handled=bindings::handle(unit,state,id,at)?;
        if(properties.properties[values::type_id(unit,id)].copyable){let usize dropped=bindings::drop(unit,state,id,at)?;}
        else{let usize consumed=bindings::consume(unit,state,id,at)?;}
    }j+=1;}
    if(returned.typed){let usize initialized=bindings::initialize(unit,state,returned.value,at)?;}
    return .ok(returned);
}

pub struct Reserved { context::Value returned; bool extended; }
fn Result<Reserved,errors::Error> reserve_result(ref mut values::Program unit,ref mut bindings::State state,
    ref signatures::Table table,ref functions::Plan plan,usize target,ref usize[] arguments,
    ref usize[] captures,usize count,bool has_values,usize at){
    let usize i=count;var bool extended=has_values;
    let usize result=plan.results[target];var context::Value returned=context::nothing();
    if(result==66){extended=true;
        let usize input=table.return_slice_inputs[target] as usize;
        if(input==0 || input>count){return .err(wrong(at));}let usize selected=input-1;
        if(selected>=count || arguments[selected]<224 || arguments[selected]>=240){return .err(wrong(at));}
        let usize view=views::call_result(unit,ref mut state.views,arguments[selected]-224,at)?;
        returned=view_source::value(view,64);
    }else if(result!=0 && unit.catalog.nodes[result-1].kind!=1){extended=true;
        returned=context::owned(result-1,bindings::allocate(unit,state,result-1,at)?);
    }else if(result!=0){
        if(register_count(unit)>=128){return .err(errors::make(4,at));}
        let usize reg=register_count(unit);unit.body.registers=reg+1;
        let u8 tag=unit.catalog.nodes[result-1].first;unit.body.types[reg]=tag;returned=context::scalar(result-1,reg);
    }

    return .ok(Reserved{.returned=returned,.extended=extended});
}

pub struct Finish { context::Value returned; usize target; usize count; usize at; usize map; usize row; usize result;
    u8 phase; u8 request; bool extended; bool done; }
pub fn Finish finishing(usize target,usize count,bool extended,usize at){return Finish{.returned=context::nothing(),.target=target,.count=count,.at=at,.map=0,.row=0,.result=0,.phase=0,.request=0,.extended=extended,.done=false};}
pub fn Result<usize,errors::Error> resume_finish(ref mut Finish w,u8 request){if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}w.request=0;return .ok(0);}
pub fn Result<context::Value,errors::Error> finish_result(ref Finish w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.returned);}
pub fn Result<bool,errors::Error> advance_finish(ref mut values::Program unit,ref functions::Plan plan,ref properties::Plan properties,
    ref usize[] arguments,ref usize[] captures,ref mut Finish w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    let usize i=w.row;let usize at=w.at;
    if(w.phase==0){w.result=plan.results[w.target];w.request=1;w.phase=1;return .ok(false);}
    if(w.phase==1){if(call_count(unit)>=32 || position(unit)>=256){return .err(errors::make(4,at));}
        w.map=call_count(unit);unit.body.call_count=w.map+1;unit.body.call_arities[w.map]=context::byte(w.count);w.phase=2;return .ok(false);}
    if(w.phase==2){if(i==w.count){w.phase=3;return .ok(false);}unit.body.call_args[w.map*8+i]=context::byte(arguments[i]);w.row+=1;return .ok(false);}
    if(w.phase==3){let usize emitted=ir::raw(ref mut unit.body,if(w.result==66){114}else if(w.extended){93}else{9},if(w.returned.nothing){0}else{w.returned.value},w.target,w.map,at)?;
        w.row=0;w.request=2;w.phase=4;return .ok(false);}
    if(w.phase==4){if(i==w.count){w.phase=8;if(w.returned.typed){w.request=6;}return .ok(false);}
        if(captures[i]>=17){w.request=3;w.phase=7;}else if(captures[i]!=16){w.request=4;w.phase=5;}else{w.row+=1;}return .ok(false);}
    if(w.phase==5){w.request=5;w.phase=7;return .ok(false);}
    if(w.phase==7){w.row+=1;w.phase=4;return .ok(false);}
    if(w.phase==8){w.done=true;return .ok(true);}return .err(errors::make(5,at));
}
pub fn Result<context::Value,errors::Error> finish(ref mut values::Program unit,ref mut bindings::State state,
    ref signatures::Table table,ref functions::Plan plan,usize target,ref usize[] arguments,ref usize[] captures,usize count,bool has_values,usize at){
    var Finish w=finishing(target,count,has_values,at);var properties::Plan proof=properties::Plan{.count=0,.properties=[properties::Property{.bytes=0,.alignment=0,.payload_offset=0,.wrapper_depth=0,.copyable=false,.contains_buffer=false};64]};
    var budget::State meter=budget::empty();while(!w.done){let usize reset=budget::reset(ref mut meter,at)?;
        let bool done=advance_finish(unit,plan,ref proof,arguments,captures,ref mut w,ref mut meter)?;let u8 request=w.request;
        if(request!=0){if(request==1){let Reserved prepared=reserve_result(unit,state,table,plan,target,arguments,captures,count,has_values,at)?;w.returned=prepared.returned;w.extended=prepared.extended;}
            else if(request==2){proof=switch(source_properties::inspect(ref unit.catalog)){case .ok(p):{p}case .err(_):{return .err(wrong(at));}};}
            else if(request==3){let usize closed=bindings::close_view(unit,state,captures[w.row]-17,at)?;}
            else if(request==4){let usize handled=bindings::handle(unit,state,captures[w.row],at)?;}
            else if(request==5){let usize id=captures[w.row];if(proof.properties[values::type_id(unit,id)].copyable){let usize dropped=bindings::drop(unit,state,id,at)?;}
                else{let usize consumed=bindings::consume(unit,state,id,at)?;}}
            else{let usize initialized=bindings::initialize(unit,state,w.returned.value,at)?;}
            let usize resumed=resume_finish(ref mut w,request)?;}
    }return finish_result(ref w);
}
