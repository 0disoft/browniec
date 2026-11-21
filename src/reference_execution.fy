module reference_execution;
import ir as ir;
import static_ir as statics;
import static_views as views;
import reference_words as words;
import reference_access as access;
import slice_result_frames as frames;
import slice_result_runtime as runtime;
import array_slices as slices;
import array_vm as arrays;
import struct_call_vm as copies;
import fuel as fuel;
import cells as cells;
import errors as errors;
import reference_receipts as receipts;
import input_reference_views as input_views;

pub struct Arguments { u32[16] words; runtime::Capture[8] captures; u8[8] tags; usize remaining; views::Span[8] input_windows; usize input_mask; }
pub struct Step { usize live; usize remaining; }
pub fn Arguments empty(usize remaining){return Arguments{.words=[0;16],
    .captures=[runtime::capture(frames::none(),false,false);8],.tags=[0;8],.remaining=remaining,.input_windows=[views::Span{.start=0,.length=0};8],.input_mask=0};}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
pub fn bool parameters(ref ir::Program p,ref statics::Sites sites,usize f){
    if(f>=p.function_count || f>=16 || p.arities[f]>8 || p.register_starts[f]>128 || p.arities[f]>128-p.register_starts[f]){return false;}
    var usize i=0;while(i<p.arities[f]){if(sites.parameters[p.register_starts[f]+i]==3){return true;}i+=1;}return false;
}
fn Result<access::Source,errors::Error> select(ref ir::Program p,ref statics::Sites sites,
    usize f,usize site,u32 word,ref frames::Frames bindings,usize payload,usize offset){
    if(f>=p.function_count || site>=16 || sites.functions[site]!=f || sites.definitions[site]>=256){return .err(invalid(offset));}
    if(!words::runtime(word)){let views::Span span=views::inspect(sites,site,f,0,word,payload,offset)?;return .ok(access::image(site));}
    if(sites.kinds[site]!=3 || bindings.frame==0 || bindings.frame>=32 || bindings.functions[bindings.frame]!=f){return .err(invalid(offset));}
    let words::Word value=words::unpack(word,offset)?;
    if(value.argument>=16){return receipts::source(ref bindings.loans,bindings.frame,word,offset);}
    let usize position=value.argument;
    if(position>=p.arities[f] || sites.parameters[p.register_starts[f]+position]!=3 || bindings.tags[bindings.frame*8+position]!=10){return .err(invalid(offset));}
    let slices::Ticket ticket=bindings.issued[bindings.frame*8+position];
    if(ticket.slot>=16 || ticket.generation==0){return .err(invalid(offset));}
    return .ok(access::loan_window(ticket,value.span));
}
pub fn Result<access::Source,errors::Error> source(ref ir::Program p,ref statics::Sites sites,
    usize f,usize site,ref u32[] current,usize live,ref frames::Frames bindings,usize payload,usize offset){
    let usize one=1;
    if(current.len!=16 || site>=16 || live>=65536 || (live&(one<<site))==0){return .err(invalid(offset));}
    return select(p,sites,f,site,current[site],bindings,payload,offset);
}
// Input markers never select image/loan storage. Authority is the active proved
// frame/site and its private per-invocation window, not the marker integer.
pub fn Result<access::Source,errors::Error> source_input(ref ir::Program p,ref statics::Sites sites,
    usize f,usize site,ref u32[] current,usize live,ref frames::Frames bindings,
    usize payload,ref input_views::State input,usize offset){
    let usize one=1;
    if(current.len!=16 || site>=16 || live>=65536 || (live&(one<<site))==0){return .err(invalid(offset));}
    if(!input_views::is_input(current[site])){return source(p,sites,f,site,current,live,bindings,payload,offset);}
    let usize frame=bindings.frame;
    if(f>=p.function_count || frame==0 || frame>=32 || !bindings.active[frame] || bindings.functions[frame]!=f ||
        sites.kinds[site]!=3 || sites.functions[site]!=f || sites.definitions[site]>=p.count){return .err(invalid(offset));}
    return .ok(access::input_window(input_views::get(input,frame,site,offset)?));
}
// Prepay the complete CALL, including native entry/copies, before authenticating
// runtime actuals. This plan is unpublished; native entry owns the actual retain.
pub fn Result<Arguments,errors::Error> arguments(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,ref u32[] current,usize live,ref frames::Frames bindings,
    ref runtime::State state,usize capacity,usize payload,usize remaining){
    let input_views::State disabled=input_views::disabled();
    return arguments_input(p,sites,pc,f,current,live,bindings,state,capacity,payload,remaining,ref disabled);
}
pub fn Result<Arguments,errors::Error> arguments_input(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,ref u32[] current,usize live,ref frames::Frames bindings,
    ref runtime::State state,usize capacity,usize payload,usize remaining,ref input_views::State input){
    if(pc>=p.count || pc>=256 || p.code[pc*8]!=78 || current.len!=16 || f>=p.function_count || f>=16 ||
        pc<p.starts[f] || pc>=p.ends[f] || bindings.frame==0 || bindings.frame>=32 || bindings.functions[bindings.frame]!=f){return .err(invalid(0));}
    let usize offset=p.offsets[pc];let usize target=p.code[pc*8+2] as usize;let usize map=p.code[pc*8+3] as usize;
    if(target>=p.function_count || map>=p.call_count || p.arities[target]>8 || p.call_arities[map] as usize!=p.arities[target]){return .err(invalid(offset));}
    let usize one=1;let usize dst=p.code[pc*8+1] as usize;
    if(sites.results[target]!=0 && (dst>=16 || sites.functions[dst]!=f || sites.definitions[dst]!=pc ||
        sites.kinds[dst]!=sites.results[target] || (live&(one<<dst))!=0)){return .err(invalid(offset));}
    var usize count=0;var usize loans=0;var usize returned=0;var usize input_count=0;var usize i=0;
    while(i<p.arities[target]){let u8 kind=sites.parameters[p.register_starts[target]+i];let usize actual=p.call_args[map*8+i] as usize;
        if(kind!=0){count+=1;if(kind==3 && ((actual>=160 && actual<176) ||
            (actual>=192 && actual<208 && words::runtime(current[actual-192])))){loans+=1;}
            if(kind==3 && actual>=192 && actual<208 && words::returned(current[actual-192])){returned+=1;}
            if(kind==3 && actual>=192 && actual<208 && input_views::is_input(current[actual-192])){input_count+=1;}}i+=1;
    }
    let usize price=fuel::reference_call(count,loans)+fuel::reference_result_lookup()*returned+fuel::input_arguments(input_count);let usize work=copies::cost(p,target,offset)?+p.arities[target];
    if(remaining<price+runtime::cost()+work){return .err(errors::make(8,offset));}
    var Arguments result=empty(remaining-price);var usize mask=0;i=0;
    while(i<p.arities[target]){let usize formal=p.register_starts[target]+i;let u8 kind=sites.parameters[formal];let usize actual=p.call_args[map*8+i] as usize;
        if(kind!=0){let usize future=sites.formal_sites[formal] as usize;
            if(future==0 || future>16 || sites.functions[future-1]!=target || sites.kinds[future-1]!=kind || (mask&(one<<(future-1)))!=0){return .err(invalid(offset));}
            var access::Source selected=access::loan(frames::none());var u32 word=0;
            if(kind==3 && actual>=160 && actual<176){selected=access::loan(bindings.sites[bindings.frame*16+actual-160]);}
            else{if(actual<192 || actual>=208){return .err(invalid(offset));}
                let usize site=actual-192;
                if(if(kind==3){sites.kinds[site]!=1 && sites.kinds[site]!=3}else{sites.kinds[site]!=kind}){return .err(invalid(offset));}
                selected=source_input(p,sites,f,site,current,live,bindings,payload,input,offset)?;word=current[site];
            }
            if(selected.storage==2){
                if(kind!=3){return .err(invalid(offset));}
                let slices::Ticket ticket=selected.ticket;
                let usize length=switch(slices::length(ref state.runtime.pool,ticket,ref state.runtime.owners,capacity)){
                    case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
                };
                if(state.runtime.pool.slots[ticket.slot].exclusive || state.runtime.pool.slots[ticket.slot].view.element!=10){return .err(invalid(offset));}
                let views::Span span=if(selected.window){selected.span}else{views::Span{.start=0,.length=length}};
                if(span.start>length || span.length>length-span.start){return .err(invalid(offset));}
                word=words::pack(i,span,offset)?;result.tags[i]=10;result.captures[i]=runtime::capture(ticket,false,false);
            }else if(selected.storage==3){
                if(kind!=3){return .err(invalid(offset));}
                result.input_windows[i]=selected.span;result.input_mask|=one<<i;word=input_views::marker();
            }else{let views::Span checked=views::inspect(sites,future-1,target,if(kind==3){1}else{kind},word,payload,offset)?;}
            result.words[future-1]=word;mask|=one<<(future-1);
        }else{let usize ordinary=p.slice_parameters[formal] as usize;
            if(ordinary!=0){if(actual<160 || actual>=176){return .err(invalid(offset));}
                result.tags[i]=p.slice_elements[ordinary-1];result.captures[i]=runtime::capture(bindings.sites[bindings.frame*16+actual-160],false,false);}
        }i+=1;
    }return .ok(result);
}
pub fn Result<usize,errors::Error> parameter(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,ref u32[] current,usize live,ref frames::Frames bindings,
    ref runtime::State state,ref u8[] payload,usize capacity,usize remaining){
    if(pc>=p.count || pc>=256 || f>=p.function_count || f>=16 || pc<p.starts[f] || pc>=p.ends[f]){return .err(invalid(0));}
    let usize at=pc*8;let usize offset=p.offsets[pc];let usize dst=p.code[at+1] as usize;let usize formal=p.code[at+2] as usize;let usize one=1;
    if(p.code[at]!=77 || p.code[at+3]!=3 || current.len!=16 || dst>=16 || (live&(one<<dst))!=0 ||
        sites.definitions[dst]!=pc || sites.functions[dst]!=f || sites.kinds[dst]!=3 ||
        formal<p.register_starts[f] || formal>=p.register_starts[f]+p.arities[f] ||
        sites.parameters[formal]!=3 || sites.formal_sites[formal] as usize!=dst+1){return .err(invalid(offset));}
    let bool loan=words::runtime(current[dst]);let usize price=fuel::reference_parameter(loan);
    if(remaining<price){return .err(errors::make(8,offset));}
    let access::Source selected=select(p,sites,f,dst,current[dst],bindings,payload.len,offset)?;
    if(loan){let words::Word word=words::unpack(current[dst],offset)?;
        if(word.argument!=formal-p.register_starts[f]){return .err(invalid(offset));}
        let access::Value checked=access::length(ref selected,sites,f,current,live,payload,
            ref state.runtime.pool,ref state.runtime.owners,capacity,remaining-16,offset)?;
    }return .ok(remaining-price);
}
// Logical aliases/ranges retain the transaction's issued formal, not a new
// physical lease. Every read still validates its full ticket and actual window.
pub fn Result<Step,errors::Error> step(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,ref mut u32[] current,usize live,ref frames::Frames bindings,
    ref i64[] registers,usize payload,usize remaining){
    if(pc>=p.count || pc>=256 || f>=p.function_count || f>=16 || pc<p.starts[f] || pc>=p.ends[f]){return .err(invalid(0));}
    let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize one=1;
    if(dst>=16 || current.len!=16 || sites.kinds[dst]!=3 || sites.functions[dst]!=f){return .err(invalid(offset));}
    let usize from=if(op==70){dst}else{a};
    if(from>=16){return .err(invalid(offset));}
    let usize extra=if(words::returned(current[from])){fuel::reference_result_lookup()}else{0};
    if(extra!=0 && remaining<extra+fuel::static_instruction(op,0,0)){return .err(errors::make(8,offset));}
    let access::Source selected=source(p,sites,f,from,current,live,bindings,payload,offset)?;
    if(op!=70 && (sites.definitions[dst]!=pc || (live&(one<<dst))!=0 || sites.kinds[from]!=3)){return .err(invalid(offset));}
    if(op!=70 && op!=75 && op!=76){return .err(invalid(offset));}
    let usize price=fuel::static_instruction(op,0,0)+extra;if(remaining<price){return .err(errors::make(8,offset));}
    if(op==70){current[dst]=0;return .ok(Step{.live=live^(one<<dst),.remaining=remaining-price});}
    var u32 word=current[from];
    if(op==76){if(p.code[at+3] as usize>=registers.len || p.code[at+4] as usize>=registers.len){return .err(invalid(offset));}
        let usize lo=cells::unpack(registers[p.code[at+3] as usize],offset)?;let usize hi=cells::unpack(registers[p.code[at+4] as usize],offset)?;
        let views::Span span=if(selected.storage==2){selected.span}else{views::inspect(sites,from,f,1,word,payload,offset)?};
        let u32 cropped=views::crop(ref span,lo,hi,if(selected.storage==2){4096}else{payload},offset)?;
        if(selected.storage==2){let words::Word parent=words::unpack(word,offset)?;
            let views::Span narrowed=views::unpack(cropped,4096,offset)?;
            word=if(parent.argument>=16){words::pack_result(parent.argument-16,narrowed,offset)?}
                else{words::pack(parent.argument,narrowed,offset)?};}else{word=cropped;}
    }
    if(selected.storage==1){let views::Span checked=views::inspect(sites,dst,f,1,word,payload,offset)?;}
    current[dst]=word;return .ok(Step{.live=live|(one<<dst),.remaining=remaining-price});
}

