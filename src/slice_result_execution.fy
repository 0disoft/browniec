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
import place_dispatch as places;
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
import output_return_proof as output_proof;
import reference_access as access;
import reference_execution as references;
import reference_words as words;
import reference_receipts as receipts;
import reference_return_execution as reference_returns;
import fuel as meter;
import std::vec as vec;
import std::bytes as bytes;
import input_reference_views as input_views;
import cells as cells;
import static_views as input_spans;
import runtime_output as output;
import output_execution as output_steps;
import slice_result_cursor as cursors;
import output_copy_cursor as output_copy;
import array_fill_cursor as array_fill;
import array_fill_execution as array_steps;
import array_copy_execution as array_copies;
import array_list_execution as array_lists;
import struct_work_execution as record_steps;
import call_work_execution as call_steps;
import call_metadata_state as call_metadata;
import metadata_budget as metadata_budget;
import return_metadata_execution as return_metadata;
import runtime_metadata_work as metadata_work;
import call_capture_plan as capture_plans;
import return_work_execution as return_steps;
import return_work_cursor as return_work;
import call_copy_cursor as call_copy;

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
fn Result<usize,errors::Error> admit(ref body_ir::Program body,ref u8[] elements,ref statics::Sites sites,usize function,ref i64[] values,usize captures,ref owners::Token[] inputs,bool view,bool input){
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
        if(sites.parameters[r]!=0){
            if(!input || function!=body.entry || values.len!=1 || i!=0 || sites.parameters[r]!=3 || values[i]!=0 || inputs.len!=0){return .err(errors::make(5,0));}
            i+=1;continue;
        }
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
// Exact separately admitted input ABI. No input owner or descriptor escapes;
// the caller's immutable backing remains borrowed through every nested frame.
pub fn Result<Scalar,errors::Error> execute_input_scalar(ref image_calls::Program unit,ref images::Image image,
    ref u8[] guest,ref mut runtime::State state,ref mut u8[] data,usize fuel){
    var usize remaining=fuel;
    return execute_input_scalar_metered(unit,image,guest,state,data,ref mut remaining);
}
// Explicit terminal meter: every committed debit survives Result::err. Helper
// transactions return a new balance only on success; failed atomic work does
// not commit its price. Dispatch and staged metadata debits remain independent.
pub fn Result<Scalar,errors::Error> execute_input_scalar_metered(ref image_calls::Program unit,ref images::Image image,
    ref u8[] guest,ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining){
    let image_verifier::ReferenceReturnProof proof=image_verifier::inspect_input_returns(unit,image)?;
    if(guest.len>1048576){return .err(errors::make(4,0));}
    let u8[16] none=[0;16];let runtime::Capture[1] captures=[runtime::capture(frames::none(),false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    return switch(invoke_input_metered(ref unit.body,ref none,ref none,unit.body.entry,ref captures,ref values,ref inputs[..0],
        state,data,remaining,false,ref proof.statics,images::payload(image),true,guest,ref proof.recipes.site_origins)){
        case .ok(v):{if(v.view){.err(errors::make(5,0))}else{.ok(v.scalar)}}case .err(e):{.err(e)}
    };
}
// A separately admitted output dialect; no ordinary/input entry point accepts
// EMIT116. The exact transaction and single VM Fuel meter stay borrowed through
// all nested calls and are never exposed to the guest.
pub fn Result<Scalar,errors::Error> execute_output_scalar_metered(ref image_calls::Program unit,ref images::Image image,
    ref u8[] guest,bool input,ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining,
    ref mut output::Transaction staged){
    var cursors::Stats stats=cursors::stats();
    return execute_output_scalar_quantized(unit,image,guest,input,state,data,remaining,staged,4096,ref mut stats);
}
pub fn Result<Scalar,errors::Error> execute_output_scalar_quantized(ref image_calls::Program unit,ref images::Image image,
    ref u8[] guest,bool input,ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining,
    ref mut output::Transaction staged,usize quantum,ref mut cursors::Stats stats){
    if(!cursors::valid_quantum(quantum)){return .err(errors::make(5,0));}
    let output_proof::Proof proof=output_proof::inspect(unit,image,input)?;
    if(guest.len>1048576 || (!input && guest.len!=0)){return .err(errors::make(4,0));}
    let usize arity=if(input){1}else{0};
    let runtime::Capture[1] captures=[runtime::capture(frames::none(),false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    return switch(invoke_output_quantized(ref unit.body,ref proof.elements,ref proof.parameters,unit.body.entry,ref captures[..arity],ref values[..arity],ref inputs[..0],
        state,data,remaining,false,ref proof.ordinary.statics,images::payload(image),input,guest,ref proof.ordinary.recipes.site_origins,staged,quantum,stats)){
        case .ok(v):{if(v.view){.err(errors::make(5,0))}else{.ok(v.scalar)}}case .err(e):{.err(e)}
    };
}
// Trusted owning Program boundary: sites/origins/parameters, plans and work belong
// to this exact immutable code/image. Work already includes the entry arity.
// Raw callers must continue through the independently verified entry above.
pub fn Result<Scalar,errors::Error> execute_output_admitted(ref image_calls::Program unit,ref images::Image image,
    ref statics::Sites sites,ref u8[] origins,ref u8[] parameters,ref list_values::Requirement list_plan,ref places::Requirement place_plan,usize work,
    ref u8[] guest,bool input,ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining,
    ref mut output::Transaction staged,usize quantum,ref mut cursors::Stats stats,ref capture_plans::Plan plans){
    if(!cursors::valid_quantum(quantum) || parameters.len!=16){return .err(errors::make(5,0));}
    if(guest.len>1048576 || (!input && guest.len!=0)){return .err(errors::make(4,0));}
    let usize arity=if(input){1}else{0};
    let u8[16] none=[0;16];let runtime::Capture[1] captures=[runtime::capture(frames::none(),false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize admitted=admit(ref unit.body,ref none,sites,unit.body.entry,ref values[..arity],arity,ref inputs[..0],false,input)?;
    let usize depth=switch(authority::inspect(ref state.runtime.authority)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    if(!available(ref state.runtime.authority,true)){return .err(errors::make(5,0));}
    return switch(invoke_output_planned(ref unit.body,parameters,unit.body.entry,ref captures[..arity],ref values[..arity],ref inputs[..0],
        state,data,remaining,sites,images::payload(image),input,guest,origins,list_plan,place_plan,work,staged,quantum,stats,plans)){
        case .ok(v):{if(v.view){.err(errors::make(5,0))}else{.ok(v.scalar)}}case .err(e):{.err(e)}
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
    let u8[16] origins=[0;16];
    return invoke_input(body,elements,parameters,function,captures,values,inputs,state,data,fuel,view,
        sites,literals,false,literals[..0],ref origins);
}
fn Result<Outcome,errors::Error> invoke_input(ref body_ir::Program body,ref u8[] elements,ref u8[] parameters,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel,bool view,
    ref statics::Sites sites,ref u8[] literals,bool input,ref u8[] guest,ref u8[] origins){
    var usize remaining=fuel;
    return invoke_input_metered(body,elements,parameters,function,captures,values,inputs,state,data,ref mut remaining,view,
        sites,literals,input,guest,origins);
}
fn Result<Outcome,errors::Error> invoke_input_metered(ref body_ir::Program body,ref u8[] elements,ref u8[] parameters,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining,bool view,
    ref statics::Sites sites,ref u8[] literals,bool input,ref u8[] guest,ref u8[] origins){
    var output::Transaction disabled=output::disabled();
    return invoke_output_metered(body,elements,parameters,function,captures,values,inputs,state,data,remaining,view,
        sites,literals,input,guest,origins,ref mut disabled);
}
fn Result<Outcome,errors::Error> invoke_output_metered(ref body_ir::Program body,ref u8[] elements,ref u8[] parameters,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining,bool view,
    ref statics::Sites sites,ref u8[] literals,bool input,ref u8[] guest,ref u8[] origins,ref mut output::Transaction staged){
    var cursors::Stats stats=cursors::stats();
    return invoke_output_quantized(body,elements,parameters,function,captures,values,inputs,state,data,remaining,view,
        sites,literals,input,guest,origins,staged,4096,ref mut stats);
}
fn Result<Outcome,errors::Error> invoke_output_quantized(ref body_ir::Program body,ref u8[] elements,ref u8[] parameters,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining,bool view,
    ref statics::Sites sites,ref u8[] literals,bool input,ref u8[] guest,ref u8[] origins,ref mut output::Transaction staged,usize quantum,ref mut cursors::Stats stats){
    if(!cursors::valid_quantum(quantum)){return .err(errors::make(5,0));}
    let usize admitted=admit(body,elements,sites,function,values,captures.len,inputs,view,input)?;
    let usize depth=switch(authority::inspect(ref state.runtime.authority)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    if(!available(ref state.runtime.authority,true)){return .err(errors::make(5,0));}
    let list_values::Requirement list_plan=list_values::requirement(body)?;
    let places::Requirement place_plan=places::requirement(body)?;
    let usize work=owned_calls::cost(body,function,0)?+body.arities[function];
    let capture_plans::Plan plans=capture_plans::empty();
    return invoke_output_planned(body,parameters,function,captures,values,inputs,state,data,remaining,
        sites,literals,input,guest,origins,ref list_plan,ref place_plan,work,staged,quantum,stats,ref plans);
}
// Both entry paths finish admission before setup. Preserve Fuel preflight,
// allocation/debit order and abort semantics while consuming exact cached plans.
fn Result<Outcome,errors::Error> invoke_output_planned(ref body_ir::Program body,ref u8[] parameters,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,ref mut usize remaining,
    ref statics::Sites sites,ref u8[] literals,bool input,ref u8[] guest,ref u8[] origins,
    ref list_values::Requirement list_plan,ref places::Requirement place_plan,usize work,
    ref mut output::Transaction staged,usize quantum,ref mut cursors::Stats stats,ref capture_plans::Plan plans){
    let usize input_cost=if(input){meter::input_prepare()}else{0};
    if(*remaining<runtime::cost()+work+list_plan.cost+place_plan.cost+input_cost){return .err(errors::make(8,0));}
    var input_views::State windows=if(input){input_views::open(guest.len)?}else{input_views::disabled()};
    *remaining-=input_cost;
    var vec::Vec<i64> list_cells=list_values::prepare_values(list_plan)?;
    var bytes::Buffer list_scratch=list_values::prepare_encoded(list_plan)?;
    *remaining-=list_plan.cost;
    var vec::Vec<usize> place_state=places::prepare_metered(place_plan,*remaining)?;
    *remaining-=place_plan.cost;
    let runtime::Entered first=entry::enter_prepared(body,function,binding(body,parameters,function),captures,inputs,state,data,*remaining,work)?;
    *remaining=first.call.remaining;
    let Result<Outcome,errors::Error> outcome=start_cached(body,parameters,function,ref first,values,state,data,sites,literals,ref mut list_cells,ref mut list_scratch,ref mut place_state,ref mut windows,guest,origins,remaining,staged,quantum,stats,plans);
    return switch(outcome){
        case .ok(v):{.ok(v)}
        case .err(e):{
            // No result receipt escapes on failure. Preserve the first error and
            // earlier payload writes; invocation metadata drains at zero Fuel.
            places::abort(ref mut place_state);
            let bool drained=runtime::abort(state,data.len,0).is_ok;
            .err(e)
        }
    };
}
// Keep the large frame maps out of the independent admission call stack.
// Their native storage is needed only after verification and initial entry.
fn Result<Outcome,errors::Error> start(ref body_ir::Program body,ref u8[] parameters,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,usize quantum,ref mut cursors::Stats stats){
    let capture_plans::Plan plans=capture_plans::empty();
    return start_cached(body,parameters,function,first,values,state,data,sites,literals,list_cells,list_scratch,place_state,windows,guest,origins,remaining,staged,quantum,stats,ref plans);
}
fn Result<Outcome,errors::Error> start_cached(ref body_ir::Program body,ref u8[] parameters,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,usize quantum,ref mut cursors::Stats stats,ref capture_plans::Plan plans){
    var frames::Frames bindings=frames::empty(state);
    return run(body,parameters,function,first,values,ref mut bindings,state,data,sites,literals,list_cells,list_scratch,place_state,windows,guest,origins,remaining,staged,quantum,stats,plans);
}
fn input_spans::Span span_for_input(usize length){return input_spans::Span{.start=0,.length=length};}
fn Result<Outcome,errors::Error> run(ref body_ir::Program body,ref u8[] parameters,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,usize quantum,ref mut cursors::Stats stats,ref capture_plans::Plan plans){
    var cursors::Cursor cursor=cursors::empty();
    var usize[32] static_live=[0;32];var u32[512] static_words=[0;512];
    var i64[4096] registers=[0;4096];
    let usize begun=begin_saved(body,function,first,values,bindings,sites,windows,guest.len,
        ref mut cursor,ref mut static_words,ref mut registers)?;
    while(cursor.active){
        let Option<Outcome> progress=drive(body,parameters,bindings,state,data,sites,literals,list_cells,list_scratch,place_state,windows,guest,origins,remaining,staged,ref mut cursor,ref mut static_live,ref mut static_words,ref mut registers,quantum,stats,plans)?;
        switch(progress){case .none:{}case .some(value):{return .ok(value);}};
    }
    return .err(errors::make(5,0));
}
// One-time entry initialization shared by synchronous and owning callers.
// The owning caller supplies separately projected banks, never a whole-state copy.
fn Result<usize,errors::Error> begin_saved(ref body_ir::Program body,usize function,ref runtime::Entered first,
    ref i64[] values,ref mut frames::Frames bindings,ref statics::Sites sites,ref mut input_views::State windows,
    usize guest_length,ref mut cursors::Cursor cursor,ref mut u32[] static_words,ref mut i64[] registers){
    if(cursor.active || bindings.frame!=0 || static_words.len!=512 || registers.len!=4096){return .err(errors::make(5,0));}
    let usize entered=frames::push(body,bindings,first.call,function,128,32,0)?;
    entry::bind(body,function,ref first.copies,bindings);
    if(input_views::enabled(windows)){
        let usize formal=body.register_starts[function];let usize site=sites.formal_sites[formal] as usize;
        if(body.arities[function]!=1 || sites.parameters[formal]!=3 || site==0 || site>16){return .err(errors::make(5,0));}
        let usize granted=input_views::put_grant(windows,1,0,span_for_input(guest_length),0)?;
        let usize bound=input_views::put(windows,1,site-1,span_for_input(guest_length),0)?;
        static_words[16+site-1]=input_views::marker();
    }
    var usize i=0;while(i<values.len){registers[128+body.register_starts[function]+i]=values[i];i+=1;}
    cursor.pc=body.starts[function];cursor.active=true;
    return .ok(cursor.pc);
}
// Low-level saved entry computes its own price after the shared admission checks.
pub fn Result<usize,errors::Error> start_output_saved(ref body_ir::Program body,ref statics::Sites sites,bool input,usize guest_length,
    ref mut runtime::State state,ref mut u8[] data,ref mut frames::Frames bindings,ref mut input_views::State windows,ref mut usize remaining,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers){
    let u8[16] none=[0;16];
    return start_output_impl(body,sites,ref none,input,guest_length,state,data,bindings,windows,remaining,
        cursor,static_live,static_words,registers,.none);
}
// Legacy prepared entry retains zero selected origins.
pub fn Result<usize,errors::Error> start_output_prepared(ref body_ir::Program body,ref statics::Sites sites,bool input,usize guest_length,
    ref mut runtime::State state,ref mut u8[] data,ref mut frames::Frames bindings,ref mut input_views::State windows,ref mut usize remaining,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,usize work){
    let u8[16] none=[0;16];
    return start_output_prepared_with_parameters(body,sites,ref none,input,guest_length,state,data,bindings,windows,remaining,
        cursor,static_live,static_words,registers,work);
}
// Trusted owning-output bridge. Exact code/image proof and storage preparation
// precede this entry; work and selected origins belong to the pinned Program.
pub fn Result<usize,errors::Error> start_output_prepared_with_parameters(ref body_ir::Program body,ref statics::Sites sites,ref u8[] parameters,bool input,usize guest_length,
    ref mut runtime::State state,ref mut u8[] data,ref mut frames::Frames bindings,ref mut input_views::State windows,ref mut usize remaining,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,usize work){
    return start_output_impl(body,sites,parameters,input,guest_length,state,data,bindings,windows,remaining,
        cursor,static_live,static_words,registers,.some(work));
}
// Share validation, entry publication and saved-bank initialization. The raw
// wrapper keeps cost calculation after admission; prepared entry never rescans.
fn Result<usize,errors::Error> start_output_impl(ref body_ir::Program body,ref statics::Sites sites,ref u8[] parameters,bool input,usize guest_length,
    ref mut runtime::State state,ref mut u8[] data,ref mut frames::Frames bindings,ref mut input_views::State windows,ref mut usize remaining,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,Option<usize> prepared_work){
    if(guest_length>1048576 || (!input && guest_length!=0) || input!=input_views::enabled(windows) ||
        parameters.len!=16 || static_live.len!=32 || static_words.len!=512 || registers.len!=4096 || cursor.active || bindings.frame!=0){return .err(errors::make(5,0));}
    let usize arity=if(input){1}else{0};
    let u8[16] none=[0;16];let runtime::Capture[1] captures=[runtime::capture(frames::none(),false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize admitted=admit(body,ref none,sites,body.entry,ref values[..arity],arity,ref inputs[..0],false,input)?;
    let usize depth=switch(authority::inspect(ref state.runtime.authority)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    if(!available(ref state.runtime.authority,true)){return .err(errors::make(5,0));}
    let runtime::Contract contract=binding(body,parameters,body.entry);
    let usize work=switch(prepared_work){case .some(value):{value}case .none:{owned_calls::cost(body,body.entry,0)?+contract.arity}};
    let runtime::Entered first=entry::enter_prepared(body,body.entry,contract,ref captures[..arity],ref inputs[..0],state,data,*remaining,work)?;
    *remaining=first.call.remaining;
    return begin_saved(body,body.entry,ref first,ref values[..arity],bindings,sites,windows,guest_length,cursor,static_words,registers);
}
// Returns to the owning caller at Pending; it never recreates entry, banks,
// proofs, frames, or staged output. Bulk operations remain atomic for now.
pub fn Result<Option<Scalar>,errors::Error> step_output_saved(ref body_ir::Program body,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,usize quantum,ref mut cursors::Stats stats){
    let u8[16] none=[0;16];
    return step_output_saved_with_parameters(body,ref none,bindings,state,data,sites,literals,list_cells,list_scratch,place_state,windows,guest,origins,
        remaining,staged,cursor,static_live,static_words,registers,quantum,stats);
}
// Resume with the exact immutable owning Preparation's selected origins.
pub fn Result<Option<Scalar>,errors::Error> step_output_saved_with_parameters(ref body_ir::Program body,ref u8[] parameters,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,usize quantum,ref mut cursors::Stats stats){
    let capture_plans::Plan plans=capture_plans::empty();
    return step_output_cached(body,parameters,bindings,state,data,sites,literals,list_cells,list_scratch,place_state,windows,guest,origins,remaining,staged,cursor,static_live,static_words,registers,quantum,stats,ref plans);
}
pub fn Result<Option<Scalar>,errors::Error> step_output_cached(ref body_ir::Program body,ref u8[] parameters,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,usize quantum,ref mut cursors::Stats stats,ref capture_plans::Plan plans){
    if(parameters.len!=16 || static_live.len!=32 || static_words.len!=512 || registers.len!=4096 || origins.len!=16){return .err(errors::make(5,0));}
    return switch(drive(body,parameters,bindings,state,data,sites,literals,list_cells,list_scratch,place_state,windows,guest,origins,
        remaining,staged,cursor,static_live,static_words,registers,quantum,stats,plans)){
        case .err(e):{.err(e)}case .ok(v):{switch(v){
            case .none:{.ok(.none)}case .some(done):{if(done.view){.err(errors::make(5,0))}else{.ok(.some(done.scalar))}}
        }}
    };
}
// Only this owning adapter borrows the preallocated metadata Core. Legacy
// saved/raw and synchronous execution retain their independent atomic oracle
// without constructing a large unused Work on the native stack.
pub fn Result<Option<Scalar>,errors::Error> step_output_cached_staged(ref body_ir::Program body,ref u8[] parameters,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,
    usize quantum,ref mut cursors::Stats stats,ref capture_plans::Plan plans,ref mut call_metadata::State metadata){
    if(parameters.len!=16 || static_live.len!=32 || static_words.len!=512 || registers.len!=4096 || origins.len!=16 || !cursor.active){return .err(errors::make(5,0));}
    let usize admitted=cursors::begin(stats,quantum)?;
    cursor.output.last=0;cursor.array.last=0;cursor.call.last=0;cursor.returned.last=0;
    let usize reset=metadata_budget::reset(ref mut cursor.metadata,0)?;metadata.copy.last=0;
    var usize visited=0;
    let Result<Option<Outcome>,errors::Error> outcome=dispatch_staged(body,parameters,bindings,state,data,sites,literals,list_cells,list_scratch,
        place_state,windows,guest,origins,remaining,staged,cursor,static_live,static_words,registers,quantum,ref mut visited,plans,metadata);
    return switch(outcome){
        case .err(e):{cursor.active=false;let usize recorded=cursors::finish(stats,visited,false)?;.err(e)}
        case .ok(value):{let bool pending=switch(value){case .none:{true}case .some(_):{false}};
            let usize recorded=cursors::finish(stats,visited,pending)?;
            if(!pending){cursor.active=false;}
            switch(value){case .none:{.ok(.none)}case .some(done):{if(done.view){.err(errors::make(5,0))}else{.ok(.some(done.scalar))}}}
        }
    };
}
fn Result<usize,errors::Error> dispatch_room(ref cursors::Cursor cursor){
    if(cursor.output.last>4096 || cursor.array.last>4096-cursor.output.last){return .err(errors::make(5,0));}
    if(cursor.call.last>4096-cursor.output.last-cursor.array.last){return .err(errors::make(5,0));}
    if(cursor.returned.last>4096-cursor.output.last-cursor.array.last-cursor.call.last){return .err(errors::make(5,0));}
    if(cursor.metadata.last>4096-cursor.output.last-cursor.array.last-cursor.call.last-cursor.returned.last){return .err(errors::make(5,0));}
    return .ok(4096-cursor.output.last-cursor.array.last-cursor.call.last-cursor.returned.last-cursor.metadata.last);
}
fn Result<Option<Outcome>,errors::Error> dispatch_staged(ref body_ir::Program body,ref u8[] parameters,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,
    usize quantum,ref mut usize visited,ref capture_plans::Plan plans,ref mut call_metadata::State metadata){
    while(cursor.pc<body.count){
        let usize room=dispatch_room(cursor)?;if(*visited==quantum || room==0){return .ok(.none);}
        let usize frame=bindings.frame;if(frame==0 || frame>=32){return .err(errors::make(5,0));}
        let usize f=bindings.functions[frame];if(f>=body.function_count || cursor.pc<body.starts[f] || cursor.pc>=body.ends[f]){return .err(errors::make(5,0));}
        let usize offset=body.offsets[cursor.pc];
        if(cursor.return_metadata.pending){
            if(cursor.return_metadata.pc!=cursor.pc || cursor.return_metadata.frame!=frame || metadata.active ||
                cursor.call.pending || cursor.array.active || cursor.output.active){return .err(errors::make(5,offset));};
            *visited+=1;
            var return_metadata::State returning=cursor.return_metadata;
            let bool finished=return_metadata::advance(ref mut returning,ref mut metadata.metadata,ref mut cursor.metadata,
                body,sites,bindings,state,data.len,windows,origins,static_live,static_words,registers,remaining,room,plans)?;
            cursor.return_metadata=returning;
            if(!finished){return .ok(.none);}
            cursor.pc=returning.next;
            if(returning.complete){
                let ref metadata_work::State completed_plan=ref metadata.metadata;
                let runtime::Returned result=completed_plan.returned;
                if(returning.view){return .ok(.some(transferred(result)));}
                return .ok(.some(completed(Scalar{.value=returning.value,.remaining=*remaining,.resumed=result.resumed})));
            }continue;
        }
        if(metadata.active){
            if(!cursor.call.pending || cursor.call.pc!=cursor.pc || cursor.call.frame!=frame || cursor.array.active || cursor.output.active){return .err(errors::make(5,offset));};
            *visited+=1;
            let bool finished=call_steps::advance_staged(metadata,ref mut cursor.metadata,body,sites,bindings,state,data,
                windows,static_live,static_words,registers,remaining,room)?;
            cursor.call=metadata.copy;cursor.call_metadata_phase=metadata.phase;
            if(finished){cursor.pc=body.starts[cursor.call.target];continue;}return .ok(.none);
        }
        if(cursor.call.pending){return .err(errors::make(5,offset));}
        if(call_steps::operation(body,cursor.pc) && !cursor.array.active && !cursor.output.active){
            if(*remaining==0){return .err(errors::make(8,offset));};*remaining-=1;*visited+=1;
            let usize begun=call_steps::begin_staged(metadata,body,parameters,sites,cursor.pc,bindings,state,data.len,literals.len,
                static_words[frame*16..frame*16+16],static_live[frame],windows,place_state,remaining,plans)?;
            let bool finished=call_steps::advance_staged(metadata,ref mut cursor.metadata,body,sites,bindings,state,data,
                windows,static_live,static_words,registers,remaining,room)?;
            cursor.call=metadata.copy;cursor.call_metadata_phase=metadata.phase;
            if(finished){cursor.pc=body.starts[cursor.call.target];continue;}return .ok(.none);
        }
        if(return_metadata::operation(body,cursor.pc) && !cursor.array.active && !cursor.output.active){
            if(*remaining==0){return .err(errors::make(8,offset));}
            let usize measured=return_steps::required(body,cursor.pc)?;
            if(measured>4096){return .err(errors::make(5,offset));}if(measured>room){return .ok(.none);}
            let usize ready=return_work::check(ref cursor.returned,measured,offset)?;
            *remaining-=1;*visited+=1;
            let usize empty=place_frames::empty_frame(place_state,frame,offset)?;
            var return_metadata::State returning=cursor.return_metadata;
            let usize begun=return_metadata::begin(ref mut returning,body,sites,cursor.pc,bindings,state,data,literals.len,
                windows,origins,static_live,static_words,registers,remaining)?;
            cursor.return_metadata=returning;
            let usize instruction=cursor.pc;let u8 operation=body.code[instruction*8];
            return_work::record(ref mut cursor.returned,measured,instruction,frame,operation);
            // Prefix preparation remains atomic; run it alone before the first
            // restoration stage, without claiming a false 4096 metadata debit.
            return .ok(.none);
        }
        let Option<Outcome> result=dispatch(body,parameters,bindings,state,data,sites,literals,list_cells,list_scratch,place_state,windows,
            guest,origins,remaining,staged,cursor,static_live,static_words,registers,quantum,visited,plans,true)?;
        switch(result){case .some(done):{return .ok(.some(done));}case .none:{}};
        if((!call_steps::operation(body,cursor.pc) && !return_metadata::operation(body,cursor.pc)) || cursor.array.active || cursor.output.active){return .ok(.none);}
    }return .err(errors::make(5,0));
}
pub fn void abort_saved(ref mut runtime::State state,usize capacity,ref mut vec::Vec<usize> place_state){
    places::abort(place_state);let bool drained=runtime::abort(state,capacity,0).is_ok;
}
// Instruction suspension only: bulk helpers and setup/cleanup still need
// resumable work recipes before this becomes the public bounded-step contract.
fn Result<Option<Outcome>,errors::Error> drive(ref body_ir::Program body,ref u8[] parameters,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,usize quantum,ref mut cursors::Stats stats,ref capture_plans::Plan plans){
    if(!cursor.active){return .err(errors::make(5,0));}
    let usize admitted=cursors::begin(stats,quantum)?;
    cursor.output.last=0;
    cursor.array.last=0;cursor.call.last=0;cursor.returned.last=0;
    let usize reset=metadata_budget::reset(ref mut cursor.metadata,0)?;
    var usize visited=0;
    let Result<Option<Outcome>,errors::Error> outcome=dispatch(body,parameters,bindings,state,data,sites,literals,list_cells,list_scratch,
        place_state,windows,guest,origins,remaining,staged,cursor,static_live,static_words,registers,quantum,ref mut visited,plans,false);
    return switch(outcome){
        case .err(e):{cursor.active=false;let usize recorded=cursors::finish(stats,visited,false)?;.err(e)}
        case .ok(progress):{
            let bool pending=switch(progress){case .none:{true}case .some(_):{false}};
            let usize recorded=cursors::finish(stats,visited,pending)?;
            if(!pending){cursor.active=false;}
            return .ok(progress);
        }
    };
}
fn Result<Option<Outcome>,errors::Error> dispatch(ref body_ir::Program body,ref u8[] parameters,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref mut u8[] data,ref statics::Sites sites,ref u8[] literals,
    ref mut vec::Vec<i64> list_cells,ref mut bytes::Buffer list_scratch,ref mut vec::Vec<usize> place_state,
    ref mut input_views::State windows,ref u8[] guest,ref u8[] origins,ref mut usize remaining,ref mut output::Transaction staged,
    ref mut cursors::Cursor cursor,ref mut usize[] static_live,ref mut u32[] static_words,ref mut i64[] registers,usize quantum,ref mut usize visited,ref capture_plans::Plan plans,bool stop_calls){
    var usize i=0;
    while(cursor.pc<body.count){
        let usize bytes_left=dispatch_room(cursor)?;
        if(*visited==quantum || bytes_left==0){return .ok(.none);}
        let usize frame=bindings.frame;let usize f=bindings.functions[frame];
        if(frame==0 || f>=body.function_count || cursor.pc<body.starts[f] || cursor.pc>=body.ends[f]){return .err(errors::make(5,0));}
        let usize instruction=cursor.pc;let usize at=cursor.pc*8;let usize offset=body.offsets[cursor.pc];let u8 op=body.code[at];
        let usize dst=body.code[at+1] as usize;let usize a=body.code[at+2] as usize;let usize b=body.code[at+3] as usize;
        let usize base=frame*128;
        if(cursor.call.pending){
            if(cursor.call.pc!=cursor.pc || cursor.call.frame!=frame || cursor.array.active || cursor.output.active){return .err(errors::make(5,offset));};
            *visited+=1;var call_copy::State calling=cursor.call;
            let bool finished=call_steps::advance(ref mut calling,body,parameters,sites,bindings,state,data,literals.len,
                windows,static_live,static_words,registers,remaining,bytes_left,plans)?;
            cursor.call=calling;if(finished){cursor.pc=body.starts[calling.target];}continue;
        }
        if(cursor.array.active && (cursor.array.op==41 || cursor.array.op==42 || cursor.array.op==46 ||
            cursor.array.op==47 || cursor.array.op==48 || cursor.array.op==49)){
            if(!record_steps::operation(body,cursor.pc) || cursor.pc!=cursor.array.pc || frame!=cursor.array.frame ||
                offset!=cursor.array.offset || cursor.output.active){return .err(errors::make(5,offset));};
            *visited+=1;var array_fill::State recording=cursor.array;
            let bool finished=record_steps::advance(ref mut recording,body,bindings,state,data,place_state,bytes_left)?;
            cursor.array=recording;if(finished){cursor.pc+=1;}continue;
        }
        if(cursor.array.active && (cursor.array.op==80 || cursor.array.op==81)){
            let u8 expected_op=if(array_lists::selected_list(body,cursor.pc)){81}else{op};
            if(!array_lists::operation(body,cursor.pc) || expected_op!=cursor.array.op || cursor.pc!=cursor.array.pc ||
                frame!=cursor.array.frame || offset!=cursor.array.offset || cursor.output.active){return .err(errors::make(5,offset));};
            *visited+=1;var array_fill::State listing=cursor.array;
            let bool finished=array_lists::advance(ref mut listing,body,bindings,state,data,registers[base..base+128],
                list_cells,list_scratch,place_state,bytes_left)?;
            cursor.array=listing;if(finished){cursor.pc+=1;continue;}return .ok(.none);
        }
        if(cursor.array.active && (cursor.array.op==34 || cursor.array.op==38)){
            let u8 expected_op=if(array_copies::selected_copy(body,cursor.pc)){38}else{op};
            if(!array_copies::operation(body,cursor.pc) || expected_op!=cursor.array.op || cursor.pc!=cursor.array.pc ||
                frame!=cursor.array.frame || offset!=cursor.array.offset || cursor.output.active){return .err(errors::make(5,offset));};
            *visited+=1;var array_fill::State copying=cursor.array;
            let bool finished=array_copies::advance(ref mut copying,body,bindings,state,data,place_state,bytes_left)?;
            cursor.array=copying;if(finished){cursor.pc+=1;}continue;
        }
        if(cursor.array.active){
            let bool selected_fill=array_steps::selected_fill(body,cursor.pc);
            let u8 expected_op=if(selected_fill){40}else{op};
            if((op!=33 && op!=40 && !selected_fill) || expected_op!=cursor.array.op || cursor.pc!=cursor.array.pc ||
                frame!=cursor.array.frame || offset!=cursor.array.offset || cursor.output.active){return .err(errors::make(5,offset));};
            *visited+=1;var array_fill::State filling=cursor.array;
            let bool finished=array_steps::advance(ref mut filling,body,bindings,state,data,place_state,bytes_left)?;
            cursor.array=filling;if(finished){cursor.pc+=1;}continue;
        }
        if(cursor.output.active){
            if(op!=116 || cursor.output.offset!=offset){return .err(errors::make(5,offset));};
            // A continuation visit is work on an already prepaid instruction.
            // The source stays pinned and no guest opcode or charge is replayed.
            *visited+=1;var output_copy::State copying=cursor.output;
            let bool finished=output_steps::advance_limited(ref mut copying,guest,literals,data,staged,bytes_left)?;
            cursor.output=copying;if(finished){cursor.pc+=1;}continue;
        };
        // Owning Core routes CALL/RET authority stages outside this independent
        // dispatcher. Stop before any opcode debit or argument preparation.
        if(stop_calls && (call_steps::operation(body,cursor.pc) || return_metadata::operation(body,cursor.pc))){return .ok(.none);};
        if(*remaining==0){return .err(errors::make(8,offset));};
        if(array_copies::begin_bytes(body,cursor.pc)>bytes_left){return .ok(.none);};
        if(record_steps::operation(body,cursor.pc)){
            let usize staged=record_steps::required_bytes(body,cursor.pc,bindings,place_state,*remaining)?;
            if(staged>bytes_left){return .ok(.none);}
        };
        var usize return_bytes=0;
        if(op==8 || op==39 || op==50 || op==65 || op==79 || op==82){
            return_bytes=return_steps::required(body,cursor.pc)?;
            if(return_bytes>4096){return .err(errors::make(5,offset));}
            if(return_bytes>bytes_left){return .ok(.none);}
            let usize ready=return_work::check(ref cursor.returned,return_bytes,offset)?;
        };
        *remaining-=1;*visited+=1;
        if(record_steps::operation(body,cursor.pc)){
            var array_fill::State recording=record_steps::begin(body,cursor.pc,bindings,state,registers[base..base+128],data,place_state,remaining)?;
            if(recording.total>18446744073709551615-cursor.array.total || recording.last>4096-cursor.array.last){return .err(errors::make(5,offset));}
            recording.total+=cursor.array.total;recording.last+=cursor.array.last;
            let usize room=4096-cursor.output.last-cursor.call.last-cursor.returned.last-cursor.metadata.last-recording.last;
            if(room!=0){let bool finished=record_steps::advance(ref mut recording,body,bindings,state,data,place_state,room)?;}
            cursor.array=recording;if(!recording.active){cursor.pc+=1;}continue;
        }
        if(array_lists::operation(body,cursor.pc)){
            var array_fill::State listing=array_lists::begin(body,cursor.pc,bindings,state,data.len,list_cells,list_scratch,place_state,remaining)?;
            listing.total=cursor.array.total;listing.last=cursor.array.last;
            let bool finished=array_lists::advance(ref mut listing,body,bindings,state,data,registers[base..base+128],
                list_cells,list_scratch,place_state,bytes_left)?;
            cursor.array=listing;if(finished){cursor.pc+=1;continue;}return .ok(.none);
        }
        if(array_copies::operation(body,cursor.pc)){
            var array_fill::State copying=array_copies::begin(body,cursor.pc,bindings,state,data,place_state,remaining)?;
            if(copying.total>18446744073709551615-cursor.array.total || copying.last>4096-cursor.array.last){return .err(errors::make(5,offset));}
            copying.total+=cursor.array.total;copying.last+=cursor.array.last;
            let usize room=4096-cursor.output.last-cursor.call.last-cursor.returned.last-cursor.metadata.last-copying.last;
            if(copying.active && room!=0){let bool finished=array_copies::advance(ref mut copying,body,bindings,state,data,place_state,room)?;}
            cursor.array=copying;if(!copying.active){cursor.pc+=1;}continue;
        }
        if(op==33 || op==40 || array_steps::selected_fill(body,cursor.pc)){
            var array_fill::State filling=array_steps::begin(body,cursor.pc,bindings,state,registers[base..base+128],data.len,place_state,remaining)?;
            filling.total=cursor.array.total;filling.last=cursor.array.last;
            let bool finished=array_steps::advance(ref mut filling,body,bindings,state,data,place_state,bytes_left)?;
            cursor.array=filling;if(finished){cursor.pc+=1;}continue;
        }
        if(op==116){
            var output_copy::State copying=output_steps::begin(body,sites,cursor.pc,f,bindings,state,
                static_words[frame*16..frame*16+16],static_live[frame],windows,guest,literals,data,staged,remaining)?;
            copying.total=cursor.output.total;copying.last=cursor.output.last;
            if(copying.active){let bool finished=output_steps::advance_limited(ref mut copying,guest,literals,data,staged,bytes_left)?;}
            cursor.output=copying;if(!copying.active){cursor.pc+=1;}continue;
        }
        if(op>=83 && op<=87){
            let usize price=places::price(body,cursor.pc,f,frame,place_state)?;
            if(*remaining<price){return .err(errors::make(8,offset));}
            let u8 kind=body.code[at+4];let owners::Token none=owners::Token{.slot=0,.generation=0};
            let owners::Token current=if(op==83 && (kind==2 || kind==4)){record_bindings::get(ref bindings.records,frame*16+a)}else{none};
            let owners::Token source=if(op==85 && kind==4){record_bindings::get(ref bindings.records,frame*16+b)}else{none};
            *remaining=places::bound(body,cursor.pc,f,frame,place_state,ref state.runtime.owners,ref bindings.tokens,current,source,
                ref state.runtime.pool,ref bindings.sites,data,registers[base..base+128],list_cells,list_scratch,*remaining)?;
            cursor.pc+=1;continue;
        }
        if(op==8 || op==39 || op==50 || op==65 || op==79 || op==82){let usize ended=place_frames::empty_frame(place_state,frame,offset)?;}
        var bool byte_loan=false;
        if(op==57 || op==58){byte_loan=body_ir::slice_element(body,a,offset)?==10;}
        if(op==71 || op==72 || byte_loan){
            if(!byte_loan && words::returned(static_words[frame*16+a])){
                let usize extra=meter::reference_result_lookup();
                let usize price=meter::slice_base(if(op==71){58}else{57},1);
                if(*remaining<extra+price){return .err(errors::make(8,offset));};*remaining-=extra;
            }
            let bool input_read=!byte_loan && input_views::is_input(static_words[frame*16+a]);
            if(input_read){let usize price=meter::input_metadata()+meter::static_instruction(if(op==71){71}else{72},0,0);
                if(*remaining<price){return .err(errors::make(8,offset));};*remaining-=meter::input_metadata();}
            let access::Source source=if(byte_loan){access::loan(bindings.sites[frame*16+a])}
                else if(sites.kinds[a]==3){references::source_input(body,sites,f,a,static_words[frame*16..frame*16+16],static_live[frame],bindings,literals.len,windows,offset)?}
                else{access::image(a)};
            let access::Value result=if(source.storage==3){
                let usize price=meter::static_instruction(if(op==71){71}else{72},0,0);
                let i64 value=if(op==71){access::checked_byte(guest,source.span,registers[base+b],offset)?}
                    else{cells::pack(source.span.length,offset)?};
                access::Value{.value=value,.remaining=*remaining-price}
            }else if(op==71 || op==58){access::read(ref source,sites,f,
                    static_words[frame*16..frame*16+16],static_live[frame],literals,
                    ref state.runtime.pool,ref state.runtime.owners,data,registers[base+b],*remaining,offset)?}
                else{access::length(ref source,sites,f,
                    static_words[frame*16..frame*16+16],static_live[frame],literals,
                    ref state.runtime.pool,ref state.runtime.owners,data.len,*remaining,offset)?};
            registers[base+dst]=result.value;*remaining=result.remaining;cursor.pc+=1;continue;
        }
        if(op==77){
            *remaining=if(body.code[at+3]==3){references::parameter_input(body,sites,cursor.pc,f,
                static_words[frame*16..frame*16+16],static_live[frame],bindings,state,literals,data.len,*remaining,windows)?}
                else{transfer::parameter(body,sites,literals.len,cursor.pc,f,
                    static_words[frame*16..frame*16+16],static_live[frame],*remaining)?};
            let usize one=1;static_live[frame]|=one<<dst;cursor.pc+=1;continue;
        }
        if((op==70 || op==75 || op==76) && dst<16 && sites.kinds[dst]==3){
            if(op==70 && words::returned(static_words[frame*16+dst])){
                let receipts::Closed closed=receipts::close(ref mut bindings.loans,state,frame,dst,
                    static_words[frame*16..frame*16+16],static_live[frame],data.len,*remaining,offset)?;
                static_live[frame]=closed.live;*remaining=closed.remaining;cursor.pc+=1;continue;
            }
            let references::Step next=references::step_input(body,sites,cursor.pc,f,
                static_words[frame*16..frame*16+16],static_live[frame],bindings,
                registers[base..base+128],literals.len,*remaining,windows)?;
            static_live[frame]=next.live;*remaining=next.remaining;cursor.pc+=1;continue;
        }
        if(statics::operation(op)){
            let immutable::Step next=immutable::step_frame(body,sites,literals,cursor.pc,f,
                registers[base..base+128],static_live[frame],*remaining,static_words[frame*16..frame*16+16])?;
            static_live[frame]=next.live;*remaining=next.remaining;cursor.pc+=1;continue;
        }
        if(bindings.prepared[frame] && (op==37 || op==45 || op==56 || op==62)){
            // The terminal recipe is independently proved. Physical CLOSE/END
            // belongs to native handoff's staged cleanup, never to both paths.
            cursor.pc+=1;continue;
        }
        if(op==63){
            let slices::Ticket current=bindings.sites[frame*16+a];
            let usize prepared=frames::prepare(bindings,dst,current)?;cursor.pc+=1;continue;
        }
        if(op==67 || op==68){
            // Native handoff and frame publication have already committed this
            // proved recipe. Never acquire or close the same child twice.
            if((op==67 && !frames::result_bound(bindings,dst)) ||
                (op==68 && bindings.sites[frame*16+dst].slot!=16)){return .err(errors::make(5,offset));}
            cursor.pc+=1;continue;
        }
        if(call_steps::operation(body,cursor.pc)){
            var call_copy::State calling=call_steps::begin(body,parameters,sites,cursor.pc,bindings,state,data.len,literals.len,
                static_words[frame*16..frame*16+16],static_live[frame],windows,place_state,remaining,plans)?;
            calling.total=cursor.call.total;calling.last=cursor.call.last;
            let bool finished=call_steps::advance(ref mut calling,body,parameters,sites,bindings,state,data,literals.len,
                windows,static_live,static_words,registers,remaining,bytes_left,plans)?;
            cursor.call=calling;if(finished){cursor.pc=body.starts[calling.target];}continue;
        }
        if(op==79){
            let usize input_work=if(input_views::enabled(windows)){meter::input_frame()}else{0};
            if(*remaining<input_work){return .err(errors::make(8,offset));};*remaining-=input_work;
            let usize next=bindings.continuations[frame];
            if(frame<=1 || next==0 || next>body.count){return .err(errors::make(5,offset));}
            let usize parent=frame-1;let usize caller=bindings.functions[parent];
            if(sites.results[f]==3){
                let reference_returns::Returned staged=reference_returns::prepare_input(body,sites,cursor.pc,f,
                    static_words[frame*16..frame*16+16],static_live[frame],static_live[parent],bindings,state,literals.len,*remaining,windows,origins)?;
                *remaining=staged.remaining;
                if(staged.loan){var runtime::Call call=frames::current(bindings);
                    let runtime::Returned result=records::handoff(bindings,state,ref mut call,staged.ticket,data.len,staged.remaining)?;
                    *remaining=result.remaining;
                    let usize resumed=frames::pop_reference(body,bindings,result)?;
                    static_live[parent]=receipts::publish(ref mut bindings.loans,parent,staged.destination,result.held,staged.span,
                        static_words[parent*16..parent*16+16],static_live[parent],offset)?;
                    *remaining=result.remaining;
                }else{let runtime::Resumed resumed=owned::leave(body,cursor.pc,8,bindings,state,data,staged.remaining)?;
                    *remaining=resumed.remaining;
                    if(staged.input){let usize published=input_views::put(windows,parent,staged.destination,staged.span,offset)?;}
                    static_words[parent*16+staged.destination]=staged.word;let usize one=1;static_live[parent]|=one<<staged.destination;
                    *remaining=resumed.remaining;
                }
                let usize cleared=input_views::clear_frame(windows,frame,offset)?;
                static_live[frame]=0;i=0;while(i<16){static_words[frame*16+i]=0;i+=1;}return_work::record(ref mut cursor.returned,return_bytes,instruction,frame,op);cursor.pc=next;continue;
            }
            let transfer::Returned staged=transfer::returned(body,sites,literals.len,cursor.pc,f,
                static_words[frame*16..frame*16+16],static_live[frame],next-1,caller,
                bindings.destinations[frame],static_live[parent],*remaining)?;
            *remaining=staged.remaining;
            // The native ordinary-return transaction restores all loan inputs;
            // no image view or payload ownership is transferred by that layer.
            let runtime::Resumed resumed=switch(owned::leave(body,cursor.pc,8,bindings,state,data,staged.remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            *remaining=resumed.remaining;let usize cleared=input_views::clear_frame(windows,frame,offset)?;static_live[frame]=0;
            i=0;while(i<16){static_words[frame*16+i]=0;i+=1;}
            static_words[parent*16+staged.destination]=staged.word;
            let usize one=1;static_live[parent]|=one<<staged.destination;return_work::record(ref mut cursor.returned,return_bytes,instruction,frame,op);cursor.pc=next;continue;
        }
        if(op==65){
            let usize input_work=if(input_views::enabled(windows)){meter::input_frame()}else{0};
            if(*remaining<input_work){return .err(errors::make(8,offset));};*remaining-=input_work;
            if(static_live[frame]!=0){return .err(errors::make(5,offset));}
            let usize selected=frames::selected(bindings,a)?;var runtime::Call call=frames::current(bindings);
            let runtime::Returned result=switch(records::handoff(bindings,state,ref mut call,bindings.results[selected],data.len,*remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };*remaining=result.remaining;
            return_work::record(ref mut cursor.returned,return_bytes,instruction,frame,op);
            cursor.pc=frames::pop_cached(body,bindings,result,plans)?;let usize cleared=input_views::clear_frame(windows,frame,offset)?;
            if(bindings.frame==0){return .ok(.some(transferred(result)));}continue;
        }
        if(op==8 || op==39 || op==50 || op==82){
            let usize input_work=if(input_views::enabled(windows)){meter::input_frame()}else{0};
            if(*remaining<input_work){return .err(errors::make(8,offset));};*remaining-=input_work;
            if(op==82 && (frame==1 || body.return_types[f]!=13)){return .err(errors::make(5,offset));}
            if(static_live[frame]!=0){return .err(errors::make(5,offset));}
            let usize destination=bindings.destinations[frame];let usize next=bindings.continuations[frame];
            let i64 value=if(op==8){registers[base+a]}else{0};
            let runtime::Resumed resumed=switch(owned::leave(body,cursor.pc,op,bindings,state,data,*remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
            };
            *remaining=resumed.remaining;let usize cleared=input_views::clear_frame(windows,frame,offset)?;
            return_work::record(ref mut cursor.returned,return_bytes,instruction,frame,op);
            if(frame==1){return .ok(.some(completed(Scalar{.value=value,.remaining=*remaining,.resumed=resumed.tickets})));}
            if(op==8){registers[(frame-1)*128+destination]=value;}cursor.pc=next;continue;
        }
        if(op>=41 && op<=49){*remaining=records::step(body,cursor.pc,bindings,state,registers[base..base+128],data,*remaining)?;cursor.pc+=1;continue;}
        if((op>=33 && op<=40) || (op>=51 && op<=53)){*remaining=owned::step(body,cursor.pc,bindings,state,registers[base..base+128],data,*remaining)?;cursor.pc+=1;continue;}
        if(op>=54 && op<=62){*remaining=loans::step(body,cursor.pc,bindings,state,registers[base..base+128],data,*remaining)?;cursor.pc+=1;continue;}
        if(op==8 || op==9 || op==25 || op>=33){return .err(errors::make(5,offset));}
        if(op==19 || op==20 || op==21 || op==22){
            if(op==19 || op==22){cursor.pc=a;}else if((registers[base+a]==0)==(op==20)){cursor.pc=b;}else{cursor.pc+=1;}continue;
        }
        if(op==24){let i64 subject=registers[base+a];let u8 variant=body.code[at+3];
            if(tagged::variant(subject)!=variant){cursor.pc=body.code[at+4] as usize;}
            else{if(types::payload(body.types[a],variant)!=0){registers[base+dst]=tagged::unpack(subject,variant);}cursor.pc+=1;}continue;
        }
        if(op==18){registers[base+dst]=registers[base+a];}
        else{registers[base+dst]=scalar::scalar(body,cursor.pc,registers[base..base+128])?;}
        cursor.pc+=1;
    }return .err(errors::make(5,0));
}
