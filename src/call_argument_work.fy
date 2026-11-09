module call_argument_work;
import ir as ir;
import static_ir as statics;
import static_views as views;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import reference_execution as references;
import reference_access as access;
import reference_words as words;
import array_slices as slices;
import array_owners as owners;
import array_vm as arrays;
import struct_call_vm as copies;
import input_reference_views as input_views;
import metadata_budget as budget;
import fuel as fuel;
import errors as errors;

// Private, invocation-local argument preparation. The frozen Program, Sites,
// frame bindings, runtime and input snapshot remain owned by the parent. This
// state contains only scalar progress and the unpublished result image.
pub struct State {
    references::Arguments result;
    usize remaining; usize target; usize map; usize offset;
    usize count; usize index; usize price; usize work; usize word_mask;
    u8 phase; bool generic; bool active; bool done;
}
pub fn State empty(){
    return State{.result=references::empty(0),.remaining=0,.target=0,.map=0,.offset=0,
        .count=0,.index=0,.price=0,.work=0,.word_mask=0,.phase=0,.generic=false,
        .active=false,.done=false};
}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
fn errors::Error shortage(usize offset){return errors::make(8,offset);}

// Start only the invocation metadata. No Program, Sites, frame, runtime or
// input entry is read here, so the context coordinator can pin its own image
// between begin and the first admitted advance.
pub fn Result<usize,errors::Error> begin(ref mut State w,bool generic,usize remaining){
    if(w.active){return .err(invalid(0));}
    w.remaining=remaining;
    w.target=0;w.map=0;w.offset=0;w.count=0;w.index=0;w.price=0;w.work=0;w.word_mask=0;
    w.phase=0;w.generic=generic;w.active=true;w.done=false;return .ok(0);
}
fn void fail(ref mut State w){
    w.result=references::empty(w.remaining);w.active=false;w.done=false;
}
fn bool site(ref statics::Sites sites,usize id,usize f,u8 kind){
    return id<16 && sites.definitions[id]<256 && sites.functions[id]==f &&
        (kind==1 || kind==2) && sites.kinds[id]==kind;
}

// The generic header preserves references::arguments_input's complete static
// preflight and preprice order. It reads at most eight parameter/actual pairs;
// no source, receipt, owner, pool or payload is authenticated in this stage.
fn Result<usize,errors::Error> generic_header(ref mut State w,ref ir::Program p,
    ref statics::Sites sites,usize pc,usize caller,ref u32[] current,usize live,
    ref frames::Frames bindings,ref runtime::State state,usize capacity,usize payload){
    if(pc>=p.count || pc>=256 || p.code[pc*8]!=78 || current.len!=16 || caller>=p.function_count || caller>=16 ||
        pc<p.starts[caller] || pc>=p.ends[caller] || bindings.frame==0 || bindings.frame>=32 ||
        bindings.functions[bindings.frame]!=caller){return .err(invalid(0));}
    let usize offset=p.offsets[pc];let usize target=p.code[pc*8+2] as usize;let usize map=p.code[pc*8+3] as usize;
    if(target>=p.function_count || map>=p.call_count || p.arities[target]>8 ||
        p.call_arities[map] as usize!=p.arities[target]){return .err(invalid(offset));}
    let usize one=1;let usize dst=p.code[pc*8+1] as usize;
    if(sites.results[target]!=0 && (dst>=16 || sites.functions[dst]!=caller || sites.definitions[dst]!=pc ||
        sites.kinds[dst]!=sites.results[target] || (live&(one<<dst))!=0)){return .err(invalid(offset));}
    var usize count=0;var usize loans=0;var usize returned=0;var usize input_count=0;var usize i=0;
    while(i<p.arities[target]){
        let u8 kind=sites.parameters[p.register_starts[target]+i];
        let usize actual=p.call_args[map*8+i] as usize;
        if(kind!=0){
            count+=1;
            if(kind==3 && ((actual>=160 && actual<176) ||
                (actual>=192 && actual<208 && words::runtime(current[actual-192])))){loans+=1;}
            if(kind==3 && actual>=192 && actual<208 && words::returned(current[actual-192])){returned+=1;}
            if(kind==3 && actual>=192 && actual<208 && input_views::is_input(current[actual-192])){input_count+=1;}
        }
        i+=1;
    }
    let usize price=fuel::reference_call(count,loans)+fuel::reference_result_lookup()*returned+
        fuel::input_arguments(input_count);
    let Result<usize,errors::Error> copy_cost=copies::cost(p,target,offset);
    let usize work=switch(copy_cost){case .ok(v):{v+p.arities[target]}case .err(e):{return .err(e);}};
    if(w.remaining<price+runtime::cost()+work){return .err(shortage(offset));}
    w.result=references::empty(w.remaining-price);w.target=target;w.map=map;w.offset=offset;
    w.count=p.arities[target];w.index=0;w.price=price;w.work=work;w.word_mask=0;w.phase=1;
    return .ok(0);
}