// Pure preflight for the exact fixed child-frame input publication. clear_frame
// removes old cells, so only bounds, unique sites and spans can fail afterward.
pub fn Result<usize,errors::Error> validate_input_arguments(ref ir::Program p,ref statics::Sites sites,
    usize target,usize frame,ref Arguments staged,ref input_views::State input,usize offset){
    if(!input_views::enabled(input) || frame==0 || frame>=32 || target>=p.function_count ||
        p.arities[target]>8 || staged.input_mask>=256){return .err(invalid(offset));}
    var usize used=0;var usize count=0;var usize i=0;let usize one=1;
    while(i<p.arities[target]){if((staged.input_mask&(one<<i))!=0){
        let usize formal=p.register_starts[target]+i;let usize site=sites.formal_sites[formal] as usize;
        if(sites.parameters[formal]!=3 || site==0 || site>16 || staged.words[site-1]!=input_views::marker() ||
            (used&(one<<(site-1)))!=0){return .err(invalid(offset));}
        let views::Span span=staged.input_windows[i];
        if(!input_views::accepts(input,span)){return .err(invalid(offset));}
        used|=one<<(site-1);count+=1;
    }i+=1;}
    if((staged.input_mask>>p.arities[target])!=0){return .err(invalid(offset));}
    return .ok(count);
}
// Publish only after native CALL enter. All windows were checked while staging;
// this fixed-capacity operation cannot allocate or acquire a payload owner.
pub fn Result<usize,errors::Error> publish_input_arguments(ref ir::Program p,ref statics::Sites sites,
    usize target,usize frame,ref Arguments staged,ref mut input_views::State input,usize offset){
    if(target>=p.function_count || p.arities[target]>8 || staged.input_mask>=256){return .err(invalid(offset));}
    let usize cleared=input_views::clear_frame(input,frame,offset)?;var usize i=0;let usize one=1;
    while(i<p.arities[target]){if((staged.input_mask&(one<<i))!=0){
        let usize formal=p.register_starts[target]+i;let usize site=sites.formal_sites[formal] as usize;
        if(sites.parameters[formal]!=3 || site==0 || site>16 || staged.words[site-1]!=input_views::marker()){
            return .err(invalid(offset));}
        let usize grant=input_views::put_grant(input,frame,i,staged.input_windows[i],offset)?;
        let usize bound=input_views::put(input,frame,site-1,staged.input_windows[i],offset)?;
    }i+=1;}return .ok(frame);
}
pub fn Result<usize,errors::Error> parameter_input(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,ref u32[] current,usize live,ref frames::Frames bindings,
    ref runtime::State state,ref u8[] payload,usize capacity,usize remaining,ref input_views::State input){
    if(pc>=p.count || pc>=256 || current.len!=16){return .err(invalid(0));}
    let usize at=pc*8;let usize dst=p.code[at+1] as usize;
    if(dst>=16){return .err(invalid(p.offsets[pc]));}
    if(!input_views::is_input(current[dst])){return parameter(p,sites,pc,f,current,live,bindings,state,payload,capacity,remaining);}
    let usize offset=p.offsets[pc];let usize formal=p.code[at+2] as usize;let usize one=1;
    let usize price=fuel::reference_parameter(false)+fuel::input_metadata();
    if(remaining<price){return .err(errors::make(8,offset));}
    if(f>=p.function_count || pc<p.starts[f] || pc>=p.ends[f] || p.code[at]!=77 || p.code[at+3]!=3 ||
        live>=65536 || (live&(one<<dst))!=0 || sites.definitions[dst]!=pc || sites.functions[dst]!=f || sites.kinds[dst]!=3 ||
        formal<p.register_starts[f] || formal>=p.register_starts[f]+p.arities[f] || sites.parameters[formal]!=3 ||
        sites.formal_sites[formal] as usize!=dst+1 || bindings.frame==0 || bindings.frame>=32 ||
        !bindings.active[bindings.frame] || bindings.functions[bindings.frame]!=f){return .err(invalid(offset));}
    let views::Span span=input_views::get(input,bindings.frame,dst,offset)?;
    let views::Span grant=input_views::grant(input,bindings.frame,formal-p.register_starts[f],offset)?;
    if(span.start!=grant.start || span.length!=grant.length){return .err(invalid(offset));}
    return .ok(remaining-price);
}
pub fn Result<Step,errors::Error> step_input(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,ref mut u32[] current,usize live,ref frames::Frames bindings,
    ref i64[] registers,usize payload,usize remaining,ref mut input_views::State input,ref slices::Pool pool){
    if(pc>=p.count || pc>=256 || current.len!=16){return .err(invalid(0));}
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize from=if(op==70){dst}else{p.code[at+2] as usize};
    if(from>=16){return .err(invalid(p.offsets[pc]));}
    if(!input_views::is_input(current[from])){return step(p,sites,pc,f,current,live,bindings,registers,payload,remaining);}
    let usize offset=p.offsets[pc];let usize price=fuel::static_instruction(op,0,0)+fuel::input_metadata();
    if(remaining<price){return .err(errors::make(8,offset));}
    let access::Source selected=source_input(p,sites,f,from,current,live,bindings,payload,input,offset)?;
    let usize one=1;
    if(dst>=16 || sites.functions[dst]!=f || sites.kinds[dst]!=3 || (op!=70 && op!=75 && op!=76) ||
        (op!=70 && (sites.definitions[dst]!=pc || (live&(one<<dst))!=0))){return .err(invalid(offset));}
    if(op==70){let usize closed=input_views::close(input,bindings.frame,dst,offset)?;current[dst]=0;
        return .ok(Step{.live=live^(one<<dst),.remaining=remaining-price});}
    var views::Span span=selected.span;
    if(op==76){let usize lo=p.code[at+3] as usize;let usize hi=p.code[at+4] as usize;
        if(lo>=registers.len || hi>=registers.len){return .err(invalid(offset));}
        span=input_views::crop(ref span,cells::unpack(registers[lo],offset)?,cells::unpack(registers[hi],offset)?,offset)?;
    }
    if(input_views::configured_quota(input)){
        let usize checked=input_views::check_descriptors(input,slices::live_count(pool),1,offset)?;
    }
    let usize bound=input_views::put(input,bindings.frame,dst,span,offset)?;current[dst]=input_views::marker();
    return .ok(Step{.live=live|(one<<dst),.remaining=remaining-price});
}
