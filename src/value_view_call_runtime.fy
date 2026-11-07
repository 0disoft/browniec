module value_view_call_runtime;
import value_buffer_views as views;
import value_view_runtime as view_runtime;
import value_frames as frames;
import value_frame_layout as layouts;
import value_roots as roots;
import std::bytes as bytes;
import std::vec as vec;

// Native coordinator foundation only. Local IDs/signature selections are not
// guest authority; admitting reference parameters/results still needs IR proof.
// Both activations must be current, adjacent, and the callee must be the top.
fn Result<usize,frames::Error> pair(ref layouts::Plan plan,ref frames::State state,
    ref vec::Vec<bytes::Buffer> frame_data,frames::Token caller,frames::Token callee){
    let usize outer=frames::inspect_frame(plan,state,frame_data,caller)?;
    let usize inner=frames::inspect_frame(plan,state,frame_data,callee)?;
    if(state.depth<2 || caller.frame+1!=callee.frame || callee.frame!=state.depth-1){return .err(.State);}
    return .ok(0);
}
// No implicit cleanup: CALL requires an empty view lane, RETURN allows only
// the selected descriptor. Reject malformed bindings rather than hiding them.
fn Result<usize,frames::Error> lane(ref views::Pool pool,usize frame,usize except){
    if(pool.closed){return .err(.State);}var usize i=0;
    while(i<32){let views::Row row=pool.rows[i];
        if(row.live && (row.binding>=512 || (row.binding/16==frame && row.binding!=except))){return .err(.State);}
        i+=1;
    }return .ok(0);
}

// Success is the number of aliases installed (0..8), not a ticket or byte count.
// No frame/root mutation or payload allocation/copy: aliases prepays512 per
// argument and publishes the complete batch atomically, preserving actuals.
pub fn Result<usize,frames::Error> arguments(ref layouts::Plan plan,ref frames::State state,
    ref vec::Vec<bytes::Buffer> frame_data,ref mut views::Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> backing,ref vec::Vec<bytes::Buffer> scratch,
    frames::Token caller,frames::Token callee,ref usize[] source_ids,ref usize[] formal_ids,
    ref mut usize fuel){
    let usize checked=pair(plan,state,frame_data,caller,callee)?;
    if(source_ids.len!=formal_ids.len){return .err(.State);}
    if(source_ids.len>8){return .err(.Bounds);}
    var usize[8] sources=[0;8];var usize[8] destinations=[0;8];var usize i=0;
    while(i<source_ids.len){
        if(source_ids[i]>=16 || formal_ids[i]>=16){return .err(.Bounds);}
        sources[i]=caller.frame*16+source_ids[i];destinations[i]=callee.frame*16+formal_ids[i];i+=1;
    }
    let usize empty=lane(pool,callee.frame,512)?;
    return switch(views::aliases(pool,store,backing,scratch,
        ref sources[..source_ids.len],ref destinations[..formal_ids.len],fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(view_runtime::failure(e))}
    };
}

// Success is destination_id, the caller's logical local view ID (0..15).
// The selected actual's authenticated descriptor bounds the result's exact
// physical root and subwindow. Handoff costs256 and moves only the descriptor;
// closing the origin after callee leave must retain the lease until last alias.
pub fn Result<usize,frames::Error> result(ref layouts::Plan plan,ref frames::State state,
    ref vec::Vec<bytes::Buffer> frame_data,ref mut views::Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> backing,ref vec::Vec<bytes::Buffer> scratch,
    frames::Token caller,frames::Token callee,usize source_id,usize destination_id,usize origin_id,
    ref mut usize fuel){
    let usize checked=pair(plan,state,frame_data,caller,callee)?;
    if(source_id>=16 || destination_id>=16 || origin_id>=16){return .err(.Bounds);}
    if(state.frames[callee.frame].live!=0){return .err(.State);}
    let usize selected=callee.frame*16+source_id;
    let usize empty=lane(pool,callee.frame,selected)?;
    let views::Ticket source=switch(views::lookup(pool,store,backing,scratch,selected)){
        case .ok(v):{v}case .err(e):{return .err(view_runtime::failure(e));}
    };
    let usize origin_binding=caller.frame*16+origin_id;
    let views::Ticket origin=switch(views::lookup(pool,store,backing,scratch,origin_binding)){
        case .ok(v):{v}case .err(e):{return .err(view_runtime::failure(e));}
    };
    return switch(views::handoff(pool,store,backing,scratch,source,selected,
        caller.frame*16+destination_id,origin,origin_binding,fuel)){
        case .ok(_):{.ok(destination_id)}case .err(e):{.err(view_runtime::failure(e))}
    };
}