// Static header validation is intentionally distinct: it proves every actual
// before applying static_call Fuel, matching transfer::arguments exactly.
fn Result<usize,errors::Error> static_header(ref mut State w,ref ir::Program p,
    ref statics::Sites sites,usize pc,usize caller,ref u32[] current,usize live){
    if(!sites.call_profile || pc>=p.count || pc>=256 || caller>=p.function_count || caller>=16 ||
        pc<p.starts[caller] || pc>=p.ends[caller] || current.len!=16 || live>=65536 || p.code[pc*8]!=78){
        return .err(invalid(0));
    }
    let usize offset=p.offsets[pc];let usize at=pc*8;let usize target=p.code[at+2] as usize;
    let usize map=p.code[at+3] as usize;let usize dst=p.code[at+1] as usize;let usize one=1;
    if(target>=p.function_count || target>=16 || map>=p.call_count || map>=32 ||
        p.arities[target]>8 || p.call_arities[map] as usize!=p.arities[target] ||
        p.register_starts[target]>128 || p.arities[target]>128-p.register_starts[target]){
        return .err(invalid(offset));
    }
    if(sites.results[target]!=0 && (!site(sites,dst,caller,sites.results[target]) ||
        sites.definitions[dst]!=pc || (live&(one<<dst))!=0)){return .err(invalid(offset));}
    var usize count=0;var usize i=0;
    while(i<p.arities[target]){
        let usize formal=p.register_starts[target]+i;
        if(sites.parameters[formal]!=0){count+=1;}
        i+=1;
    }
    w.result=references::empty(w.remaining);w.target=target;w.map=map;w.offset=offset;
    w.count=p.arities[target];w.index=0;w.price=fuel::static_call(count);w.work=0;w.word_mask=0;w.phase=1;
    return .ok(0);
}

