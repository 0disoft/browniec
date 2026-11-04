module slice_result_execution;
import slice_result_ir as ir;
import ir as body_ir;
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
import static_ir as statics;
import static_image as images;
import static_execution as immutable;

pub struct Scalar { i64 value; usize remaining; slices::Ticket[8] resumed; }
// Internal tagged completion; inactive fields never escape either native API.
struct Outcome { bool view; runtime::Returned borrowed; Scalar scalar; }
fn Outcome transferred(runtime::Returned value){
    return Outcome{.view=true,.borrowed=value,.scalar=Scalar{.value=0,.remaining=value.remaining,.resumed=value.resumed}};
}
fn Outcome completed(Scalar value){
    let slices::Ticket dead=slices::Ticket{.slot=16,.generation=0};
    let owners::View empty=owners::View{.root=owners::Token{.slot=16,.generation=0},.element=0,.length=0,.start=0,.end=0};
    return Outcome{.view=false,.scalar=value,.borrowed=runtime::Returned{.held=runtime::Held{
        .issued=dead,.view=empty,.exclusive=false,.close_parent=false,.drop=false,.depth=0,.frame=0,.active=false},
        .resumed=[dead;8],.remaining=value.remaining}};
}

// Read the canonical stack through its own reference; do not keep full outer
// State snapshots alive in the native driver across ownership transactions.
fn bool available(ref authority::State stack,bool root){return stack.depth<31 && (!root || stack.frame==0);}

