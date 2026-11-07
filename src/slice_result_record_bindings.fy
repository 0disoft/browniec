module slice_result_record_bindings;
import array_owners as owners;
import struct_vm as records;

// At most sixteen records can be live across every frame, because their owners
// share the same sixteen-slot table with arrays. Retain exact generations here.
// Index by owner slot; location is frame*16+record site, never a guest value.
pub struct State { owners::Token[16] tokens; usize[16] locations; }
fn owners::Token none(){return owners::Token{.slot=0,.generation=0};}
pub fn State empty(){return State{.tokens=[none();16],.locations=[512;16]};}
pub fn owners::Token get(ref State state,usize location){
    var usize i=0;while(i<16){if(state.tokens[i].generation!=0 && state.locations[i]==location){return state.tokens[i];}i+=1;}
    return none();
}
// Publication is infallible after owner allocation/transfer and verified site
// admission. A fresh owner slot cannot contain another live record binding.
pub fn void bind(ref mut State state,usize location,owners::Token token){
    state.tokens[token.slot]=token;state.locations[token.slot]=location;
}
pub fn void forget(ref mut State state,usize location){
    var usize i=0;while(i<16){if(state.locations[i]==location){state.tokens[i]=none();state.locations[i]=512;}i+=1;}
}
pub fn void clear_frame(ref mut State state,usize frame){
    var usize i=0;while(i<16){if(state.locations[i]/16==frame){state.tokens[i]=none();state.locations[i]=512;}i+=1;}
}
// Extract only one frame in a single sixteen-owner scan. No global 512-token
// compatibility map is materialized by saved return preparation.
pub fn owners::Token[16] frame_tokens(ref State state,usize frame){
    var owners::Token[16] tokens=[none();16];var usize i=0;
    while(i<16){if(state.tokens[i].generation!=0 && state.locations[i]/16==frame){
        tokens[state.locations[i]%16]=state.tokens[i];}i+=1;}
    return tokens;
}
// Expand only while a record operation needs the existing VM adapter. The large
// public compatibility map is absent from admission and borrowed handoff stacks.
pub fn records::State materialize(ref State state){
    var records::State plan=records::empty();var usize i=0;
    while(i<16){if(state.tokens[i].generation!=0){plan.tokens[state.locations[i]]=state.tokens[i];}i+=1;}
    return plan;
}