// Authenticate one argument in the same order as references::arguments_input.
// Every result field is committed only after this argument's complete checks.
fn Result<usize,errors::Error> generic_argument(ref mut State w,ref ir::Program p,
    ref statics::Sites sites,usize caller,ref u32[] current,usize live,
    ref frames::Frames bindings,ref runtime::State native,usize capacity,usize payload,
    ref input_views::State input){
    let usize i=w.index;let usize formal=p.register_starts[w.target]+i;
    let u8 kind=sites.parameters[formal];let usize actual=p.call_args[w.map*8+i] as usize;
    let usize one=1;let usize offset=w.offset;
    if(kind==0){
        let usize ordinary=p.slice_parameters[formal] as usize;
        if(ordinary!=0){
            if(actual<160 || actual>=176){return .err(invalid(offset));}
            let u8 tag=p.slice_elements[ordinary-1];
            let slices::Ticket ticket=bindings.sites[bindings.frame*16+actual-160];
            w.result.tags[i]=tag;w.result.captures[i]=runtime::capture(ticket,false,false);
        }
        return .ok(0);
    }
    let usize future=sites.formal_sites[formal] as usize;
    if(future==0 || future>16 || sites.functions[future-1]!=w.target ||
        sites.kinds[future-1]!=kind || (w.word_mask&(one<<(future-1)))!=0){
        return .err(invalid(offset));
    }
    var access::Source selected=access::loan(frames::none());var u32 word=0;
    if(kind==3 && actual>=160 && actual<176){
        selected=access::loan(bindings.sites[bindings.frame*16+actual-160]);
    }else{
        if(actual<192 || actual>=208){return .err(invalid(offset));}
        let usize source=actual-192;
        if(if(kind==3){sites.kinds[source]!=1 && sites.kinds[source]!=3}else{sites.kinds[source]!=kind}){
            return .err(invalid(offset));
        }
        selected=references::source_input(p,sites,caller,source,current,live,bindings,payload,input,offset)?;
        word=current[source];
    }
    var u8 tag=0;var runtime::Capture capture=runtime::capture(frames::none(),false,false);
    var views::Span window=views::Span{.start=0,.length=0};var bool input_argument=false;
    if(selected.storage==2){
        if(kind!=3){return .err(invalid(offset));}
        let slices::Ticket ticket=selected.ticket;
        let ref runtime::Runtime image=ref native.runtime;
        let ref slices::Pool pool=ref image.pool;
        let ref owners::Table table=ref image.owners;
        let Result<usize,owners::Error> measured=slices::length(pool,ticket,table,capacity);
        let usize length=switch(measured){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
        let slices::Slot entry=pool.slots[ticket.slot];
        if(entry.exclusive || entry.view.element!=10){return .err(invalid(offset));}
        let views::Span span=if(selected.window){selected.span}else{views::Span{.start=0,.length=length}};
        if(span.start>length || span.length>length-span.start){return .err(invalid(offset));}
        word=words::pack(i,span,offset)?;tag=10;capture=runtime::capture(ticket,false,false);
    }else if(selected.storage==3){
        if(kind!=3){return .err(invalid(offset));}
        window=selected.span;input_argument=true;word=input_views::marker();
    }else{
        let u8 inspected=if(kind==3){1}else{kind};
        let views::Span checked=views::inspect(sites,future-1,w.target,inspected,word,payload,offset)?;
    }
    w.result.words[future-1]=word;w.word_mask|=one<<(future-1);w.result.tags[i]=tag;
    if(tag==10){w.result.captures[i]=capture;}
    if(input_argument){w.result.input_windows[i]=window;w.result.input_mask|=one<<i;}
    return .ok(0);
}

// Authenticate one Static actual. The complete result remains unpublished and
// static Fuel is still unpaid until all actuals have passed this same check.
fn Result<usize,errors::Error> static_argument(ref mut State w,ref ir::Program p,
    ref statics::Sites sites,usize caller,ref u32[] current,usize live,usize payload){
    let usize i=w.index;let usize formal=p.register_starts[w.target]+i;
    let u8 kind=sites.parameters[formal];let usize one=1;let usize offset=w.offset;
    if(kind==0){return .ok(0);}
    let usize encoded=p.call_args[w.map*8+i] as usize;let usize future=sites.formal_sites[formal] as usize;
    if(encoded<192 || encoded>=208 || future==0 || future>16 ||
        !site(sites,future-1,w.target,kind) || (w.word_mask&(one<<(future-1)))!=0){
        return .err(invalid(offset));
    }
    let views::Span actual=views::live(sites,encoded-192,caller,kind,current,live,payload,offset)?;
    let u32 word=current[encoded-192];
    let views::Span checked=views::inspect(sites,future-1,w.target,kind,word,payload,offset)?;
    w.result.words[future-1]=word;w.word_mask|=one<<(future-1);return .ok(0);
}

fn Result<usize,errors::Error> finish_static(ref mut State w){
    if(w.remaining<w.price){fail(w);return .err(shortage(w.offset));}
    w.result.remaining=w.remaining-w.price;w.active=false;w.done=true;w.phase=2;return .ok(0);
}

// Each successful admitted dispatch performs one fixed 4096-unit phase. A
// nonempty allowance returns a normal deferral before any State or result read.
pub fn Result<bool,errors::Error> advance(ref mut State w,ref ir::Program p,
    ref statics::Sites sites,usize pc,usize caller,ref u32[] words,usize live,
    ref frames::Frames bindings,ref runtime::State runtime,usize capacity,usize payload,
    ref input_views::State input,ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>1){return .err(invalid(0));}
    if(w.count!=0 && w.index>w.count){return .err(invalid(w.offset));}
    let Result<bool,errors::Error> admitted=budget::admit(allowance,4096,0);
    let bool has_room=switch(admitted){case .ok(v):{v}case .err(_):{return .err(invalid(0));}};
    if(!has_room){return .ok(false);}
    if(w.phase==0){
        let Result<usize,errors::Error> header=if(w.generic){
            generic_header(w,p,sites,pc,caller,words,live,bindings,runtime,capacity,payload)
        }else{static_header(w,p,sites,pc,caller,words,live)};
        switch(header){case .ok(_):{}case .err(e):{fail(w);return .err(e);}};
        if(w.count==0){
            if(!w.generic){switch(finish_static(w)){case .ok(_):{}case .err(e):{return .err(e);}}}else{
                w.active=false;w.done=true;w.phase=2;
            }
            return .ok(true);
        }
        return .ok(false);
    }
    let Result<usize,errors::Error> argument=if(w.generic){
        generic_argument(w,p,sites,caller,words,live,bindings,runtime,capacity,payload,input)
    }else{static_argument(w,p,sites,caller,words,live,payload)};
    switch(argument){case .ok(_):{}case .err(e):{fail(w);return .err(e);}};
    w.index+=1;
    if(w.index<w.count){return .ok(false);}
    if(!w.generic){
        switch(finish_static(w)){case .ok(_):{}case .err(e):{return .err(e);}}
    }
    w.active=false;w.done=true;w.phase=2;return .ok(true);
}