fn runtime::Contract binding(ref ir::Program unit,usize f){
    let ref body_ir::Program body=ref unit.body;
    var runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=body.arities[f],.selected=unit.parameters[f] as usize};
    var usize i=0;while(i<c.arity){let usize site=body.slice_parameters[body.register_starts[f]+i] as usize;
        if(site!=0){c.tags[i]=body.slice_elements[site-1];}i+=1;}return c;
}
// Deliberately separate admission from ordinary Program/CLI execution. This
// dialect has native borrowed inputs, owned arrays/records, ordinary CALLs and
// forwarded results. Explicit native owned entry is separate from public source admission.
fn Result<usize,errors::Error> admit(ref ir::Program unit,usize function,ref i64[] values,usize captures,ref owners::Token[] inputs,bool view){
    let ref body_ir::Program body=ref unit.body;
    if(function>=body.function_count ||
        values.len!=body.arities[function] || captures!=values.len || (inputs.len!=0 && inputs.len!=values.len)){return .err(errors::make(5,0));}
    if(view){if(unit.elements[function]==0){return .err(errors::make(5,0));}}
    else if(unit.elements[function]!=0 || !types::scalar(body.return_types[function]) ||
        body.array_results[function]!=0 || body.record_results[function]!=0){return .err(errors::make(5,0));}
    var usize i=0;
    i=0;while(i<body.function_count){var usize a=0;while(a<body.arities[i]){
        let usize r=body.register_starts[i]+a;
        if(body.slice_parameters[r]==0 && body.array_parameters[r]==0 && body.record_parameters[r]==0 && !types::valid(body.types[r])){return .err(errors::make(5,0));}a+=1;
    }i+=1;}
    i=0;while(i<values.len){let usize r=body.register_starts[function]+i;
        let bool aggregate=body.array_parameters[r]!=0 || body.record_parameters[r]!=0;
        if(aggregate){
            if(inputs.len==0 || inputs[i].generation==0 || inputs[i].slot>=16 || values[i]!=0){return .err(errors::make(5,0));}
        }else if(inputs.len!=0 && (inputs[i].slot!=0 || inputs[i].generation!=0)){return .err(errors::make(5,0));}
        if(aggregate){i+=1;continue;}
        if(body.slice_parameters[r]!=0){if(values[i]!=0){return .err(errors::make(5,0));}}
        else{let u8 tag=body.types[r];if(!types::scalar(tag)){return .err(errors::make(5,0));}if(if(tag==2){values[i]!=0 && values[i]!=1}else{!types::fits(tag,values[i])}){return .err(errors::make(5,0));}}i+=1;
    }return .ok(body.count);
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
    return switch(invoke(unit,function,captures,values,inputs,state,data,fuel,true)){
        case .ok(outcome):{if(outcome.view){.ok(outcome.borrowed)}else{.err(errors::make(5,0))}}
        case .err(e):{.err(e)}
    };
}
// Ordinary entries use the same canonical ownership/dispatch/abort path. Return
// fresh resumed inputs explicitly; the host must not guess a rotated generation.
pub fn Result<Scalar,errors::Error> execute_scalar(ref ir::Program unit,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    return switch(invoke(unit,function,captures,values,inputs,state,data,fuel,false)){
        case .ok(outcome):{if(!outcome.view){.ok(outcome.scalar)}else{.err(errors::make(5,0))}}
        case .err(e):{.err(e)}
    };
}
// Image-aware entry independently proves the exact code/payload before any
// native owner transfer. The borrowed image remains live for the entire call.
pub fn Result<Scalar,errors::Error> execute_image_scalar(ref ir::Program unit,ref images::Image image,
    usize function,ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let verifier::ImageProof proof=verifier::inspect_image(unit,image)?;
    return switch(invoke_proved(unit,function,captures,values,inputs,state,data,fuel,false,
        ref proof.statics,images::payload(image))){
        case .ok(outcome):{if(!outcome.view){.ok(outcome.scalar)}else{.err(errors::make(5,0))}}
        case .err(e):{.err(e)}
    };
}
fn Result<Outcome,errors::Error> invoke(ref ir::Program unit,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel,bool view){
    let verifier::Proof proof=verifier::inspect(unit)?;
    let statics::Sites sites=statics::empty();let u8[1] unused=[0];
    return invoke_proved(unit,function,captures,values,inputs,state,data,fuel,view,ref sites,ref unused[..0]);
}
fn Result<Outcome,errors::Error> invoke_proved(ref ir::Program unit,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel,bool view,
    ref statics::Sites sites,ref u8[] literals){
    let ref body_ir::Program body=ref unit.body;
    let usize admitted=admit(unit,function,values,captures.len,inputs,view)?;
    let usize depth=switch(authority::inspect(ref state.runtime.authority)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    if(!available(ref state.runtime.authority,true)){return .err(errors::make(5,0));}
    let runtime::Entered first=entry::enter(body,function,binding(unit,function),captures,inputs,state,data,fuel)?;
    let Result<Outcome,errors::Error> outcome=start(unit,function,ref first,values,state,data,sites,literals);
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
fn Result<Outcome,errors::Error> start(ref ir::Program unit,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals){
    var frames::Frames bindings=frames::empty(state);
    return run(unit,function,first,values,ref mut bindings,state,data,sites,literals);
}
fn Result<Outcome,errors::Error> run(ref ir::Program unit,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals){
    let ref body_ir::Program body=ref unit.body;
    var usize[32] static_live=[0;32];
    var i64[4096] registers=[0;4096];var usize remaining=first.call.remaining;
    let usize entered=frames::push(body,bindings,first.call,function,128,32,0)?;
    entry::bind(body,function,ref first.copies,bindings);
    var usize i=0;while(i<values.len){registers[128+body.register_starts[function]+i]=values[i];i+=1;}
    var usize pc=body.starts[function];
    while(pc<body.count){
        let usize frame=bindings.frame;let usize f=bindings.functions[frame];
        if(frame==0 || f>=body.function_count || pc<body.starts[f] || pc>=body.ends[f]){return .err(errors::make(5,0));}
        let usize at=pc*8;let usize offset=body.offsets[pc];let u8 op=body.code[at];
        let usize dst=body.code[at+1] as usize;let usize a=body.code[at+2] as usize;let usize b=body.code[at+3] as usize;
        let usize base=frame*128;
        if(remaining==0){return .err(errors::make(8,offset));}remaining-=1;
        if(statics::operation(op)){
            let immutable::Step next=immutable::step(body,sites,literals,pc,f,
                ref mut registers[base..base+128],static_live[frame],remaining)?;
            static_live[frame]=next.live;remaining=next.remaining;pc+=1;continue;
        }
        if(bindings.prepared[frame] && (op==37 || op==45 || op==56 || op==62)){
            // The terminal recipe is independently proved. Physical CLOSE/END
            // belongs to native handoff's staged cleanup, never to both paths.
            pc+=1;continue;
        }
        if(op==63){
            let slices::Ticket current=bindings.sites[frame*16+a];
            let usize prepared=frames::prepare(bindings,dst,current)?;pc+=1;continue;
        }
        if(op==67 || op==68){
            // Native handoff and frame publication have already committed this
            // proved recipe. Never acquire or close the same child twice.
            if((op==67 && !frames::result_bound(bindings,dst)) ||
                (op==68 && bindings.sites[frame*16+dst].slot!=16)){return .err(errors::make(5,offset));}
            pc+=1;continue;
        }
        if(op==9 || op==64 || op==66){
            if(frame>=31 || !available(ref state.runtime.authority,false)){return .err(errors::make(12,offset));}
            let runtime::Contract c=binding(unit,a);
            remaining=switch(owned::enter(body,pc,c,bindings,state,data,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            static_live[frame+1]=0;
            i=0;while(i<c.arity){let usize formal=body.register_starts[a]+i;let usize source=body.call_args[b*8+i] as usize;
                if(c.tags[i]==0 && body.array_parameters[formal]==0 && body.record_parameters[formal]==0){registers[(frame+1)*128+formal]=registers[base+source];}i+=1;
            }pc=body.starts[a];continue;
        }
        if(op==65){
            if(static_live[frame]!=0){return .err(errors::make(5,offset));}
            let usize selected=frames::selected(bindings,a)?;var runtime::Call call=frames::current(bindings);
            let runtime::Returned result=switch(records::handoff(bindings,state,ref mut call,bindings.results[selected],data.len,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };remaining=result.remaining;
            pc=frames::pop(body,bindings,result)?;
            if(bindings.frame==0){return .ok(transferred(result));}continue;
        }
        if(op==8 || op==39 || op==50){
            if(static_live[frame]!=0){return .err(errors::make(5,offset));}
            let usize destination=bindings.destinations[frame];let usize next=bindings.continuations[frame];
            let i64 value=if(op==8){registers[base+a]}else{0};
            let runtime::Resumed resumed=switch(owned::leave(body,pc,op,bindings,state,data,remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            remaining=resumed.remaining;
            if(frame==1){return .ok(completed(Scalar{.value=value,.remaining=remaining,.resumed=resumed.tickets}));}
            if(op==8){registers[(frame-1)*128+destination]=value;}pc=next;continue;
        }
        if(op>=41 && op<=49){remaining=records::step(body,pc,bindings,state,ref mut registers[base..base+128],data,remaining)?;pc+=1;continue;}
        if((op>=33 && op<=40) || (op>=51 && op<=53)){remaining=owned::step(body,pc,bindings,state,ref mut registers[base..base+128],data,remaining)?;pc+=1;continue;}
        if(op>=54 && op<=62){remaining=loans::step(body,pc,bindings,state,ref mut registers[base..base+128],data,remaining)?;pc+=1;continue;}
        if(op==8 || op==9 || op==25 || op>=33){return .err(errors::make(5,offset));}
        if(op==19 || op==20 || op==21 || op==22){
            if(op==19 || op==22){pc=a;}else if((registers[base+a]==0)==(op==20)){pc=b;}else{pc+=1;}continue;
        }
        if(op==24){let i64 subject=registers[base+a];let u8 variant=body.code[at+3];
            if(tagged::variant(subject)!=variant){pc=body.code[at+4] as usize;}
            else{if(types::payload(body.types[a],variant)!=0){registers[base+dst]=tagged::unpack(subject,variant);}pc+=1;}continue;
        }
        if(op==18){registers[base+dst]=registers[base+a];}
        else{registers[base+dst]=scalar::scalar(body,pc,ref registers[base..base+128])?;}
        pc+=1;
    }return .err(errors::make(5,0));
}
