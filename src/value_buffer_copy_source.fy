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
import metadata_budget as budget;

// One native APPEND104 or APPEND_VIEW112 fills an independent empty root.
// Both inputs share the exact Result wrapper, ownership and failure cleanup.
pub fn Result<context::Value,errors::Error> finish_raw(ref mut values::Program unit,
    ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,
    ref mut looping::State flow,borrows::Reference source,usize exact,usize at){
    if(source.writing){return .err(errors::make(3,at));}
    let usize borrowed=borrows::end(state,source,at)?;
    return copy_raw(unit,state,paths,flow,source.slot,false,source.temporary,exact,at);
}
pub fn Result<context::Value,errors::Error> finish_view_raw(ref mut values::Program unit,
    ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,
    ref mut looping::State flow,usize source,usize exact,usize at){
    return copy_raw(unit,state,paths,flow,source,true,false,exact,at);
}
fn Result<context::Value,errors::Error> copy_raw(ref mut values::Program unit,
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

// One original construction/CFG/cleanup service per admitted stage.
pub struct Copy { usize source; usize exact; usize at; usize buffer; usize error; usize result; usize size; usize growth; usize destination; usize copied; usize outcome; usize mark; usize entry; usize alternative; usize impossible; usize skip; usize error_skip; borrows::Reference loan; ops::Case success; ops::Case failure; branches::Exit left; branches::Exit right; u8 phase; u8 request; bool needs_loan; bool view; bool temporary; bool done; }
pub fn Copy copying(usize source,bool view,bool temporary,usize exact,usize at,borrows::Reference loan,bool needs_loan){return Copy{.source=source,.exact=exact,.at=at,.buffer=0,.error=0,.result=0,.size=0,.growth=0,.destination=0,.copied=0,.outcome=0,.mark=0,.entry=0,.alternative=0,.impossible=0,.skip=0,.error_skip=0,.loan=loan,.success=ops::Case{.instruction=0,.payload=0},.failure=ops::Case{.instruction=0,.payload=0},.left=branches::Exit{.path=0,.terminal=false,.jump=0},.right=branches::Exit{.path=0,.terminal=false,.jump=0},.phase=0,.request=0,.needs_loan=needs_loan,.view=view,.temporary=temporary,.done=false};}
pub fn Result<context::Value,errors::Error> prepared(ref Copy w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(context::owned(w.result,w.destination));}
pub fn Result<bool,errors::Error> advance(ref mut values::Program unit,ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,ref mut Copy w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.request=1;return .ok(false);
}
pub fn Result<bool,errors::Error> service(ref mut values::Program unit,ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,ref mut Copy w){
    if(w.done || w.request!=1){return .err(errors::make(5,w.at));}let u8 phase=w.phase;
    if(phase==0){if(w.needs_loan && w.loan.writing){return .err(errors::make(3,w.at));}w.phase=1;w.request=0;return .ok(false);}
    if(phase==1){if(w.needs_loan){let usize ended=borrows::end(state,w.loan,w.at)?;}w.phase=2;w.request=0;return .ok(false);}
    if(phase==2){w.buffer=context::intern(unit,4,0,0,w.at)?;w.phase=3;w.request=0;return .ok(false);}
    if(phase==3){w.error=context::intern(unit,1,10,0,w.at)?;w.phase=4;w.request=0;return .ok(false);}
    if(phase==4){w.result=context::intern(unit,6,context::byte(w.buffer),context::byte(w.error),w.at)?;w.phase=5;w.request=0;return .ok(false);}
    if(phase==5){let context::Value expected=context::expected(context::owned(w.result,0),w.exact,w.at)?;w.phase=6;w.request=0;return .ok(false);}
    if(phase==6){w.size=context::intern(unit,1,12,0,w.at)?;w.phase=7;w.request=0;return .ok(false);}
    if(phase==7){w.growth=context::intern(unit,6,context::byte(w.size),context::byte(w.error),w.at)?;w.phase=8;w.request=0;return .ok(false);}
    if(phase==8){w.destination=bindings::allocate(unit,state,w.result,w.at)?;w.phase=9;w.request=0;return .ok(false);}
    if(phase==9){w.copied=ops::empty_buffer(unit,state,w.buffer,w.at)?;w.phase=10;w.request=0;return .ok(false);}
    if(phase==10){w.outcome=buffer_ops::grow(unit,state,if(w.view){112}else{104},w.growth,w.copied,w.source,w.at)?;w.phase=11;w.request=0;return .ok(false);}
    if(phase==11){if(w.view){let usize closed=bindings::close_view(unit,state,w.source,w.at)?;}w.phase=12;w.request=0;return .ok(false);}
    if(phase==12){w.mark=branches::mark(paths);w.phase=13;w.request=0;return .ok(false);}
    if(phase==13){w.entry=branches::save(paths,state,w.at)?;w.phase=14;w.request=0;return .ok(false);}
    if(phase==14){w.success=ops::case_value(unit,state,w.outcome,1,w.at)?;w.phase=15;w.request=0;return .ok(false);}
    if(phase==15){let usize released=bindings::drop(unit,state,w.outcome,w.at)?;w.phase=16;w.request=0;return .ok(false);}
    if(phase==16){let usize length=bindings::drop(unit,state,w.success.payload,w.at)?;w.phase=17;w.request=0;return .ok(false);}
    if(phase==17){let usize built=ops::tag_into(unit,state,w.destination,w.copied,1,w.at)?;w.phase=18;w.request=0;return .ok(false);}
    if(phase==18){w.skip=ir::raw(ref mut unit.body,19,0,0,0,w.at)?;w.phase=19;w.request=0;return .ok(false);}
    if(phase==19){w.left=branches::capture(paths,state,false,w.skip,w.at)?;w.phase=20;w.request=0;return .ok(false);}
    if(phase==20){let usize selected=branches::select(unit,state,paths,w.entry,w.at)?;w.phase=21;w.request=0;return .ok(false);}
    if(phase==21){w.alternative=unit.body.count;w.phase=22;w.request=0;return .ok(false);}
    if(phase==22){let usize patched=ops::patch_case(unit,w.success.instruction,w.alternative,w.at)?;w.phase=23;w.request=0;return .ok(false);}
    if(phase==23){w.failure=ops::case_value(unit,state,w.outcome,0,w.at)?;w.phase=24;w.request=0;return .ok(false);}
    if(phase==24){let usize released_error=bindings::drop(unit,state,w.outcome,w.at)?;w.phase=25;w.request=0;return .ok(false);}
    if(phase==25){let usize built_error=ops::tag_into(unit,state,w.destination,w.failure.payload,0,w.at)?;w.phase=26;w.request=0;return .ok(false);}
    if(phase==26){let usize error_payload=bindings::drop(unit,state,w.failure.payload,w.at)?;w.phase=27;w.request=0;return .ok(false);}
    if(phase==27){let usize empty_owner=bindings::drop(unit,state,w.copied,w.at)?;w.phase=28;w.request=0;return .ok(false);}
    if(phase==28){w.error_skip=ir::raw(ref mut unit.body,19,0,0,0,w.at)?;w.phase=29;w.request=0;return .ok(false);}
    if(phase==29){w.right=branches::capture(paths,state,false,w.error_skip,w.at)?;w.phase=30;w.request=0;return .ok(false);}
    if(phase==30){w.impossible=unit.body.count;w.phase=31;w.request=0;return .ok(false);}
    if(phase==31){let usize patched=ops::patch_case(unit,w.failure.instruction,w.impossible,w.at)?;w.phase=32;w.request=0;return .ok(false);}
    if(phase==32){let usize trap=ir::raw(ref mut unit.body,25,0,0,0,w.at)?;w.phase=33;w.request=0;return .ok(false);}
    if(phase==33){let bool joined=branches::join(unit,state,paths,ref w.left,ref w.right,w.at)?;w.phase=34;w.request=0;return .ok(false);}
    if(phase==34){let usize freed=looping::release(paths,flow,w.mark,w.at)?;w.phase=35;w.request=0;return .ok(false);}
    if(phase==35){if(w.temporary){let usize dropped=bindings::drop(unit,state,w.source,w.at)?;}w.phase=36;w.request=0;return .ok(false);}
    if(phase==36){w.done=true;w.request=0;return .ok(true);}return .err(errors::make(5,w.at));
}

fn Result<context::Value,errors::Error> drain(ref mut values::Program unit,ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,ref mut Copy w){var budget::State meter=budget::empty();
    while(!w.done){let usize reset=budget::reset(ref mut meter,w.at)?;let bool done=advance(unit,state,paths,flow,w,ref mut meter)?;if(w.request!=0){let bool serviced=service(unit,state,paths,flow,w)?;}}return prepared(w);}
pub fn Result<context::Value,errors::Error> finish(ref mut values::Program unit,ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,borrows::Reference source,usize exact,usize at){
    var Copy w=copying(source.slot,false,source.temporary,exact,at,source,true);return drain(unit,state,paths,flow,ref mut w);}
pub fn Result<context::Value,errors::Error> finish_view(ref mut values::Program unit,ref mut bindings::State state,ref mut vec::Vec<bindings::Snapshot> paths,ref mut looping::State flow,usize source,usize exact,usize at){
    var Copy w=copying(source,true,false,exact,at,borrows::none(),false);return drain(unit,state,paths,flow,ref mut w);}
