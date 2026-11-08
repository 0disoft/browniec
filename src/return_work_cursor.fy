module return_work_cursor;
import errors as errors;

// Private accounting receipt, not an owner or a pending result. A complete
// return validation fits one fresh batch; insufficient shared room defers it.
pub struct State { usize total; usize last; usize pc; usize frame; usize required; u8 op; }
pub fn State empty(){return State{.total=0,.last=0,.pc=0,.frame=0,.required=0,.op=0};}
pub fn Result<usize,errors::Error> check(ref State state,usize required,usize offset){
    if(state.last>4096 || state.last>state.total || required>4096-state.last){return .err(errors::make(5,offset));}
    if(required>18446744073709551615-state.total){return .err(errors::make(5,offset));}
    return .ok(required);
}
// Call once after check against the same frozen receipt and successful payload
// validation/prefix preparation. This counts work already performed, not a
// completed RET: staged authority restoration or publication can still fail.
// The owning return recipe separately reports its final publication phase.
pub fn void record(ref mut State state,usize required,usize pc,usize frame,u8 op){
    state.total+=required;state.last+=required;state.required=required;
    state.pc=pc;state.frame=frame;state.op=op;
}
