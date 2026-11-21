module metadata_budget;
import errors as errors;

// Private per-dispatch allowance. A charged stage must do actual bounded work;
// credits cannot be saved across yields and redeemed for a larger atomic scan.
// One unit bounds a visit to a fixed-size metadata entry (not a guest byte,
// instruction or CPU cycle). Nested scans/copies belong in the stage's bound.
pub struct State { usize total; usize last; usize stages; }
pub fn usize limit(){return 4096;}
pub fn usize unlimited(){return 18446744073709551615;}
pub fn Result<usize,errors::Error> prepay(ref mut usize fuel,usize offset){
    if(*fuel==unlimited()){return .ok(limit());}
    if(*fuel<limit()){return .err(errors::make(4,offset));}
    let usize remaining=*fuel-limit();
    *fuel=remaining;
    return .ok(limit());
}
pub fn Result<usize,errors::Error> reset_metered(ref mut State state,ref mut usize fuel,usize offset){
    discard reset(state,offset)?;
    return prepay(fuel,offset);
}
pub fn State empty(){return State{.total=0,.last=0,.stages=0};}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
pub fn Result<usize,errors::Error> reset(ref mut State state,usize offset){
    if(state.last>limit() || state.last>state.total || state.stages>state.total){return .err(invalid(offset));}
    state.last=0;return .ok(limit());
}
// The caller runs exactly the admitted stage before another possible yield.
// Reject overflow before changing any counter. Insufficient room is a normal
// deferral and consumes no work, Fuel, staged authority or guest instruction.
pub fn Result<bool,errors::Error> admit(ref mut State state,usize bound,usize offset){
    let usize maximum=18446744073709551615;
    if(state.last>limit() || state.last>state.total || state.stages>state.total ||
        bound==0 || bound>limit() || bound>maximum-state.total || state.stages==maximum){return .err(invalid(offset));}
    if(bound>limit()-state.last){return .ok(false);}
    state.total+=bound;state.last+=bound;state.stages+=1;return .ok(true);
}
