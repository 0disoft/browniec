module slice_result_bindings;
import slice_result_runtime as runtime;
import array_slices as slices;
import array_owners as owners;
import errors as errors;

// Sparse linear receipts. Exclusive descendants can share one physical slot:
// at most 31 canonical child entries plus 16 shared slots need 47 records.
// A dense frame/site map would reserve 512 Held values instead.
pub struct State { runtime::Held[47] held; usize[47] locations; usize[47] parents; }
fn runtime::Held unused(){
    return runtime::Held{.issued=slices::Ticket{.slot=16,.generation=0},
        .view=owners::View{.root=owners::Token{.slot=16,.generation=0},.element=0,.length=0,.start=0,.end=0},
        .exclusive=false,.close_parent=false,.drop=false,.depth=0,.frame=0,.active=false};
}
pub fn State empty(){return State{.held=[unused();47],.locations=[512;47],.parents=[512;47]};}
pub fn usize find(ref State state,usize location){
    var usize i=0;while(i<47){if(state.held[i].active && state.locations[i]==location){return i;}i+=1;}return 47;
}
pub fn bool in_frame(ref State state,usize frame){
    var usize i=0;while(i<47){if(state.held[i].active && state.locations[i]/16==frame){return true;}i+=1;}return false;
}
pub fn Result<usize,errors::Error> retain(ref mut State state,usize location,usize parent,runtime::Held held){
    if(location>=512 || parent>=512 || location==parent || location/16!=parent/16 ||
        !held.active || held.frame!=location/16 || held.issued.slot>=16 || held.issued.generation==0 ||
        find(state,location)!=47){return .err(errors::make(5,0));}
    var usize free=47;var usize i=0;while(i<47){
        let runtime::Held old=state.held[i];
        if(old.active && old.issued.slot==held.issued.slot && old.issued.generation==held.issued.generation){return .err(errors::make(5,0));}
        if(!old.active && free==47){free=i;}i+=1;
    }
    if(free==47){return .err(errors::make(12,0));}
    state.held[free]=held;state.locations[free]=location;state.parents[free]=parent;return .ok(free);
}
// Returns the original caller binding only after canonical close succeeds.
// A stale ticket or late root-drop failure leaves both receipt and runtime live.
pub struct Closed { slices::Ticket parent; usize location; usize remaining; }
pub fn Result<Closed,errors::Error> close(ref mut State state,ref mut runtime::State native,
    usize location,slices::Ticket current,usize capacity,usize fuel){
    let usize index=find(state,location);if(index==47){return .err(errors::make(5,0));}
    var runtime::Held held=state.held[index];
    let runtime::Closed closed=runtime::close(native,ref mut held,current,capacity,fuel)?;
    let usize parent=if(held.exclusive){state.parents[index]}else{512};
    state.held[index]=unused();state.locations[index]=512;state.parents[index]=512;
    return .ok(Closed{.parent=closed.parent,.location=parent,.remaining=closed.remaining});
}
// Only after successful terminal handoff/abort has already consumed that frame's
// canonical children/readers. This must never substitute for ordinary CLOSE.
pub fn void transferred(ref mut State state,usize frame){
    var usize i=0;while(i<47){if(state.held[i].active && state.locations[i]/16==frame){
        state.held[i]=unused();state.locations[i]=512;state.parents[i]=512;
    }i+=1;}
}
