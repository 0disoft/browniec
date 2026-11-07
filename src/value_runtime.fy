module value_runtime;
import value_program as programs;
import value_ir as value_ir;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_call_vm as calls;
import value_codec as codec;
import value_properties as properties;
import value_buffer_runtime as buffers;
import value_buffer_views as view_pool;
import value_view_runtime as views;
import value_view_copy_runtime as view_copy;
import value_roots as owners;
import buffer_growth as growth;
import errors as errors;
import ir as ir;
import std::bytes as bytes;
import std::vec as vec;

// Native coordinator only. Each vector is a distinct owning local; legacy
// execution supplies empty vectors and acquires no typed-domain allocation.
pub struct Step { usize pc; usize remaining; }
pub struct Budget { growth::Limits values; usize initial; }
pub fn errors::Error failure(frames::Error e,usize offset){return errors::make(switch(e){
    case .Fuel:{8}case .Quota:{13}case .Allocation:{15}case .Bounds:{14}
    case .State:{5}case .Type:{5}case .Value:{5}case .Owner:{5}
},offset);}
fn Result<usize,errors::Error> number(Result<usize,meter::Error> r,usize offset){return switch(r){
    case .ok(v):{.ok(v)}case .err(e):{.err(errors::make(switch(e){case .Fuel:{8}case .Quota:{13}case .Bounds:{5}case .State:{5}},offset))}
};}
// Logical allowance for retained-code/controller metadata, not sizeof or RAM.
// Existing ordinary aggregate backing is counted separately at its exact extent.
pub fn usize context_charge(){return 65536;}
pub fn Result<Budget,errors::Error> budget(ref programs::Program program,usize arena,growth::Limits limits,usize fuel){
    if(arena>65536){return .err(errors::make(13,0));}
    let growth::Limits remaining=switch(meter::remaining(context_charge()+arena,limits)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(13,0));}
    };
    let ref layouts::Plan plan=programs::layout(program);let usize largest=layouts::largest(plan);
    let usize width=switch(layouts::width(plan,programs::code(program).body.entry)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}
    };
    let usize initial=context_charge()+owners::setup_cost()+number(meter::setup_cost(largest),0)?+number(meter::enter_cost(width),0)?;
    if(fuel<initial){return .err(errors::make(8,0));}
    let growth::Ledger empty=growth::unowned();
    let bool view_enabled=views::present(ref programs::code(program).body);
    let usize extra_setup=if(view_enabled){views::setup_cost()}else{0};
    if(fuel-initial<extra_setup){return .err(errors::make(8,0));}
    let usize minimum=owners::metadata_charge()+meter::metadata_charge()+number(meter::charge(largest),0)?+number(meter::charge(width),0)?+
        if(view_enabled){views::metadata_charge()}else{0};
    let usize admitted=number(meter::admit(0,minimum,ref empty,remaining),0)?;
    return .ok(Budget{.values=remaining,.initial=initial+extra_setup});
}
pub fn Result<usize,errors::Error> setup(ref programs::Program program,
    ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    growth::Limits limits,usize fuel){
    if(vec::len<frames::State>(states)!=0 || vec::len<owners::State>(owner_states)!=0 || fuel<context_charge()){
        return .err(errors::make(5,0));}
    var usize remaining=fuel-context_charge();
    if(!vec::reserve<frames::State>(states,1).is_ok || !vec::reserve<owners::State>(owner_states,1).is_ok){return .err(errors::make(15,0));}
    let owners::State root_state=switch(owners::open(roots,root_scratch,limits,ref mut remaining)){
        case .ok(v):{v}case .err(e):{return .err(errors::make(switch(e){case .Fuel:{8}case .Quota:{13}case .Allocation:{15}
            case .State:{5}case .Binding:{5}case .Serial:{5}case .Owners:{13}case .Bounds:{14}},0));}
    };
    var frames::State state=switch(frames::open(programs::layout(program),data,scratch,ref root_state,limits,ref mut remaining)){
        case .ok(v):{v}case .err(e):{return .err(failure(e,0));}
    };
    let frames::Token entry=switch(frames::enter(programs::layout(program),ref mut state,data,
        programs::code(program).body.entry,ref root_state,limits,ref mut remaining)){
        case .ok(v):{v}case .err(e):{return .err(failure(e,0));}
    };
    switch(vec::push<owners::State>(owner_states,root_state)){case .ok(_):{}case .err(_):{return .err(errors::make(15,0));}};
    switch(vec::push<frames::State>(states,state)){case .ok(_):{}case .err(_):{return .err(errors::make(15,0));}};
    return .ok(remaining);
}
pub fn Result<frames::Token,errors::Error> token(ref vec::Vec<frames::State> states,usize frame,usize offset){
    if(vec::len<frames::State>(states)!=1){return .err(errors::make(5,offset));}
    let ref frames::State s=vec::at<frames::State>(states,0);
    if(frame>=s.depth || frame>=32 || s.frames[frame].generation==0){return .err(errors::make(5,offset));}
    return .ok(frames::Token{.frame=frame,.generation=s.frames[frame].generation});
}
fn frames::Address at(frames::Token frame,usize slot){return frames::Address{.frame=frame.frame,.generation=frame.generation,.slot=slot};}
pub fn Result<Step,errors::Error> instruction(ref programs::Program program,usize pc,usize frame,
    ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    ref mut i64[] registers,growth::Limits limits,usize fuel){
    var vec::Vec<view_pool::Pool> pools=vec::empty<view_pool::Pool>();
    return instruction_views(program,pc,frame,states,owner_states,data,scratch,roots,root_scratch,
        ref mut pools,registers,limits,fuel);
}
pub fn Result<Step,errors::Error> instruction_views(ref programs::Program program,usize pc,usize frame,
    ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    ref mut vec::Vec<view_pool::Pool> pools,
    ref mut i64[] registers,growth::Limits limits,usize fuel){
    let ref value_ir::Program unit=programs::code(program);let ref ir::Program body=ref unit.body;
    let usize offset=body.offsets[pc];let usize code=pc*8;let u8 op=body.code[code];
    let usize dst=body.code[code+1] as usize;let usize a=body.code[code+2] as usize;let u8 b=body.code[code+3];
    let frames::Token current=token(states,frame,offset)?;
    if(vec::len<owners::State>(owner_states)!=1 || registers.len!=128){return .err(errors::make(5,offset));}
    let ref mut frames::State state=vec::at_mut<frames::State>(states,0);
    let ref mut owners::State owned=vec::at_mut<owners::State>(owner_states,0);
    let ref layouts::Plan plan=programs::layout(program);var usize remaining=fuel;
    if(op==112){
        var usize i=4;while(i<8){if(body.code[code+i]!=0){return .err(errors::make(5,offset));}i+=1;}
        switch(view_copy::instruction(dst,a,b as usize,current,plan,state,owned,data,
            pools,roots,root_scratch,limits,ref mut remaining)){
            case .ok(_):{}case .err(e):{return .err(failure(e,offset));}
        };return .ok(Step{.pc=pc+1,.remaining=remaining});
    }
    if(op>=105 && op<=111){
        var usize i=5;while(i<8){if(body.code[code+i]!=0){return .err(errors::make(5,offset));}i+=1;}
        switch(views::instruction(op,dst,a,b as usize,body.code[code+4] as usize,current,plan,state,data,
            pools,owned,roots,root_scratch,registers,ref mut remaining)){
            case .ok(_):{}case .err(e):{return .err(failure(e,offset));}
        };return .ok(Step{.pc=pc+1,.remaining=remaining});
    }
    if(op>=99 && op<=104){
        switch(buffers::instruction(op,dst,a,b as usize,current,plan,state,owned,data,roots,
            root_scratch,registers,limits,ref mut remaining)){
            case .ok(_):{}case .err(e):{return .err(failure(e,offset));}
        };
        return .ok(Step{.pc=pc+1,.remaining=remaining});
    }
    if(op==98){
        let bool matched=switch(frames::tag_test(plan,state,data,at(current,a),b,owned,roots,root_scratch,ref mut remaining)){
            case .ok(v):{v}case .err(e):{return .err(failure(e,offset));}
        };registers[dst]=if(matched){1}else{0};return .ok(Step{.pc=pc+1,.remaining=remaining});
    }
    if(op==92){
        let frames::Case selected=switch(frames::case_value(plan,state,data,scratch,at(current,a),b,at(current,dst),owned,roots,root_scratch,ref mut remaining)){
            case .ok(v):{v}case .err(e):{return .err(failure(e,offset));}
        };return .ok(Step{.pc=if(selected.matched){pc+1}else{body.code[code+4] as usize},.remaining=remaining});
    }
    if(op==96){
        let i64 value=switch(frames::scalar_read(plan,state,data,at(current,a),ref mut remaining)){
            case .ok(v):{v}case .err(e):{return .err(failure(e,offset));}
        };registers[dst]=value;return .ok(Step{.pc=pc+1,.remaining=remaining});
    }
    let Result<usize,frames::Error> result=if(op==88 || op==89){
        frames::transfer(plan,state,data,scratch,at(current,a),at(current,dst),op==89,owned,roots,root_scratch,ref mut remaining)
    }else if(op==90){frames::drop(plan,state,data,at(current,dst),owned,roots,root_scratch,ref mut remaining)}
    else if(op==91){frames::build_tag(plan,state,data,scratch,at(current,dst),at(current,a),b,owned,roots,root_scratch,ref mut remaining)}
    else if(op==95){frames::buffer_value(plan,state,data,at(current,dst),b"",owned,roots,root_scratch,limits,ref mut remaining)}
    else if(op==97){frames::scalar_value(plan,state,data,at(current,dst),registers[a],ref mut remaining)}
    else{.err(.Type)};
    switch(result){case .ok(_):{}case .err(e):{return .err(failure(e,offset));}};
    return .ok(Step{.pc=pc+1,.remaining=remaining});
}
pub fn Result<calls::Prepared,errors::Error> begin_call(ref programs::Program program,usize pc,usize parent,
    ref mut vec::Vec<frames::State> states,ref vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch,
    growth::Limits limits,usize ordinary_cost,ref mut usize fuel){
    let ref value_ir::Program unit=programs::code(program);let ref ir::Program body=ref unit.body;let usize offset=body.offsets[pc];
    let usize charge=calls::cost(unit,programs::layout(program),pc)?;
    let usize remaining=*fuel;
    if(ordinary_cost>18446744073709551615-charge || remaining<ordinary_cost+charge){return .err(errors::make(8,offset));};
    *fuel=remaining-charge;
    if(parent>=31){return .err(errors::make(12,offset));}
    let frames::Token caller=token(states,parent,offset)?;
    if(vec::len<owners::State>(owner_states)!=1){return .err(errors::make(5,offset));}
    let ref owners::State owned=vec::at<owners::State>(owner_states,0);
    let ref mut frames::State state=vec::at_mut<frames::State>(states,0);
    let usize target=body.code[pc*8+2] as usize;
    let usize width=switch(layouts::width(programs::layout(program),target)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
    var usize prepaid=number(meter::enter_cost(width),offset)?;
    let frames::Token callee=switch(frames::enter(programs::layout(program),state,data,target,owned,limits,ref mut prepaid)){
        case .ok(v):{v}case .err(e):{return .err(failure(e,offset));}
    };
    return calls::prepare(unit,programs::layout(program),pc,parent,caller,callee,state,data,scratch,owned,roots,root_scratch);
}
pub fn void publish_call(ref programs::Program program,ref calls::Prepared batch,
    ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch){
    calls::publish(programs::layout(program),batch,vec::at_mut<frames::State>(states,0),data,scratch,
        vec::at_mut<owners::State>(owner_states,0),roots,root_scratch);
}
pub fn Result<usize,errors::Error> leave(ref programs::Program program,usize frame,usize offset,
    ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch){
    let vec::Vec<view_pool::Pool> pools=vec::empty<view_pool::Pool>();
    return leave_views(program,frame,offset,states,owner_states,data,roots,root_scratch,ref pools);
}
pub fn Result<usize,errors::Error> leave_views(ref programs::Program program,usize frame,usize offset,
    ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    ref vec::Vec<view_pool::Pool> pools){
    let frames::Token current=token(states,frame,offset)?;
    switch(views::empty_frame(pools,frame)){case .ok(_):{}case .err(e):{return .err(failure(e,offset));}};
    if(vec::at<frames::State>(states,0).frames[frame].live!=0){return .err(errors::make(5,offset));}
    return switch(frames::leave(programs::layout(program),vec::at_mut<frames::State>(states,0),data,current,
        vec::at_mut<owners::State>(owner_states,0),roots,root_scratch)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e,offset))}
    };
}
pub fn Result<usize,errors::Error> prepare_return(ref programs::Program program,usize frame,usize source,usize destination,usize offset,
    ref vec::Vec<frames::State> states,ref vec::Vec<owners::State> owner_states,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch,usize fuel){
    let vec::Vec<view_pool::Pool> pools=vec::empty<view_pool::Pool>();
    return prepare_return_views(program,frame,source,destination,offset,states,owner_states,data,scratch,roots,root_scratch,ref pools,fuel);
}
pub fn Result<usize,errors::Error> prepare_return_views(ref programs::Program program,usize frame,usize source,usize destination,usize offset,
    ref vec::Vec<frames::State> states,ref vec::Vec<owners::State> owner_states,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch,ref vec::Vec<view_pool::Pool> pools,usize fuel){
    if(frame==0 || destination<208 || destination>=224){return .err(errors::make(5,offset));}
    switch(views::empty_frame(pools,frame)){case .ok(_):{}case .err(e):{return .err(failure(e,offset));}};
    let frames::Token current=token(states,frame,offset)?;let frames::Token parent=token(states,frame-1,offset)?;
    let ref frames::State state=vec::at<frames::State>(states,0);let usize function=state.frames[frame].function;
    let usize one=1;
    if(source>=16 || state.frames[frame].live!=(one<<source) || programs::code(program).results[function]==0){return .err(errors::make(5,offset));}
    let usize id=switch(layouts::type_id(programs::layout(program),source,function)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
    let properties::Property p=switch(codec::shape(layouts::layout(programs::layout(program)),id)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
    let usize charge=8192+2*number(meter::operation_cost(p.bytes),offset)?;
    if(fuel<charge){return .err(errors::make(8,offset));}
    switch(frames::inspect_transfer(programs::layout(program),state,data,scratch,at(current,source),at(parent,destination-208),false,
        vec::at<owners::State>(owner_states,0),roots,root_scratch)){
        case .ok(_):{}case .err(e):{return .err(failure(e,offset));}
    };
    return .ok(fuel-charge);
}
pub fn void publish_return(ref programs::Program program,usize frame,usize source,usize destination,
    ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch){
    let frames::Token current=switch(token(states,frame,0)){case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}};
    let frames::Token parent=switch(token(states,frame-1,0)){case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}};
    let ref frames::State state=vec::at<frames::State>(states,0);
    let usize id=switch(layouts::type_id(programs::layout(program),source,state.frames[frame].function)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let properties::Property p=switch(codec::shape(layouts::layout(programs::layout(program)),id)){case .ok(v):{v}case .err(_):{assert(false);properties::Property{.bytes=0,.alignment=0,.payload_offset=0,.wrapper_depth=0,.copyable=false,.contains_buffer=false}}};
    var usize prepaid=switch(number(meter::operation_cost(p.bytes),0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    assert(frames::transfer(programs::layout(program),vec::at_mut<frames::State>(states,0),data,scratch,
        at(current,source),at(parent,destination-208),false,vec::at_mut<owners::State>(owner_states,0),roots,root_scratch,ref mut prepaid).is_ok);
}
pub fn Result<i64,errors::Error> finish(ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,Result<i64,errors::Error> outcome){
    if(vec::len<frames::State>(states)==0){return outcome;}
    let Option<errors::Error> cleanup_error=switch(frames::abort(vec::at_mut<frames::State>(states,0),data,scratch,
        vec::at_mut<owners::State>(owner_states,0),roots,root_scratch)){
        case .ok(_):{.none}case .err(e):{.some(failure(e,0))}
    };
    return switch(outcome){case .err(e):{.err(e)}case .ok(v):{switch(cleanup_error){case .none:{.ok(v)}case .some(e):{.err(e)}}}};
}
// The actual retained VM and native cleanup probes share this zero-Fuel exit.
// Closing the invocation's one Pool must precede frames::abort/root drain.
pub fn Result<i64,errors::Error> finish_views(ref mut vec::Vec<frames::State> states,ref mut vec::Vec<owners::State> owner_states,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    ref mut vec::Vec<view_pool::Pool> pools,Result<i64,errors::Error> outcome){
    let Result<i64,errors::Error> closed=switch(views::shutdown(pools,owner_states,roots,root_scratch)){
        case .ok(_):{outcome}case .err(e):{switch(outcome){
            case .err(original):{.err(original)}case .ok(_):{.err(failure(e,0))}
        }}
    };
    return finish(states,owner_states,data,scratch,roots,root_scratch,closed);
}
