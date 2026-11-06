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
import array_list_vm as list_values;
import slice_place_vm as places;
import record_place_vm as record_places;
import slice_result_record_bindings as record_bindings;
import place_vm as place_frames;
import struct_call_vm as owned_calls;
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
import static_call_execution as transfer;
import static_call_ir as image_calls;
import verifier as image_verifier;
import reference_access as access;
import reference_execution as references;
import reference_words as words;
import reference_receipts as receipts;
import reference_return_execution as reference_returns;
import fuel as meter;
import std::vec as vec;
import std::bytes as bytes;

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

fn runtime::Contract binding(ref body_ir::Program body,ref u8[] parameters,usize f){
    var runtime::Contract c=runtime::Contract{.tags=[0;8],.arity=body.arities[f],.selected=parameters[f] as usize};
    var usize i=0;while(i<c.arity){let usize site=body.slice_parameters[body.register_starts[f]+i] as usize;
        if(site!=0){c.tags[i]=body.slice_elements[site-1];}i+=1;}return c;
}
// Deliberately separate admission from ordinary Program/CLI execution. This
// dialect has native borrowed inputs, owned arrays/records, ordinary CALLs and
// forwarded results. Explicit native owned entry is separate from public source admission.
fn Result<usize,errors::Error> admit(ref body_ir::Program body,ref u8[] elements,ref statics::Sites sites,usize function,ref i64[] values,usize captures,ref owners::Token[] inputs,bool view){
    if(function>=body.function_count ||
        values.len!=body.arities[function] || captures!=values.len || (inputs.len!=0 && inputs.len!=values.len)){return .err(errors::make(5,0));}
    if(view){if(elements[function]==0){return .err(errors::make(5,0));}}
    else if(elements[function]!=0 || !types::scalar(body.return_types[function]) ||
        body.array_results[function]!=0 || body.record_results[function]!=0){return .err(errors::make(5,0));}
    var usize i=0;
    i=0;while(i<body.function_count){var usize a=0;while(a<body.arities[i]){
        let usize r=body.register_starts[i]+a;
        if(body.slice_parameters[r]==0 && body.array_parameters[r]==0 && body.record_parameters[r]==0 && sites.parameters[r]==0 && !types::valid(body.types[r])){return .err(errors::make(5,0));}a+=1;
    }i+=1;}
    i=0;while(i<values.len){let usize r=body.register_starts[function]+i;
        if(sites.parameters[r]!=0){return .err(errors::make(5,0));}
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
    return switch(invoke_proved(ref unit.body,ref unit.elements,ref unit.parameters,function,captures,values,inputs,state,data,fuel,false,
        ref proof.statics,images::payload(image))){
        case .ok(outcome):{if(!outcome.view){.ok(outcome.scalar)}else{.err(errors::make(5,0))}}
        case .err(e):{.err(e)}
    };
}
// Exact immutable image and complete Static/ordinary proof remain borrowed
// throughout execution. Host entry cannot manufacture Static formals/results.
pub fn Result<Scalar,errors::Error> execute_static_scalar(ref image_calls::Program unit,ref images::Image image,
    usize function,ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let image_verifier::StaticCallProof proof=image_verifier::verify_static_calls(unit,image)?;
    let u8[16] none=[0;16];
    return switch(invoke_proved(ref unit.body,ref none,ref none,function,captures,values,inputs,state,data,fuel,false,
        ref proof.statics,images::payload(image))){
        case .ok(outcome):{if(!outcome.view){.ok(outcome.scalar)}else{.err(errors::make(5,0))}}
        case .err(e):{.err(e)}
    };
}
// The retained reference-aware Program owns this exact proved code/image.
// Kind-3 external entry/results stay gated; internal CALLs select actual backing.
pub fn Result<Scalar,errors::Error> execute_reference_scalar(ref image_calls::Program unit,ref images::Image image,
    usize function,ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let image_verifier::ReferenceCallProof proof=image_verifier::inspect_reference_calls(unit,image)?;
    let u8[16] none=[0;16];
    return switch(invoke_proved(ref unit.body,ref none,ref none,function,captures,values,inputs,state,data,fuel,false,
        ref proof.statics,images::payload(image))){
        case .ok(outcome):{if(!outcome.view){.ok(outcome.scalar)}else{.err(errors::make(5,0))}}
        case .err(e):{.err(e)}
    };
}
// Result-kind-3 entry remains internal; native callers still receive scalars.
pub fn Result<Scalar,errors::Error> execute_reference_returns_scalar(ref image_calls::Program unit,ref images::Image image,
    usize function,ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let image_verifier::ReferenceReturnProof proof=image_verifier::inspect_reference_returns(unit,image)?;
    let u8[16] none=[0;16];
    return switch(invoke_proved(ref unit.body,ref none,ref none,function,captures,values,inputs,state,data,fuel,false,
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
    return invoke_proved(ref unit.body,ref unit.elements,ref unit.parameters,function,captures,values,inputs,state,data,fuel,view,ref sites,ref unused[..0]);
}
fn Result<Outcome,errors::Error> invoke_proved(ref body_ir::Program body,ref u8[] elements,ref u8[] parameters,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel,bool view,
    ref statics::Sites sites,ref u8[] literals){
    let usize admitted=admit(body,elements,sites,function,values,captures.len,inputs,view)?;
    let usize depth=switch(authority::inspect(ref state.runtime.authority)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    if(!available(ref state.runtime.authority,true)){return .err(errors::make(5,0));}
    let list_values::Requirement list_plan=list_values::requirement(body)?;
    let record_places::Requirement place_plan=record_places::requirement(body)?;
    let usize work=owned_calls::cost(body,function,0)?+body.arities[function];
    if(fuel<runtime::cost()+work+list_plan.cost+place_plan.cost){return .err(errors::make(8,0));}
    var vec::Vec<i64> list_cells=list_values::prepare_values(ref list_plan)?;
    var bytes::Buffer list_scratch=list_values::prepare_encoded(ref list_plan)?;
    var vec::Vec<usize> place_state=record_places::prepare(ref place_plan)?;
    let runtime::Entered first=entry::enter(body,function,binding(body,parameters,function),captures,inputs,state,data,fuel-list_plan.cost-place_plan.cost)?;
    let Result<Outcome,errors::Error> outcome=start(body,parameters,function,ref first,values,state,data,sites,literals,ref mut list_cells,ref mut list_scratch,ref mut place_state);
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
fn Result<Outcome,errors::Error> start(ref body_ir::Program body,ref u8[] parameters,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state){
    var frames::Frames bindings=frames::empty(state);
    return run(body,parameters,function,first,values,ref mut bindings,state,data,sites,literals,list_cells,list_scratch,place_state);
}
fn Result<Outcome,errors::Error> run(ref body_ir::Program body,ref u8[] parameters,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state){
    var usize[32] static_live=[0;32];var u32[512] static_words=[0;512];
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
        if(op>=83 && op<=86){
            if(body.code[at+4]==2 || (op==86 && place_frames::format(place_state,offset)?.prefix==2)){
                let usize price=record_places::price(body,pc,f,place_state)?;
                if(remaining<price){return .err(errors::make(8,offset));}
                let owners::Token current=if(op==83){record_bindings::get(ref bindings.records,frame*16+a)}else{owners::Token{.slot=0,.generation=0}};
                remaining=record_places::bound(body,pc,f,frame,place_state,ref state.runtime.owners,current,
                    data,ref mut registers[base..base+128],remaining)?;
            }else{remaining=places::bound(body,pc,f,frame,place_state,ref state.runtime.owners,ref bindings.tokens,
                ref state.runtime.pool,ref bindings.sites,data,ref mut registers[base..base+128],remaining)?;
            }pc+=1;continue;
        }
        if(op==8 || op==39 || op==50 || op==65 || op==79 || op==82){let usize ended=place_frames::empty_frame(place_state,frame,offset)?;}
        if(op==80 || op==81){
            remaining=owned::list(body,pc,bindings,state,ref registers[base..base+128],data,list_cells,list_scratch,remaining)?;
            pc+=1;continue;
        }
        var bool byte_loan=false;
        if(op==57 || op==58){byte_loan=body_ir::slice_element(body,a,offset)?==10;}
        if(op==71 || op==72 || byte_loan){
            if(!byte_loan && words::returned(static_words[frame*16+a])){
                let usize extra=meter::reference_result_lookup();
                let usize price=meter::slice_base(if(op==71){58}else{57},1);
                if(remaining<extra+price){return .err(errors::make(8,offset));}remaining-=extra;
            }
            let access::Source source=if(byte_loan){access::loan(bindings.sites[frame*16+a])}
                else if(sites.kinds[a]==3){references::source(body,sites,f,a,ref static_words[frame*16..frame*16+16],static_live[frame],bindings,literals.len,offset)?}
                else{access::image(a)};
            let access::Value result=if(op==71 || op==58){access::read(ref source,sites,f,
                    ref static_words[frame*16..frame*16+16],static_live[frame],literals,
                    ref state.runtime.pool,ref state.runtime.owners,data,registers[base+b],remaining,offset)?}
                else{access::length(ref source,sites,f,
                    ref static_words[frame*16..frame*16+16],static_live[frame],literals,
                    ref state.runtime.pool,ref state.runtime.owners,data.len,remaining,offset)?};
            registers[base+dst]=result.value;remaining=result.remaining;pc+=1;continue;
        }
        if(op==77){
            remaining=if(body.code[at+3]==3){references::parameter(body,sites,pc,f,
                ref static_words[frame*16..frame*16+16],static_live[frame],bindings,state,literals,data.len,remaining)?}
                else{transfer::parameter(body,sites,literals.len,pc,f,
                    ref static_words[frame*16..frame*16+16],static_live[frame],remaining)?};
            let usize one=1;static_live[frame]|=one<<dst;pc+=1;continue;
        }
        if((op==70 || op==75 || op==76) && dst<16 && sites.kinds[dst]==3){
            if(op==70 && words::returned(static_words[frame*16+dst])){
                let receipts::Closed closed=receipts::close(ref mut bindings.loans,state,frame,dst,
                    ref mut static_words[frame*16..frame*16+16],static_live[frame],data.len,remaining,offset)?;
                static_live[frame]=closed.live;remaining=closed.remaining;pc+=1;continue;
            }
            let references::Step next=references::step(body,sites,pc,f,
                ref mut static_words[frame*16..frame*16+16],static_live[frame],bindings,
                ref registers[base..base+128],literals.len,remaining)?;
            static_live[frame]=next.live;remaining=next.remaining;pc+=1;continue;
        }
        if(statics::operation(op)){
            let immutable::Step next=immutable::step_frame(body,sites,literals,pc,f,
                ref mut registers[base..base+128],static_live[frame],remaining,ref mut static_words[frame*16..frame*16+16])?;
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
        if(op==9 || op==64 || op==66 || op==78){
            if(frame>=31 || !available(ref state.runtime.authority,false)){return .err(errors::make(12,offset));}
            let usize fresh=place_frames::empty_frame(place_state,frame+1,offset)?;
            var runtime::Contract c=binding(body,parameters,a);
            let bool generic=op==78 && (sites.results[a]==3 || references::parameters(body,sites,a));
            var transfer::Arguments staged=transfer::Arguments{.words=[0;16],.remaining=remaining};
            var references::Arguments captured=references::empty(remaining);
            if(generic){captured=references::arguments(body,sites,pc,f,ref static_words[frame*16..frame*16+16],
                static_live[frame],bindings,state,data.len,literals.len,remaining)?;c.tags=captured.tags;
                if(sites.results[a]==3 && sites.origins[a]!=9){let usize origin=sites.origins[a] as usize;
                    if(origin==0 || origin>c.arity){return .err(errors::make(5,offset));}
                    c.selected=if(c.tags[origin-1]==10){origin}else{0};}
            }
            else if(op==78){staged=transfer::arguments(body,sites,literals.len,pc,f,
                ref static_words[frame*16..frame*16+16],static_live[frame],remaining)?;}
            remaining=switch(if(generic){owned::enter_captured(body,pc,c,bindings,state,data,captured.remaining,ref captured.captures[..c.arity])}
                else{owned::enter(body,pc,c,bindings,state,data,staged.remaining)}){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            static_live[frame+1]=0;
            i=0;while(i<16){static_words[(frame+1)*16+i]=if(generic){captured.words[i]}else{staged.words[i]};i+=1;}
            i=0;while(i<c.arity){let usize formal=body.register_starts[a]+i;let usize source=body.call_args[b*8+i] as usize;
                if(c.tags[i]==0 && body.array_parameters[formal]==0 && body.record_parameters[formal]==0 && sites.parameters[formal]==0){registers[(frame+1)*128+formal]=registers[base+source];}i+=1;
            }pc=body.starts[a];continue;
        }
        if(op==79){
            let usize next=bindings.continuations[frame];
            if(frame<=1 || next==0 || next>body.count){return .err(errors::make(5,offset));}
            let usize parent=frame-1;let usize caller=bindings.functions[parent];
            if(sites.results[f]==3){
                let reference_returns::Returned staged=reference_returns::prepare(body,sites,pc,f,
                    ref static_words[frame*16..frame*16+16],static_live[frame],static_live[parent],bindings,state,literals.len,remaining)?;
                if(staged.loan){var runtime::Call call=frames::current(bindings);
                    let runtime::Returned result=records::handoff(bindings,state,ref mut call,staged.ticket,data.len,staged.remaining)?;
                    let usize resumed=frames::pop_reference(body,bindings,result)?;
                    static_live[parent]=receipts::publish(ref mut bindings.loans,parent,staged.destination,result.held,staged.span,
                        ref mut static_words[parent*16..parent*16+16],static_live[parent],offset)?;
                    remaining=result.remaining;
                }else{let runtime::Resumed resumed=owned::leave(body,pc,8,bindings,state,data,staged.remaining)?;
                    static_words[parent*16+staged.destination]=staged.word;let usize one=1;static_live[parent]|=one<<staged.destination;
                    remaining=resumed.remaining;
                }
                static_live[frame]=0;i=0;while(i<16){static_words[frame*16+i]=0;i+=1;}pc=next;continue;
            }
            let transfer::Returned staged=transfer::returned(body,sites,literals.len,pc,f,
                ref static_words[frame*16..frame*16+16],static_live[frame],next-1,caller,
                bindings.destinations[frame],static_live[parent],remaining)?;
            // The native ordinary-return transaction restores all loan inputs;
            // no image view or payload ownership is transferred by that layer.
            let runtime::Resumed resumed=switch(owned::leave(body,pc,8,bindings,state,data,staged.remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            remaining=resumed.remaining;static_live[frame]=0;
            i=0;while(i<16){static_words[frame*16+i]=0;i+=1;}
            static_words[parent*16+staged.destination]=staged.word;
            let usize one=1;static_live[parent]|=one<<staged.destination;pc=next;continue;
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
        if(op==8 || op==39 || op==50 || op==82){
            if(op==82 && (frame==1 || body.return_types[f]!=13)){return .err(errors::make(5,offset));}
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
