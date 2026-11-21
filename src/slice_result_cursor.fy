module slice_result_cursor;
import errors as errors;
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
pub struct Cursor { usize pc; bool active; output_copy::State output; fills::State array; calls::State call; returns::State returned; metadata_budget::State metadata; u8 call_metadata_phase; u8 frame_limit; return_metadata::State return_metadata; }
pub fn Cursor empty(){
    return Cursor{.pc=0,.active=false,.output=output_copy::empty(),.array=fills::empty(),.call=calls::empty(),.returned=returns::empty(),.metadata=metadata_budget::empty(),.call_metadata_phase=0,.frame_limit=31,.return_metadata=return_metadata::empty()};
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
