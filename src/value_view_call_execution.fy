module value_view_call_execution;
import value_ir as value_ir;
import value_program as programs;
import value_call_vm as calls;
import value_runtime as runtime;
import value_view_call_runtime as native;
import value_buffer_views as pool;
import value_frames as frames;
import value_roots as roots;
import errors as errors;
import ir as ir;
import std::bytes as bytes;
import std::vec as vec;

// Only bounded descriptor metadata is staged. The candidate never owns a lease
// and must be discarded without shutdown on failure. No callback/reentry or
// view/root mutation may occur between preparation and single publication.
pub struct Returned { pool::Pool candidate; usize remaining; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
fn Result<usize,errors::Error> vacant(ref pool::Pool candidate,usize binding,usize offset){
    if(candidate.closed || binding>=512){return .err(invalid(offset));}
    var usize i=0;while(i<32){let pool::Row row=candidate.rows[i];
        if(row.live && (row.binding>=512 || row.binding==binding)){return .err(invalid(offset));}i+=1;
    }return .ok(0);
}
pub fn Result<Option<pool::Pool>,errors::Error> arguments(ref programs::Program program,usize pc,
    ref calls::Prepared batch,ref vec::Vec<frames::State> states,ref mut vec::Vec<roots::State> stores,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> backing,ref vec::Vec<bytes::Buffer> scratch,
    ref vec::Vec<pool::Pool> pools){
    let ref value_ir::Program unit=programs::code(program);let ref ir::Program body=ref unit.body;
    let usize offset=body.offsets[pc];
    if(vec::len<pool::Pool>(pools)==0){
        if(batch.view_count!=0 || unit.results[batch.target]>=17){return .err(invalid(offset));}
        return .ok(.none);
    }
    if(vec::len<pool::Pool>(pools)!=1 || vec::len<frames::State>(states)!=1 || vec::len<roots::State>(stores)!=1){return .err(invalid(offset));}
    // The normal typed preflight authenticates fresh adjacent frames and all
    // owned moves first. Native alias admission then resolves every actual
    // window against the original registry before any CALL consumes an owner.
    var pool::Pool candidate=*vec::at<pool::Pool>(pools,0);
    if(unit.results[batch.target]>=17){let usize empty=vacant(ref candidate,
        batch.caller.frame*16+body.code[pc*8+1] as usize,offset)?;}
    var usize prepaid=batch.view_count*512;
    switch(native::arguments(programs::layout(program),vec::at<frames::State>(states,0),data,
        ref mut candidate,vec::at_mut<roots::State>(stores,0),backing,scratch,batch.caller,batch.callee,
        ref batch.view_sources[..batch.view_count],ref batch.view_formals[..batch.view_count],ref mut prepaid)){
        case .ok(_):{}case .err(e):{return .err(runtime::failure(e,offset));}
    };assert(prepaid==0);return .ok(.some(candidate));
}
pub fn void publish(ref pool::Pool candidate,ref mut vec::Vec<pool::Pool> pools){
    let ref mut pool::Pool destination=vec::at_mut<pool::Pool>(pools,0);*destination=*candidate;
}
// Return authority comes solely from the immutable invoking instruction and
// signature's selected ordinal. The native result gate independently checks
// exact root identity, containment, adjacent frames and absence of other live
// callee values/views. The caller actual remains open until its guest CLOSE.
pub fn Result<Returned,errors::Error> result(ref programs::Program program,usize pc,usize frame,
    usize return_pc,usize destination,ref vec::Vec<frames::State> states,ref mut vec::Vec<roots::State> stores,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> backing,ref vec::Vec<bytes::Buffer> scratch,
    ref vec::Vec<pool::Pool> pools,usize fuel){
    let ref value_ir::Program unit=programs::code(program);let ref ir::Program body=ref unit.body;
    if(pc>=body.count || pc>=256){return .err(invalid(0));}let usize offset=body.offsets[pc];
    if(frame==0 || frame>=32 || return_pc==0 || return_pc>body.count ||
        vec::len<pool::Pool>(pools)!=1 || vec::len<frames::State>(states)!=1 || vec::len<roots::State>(stores)!=1){return .err(invalid(offset));}
    let usize code=pc*8;
    if(body.code[code]!=113 || body.code[code+1]!=0 || body.code[code+3]!=0){return .err(invalid(offset));}
    var usize i=4;while(i<8){if(body.code[code+i]!=0){return .err(invalid(offset));}i+=1;}
    let frames::Token caller=runtime::token(states,frame-1,offset)?;
    let frames::Token callee=runtime::token(states,frame,offset)?;
    let ref frames::State state=vec::at<frames::State>(states,0);
    let usize function=state.frames[frame].function;let usize outer=state.frames[frame-1].function;
    if(function>=body.function_count || outer>=body.function_count ||
        pc<body.starts[function] || pc>=body.ends[function]){return .err(invalid(offset));}
    let usize call=return_pc-1;let usize instruction=call*8;let usize site=body.code[instruction+3] as usize;
    let usize encoded=unit.results[function] as usize;
    if(call<body.starts[outer] || call>=body.ends[outer] || body.code[instruction]!=114 ||
        body.code[instruction+2] as usize!=function || destination>=16 || body.code[instruction+1] as usize!=destination ||
        site>=body.call_count || encoded<17 || encoded>24){return .err(invalid(offset));}
    let usize ordinal=encoded-17;let usize start=body.register_starts[function];
    if(ordinal>=body.arities[function] || body.call_arities[site] as usize!=body.arities[function] ||
        start>=128 || ordinal>=128-start || unit.parameters[start+ordinal]<17 || unit.parameters[start+ordinal]>32){return .err(invalid(offset));}
    let usize actual=body.call_args[site*8+ordinal] as usize;
    if(actual<224 || actual>=240){return .err(invalid(offset));}
    // Same two-frame inspection allowance as typed RETURN, plus one prepaid
    // descriptor move. Native handoff uses only the local256 allowance.
    if(fuel<8192+256){return .err(errors::make(8,offset));}
    var pool::Pool candidate=*vec::at<pool::Pool>(pools,0);var usize prepaid=256;
    switch(native::result(programs::layout(program),state,data,ref mut candidate,
        vec::at_mut<roots::State>(stores,0),backing,scratch,caller,callee,
        body.code[code+2] as usize,destination,actual-224,ref mut prepaid)){
        case .ok(_):{}case .err(e):{return .err(runtime::failure(e,offset));}
    };assert(prepaid==0);
    return .ok(Returned{.candidate=candidate,.remaining=fuel-8192-256});
}
