module loops;

import errors as errors;
import ir as ir;

// Pending transfers are owned by the nearest lexical loop, never a caller.
pub struct State {
    usize depth;
    usize[32] heads;
    bool[32] classic;
    usize[32] bindings;
    usize[256] breaks;
    usize[256] continues;
}
pub fn State empty() {
    return State { .depth=0, .heads=[0;32], .classic=[false;32], .bindings=[0;32],
        .breaks=[0;256], .continues=[0;256] };
}
pub fn Result<usize, errors::Error> enter(ref mut State s, usize head, bool classic, usize offset) {
    if (s.depth>=32) {return .err(errors::make(4,offset));}
    let usize level=s.depth;
    s.heads[level]=head; s.classic[level]=classic; s.depth+=1;
    return .ok(level);
}
pub fn Result<usize, errors::Error> transfer(ref mut State s, ref mut ir::Program p, bool leave, usize offset) {
    if (s.depth==0) {return .err(errors::make(2,offset));}
    let usize level=s.depth-1;
    if (!leave && !s.classic[level]) {return ir::raw(p,22,0,s.heads[level],0,offset);}
    let usize pc=ir::raw(p,19,0,0,0,offset)?;
    let usize owner=s.depth;
    if (leave) {s.breaks[pc]=owner;} else {s.continues[pc]=owner;}
    return .ok(pc);
}
pub fn Result<usize, errors::Error> resolve(ref mut State s, ref mut ir::Program p, bool leave, usize target, usize offset) {
    var usize pc=0;
    var usize patched=0;
    while (pc<p.count) {
        let usize owner=if (leave) {s.breaks[pc]} else {s.continues[pc]};
        if (owner==s.depth) {
            let usize jump=ir::patch(p,pc,target,offset)?;
            if (leave) {s.breaks[pc]=0;} else {s.continues[pc]=0;}
            patched+=1;
        }
        pc+=1;
    }
    return .ok(patched);
}
