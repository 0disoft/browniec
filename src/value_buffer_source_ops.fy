module value_buffer_source_ops;
import value_ir as values;
import value_source_bindings as bindings;
import value_source_ops as ops;
import value_properties as properties;
import errors as errors;
import ir as ir;

// Private lowering only. The parser closes argument loans and checks receiver
// references/lifetimes before calling; these helpers never manufacture loans.
fn errors::Error invalid(usize at){return errors::make(3,at);}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn u8 byte(usize value){var u8 result=0;var usize i=0;while(i<value){result+=1;i+=1;}return result;}
fn Result<usize,errors::Error> live_buffer(ref values::Program unit,ref bindings::State state,usize id,usize at){
    let usize one=1;
    if(id>=state.next || !values::slot(unit,id,state.names.function) ||
        (state.live&(one<<id))==0 || unit.catalog.nodes[values::type_id(unit,id)].kind!=4){
        return .err(invalid(at));}return .ok(id);
}
fn Result<usize,errors::Error> scalar_register(ref values::Program unit,ref bindings::State state,usize id,u8 tag,usize at){
    let ref ir::Program ir_body=ref unit.body;
    if(id>=ir_body.registers || id<ir_body.register_starts[state.names.function] ||
        ir_body.types[id]!=tag || ir_body.slots[id] || unit.parameters[id]!=0 ||
        ir_body.array_parameters[id]!=0 || ir_body.record_parameters[id]!=0 ||
        ir_body.slice_parameters[id]!=0){return .err(invalid(at));}return .ok(id);
}
// All counts/operands and destination cells are checked before publication.
// Unlike ir::raw, this append cannot fail after touching the instruction bytes.
fn void append(ref mut values::Program unit,u8 op,usize dst,usize a,usize b,usize at){
    let usize pc=unit.body.count;let usize start=pc*8;
    unit.body.code[start]=op;unit.body.code[start+1]=byte(dst);
    unit.body.code[start+2]=byte(a);unit.body.code[start+3]=byte(b);
    unit.body.code[start+4]=0;unit.body.code[start+5]=0;
    unit.body.code[start+6]=0;unit.body.code[start+7]=0;
    unit.body.offsets[pc]=at;unit.body.count=pc+1;
}
pub fn Result<usize,errors::Error> scalar(ref mut values::Program unit,ref bindings::State state,
    u8 op,usize buffer,usize index,usize at){
    let properties::Plan plan=ops::preflight(unit,state,at)?;
    if(op!=99 && op!=100){return .err(invalid(at));}
    let usize receiver=live_buffer(unit,state,buffer,at)?;
    if((state.writes&bit(buffer))!=0){return .err(invalid(at));}
    if(op==99){if(index!=0){return .err(invalid(at));}}
    else{let usize checked=scalar_register(unit,state,index,12,at)?;}
    if(unit.body.registers==128){return .err(errors::make(4,at));}
    let usize dst=unit.body.registers;
    if(unit.body.types[dst]!=0 || unit.body.slots[dst] || unit.parameters[dst]!=0 ||
        unit.body.array_parameters[dst]!=0 || unit.body.record_parameters[dst]!=0 ||
        unit.body.slice_parameters[dst]!=0){return .err(invalid(at));}
    append(unit,op,dst,buffer,index,at);
    unit.body.types[dst]=if(op==99){12}else{10};unit.body.registers=dst+1;
    return .ok(dst);
}
// No value destination: return the emitted instruction index.
pub fn Result<usize,errors::Error> write(ref mut values::Program unit,ref bindings::State state,
    usize buffer,usize index,usize value,usize at){
    let properties::Plan plan=ops::preflight(unit,state,at)?;
    let usize receiver=live_buffer(unit,state,buffer,at)?;
    if(((state.reads|state.writes)&bit(buffer))!=0){return .err(invalid(at));}
    let usize checked_index=scalar_register(unit,state,index,12,at)?;
    let usize checked_value=scalar_register(unit,state,value,10,at)?;
    let usize pc=unit.body.count;append(unit,101,buffer,index,value,at);return .ok(pc);
}
pub fn Result<usize,errors::Error> grow(ref mut values::Program unit,ref mut bindings::State state,
    u8 op,usize exact_result,usize buffer,usize argument,usize at){
    let properties::Plan plan=ops::preflight(unit,state,at)?;
    if(op<102 || op>104 || exact_result>=plan.count){return .err(invalid(at));}
    let usize receiver=live_buffer(unit,state,buffer,at)?;
    if(((state.reads|state.writes)&bit(buffer))!=0){return .err(invalid(at));}
    let properties::Node result=unit.catalog.nodes[exact_result];
    if(result.kind!=6){return .err(invalid(at));}
    let properties::Node success=unit.catalog.nodes[result.first as usize];
    let properties::Node failure=unit.catalog.nodes[result.second as usize];
    if(success.kind!=1 || success.first!=12 || failure.kind!=1 || failure.first!=10){return .err(invalid(at));}
    if(op==104){
        if(buffer==argument){return .err(invalid(at));}
        let usize source=live_buffer(unit,state,argument,at)?;
        if((state.writes&bit(argument))!=0){return .err(invalid(at));}
    }else{let usize checked=scalar_register(unit,state,argument,if(op==102){10}else{12},at)?;}
    if(state.next==16){return .err(errors::make(4,at));}
    // preflight proves allocate's complete ledger/catalog checks, and the new
    // monotonic slot is Dead, so initialize cannot reject after this point.
    let usize dst=bindings::allocate(unit,state,exact_result,at)?;
    append(unit,op,dst,buffer,argument,at);
    return bindings::initialize(unit,state,dst,at);
}
