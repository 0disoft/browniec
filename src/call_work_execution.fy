module call_work_execution;
import call_copy_cursor as cursor;
import call_copy_work as copies;
import array_owners as owners;
import array_vm as arrays;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_owned_execution as owned;
import slice_authority as authority;
import array_slices as slices;
import ir as ir;
import static_ir as statics;
import static_call_execution as transfer;
import reference_execution as references;
import input_reference_views as inputs;
import place_vm as places;
import fuel as meter;
import errors as errors;
import std::vec as vec;

// Ephemeral metadata only. The owning cursor saves scalar comparison facts;
// no argument expression, host effect, owner payload or borrowed pointer is saved.
struct Context { runtime::Contract contract; owned::Prepared prepared; references::Arguments captured; bool generic; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
pub fn bool operation(ref ir::Program p,usize pc){
    if(pc>=p.count || pc>=256){return false;}let u8 op=p.code[pc*8];
    return op==9 || op==64 || op==66 || op==78;
}
fn runtime::Contract binding(ref ir::Program p,ref u8[] parameters,usize f){
    var u8[8] tags=[0;8];var usize i=0;while(i<p.arities[f]){
        let usize site=p.slice_parameters[p.register_starts[f]+i] as usize;
        if(site!=0){tags[i]=p.slice_elements[site-1];}i+=1;}
    return runtime::Contract{.tags=tags,.arity=p.arities[f],.selected=parameters[f] as usize};
}
// Reconstruct deterministic metadata against the frozen caller. Only begin
// exposes these deductions. Continuations use a local copy of saved fuel_before.
fn Result<Context,errors::Error> context(ref ir::Program p,ref u8[] parameters,
    ref statics::Sites sites,usize pc,ref frames::Frames bindings,ref runtime::State state,
    usize capacity,usize payload,ref u32[] words,usize live,ref inputs::State windows,ref mut usize remaining){
    let usize frame=bindings.frame;let usize f=bindings.functions[frame];let usize offset=p.offsets[pc];
    if(frame>=31 || state.runtime.authority.depth>=31){return .err(errors::make(12,offset));}
    let usize input_work=if(inputs::enabled(windows)){meter::input_frame()}else{0};
    if(*remaining<input_work+runtime::cost()){return .err(errors::make(8,offset));};*remaining-=input_work;
    let usize target=p.code[pc*8+2] as usize;let u8 op=p.code[pc*8];
    var runtime::Contract c=binding(p,parameters,target);
    let bool generic=op==78 && (sites.results[target]==3 || references::parameters(p,sites,target));
    var transfer::Arguments staged=transfer::Arguments{.words=[0;16],.remaining=*remaining};
    var references::Arguments captured=references::empty(*remaining);
    if(generic){
        captured=references::arguments_input(p,sites,pc,f,words,live,bindings,state,capacity,payload,*remaining,windows)?;
        *remaining=captured.remaining;c.tags=captured.tags;
        if(sites.results[target]==3 && sites.origins[target]!=9){let usize origin=sites.origins[target] as usize;
            if(origin==0 || origin>c.arity){return .err(invalid(offset));}
            c.selected=if(c.tags[origin-1]==10){origin}else{0};}
    }else if(op==78){staged=transfer::arguments(p,sites,payload,pc,f,words,live,*remaining)?;};
    *remaining=if(generic){captured.remaining}else{staged.remaining};
    let runtime::Capture[1] none=[runtime::capture(frames::none(),false,false)];
    let owned::Prepared prepared=if(generic){owned::prepare_enter(p,pc,c,bindings,*remaining,ref captured.captures[..c.arity])?}
        else{owned::prepare_enter(p,pc,c,bindings,*remaining,ref none[..0])?};
    if(!generic){captured.words=staged.words;}
    return .ok(Context{.contract=c,.prepared=prepared,.captured=captured,.generic=generic});
}
fn Result<usize,errors::Error> future_frame(ref ir::Program p,usize pc,ref frames::Frames bindings,runtime::Call call){
    let usize at=pc*8;let usize destination=if(p.code[at]==66){160+p.code[at+5] as usize}else{p.code[at+1] as usize};
    return frames::can_push(p,bindings,call,p.code[at+2] as usize,destination,p.code[at+3] as usize,pc+1);
}
fn Result<runtime::Call,errors::Error> prepare(ref Context c,ref runtime::State state,usize capacity,usize remaining,
    ref mut authority::State next_authority,ref mut slices::Pool next_pool){
    return runtime::prepare_entry(state,c.contract,ref c.prepared.captures[..c.contract.arity],capacity,
        remaining-c.prepared.owned,next_authority,next_pool);
}

pub fn Result<cursor::State,errors::Error> begin(ref ir::Program p,ref u8[] parameters,ref statics::Sites sites,usize pc,
    ref frames::Frames bindings,ref runtime::State state,usize capacity,usize payload,ref u32[] words,usize live,
    ref inputs::State windows,ref mut vec::Vec<usize> place_state,ref mut usize remaining){
    if(!operation(p,pc) || bindings.frame==0 || bindings.frame>=32){return .err(invalid(0));}
    let usize offset=p.offsets[pc];let usize before=*remaining;
    // Preserve the old frame-place check before staging static/reference actuals.
    let usize input_work=if(inputs::enabled(windows)){meter::input_frame()}else{0};
    if(bindings.frame>=31 || state.runtime.authority.depth>=31){return .err(errors::make(12,offset));}
    if(before<input_work+runtime::cost()){return .err(errors::make(8,offset));}
    switch(places::empty_frame(place_state,bindings.frame+1,offset)){
        case .ok(_):{}case .err(e):{*remaining-=input_work;return .err(e);}
    };
    let Context c=context(p,parameters,sites,pc,bindings,state,capacity,payload,words,live,windows,remaining)?;
    var authority::State next_authority=state.runtime.authority;var slices::Pool next_pool=state.runtime.pool;
    let runtime::Call call=prepare(ref c,state,capacity,*remaining,ref mut next_authority,ref mut next_pool)?;
    let usize child=future_frame(p,pc,bindings,call)?;
    var cursor::State work=switch(if(c.prepared.records){copies::begin(ref state.runtime.owners,ref p.records.layouts,ref c.prepared.arguments[..c.prepared.count],capacity)}
        else{copies::begin_arrays(ref state.runtime.owners,ref p.records.layouts,ref c.prepared.arguments[..c.prepared.count],capacity)}){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    work.pending=true;work.charged=false;work.pc=pc;work.frame=bindings.frame;work.offset=offset;
    work.target=p.code[pc*8+2] as usize;work.fuel_before=before;work.captured=*remaining;work.remaining=call.remaining;
    return .ok(work);
}

// Reauthenticate loan/frame plans before payload work. No guest instruction or
// external callback runs between source validation and final frame publication.
pub fn Result<bool,errors::Error> advance(ref mut cursor::State work,ref ir::Program p,ref u8[] parameters,
    ref statics::Sites sites,ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,
    usize payload,ref mut inputs::State windows,ref mut usize[] live,ref mut u32[] words,
    ref mut i64[] registers,ref mut usize remaining,usize allowance){
    if(!work.pending || !operation(p,work.pc) || work.frame!=bindings.frame || work.offset!=p.offsets[work.pc] ||
        work.target!=p.code[work.pc*8+2] as usize || work.frame==0 || work.frame>=31 || live.len!=32 || words.len!=512 || registers.len!=4096){return .err(invalid(work.offset));}
    if(allowance==0 || allowance>4096 || work.last>4096 || allowance>4096-work.last){return .err(invalid(work.offset));}
    if(*remaining!=if(work.charged){work.remaining}else{work.captured}){return .err(invalid(work.offset));}
    let usize parent=work.frame;var usize replay=work.fuel_before;
    let Context c=context(p,parameters,sites,work.pc,bindings,state,data.len,payload,
        words[parent*16..parent*16+16],live[parent],windows,ref mut replay)?;
    if(replay!=work.captured || work.count!=c.prepared.count || work.reserve_first==c.prepared.records){return .err(invalid(work.offset));}
    var authority::State next_authority=state.runtime.authority;var slices::Pool next_pool=state.runtime.pool;
    let runtime::Call call=prepare(ref c,state,data.len,replay,ref mut next_authority,ref mut next_pool)?;
    if(call.remaining!=work.remaining){return .err(invalid(work.offset));}
    let usize child=future_frame(p,work.pc,bindings,call)?;
    // Input windows are metadata. Before final publication, prove every future
    // grant/site fits the same immutable input and has a unique formal site.
    if(inputs::enabled(windows) && c.generic){let usize checked=references::validate_input_arguments(p,sites,work.target,child,ref c.captured,windows,work.offset)?;}
    let usize last=work.last;var Option<owners::Copies> result=.none;
    if(!work.charged){
        result=switch(copies::validate(work,ref mut state.runtime.owners,ref p.records.layouts,
            ref c.prepared.arguments[..c.prepared.count],data,allowance)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,work.offset));}
        };
        if(work.count!=0 && work.phase==0){return .ok(false);};
        *remaining=work.remaining;work.charged=true;
    }
    let usize spent=work.last-last;
    if(work.count!=0){
        if(spent==allowance){return .ok(false);}
        result=switch(copies::advance(work,ref mut state.runtime.owners,ref p.records.layouts,
            ref c.prepared.arguments[..c.prepared.count],data,allowance-spent)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,work.offset));}
        };
    }
    var owners::Copies finished=owners::Copies{.tokens=[owners::Token{.slot=0,.generation=0};8],.count=0};
    var bool complete=false;switch(result){case .some(v):{finished=v;complete=true;}case .none:{}};
    if(!complete){return .ok(false);}
    // Every remaining check was preflighted against frozen metadata. These
    // publications cannot yield, allocate or call external code.
    state.runtime.authority=next_authority;state.runtime.pool=next_pool;
    let usize published=owned::publish_enter(p,work.pc,c.contract,bindings,call,finished,ref c.prepared)?;
    if(inputs::enabled(windows)){
        if(c.generic){let usize bound=references::publish_input_arguments(p,sites,work.target,child,ref c.captured,windows,work.offset)?;}
        else{let usize cleared=inputs::clear_frame(windows,child,work.offset)?;}
    }
    live[child]=0;var usize i=0;while(i<16){words[child*16+i]=c.captured.words[i];i+=1;}
    let usize map=p.code[work.pc*8+3] as usize;i=0;
    while(i<c.contract.arity){let usize formal=p.register_starts[work.target]+i;let usize source=p.call_args[map*8+i] as usize;
        if(c.contract.tags[i]==0 && p.array_parameters[formal]==0 && p.record_parameters[formal]==0 && sites.parameters[formal]==0){
            registers[child*128+formal]=registers[parent*128+source];}i+=1;
    }
    work.pending=false;return .ok(true);
}
