module value_buffer_copy_source;
import value_ir as values;
import value_source_bindings as bindings;
import value_source_context as context;
import value_source_ops as ops;
import value_buffer_source_ops as buffer_ops;
import value_buffer_source as borrows;
import value_source_control as branches;
import value_source_loops as looping;
import errors as errors;
import ir as ir;
import std::vec as vec;

// One native APPEND104 or APPEND_VIEW112 fills an independent empty root.
// Both inputs share the exact Result wrapper, ownership and failure cleanup.
pub fn Result<context::Value,errors::Error> finish(ref mut values::Program unit,
    ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,
    ref mut looping::State flow,borrows::Reference source,usize exact,usize at){
    if(source.writing){return .err(errors::make(3,at));}
    let usize borrowed=borrows::end(state,source,at)?;
    return copy(unit,state,paths,flow,source.slot,false,source.temporary,exact,at);
}
pub fn Result<context::Value,errors::Error> finish_view(ref mut values::Program unit,
    ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,
    ref mut looping::State flow,usize source,usize exact,usize at){
    return copy(unit,state,paths,flow,source,true,false,exact,at);
}
fn Result<context::Value,errors::Error> copy(ref mut values::Program unit,
    ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,
    ref mut looping::State flow,usize source,bool view,bool temporary,usize exact,usize at){
    let usize buffer=context::intern(unit,4,0,0,at)?;
    let usize error=context::intern(unit,1,10,0,at)?;
    let usize result=context::intern(unit,6,context::byte(buffer),context::byte(error),at)?;
    let context::Value expected=context::expected(context::owned(result,0),exact,at)?;
    let usize size=context::intern(unit,1,12,0,at)?;
    let usize growth=context::intern(unit,6,context::byte(size),context::byte(error),at)?;
    let usize destination=bindings::allocate(unit,state,result,at)?;
    let usize copied=ops::empty_buffer(unit,state,buffer,at)?;
    let usize outcome=buffer_ops::grow(unit,state,if(view){112}else{104},growth,copied,source,at)?;
    // The operation retains no native view; its anonymous capture can close now.
    if(view){let usize closed=bindings::close_view(unit,state,source,at)?;}
    let usize mark=branches::mark(paths);let usize entry=branches::save(paths,state,at)?;

    let ops::Case success=ops::case_value(unit,state,outcome,1,at)?;
    let usize released=bindings::drop(unit,state,outcome,at)?;
    let usize length=bindings::drop(unit,state,success.payload,at)?;
    let usize built=ops::tag_into(unit,state,destination,copied,1,at)?;
    let usize skip=ir::raw(ref mut unit.body,19,0,0,0,at)?;
    let branches::Exit left=branches::capture(paths,state,false,skip,at)?;

    let usize selected=branches::select(unit,state,paths,entry,at)?;
    let usize alternative=unit.body.count;
    let usize patched=ops::patch_case(unit,success.instruction,alternative,at)?;
    let ops::Case failure=ops::case_value(unit,state,outcome,0,at)?;
    let usize released_error=bindings::drop(unit,state,outcome,at)?;
    let usize built_error=ops::tag_into(unit,state,destination,failure.payload,0,at)?;
    let usize error_payload=bindings::drop(unit,state,failure.payload,at)?;
    let usize empty_owner=bindings::drop(unit,state,copied,at)?;
    // The preceding success CASE already proves this error CASE exhaustive.
    // Keep its impossible mismatch edge on a real failure instruction for the
    // independent CFG instead of letting it fall through uninitialized output.
    let usize error_skip=ir::raw(ref mut unit.body,19,0,0,0,at)?;
    let branches::Exit right=branches::capture(paths,state,false,error_skip,at)?;
    let usize impossible=unit.body.count;
    let usize failure_patch=ops::patch_case(unit,failure.instruction,impossible,at)?;
    let usize trap=ir::raw(ref mut unit.body,25,0,0,0,at)?;
    let bool joined=branches::join(unit,state,paths,ref left,ref right,at)?;
    let usize freed=looping::release(paths,flow,mark,at)?;
    if(temporary){let usize dropped=bindings::drop(unit,state,source,at)?;}
    return .ok(context::owned(result,destination));
}
