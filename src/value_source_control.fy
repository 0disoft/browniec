module value_source_control;
import value_source_bindings as bindings;
import value_ir as values;
import ir as ir;
import errors as errors;
import std::vec as vec;
import value_view_bindings as views;

// These are compiler CFG exits, never runtime owner snapshots. Every continuing
// arm ends in a pending forward JUMP. Terminal arms have no such instruction.
// Keep large snapshots off recursive parser frames. Scoped indices identify
// compiler-only entries in one invocation-local owning vector, never VM handles.
pub struct Exit { usize path; bool terminal; usize jump; }
pub fn Result<usize,errors::Error> save(ref mut vec::Vec<bindings::Snapshot> paths,ref bindings::State state,usize at){
    let usize n=vec::len<bindings::Snapshot>(paths);
    if(n>=128){return .err(errors::make(4,at));}
    if(n==vec::capacity<bindings::Snapshot>(paths)){
        let usize capacity=if(n==0){4}else{n*2};
        if(!vec::reserve<bindings::Snapshot>(paths,capacity).is_ok){return .err(errors::make(15,at));}
    }
    let bindings::Snapshot snapshot=bindings::snapshot(state);
    if(!vec::push<bindings::Snapshot>(paths,snapshot).is_ok){return .err(errors::make(15,at));}
    return .ok(n);
}
pub fn Result<usize,errors::Error> select(ref values::Program unit,ref mut bindings::State state,
    ref vec::Vec<bindings::Snapshot> paths,usize path,usize at){
    if(path>=vec::len<bindings::Snapshot>(paths)){return .err(errors::make(3,at));}
    return bindings::select_path(unit,state,vec::at<bindings::Snapshot>(paths,path),at);
}
pub fn usize mark(ref vec::Vec<bindings::Snapshot> paths){return vec::len<bindings::Snapshot>(paths);}
pub fn Result<usize,errors::Error> release(ref mut vec::Vec<bindings::Snapshot> paths,usize mark,usize at){
    if(mark>vec::len<bindings::Snapshot>(paths)){return .err(errors::make(3,at));}
    while(vec::len<bindings::Snapshot>(paths)>mark){
        switch(vec::pop<bindings::Snapshot>(paths)){case .some(_):{}case .none:{return .err(errors::make(3,at));}};
    }return .ok(mark);
}
pub fn Result<Exit,errors::Error> capture(ref mut vec::Vec<bindings::Snapshot> paths,ref bindings::State state,
    bool terminal,usize jump,usize at){
    let usize path=if(terminal){128}else{save(paths,state,at)?};
    return .ok(Exit{.path=path,.terminal=terminal,.jump=jump});
}
fn Result<usize,errors::Error> trim(ref mut values::Program unit,ref mut bindings::State state,usize common,usize at){
    let usize one=1;var usize id=state.next;
    while(id!=0){id-=1;if(((state.live|state.maybe)&(one<<id))!=0 && ((common|state.loop_roots)&(one<<id))==0){
        let usize dropped=bindings::drop(unit,state,id,at)?;
    }}return .ok(state.live);
}
fn Result<usize,errors::Error> target(ref mut values::Program unit,usize jump,usize at){
    if(jump>=unit.body.count || unit.body.code[jump*8]!=19){return .err(errors::make(3,at));}
    let usize pc=unit.body.count;return ir::patch(ref mut unit.body,jump,pc,at);
}
// Merge only continuing edges. If a name moved on one edge, explicitly drop its
// still-live value on the other edge and mark it Dead after the join. This admits
// legal conditional moves without reviving owners. Anonymous roots pinned by
// surviving view descriptors remain possible and use conditional cleanup later.
// A subsequent read of that maybe-moved name rejects; mutable reinitialization is
// allowed. Different surviving lexical names still reject through binder::merge.
pub fn Result<bool,errors::Error> join(ref mut values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,ref Exit left,ref Exit right,usize at){
    if(left.terminal && right.terminal){return .ok(true);}
    if(left.terminal){
        let usize selected=select(unit,state,paths,right.path,at)?;
        let usize patched=target(unit,right.jump,at)?;return .ok(false);
    }
    if(right.terminal){
        let usize selected=select(unit,state,paths,left.path,at)?;
        let usize patched=target(unit,left.jump,at)?;return .ok(false);
    }
    if(left.path>=mark(paths) || right.path>=mark(paths)){return .err(errors::make(3,at));}
    let usize a_live=vec::at<bindings::Snapshot>(paths,left.path).state.live;
    let usize b_live=vec::at<bindings::Snapshot>(paths,right.path).state.live;
    let usize a_maybe=vec::at<bindings::Snapshot>(paths,left.path).state.maybe;
    let usize b_maybe=vec::at<bindings::Snapshot>(paths,right.path).state.maybe;
    var usize roots=0;var usize id=0;while(id<16){
        roots|=views::local_roots(ref vec::at<bindings::Snapshot>(paths,left.path).state.views,id);
        roots|=views::local_roots(ref vec::at<bindings::Snapshot>(paths,right.path).state.views,id);id+=1;
    }
    let usize common=(a_live&b_live)|roots;
    if(a_live==b_live && a_maybe==b_maybe){
        let usize selected=select(unit,state,paths,right.path,at)?;
        let usize matched=bindings::merge(unit,state,vec::at<bindings::Snapshot>(paths,left.path),at)?;
        let usize a=target(unit,left.jump,at)?;let usize b=target(unit,right.jump,at)?;
        return .ok(false);
    }
    let usize selected_left=select(unit,state,paths,left.path,at)?;
    let usize a=target(unit,left.jump,at)?;let usize trimmed_left=trim(unit,state,common,at)?;
    let usize normalized=save(paths,state,at)?;
    let usize skip=ir::raw(ref mut unit.body,19,0,0,0,at)?;
    let usize selected_right=select(unit,state,paths,right.path,at)?;
    let usize b=target(unit,right.jump,at)?;let usize trimmed_right=trim(unit,state,common,at)?;
    let usize matched=bindings::merge(unit,state,vec::at<bindings::Snapshot>(paths,normalized),at)?;
    let usize end=unit.body.count;let usize patched=ir::patch(ref mut unit.body,skip,end,at)?;
    return .ok(false);
}
