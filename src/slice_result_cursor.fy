module slice_result_cursor;
import errors as errors;
import std::num as num;
import output_copy_cursor as output_copy;
import array_fill_cursor as fills;
import call_copy_cursor as calls;
import return_work_cursor as returns;
import metadata_budget as metadata_budget;
import return_metadata_execution as return_metadata;

// Trusted private synchronous state, not a guest capability or a work budget.
// The dispatcher owns these inline/native-stack values; no heap is allocated.
// Register/static banks stay separately borrowed: the pinned compiler treats
// simultaneous loans of sibling array fields as loans of the whole struct.
pub struct Limits { u8 frames; u8 owners; u8 descriptors; }
pub fn Limits default_limits(){return Limits{.frames=31,.owners=16,.descriptors=16};}

fn u8 narrow(usize value,u8 ceiling){
    if(value>=ceiling as usize){return ceiling;}
    let i64 small=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(small)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
pub fn Limits limits(usize frames,usize owners,usize descriptors){
    return Limits{.frames=narrow(frames,31),.owners=narrow(owners,16),.descriptors=narrow(descriptors,16)};
}
// Operation 9 has one native word for its argument. Each narrowed count
// fits five bits. Keep serialization here and execution on the typed value.
pub fn usize encode_limits(Limits selected){
    return (selected.frames as usize) | ((selected.owners as usize)<<5) | ((selected.descriptors as usize)<<10);
}
pub fn Result<Limits,errors::Error> decode_limits(usize word){
    let usize frames=word&31;
    let usize owners=(word>>5)&31;
    let usize descriptors=(word>>10)&31;
    if(word>>15!=0 || frames==0 || owners==0 || owners>16 || descriptors==0 || descriptors>16){
        return .err(errors::make(5,0));
    }
    return .ok(limits(frames,owners,descriptors));
}

pub struct Cursor { usize pc; bool active; output_copy::State output; fills::State array; calls::State call; returns::State returned; metadata_budget::State metadata; u8 call_metadata_phase; Limits limits; return_metadata::State return_metadata; }
pub fn Cursor empty(){
    return Cursor{.pc=0,.active=false,.output=output_copy::empty(),.array=fills::empty(),.call=calls::empty(),.returned=returns::empty(),.metadata=metadata_budget::empty(),.call_metadata_phase=0,.limits=default_limits(),.return_metadata=return_metadata::empty()};
}
pub struct Stats { usize calls; usize yields; usize dispatched; usize last; usize maximum; }
pub fn Stats stats(){return Stats{.calls=0,.yields=0,.dispatched=0,.last=0,.maximum=0};}
pub fn bool valid_quantum(usize quantum){return quantum>=1 && quantum<=4096;}
fn errors::Error invalid(){return errors::make(5,0);}
fn bool valid(ref Stats s){
    return s.last<=s.maximum && s.maximum<=4096 && s.maximum<=s.dispatched &&
        s.yields<=s.calls && (s.calls!=0 || s.dispatched==0) &&
        ((s.dispatched==0)==(s.maximum==0));
}
// Reserve arithmetic headroom for the entire batch before changing history.
// Quantum is trusted by the dispatcher; Stats does not grant execution authority.
pub fn Result<usize,errors::Error> begin(ref mut Stats s,usize quantum){
    let usize maximum=18446744073709551615;
    if(!valid_quantum(quantum) || !valid(s) || s.calls==maximum ||
        quantum>maximum-s.dispatched || s.yields==maximum){return .err(invalid());}
    s.calls+=1;s.last=0;return .ok(quantum);
}
// Aggregate once on Pending, Complete or error. Zero visits are valid on an
// error/Complete return, but cannot constitute a pending instruction boundary.
pub fn Result<usize,errors::Error> finish(ref mut Stats s,usize visited,bool pending){
    let usize maximum=18446744073709551615;
    if(!valid(s) || s.calls==0 || visited>4096 || visited>maximum-s.dispatched ||
        (pending && (visited==0 || s.yields==maximum || s.yields>=s.calls))){return .err(invalid());}
    let usize dispatched=s.dispatched+visited;
    let usize yields=s.yields+if(pending){1}else{0};
    let usize high=if(visited>s.maximum){visited}else{s.maximum};
    s.dispatched=dispatched;s.last=visited;s.maximum=high;s.yields=yields;
    return .ok(visited);
}
// Optional scalar counters; canonical batching uses one local visited counter and
// finish instead of per-opcode historical Stats updates.
pub fn Result<usize,errors::Error> visit(ref mut Stats s){
    if(!valid(s) || s.calls==0 || s.last>=4096 || s.dispatched==18446744073709551615){return .err(invalid());}
    let usize last=s.last+1;s.dispatched+=1;s.last=last;
    if(last>s.maximum){s.maximum=last;}return .ok(last);
}
pub fn Result<usize,errors::Error> yielded(ref mut Stats s){
    if(!valid(s) || s.calls==0 || s.last==0 || s.yields==18446744073709551615 || s.yields>=s.calls){
        return .err(invalid());
    }
    s.yields+=1;return .ok(s.yields);
}
