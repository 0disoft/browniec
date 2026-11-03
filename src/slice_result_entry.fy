module slice_result_entry;
import ir as ir;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_record_bindings as records;
import array_owners as owners;
import struct_call_vm as calls;
import errors as errors;

// Only independently admitted Programs enter here. Inputs are indexed by formal
// argument; borrowed/scalar positions contain the exact dead token (0,0).
// Original native roots stay outside the guest frame; parameters are value copies.
pub fn Result<runtime::Entered,errors::Error> enter(ref ir::Program p,usize function,
    runtime::Contract contract,ref runtime::Capture[] captures,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let usize work=calls::cost(p,function,0)?;
    if(fuel<runtime::cost()+work){return .err(errors::make(8,0));}
    var owners::CallArgument[8] arguments=[owners::CallArgument{
        .source=owners::Token{.slot=0,.generation=0},.element=0,.length=0,.record=0};8];
    var usize count=0;var usize i=0;
    while(i<contract.arity){let usize r=p.register_starts[function]+i;
        let usize a=p.array_parameters[r] as usize;let usize record=p.record_parameters[r] as usize;
        if(a!=0){arguments[count]=owners::CallArgument{.source=inputs[i],
            .element=p.arrays.elements[a-1],.length=p.arrays.lengths[a-1],.record=0};count+=1;}
        else if(record!=0){arguments[count]=owners::CallArgument{.source=inputs[i],
            .element=0,.length=0,.record=p.records.records[record-1] as usize};count+=1;}
        i+=1;
    }
    if(count==0){
        let runtime::Call call=runtime::enter(state,contract,captures,data.len,fuel)?;
        return .ok(runtime::Entered{.call=call,.copies=owners::Copies{
            .tokens=[owners::Token{.slot=0,.generation=0};8],.count=0}});
    }
    return runtime::enter_records(state,contract,captures,ref p.records.layouts,
        ref arguments[..count],data,fuel-work);
}
// Infallible publication after the admitted initial frame is pushed. Each token
// was reserved/copied in formal order by the same entry transaction.
pub fn void bind(ref ir::Program p,usize function,ref owners::Copies copies,ref mut frames::Frames bindings){
    let usize base=bindings.frame*16;var usize i=0;var usize copied=0;
    while(i<p.arities[function]){let usize r=p.register_starts[function]+i;
        let usize a=p.array_parameters[r] as usize;let usize record=p.record_parameters[r] as usize;
        if(a!=0){bindings.tokens[base+a-1]=copies.tokens[copied];copied+=1;}
        else if(record!=0){records::bind(ref mut bindings.records,base+record-1,copies.tokens[copied]);copied+=1;}
        i+=1;
    }
}
