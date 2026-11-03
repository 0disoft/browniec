module slice_result_execution;
import slice_result_ir as ir;
import slice_result_verifier as verifier;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_loan_execution as loans;
import vm_execution as scalar;
import slice_authority as authority;
import array_vm as arrays;
import array_slices as slices;
import types as types;
import tagged as tagged;
import errors as errors;

fn runtime::Contract binding(ref ir::Program unit,usize f){
    var runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=unit.body.arities[f],.selected=unit.parameters[f] as usize};
    var usize i=0;while(i<c.arity){let usize site=unit.body.slice_parameters[unit.body.register_starts[f]+i] as usize;
        if(site!=0){c.tags[i]=unit.body.slice_elements[site-1];}i+=1;}return c;
}
// Deliberately separate admission from ordinary Program/CLI execution. This
// first dialect has rootless borrowed inputs, scalar instructions and forwarded
// result CALLs. Owned locals/arguments and ordinary CALLs await owner integration.
fn Result<usize,errors::Error> admit(ref ir::Program unit,usize function,ref i64[] values,usize captures){
    let verifier::Proof proof=verifier::inspect(unit)?;
    if(function>=unit.body.function_count || unit.elements[function]==0 ||
        values.len!=unit.body.arities[function] || captures!=values.len || unit.body.arrays.count!=0 || unit.body.records.count!=0){return .err(errors::make(5,0));}
    var usize i=0;while(i<16){if(unit.body.slice_roots[i]!=0){return .err(errors::make(5,0));}i+=1;}
    i=0;while(i<unit.body.function_count){var usize a=0;while(a<unit.body.arities[i]){
        let usize r=unit.body.register_starts[i]+a;
        if(unit.body.slice_parameters[r]==0 && !types::scalar(unit.body.types[r])){return .err(errors::make(5,0));}a+=1;
    }i+=1;}
    i=0;while(i<unit.body.count){let u8 op=unit.body.code[i*8];
        if(op==9 || (op>=33 && op<=54)){return .err(errors::make(5,unit.body.offsets[i]));}i+=1;
    }
    i=0;while(i<values.len){let usize r=unit.body.register_starts[function]+i;
        if(unit.body.slice_parameters[r]!=0){if(values[i]!=0){return .err(errors::make(5,0));}}
        else{let u8 tag=unit.body.types[r];if(if(tag==2){values[i]!=0 && values[i]!=1}else{!types::fits(tag,values[i])}){return .err(errors::make(5,0));}}i+=1;
    }return .ok(proof.returns);
}
pub fn Result<runtime::Returned,errors::Error> execute(ref ir::Program unit,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let usize admitted=admit(unit,function,values,captures.len)?;
    let usize depth=switch(authority::inspect(ref state.runtime.authority)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    if(state.runtime.authority.frame!=0 || depth>=31){return .err(errors::make(5,0));}
    var frames::Frames bindings=frames::empty(state);
    let runtime::Call first=runtime::enter(state,binding(unit,function),captures,data.len,fuel)?;
    let Result<runtime::Returned,errors::Error> outcome=run(unit,function,first,values,ref mut bindings,state,data);
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
fn Result<runtime::Returned,errors::Error> run(ref ir::Program unit,usize function,runtime::Call first,
    ref i64[] values,ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data){
    var i64[4096] registers=[0;4096];var usize remaining=first.remaining;
    let usize entered=frames::push(ref unit.body,bindings,first,function,128,32,0)?;
    var usize i=0;while(i<values.len){registers[128+unit.body.register_starts[function]+i]=values[i];i+=1;}
    var usize pc=unit.body.starts[function];
    while(pc<unit.body.count){
        let usize frame=bindings.frame;let usize f=bindings.functions[frame];
        if(frame==0 || f>=unit.body.function_count || pc<unit.body.starts[f] || pc>=unit.body.ends[f]){return .err(errors::make(5,0));}
        let usize at=pc*8;let usize offset=unit.body.offsets[pc];let u8 op=unit.body.code[at];
        let usize dst=unit.body.code[at+1] as usize;let usize a=unit.body.code[at+2] as usize;let usize b=unit.body.code[at+3] as usize;
        let usize base=frame*128;
        if(remaining==0){return .err(errors::make(8,offset));}remaining-=1;
        if(bindings.prepared[frame] && (op==56 || op==62)){
            // The terminal recipe is independently proved. Physical CLOSE/END
            // belongs to native handoff's staged cleanup, never to both paths.
            pc+=1;continue;
        }
        if(op==63){
            let slices::Ticket current=bindings.sites[frame*16+a];
            let usize prepared=frames::prepare(bindings,dst,current)?;pc+=1;continue;
        }
        if(op==64){
            if(frame>=31 || state.runtime.authority.depth>=31){return .err(errors::make(12,offset));}
            let runtime::Contract c=binding(unit,a);var runtime::Capture[8] args=[runtime::capture(frames::none(),false,false);8];
            i=0;while(i<c.arity){let usize source=unit.body.call_args[b*8+i] as usize;
                if(c.tags[i]!=0){args[i]=runtime::capture(bindings.sites[frame*16+source-160],false,false);}i+=1;
            }
            let runtime::Call call=switch(runtime::enter(state,c,ref args[..c.arity],data.len,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };remaining=call.remaining;
            i=0;while(i<c.arity){let usize source=unit.body.call_args[b*8+i] as usize;
                if(c.tags[i]==0){registers[(frame+1)*128+unit.body.register_starts[a]+i]=registers[base+source];}
                else if((c.tags[i]&128)!=0){bindings.sites[frame*16+source-160]=frames::none();}i+=1;
            }
            let usize child=frames::push(ref unit.body,bindings,call,a,dst,b,pc+1)?;pc=unit.body.starts[a];continue;
        }
        if(op==65){
            let usize selected=frames::selected(bindings,a)?;var runtime::Call call=frames::current(bindings);
            let runtime::Returned result=switch(runtime::handoff(state,ref mut call,bindings.results[selected],data.len,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };remaining=result.remaining;
            pc=frames::pop(ref unit.body,bindings,result)?;
            if(bindings.frame==0){return .ok(result);}continue;
        }
        if(op>=55 && op<=62){remaining=loans::step(ref unit.body,pc,bindings,state,ref mut registers[base..base+128],data,remaining)?;pc+=1;continue;}
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
