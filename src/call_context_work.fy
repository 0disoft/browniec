module call_context_work;
import call_argument_work as arguments;
import call_owned_work as owned;
import call_capture_plan as plans;
import reference_execution as references;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_authority as authority;
import input_reference_views as inputs;
import place_vm as places;
import ir as ir;
import static_ir as statics;
import fuel as meter;
import metadata_budget as budget;
import std::vec as vec;
import errors as errors;

// Private invocation-local banks. The owning parent pins their exact Program,
// frame, cache, words and input snapshot through completion or cancellation.
pub struct State {
    arguments::State arguments; owned::State owned; runtime::Contract contract;
    usize phase; usize caller; usize capacity; usize payload; usize remaining;
    bool generic; bool active; bool done;
}
pub fn State empty(){return State{.arguments=arguments::empty(),.owned=owned::empty(),
    .contract=runtime::Contract{.tags=[0;8],.arity=0,.selected=0},
    .phase=0,.caller=0,.capacity=0,.payload=0,.remaining=0,.generic=false,.active=false,.done=false};}
pub fn Result<usize,errors::Error> begin(ref mut State w,usize capacity,usize payload,usize remaining){
    if(w.active){return .err(errors::make(5,0));}
    w.phase=0;w.caller=0;w.capacity=capacity;w.payload=payload;w.remaining=remaining;
    w.generic=false;w.active=true;w.done=false;return .ok(0);
}
fn bool frame_room(ref authority::State a){return a.depth<31;}
fn Result<usize,errors::Error> prefix(ref mut State w,ref ir::Program p,ref u8[] parameters,
    ref statics::Sites sites,usize pc,ref frames::Frames bindings,ref runtime::State state,
    ref inputs::State windows,ref vec::Vec<usize> places,ref mut usize remaining){
    let usize frame=bindings.frame;let usize offset=p.offsets[pc];
    if(frame>=31 || !frame_room(ref state.runtime.authority)){return .err(errors::make(12,offset));}
    let usize input_work=if(inputs::enabled(windows)){meter::input_frame()}else{0};
    if(*remaining<input_work+runtime::cost()){return .err(errors::make(8,offset));}
    switch(places::empty_frame(places,frame+1,offset)){
        case .ok(_):{}case .err(e):{*remaining-=input_work;w.remaining=*remaining;return .err(e);}
    };
    *remaining-=input_work;w.remaining=*remaining;w.caller=bindings.functions[frame];
    let usize target=p.code[pc*8+2] as usize;let u8 op=p.code[pc*8];
    var u8[8] tags=[0;8];var usize i=0;
    while(i<p.arities[target]){let usize site=p.slice_parameters[p.register_starts[target]+i] as usize;
        if(site!=0){tags[i]=p.slice_elements[site-1];}i+=1;}
    w.contract=runtime::Contract{.tags=tags,.arity=p.arities[target],.selected=parameters[target] as usize};
    w.generic=op==78 && (sites.results[target]==3 || references::parameters(p,sites,target));
    w.arguments=arguments::empty();w.owned=owned::empty();
    w.arguments.result=references::empty(*remaining);
    if(op==78){let bool generic=w.generic;let usize fuel=w.remaining;
        let usize begun=arguments::begin(ref mut w.arguments,generic,fuel)?;w.phase=1;
    }else{w.phase=2;}
    return .ok(0);
}
fn Result<usize,errors::Error> select(ref mut State w,ref ir::Program p,ref statics::Sites sites,usize pc){
    let usize target=p.code[pc*8+2] as usize;
    if(w.generic){
        let ref arguments::State staged=ref w.arguments;let ref references::Arguments captured=ref staged.result;
        let u8[8] tags=captured.tags;w.contract.tags=tags;
        if(sites.results[target]==3 && sites.origins[target]!=9){let usize origin=sites.origins[target] as usize;
            let ref runtime::Contract contract=ref w.contract;
            if(origin==0 || origin>contract.arity){return .err(errors::make(5,p.offsets[pc]));}
            w.contract.selected=if(tags[origin-1]==10){origin}else{0};
        }
    }
    let usize begun=owned::begin(ref mut w.owned)?;w.phase=3;return .ok(0);
}
fn Result<bool,errors::Error> advance_inner(ref mut State w,ref ir::Program p,ref u8[] parameters,
    ref statics::Sites sites,usize pc,ref frames::Frames bindings,ref runtime::State state,
    ref u32[] words,usize live,ref inputs::State windows,ref vec::Vec<usize> places,
    ref mut usize remaining,ref plans::Plan cache,ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>4 || pc>=p.count || pc>=256 || parameters.len!=16 || words.len!=16){return .err(errors::make(5,0));}
    if(allowance.last!=0){return .ok(false);}
    if(*remaining!=w.remaining){return .err(errors::make(5,p.offsets[pc]));}
    if(w.phase==1){
        let usize caller=w.caller;let usize capacity=w.capacity;let usize payload=w.payload;
        let bool done=arguments::advance(ref mut w.arguments,p,sites,pc,caller,words,live,bindings,state,capacity,payload,windows,allowance)?;
        if(done){let ref arguments::State result=ref w.arguments;let ref references::Arguments captured=ref result.result;
            let usize fuel=captured.remaining;w.remaining=fuel;*remaining=fuel;w.phase=2;}
        return .ok(false);
    }
    if(w.phase==3){
        let runtime::Contract contract=w.contract;let usize fuel=w.remaining;
        let usize count=if(w.generic){contract.arity}else{0};
        // The compiler cannot borrow sibling banks concurrently. Copy only the
        // eight supplied captures, never their complete argument/context bank.
        let ref arguments::State result=ref w.arguments;let ref references::Arguments captured=ref result.result;
        let runtime::Capture[8] supplied=captured.captures;
        let bool done=owned::advance(ref mut w.owned,p,pc,contract,bindings,fuel,ref supplied[..count],cache,allowance)?;
        if(done){w.phase=4;}return .ok(false);
    }
    if(!budget::admit(allowance,4096,p.offsets[pc])?){return .ok(false);}
    let Result<usize,errors::Error> result=if(w.phase==0){prefix(w,p,parameters,sites,pc,bindings,state,windows,places,remaining)}
        else if(w.phase==2){select(w,p,sites,pc)}else{w.active=false;w.done=true;.ok(0)};
    switch(result){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
    return .ok(w.done);
}

pub fn Result<bool,errors::Error> advance(ref mut State w,ref ir::Program p,ref u8[] parameters,
    ref statics::Sites sites,usize pc,ref frames::Frames bindings,ref runtime::State state,
    ref u32[] words,usize live,ref inputs::State windows,ref vec::Vec<usize> places,
    ref mut usize remaining,ref plans::Plan cache,ref mut budget::State allowance){
    let Result<bool,errors::Error> result=advance_inner(w,p,parameters,sites,pc,bindings,state,words,live,windows,places,remaining,cache,allowance);
    return switch(result){case .ok(v):{.ok(v)}case .err(e):{
        w.active=false;w.arguments.active=false;w.owned.active=false;.err(e)
    }};
}
