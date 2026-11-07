module value_call_vm;
import value_ir as value_ir;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_frames as frames;
import value_roots as value_roots;
import value_codec as codec;
import value_properties as properties;
import errors as errors;
import ir as ir;
import std::bytes as bytes;
import std::vec as vec;

// Invocation-local metadata, never an executable capability or an owning value.
// The independently verified immutable unit and matching retained Plan remain
// with their native State/vectors. Prepare and publish admit no intervening
// typed/root mutation, callback or reentry. Ordinary CALL publication may occur
// between them only after its own complete atomic preflight has succeeded.
pub struct Prepared {
    frames::Address[8] sources; frames::Address[8] destinations;
    bool[8] copying; usize[8] costs; usize count;
    usize[8] view_sources; usize[8] view_formals; usize view_count;
    frames::Token caller; frames::Token callee; usize target; usize total;
}
fn frames::Address nowhere(){return frames::Address{.frame=0,.generation=0,.slot=0};}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
fn usize offset(ref value_ir::Program unit,usize pc){let ref ir::Program body=ref unit.body;return if(pc<256){body.offsets[pc]}else{0};}
fn Result<usize,errors::Error> add(usize a,usize b,usize at){
    if(b>18446744073709551615-a){return .err(invalid(at));}return .ok(a+b);
}
fn Result<usize,errors::Error> declared(ref value_ir::Program unit,ref layouts::Plan plan,
    usize slot,usize function,usize at){
    if(!value_ir::slot(unit,slot,function)){return .err(invalid(at));}
    let usize id=switch(layouts::type_id(plan,slot,function)){case .ok(v):{v}case .err(_):{return .err(invalid(at));}};
    if(id!=value_ir::type_id(unit,slot)){return .err(invalid(at));}return .ok(id);
}
fn Result<usize,errors::Error> same(ref layouts::Plan plan,usize a,usize b,usize at){
    if(!switch(codec::same(layouts::layout(plan),a,b)){case .ok(v):{v}case .err(_):{false}}){return .err(invalid(at));}
    return .ok(a);
}
// All instruction/array bounds and static argument metadata precede backing.
// This also derives exactly the work prepaid for enter + inspect + transfer.
fn Result<Prepared,errors::Error> metadata(ref value_ir::Program unit,ref layouts::Plan plan,usize pc){
    let ref ir::Program body=ref unit.body;let usize at=offset(unit,pc);
    let usize functions=body.function_count;
    if(body.count==0 || body.count>256 || pc>=body.count || functions==0 || functions>16 ||
        layouts::functions(plan)!=functions || body.registers>128 || body.call_count>32){return .err(invalid(at));}
    let usize instruction=pc*8;let u8 op=body.code[instruction];
    if(op!=9 && op!=93 && op!=114){return .err(invalid(at));}
    var usize i=4;while(i<8){if(body.code[instruction+i]!=0){return .err(invalid(at));}i+=1;}
    let usize target=body.code[instruction+2] as usize;
    let usize site=body.code[instruction+3] as usize;
    if(target>=functions || site>=body.call_count){return .err(invalid(at));}
    let usize arity=body.arities[target];
    let usize start=body.register_starts[target];let usize end=body.register_ends[target];
    if(arity>8 || body.call_arities[site] as usize!=arity || start>end || end>body.registers || arity>end-start){return .err(invalid(at));}
    var usize caller=0;while(caller<functions && (pc<body.starts[caller] || pc>=body.ends[caller])){caller+=1;}
    if(caller==functions || body.starts[target]>=body.ends[target] || body.ends[target]>body.count ||
        body.register_starts[caller]>body.register_ends[caller] || body.register_ends[caller]>body.registers){return .err(invalid(at));}
    let usize width=switch(layouts::width(plan,target)){case .ok(v):{v}case .err(_):{return .err(invalid(at));}};
    let usize entry=switch(meter::enter_cost(width)){case .ok(v):{v}case .err(_):{return .err(invalid(at));}};
    var Prepared batch=Prepared{.sources=[nowhere();8],.destinations=[nowhere();8],.copying=[false;8],.costs=[0;8],
        .count=0,.view_sources=[0;8],.view_formals=[0;8],.view_count=0,.caller=frames::Token{.frame=0,.generation=0},.callee=frames::Token{.frame=0,.generation=0},
        .target=target,.total=add(entry,8192,at)?};
    var usize formals=0;var usize view_formals=0;let usize one=1;i=0;
    while(i<8){let usize actual=body.call_args[site*8+i] as usize;
        if(i>=arity){if(actual!=0){return .err(invalid(at));}}
        else{
            let usize reg=start+i;let usize encoded=unit.parameters[reg] as usize;
            if(encoded==0){if(actual>=208){return .err(invalid(at));}}
            else if(encoded>=17 && encoded<=32){
                if(actual<224 || actual>=240 || body.types[reg]!=0 || body.slots[reg] ||
                    body.array_parameters[reg]!=0 || body.record_parameters[reg]!=0 || body.slice_parameters[reg]!=0){return .err(invalid(at));}
                let usize dst=encoded-17;
                if((view_formals&(one<<dst))!=0){return .err(invalid(at));}view_formals|=one<<dst;
                let usize n=batch.view_count;batch.view_sources[n]=actual-224;batch.view_formals[n]=dst;
                batch.view_count=n+1;batch.total=add(batch.total,512,at)?;
            }
            else{
                if(encoded>16 || actual<208 || actual>=224 || body.types[reg]!=0 || body.slots[reg] ||
                    body.array_parameters[reg]!=0 || body.record_parameters[reg]!=0 || body.slice_parameters[reg]!=0){return .err(invalid(at));}
                let usize dst=encoded-1;let usize src=actual-208;
                let usize src_id=declared(unit,plan,src,caller,at)?;let usize dst_id=declared(unit,plan,dst,target,at)?;
                let usize equal=same(plan,src_id,dst_id,at)?;
                if((formals&(one<<dst))!=0){return .err(invalid(at));}formals|=one<<dst;
                let properties::Property p=switch(codec::shape(layouts::layout(plan),src_id)){case .ok(v):{v}case .err(_):{return .err(invalid(at));}};
                let usize charge=switch(meter::operation_cost(p.bytes)){case .ok(v):{v}case .err(_):{return .err(invalid(at));}};
                let usize n=batch.count;batch.sources[n]=frames::Address{.frame=0,.generation=0,.slot=src};
                batch.destinations[n]=frames::Address{.frame=0,.generation=0,.slot=dst};
                batch.copying[n]=p.copyable;batch.costs[n]=charge;batch.count=n+1;
                batch.total=add(batch.total,add(charge,charge,at)?,at)?;
            }
        }i+=1;
    }
    let usize result=unit.results[target] as usize;
    if(result>24 || (op==114)!=(result>=17) ||
        (op==93)!=(result<17 && (result!=0 || batch.count!=0 || batch.view_count!=0))){return .err(invalid(at));}
    if(result>=17){
        let usize ordinal=result-17;
        if(ordinal>=arity || unit.parameters[start+ordinal]<17 || unit.parameters[start+ordinal]>32 ||
            body.code[instruction+1]>=16 || body.return_types[target]!=0 ||
            body.array_results[target]!=0 || body.record_results[target]!=0){return .err(invalid(at));}
    }
    else if(result!=0){
        if(result>16 || body.return_types[target]!=0 || body.array_results[target]!=0 || body.record_results[target]!=0){return .err(invalid(at));}
        let usize src_id=declared(unit,plan,result-1,target,at)?;
        let usize dst_id=declared(unit,plan,body.code[instruction+1] as usize,caller,at)?;
        let usize equal=same(plan,src_id,dst_id,at)?;
    }
    return .ok(batch);
}
pub fn Result<usize,errors::Error> cost(ref value_ir::Program unit,ref layouts::Plan plan,usize pc){
    let Prepared batch=metadata(unit,plan,pc)?;return .ok(batch.total);
}
// Caller has paid cost(), entered the empty callee using local enter_cost Fuel,
// and will discard that empty callee if either prepare or ordinary CALL fails.
pub fn Result<Prepared,errors::Error> prepare(ref value_ir::Program unit,ref layouts::Plan plan,usize pc,usize parent,
    frames::Token caller,frames::Token callee,ref frames::State state,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,ref value_roots::State roots_state,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> roots_scratch){
    let ref ir::Program body=ref unit.body;var Prepared batch=metadata(unit,plan,pc)?;let usize at=offset(unit,pc);
    if(parent>=31){return .err(errors::make(12,at));}
    if(caller.frame!=parent || callee.frame!=parent+1 || state.depth!=parent+2){return .err(invalid(at));}
    if(!frames::inspect_frame(plan,state,data,caller).is_ok || !frames::inspect_frame(plan,state,data,callee).is_ok){return .err(invalid(at));}
    let usize function=state.frames[parent].function;
    if(pc<body.starts[function] || pc>=body.ends[function] || state.frames[callee.frame].function!=batch.target ||
        state.frames[callee.frame].live!=0 || state.frames[callee.frame].next!=1){return .err(invalid(at));}
    var usize i=0;while(i<16){if(state.order[callee.frame*16+i]!=0){return .err(invalid(at));}i+=1;}
    // Simulate only consumed actuals, preserving the original native bytes and
    // roots. Destination formals are unique and occupy the fresh activation.
    var frames::State simulated=*state;let usize one=1;i=0;
    while(i<batch.count){let usize src=batch.sources[i].slot;let usize dst=batch.destinations[i].slot;
        batch.sources[i]=frames::Address{.frame=caller.frame,.generation=caller.generation,.slot=src};
        batch.destinations[i]=frames::Address{.frame=callee.frame,.generation=callee.generation,.slot=dst};
        if((simulated.frames[parent].live&(one<<src))==0){return .err(invalid(at));}
        if(!frames::inspect_transfer(plan,state,data,scratch,batch.sources[i],batch.destinations[i],batch.copying[i],roots_state,roots,roots_scratch).is_ok){return .err(invalid(at));}
        if(!batch.copying[i]){let usize live=simulated.frames[parent].live&(~(one<<src));
            simulated.frames[parent].live=live;simulated.order[parent*16+src]=0;}
        i+=1;
    }
    if(unit.results[batch.target]!=0 && unit.results[batch.target]<=16){
        let frames::Address destination=frames::Address{.frame=caller.frame,.generation=caller.generation,.slot=body.code[pc*8+1] as usize};
        if(!frames::inspect_destination(plan,ref simulated,data,destination).is_ok){return .err(invalid(at));}
    }
    batch.caller=caller;batch.callee=callee;return .ok(batch);
}
// All fallible typed work has finished before ordinary owner/loan publication.
// The trusted coordinator consumes this batch exactly once without mutation.
pub fn void publish(ref layouts::Plan plan,ref Prepared batch,ref mut frames::State state,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut value_roots::State roots_state,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> roots_scratch){
    var usize i=0;while(i<batch.count){var usize prepaid=batch.costs[i];
        assert(frames::transfer(plan,state,data,scratch,batch.sources[i],batch.destinations[i],batch.copying[i],
            roots_state,roots,roots_scratch,ref mut prepaid).is_ok);
        assert(prepaid==0);i+=1;
    }
}
