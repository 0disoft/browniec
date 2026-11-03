module slice_result_execution;
import slice_result_ir as ir;
import slice_result_verifier as verifier;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_loan_execution as loans;
import vm_execution as scalar;
import slice_authority as authority;
import array_vm as arrays;
import slice_result_owned_execution as owned;
import slice_result_record_execution as records;
import array_slices as slices;
import types as types;
import tagged as tagged;
import errors as errors;
import array_owners as owners;
import slice_result_entry as entry;

fn runtime::Contract binding(ref ir::Program unit,usize f){
    var runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=unit.body.arities[f],.selected=unit.parameters[f] as usize};
    var usize i=0;while(i<c.arity){let usize site=unit.body.slice_parameters[unit.body.register_starts[f]+i] as usize;
        if(site!=0){c.tags[i]=unit.body.slice_elements[site-1];}i+=1;}return c;
}
// Deliberately separate admission from ordinary Program/CLI execution. This
// dialect has native borrowed inputs, owned arrays/records, ordinary CALLs and
// forwarded results. Explicit native owned entry is separate from public source admission.
fn Result<usize,errors::Error> admit(ref ir::Program unit,usize function,ref i64[] values,usize captures,ref owners::Token[] inputs){
    let verifier::Proof proof=verifier::inspect(unit)?;
    if(function>=unit.body.function_count || unit.elements[function]==0 ||
        values.len!=unit.body.arities[function] || captures!=values.len || (inputs.len!=0 && inputs.len!=values.len)){return .err(errors::make(5,0));}
    var usize i=0;
    i=0;while(i<unit.body.function_count){var usize a=0;while(a<unit.body.arities[i]){
        let usize r=unit.body.register_starts[i]+a;
        if(unit.body.slice_parameters[r]==0 && unit.body.array_parameters[r]==0 && unit.body.record_parameters[r]==0 && !types::valid(unit.body.types[r])){return .err(errors::make(5,0));}a+=1;
    }i+=1;}
    i=0;while(i<values.len){let usize r=unit.body.register_starts[function]+i;
        let bool aggregate=unit.body.array_parameters[r]!=0 || unit.body.record_parameters[r]!=0;
        if(aggregate){
            if(inputs.len==0 || inputs[i].generation==0 || inputs[i].slot>=16 || values[i]!=0){return .err(errors::make(5,0));}
        }else if(inputs.len!=0 && (inputs[i].slot!=0 || inputs[i].generation!=0)){return .err(errors::make(5,0));}
        if(aggregate){i+=1;continue;}
        if(unit.body.slice_parameters[r]!=0){if(values[i]!=0){return .err(errors::make(5,0));}}
        else{let u8 tag=unit.body.types[r];if(!types::scalar(tag)){return .err(errors::make(5,0));}if(if(tag==2){values[i]!=0 && values[i]!=1}else{!types::fits(tag,values[i])}){return .err(errors::make(5,0));}}i+=1;
    }return .ok(proof.returns);
}
pub fn Result<runtime::Returned,errors::Error> execute(ref ir::Program unit,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    return execute_owned(unit,function,captures,values,ref inputs[..0],state,data,fuel);
}
// Empty inputs preserve the legacy borrowed/scalar-only entry. A nonempty input
// vector is formal-indexed, with zero scalar cells for every aggregate position.
pub fn Result<runtime::Returned,errors::Error> execute_owned(ref ir::Program unit,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let usize admitted=admit(unit,function,values,captures.len,inputs)?;
    let usize depth=switch(authority::inspect(ref state.runtime.authority)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    if(state.runtime.authority.frame!=0 || depth>=31){return .err(errors::make(5,0));}
    let runtime::Entered first=entry::enter(ref unit.body,function,binding(unit,function),captures,inputs,state,data,fuel)?;
    let Result<runtime::Returned,errors::Error> outcome=start(unit,function,first,values,state,data);
    return switch(outcome){
        case .ok(v):{.ok(v)}
        case .err(e):{
            // No result receipt escapes on failure. Preserve the first error and
            // earlier payload writes; invocation metadata drains at zero Fuel.
            let bool drained=runtime::abort(state,data.len,0).is_ok;
            .err(e)
        }
    };
}
// Keep the large frame maps out of the independent admission call stack.
// Their native storage is needed only after verification and initial entry.
fn Result<runtime::Returned,errors::Error> start(ref ir::Program unit,usize function,runtime::Entered first,
    ref i64[] values,ref mut runtime::State state,ref mut u8[] data){
    var frames::Frames bindings=frames::empty(state);
    return run(unit,function,first,values,ref mut bindings,state,data);
}
fn Result<runtime::Returned,errors::Error> run(ref ir::Program unit,usize function,runtime::Entered first,
    ref i64[] values,ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data){
    var i64[4096] registers=[0;4096];var usize remaining=first.call.remaining;
    let usize entered=frames::push(ref unit.body,bindings,first.call,function,128,32,0)?;
    entry::bind(ref unit.body,function,ref first.copies,bindings);
    var usize i=0;while(i<values.len){registers[128+unit.body.register_starts[function]+i]=values[i];i+=1;}
    var usize pc=unit.body.starts[function];
    while(pc<unit.body.count){
        let usize frame=bindings.frame;let usize f=bindings.functions[frame];
        if(frame==0 || f>=unit.body.function_count || pc<unit.body.starts[f] || pc>=unit.body.ends[f]){return .err(errors::make(5,0));}
        let usize at=pc*8;let usize offset=unit.body.offsets[pc];let u8 op=unit.body.code[at];
        let usize dst=unit.body.code[at+1] as usize;let usize a=unit.body.code[at+2] as usize;let usize b=unit.body.code[at+3] as usize;
        let usize base=frame*128;
        if(remaining==0){return .err(errors::make(8,offset));}remaining-=1;
        if(bindings.prepared[frame] && (op==37 || op==45 || op==56 || op==62)){
            // The terminal recipe is independently proved. Physical CLOSE/END
            // belongs to native handoff's staged cleanup, never to both paths.
            pc+=1;continue;
        }
        if(op==63){
            let slices::Ticket current=bindings.sites[frame*16+a];
            let usize prepared=frames::prepare(bindings,dst,current)?;pc+=1;continue;
        }
        if(op==9 || op==64){
            if(frame>=31 || state.runtime.authority.depth>=31){return .err(errors::make(12,offset));}
            let runtime::Contract c=binding(unit,a);
            remaining=switch(owned::enter(ref unit.body,pc,c,bindings,state,data,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            i=0;while(i<c.arity){let usize formal=unit.body.register_starts[a]+i;let usize source=unit.body.call_args[b*8+i] as usize;
                if(c.tags[i]==0 && unit.body.array_parameters[formal]==0 && unit.body.record_parameters[formal]==0){registers[(frame+1)*128+formal]=registers[base+source];}i+=1;
            }pc=unit.body.starts[a];continue;
        }
        if(op==65){
            let usize selected=frames::selected(bindings,a)?;var runtime::Call call=frames::current(bindings);
            let runtime::Returned result=switch(records::handoff(bindings,state,ref mut call,bindings.results[selected],data.len,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };remaining=result.remaining;
            pc=frames::pop(ref unit.body,bindings,result)?;
            if(bindings.frame==0){return .ok(result);}continue;
        }
        if(op==8 || op==39 || op==50){
            let usize destination=bindings.destinations[frame];let usize next=bindings.continuations[frame];
            let i64 value=if(op==8){registers[base+a]}else{0};
            remaining=switch(owned::leave(ref unit.body,pc,op,bindings,state,data,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            if(op==8){registers[(frame-1)*128+destination]=value;}pc=next;continue;
        }
        if(op>=41 && op<=49){remaining=records::step(ref unit.body,pc,bindings,state,ref mut registers[base..base+128],data,remaining)?;pc+=1;continue;}
        if((op>=33 && op<=40) || (op>=51 && op<=53)){remaining=owned::step(ref unit.body,pc,bindings,state,ref mut registers[base..base+128],data,remaining)?;pc+=1;continue;}
        if(op>=54 && op<=62){remaining=loans::step(ref unit.body,pc,bindings,state,ref mut registers[base..base+128],data,remaining)?;pc+=1;continue;}
        if(op==8 || op==9 || op==25 || op>=33){return .err(errors::make(5,offset));}
        if(op==19 || op==20 || op==21 || op==22){
            if(op==19 || op==22){pc=a;}else if((registers[base+a]==0)==(op==20)){pc=b;}else{pc+=1;}continue;
        }
        if(op==24){let i64 subject=registers[base+a];let u8 variant=unit.body.code[at+3];
            if(tagged::variant(subject)!=variant){pc=unit.body.code[at+4] as usize;}
            else{if(types::payload(unit.body.types[a],variant)!=0){registers[base+dst]=tagged::unpack(subject,variant);}pc+=1;}continue;
        }
        if(op==18){registers[base+dst]=registers[base+a];}
        else{registers[base+dst]=scalar::scalar(ref unit.body,pc,ref registers[base..base+128])?;}
        pc+=1;
    }return .err(errors::make(5,0));
}
