module value_source_loops;
import value_source_bindings as bindings;
import value_source_control as branches;
import value_ir as values;
import ir as ir;
import errors as errors;
import std::vec as vec;

// Compiler metadata only. Snapshot indices never restore native owner authority.
pub struct Frame {
    usize entry; usize names; usize head; bool classic;
    bool outer_tracking; usize outer_kills; usize outer_generated; usize outer_required;
    usize generated;
}
pub struct State { usize depth; Frame[32] frames; usize[256] owners; usize[256] paths; bool[256] leaves; }
fn Frame empty_frame(){return Frame{.entry=128,.names=0,.head=0,.classic=false,.outer_tracking=false,
    .outer_kills=0,.outer_generated=0,.outer_required=0,.generated=0};}
pub fn State empty(){return State{.depth=0,.frames=[empty_frame();32],.owners=[0;256],.paths=[0;256],.leaves=[false;256]};}
fn errors::Error invalid(usize at){return errors::make(3,at);}
fn usize position(ref values::Program unit){let ref ir::Program body=ref unit.body;return body.count;}
// Branch-local scratch may end before its break/for-continue edge is resolved.
// Keep those escaping exits in the same bounded pool, compacting their indices;
// ancestor entries and ordinary branch exits below mark stay byte-identical.
pub fn Result<usize,errors::Error> release(ref mut vec::Vec<bindings::Snapshot> paths,
    ref mut State loops,usize mark,usize at){
    let usize count=branches::mark(paths);if(mark>count){return .err(invalid(at));}
    var usize write=mark;var usize read=mark;
    while(read<count){
        var bool retained=false;var usize pc=0;
        while(pc<256){if(loops.owners[pc]!=0 && loops.paths[pc]==read+1){retained=true;}pc+=1;}
        if(retained){
            if(write!=read){
                let bindings::Snapshot saved=bindings::snapshot(ref vec::at<bindings::Snapshot>(paths,read).state);
                let ref mut bindings::Snapshot target=vec::at_mut<bindings::Snapshot>(paths,write);target.state=saved.state;
            }
            pc=0;while(pc<256){if(loops.owners[pc]!=0 && loops.paths[pc]==read+1){loops.paths[pc]=write+1;}pc+=1;}
            write+=1;
        }read+=1;
    }
    return branches::release(paths,write,at);
}
pub fn Result<usize,errors::Error> begin(ref values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut State loops,usize head,bool classic,usize at){
    if(loops.depth>=32){return .err(errors::make(4,at));}
    let usize level=loops.depth;
    let usize names=state.names.count;
    let bool tracking=state.tracking;let usize kills=state.kills;
    let usize generated=state.generated;let usize required=state.required;
    state.tracking=true;state.kills=0;state.generated=0;state.required=0;
    let usize entry=branches::save(paths,state,at)?;
    loops.frames[level]=Frame{.entry=entry,.names=names,.head=head,.classic=classic,
        .outer_tracking=tracking,.outer_kills=kills,.outer_generated=generated,.outer_required=required,.generated=0};
    loops.depth+=1;return .ok(level);
}
fn Result<usize,errors::Error> clean(ref mut values::Program unit,ref mut bindings::State state,
    ref vec::Vec<bindings::Snapshot> paths,ref Frame frame,usize at){
    if(frame.entry>=branches::mark(paths)){return .err(invalid(at));}
    state.reads=vec::at<bindings::Snapshot>(paths,frame.entry).state.reads;
    state.writes=vec::at<bindings::Snapshot>(paths,frame.entry).state.writes;
    let usize named=bindings::leave_scope(unit,state,frame.names,at)?;
    let usize live=vec::at<bindings::Snapshot>(paths,frame.entry).state.live;
    let usize one=1;var usize id=state.next;
    while(id!=0){id-=1;if((state.live&(one<<id))!=0 && (live&(one<<id))==0){
        let usize dropped=bindings::drop(unit,state,id,at)?;
    }}return .ok(live);
}
pub fn Result<usize,errors::Error> repeat(ref mut values::Program unit,ref mut bindings::State state,
    ref vec::Vec<bindings::Snapshot> paths,ref mut State loops,usize at){
    if(loops.depth==0 || loops.depth>32){return .err(errors::make(2,at));}
    let usize level=loops.depth-1;let Frame frame=loops.frames[level];
    let usize expected=clean(unit,state,paths,ref frame,at)?;
    if(state.live!=expected){return .err(invalid(at));}
    loops.frames[level].generated|=state.generated;
    return ir::raw(ref mut unit.body,22,0,frame.head,0,at);
}
pub fn Result<usize,errors::Error> transfer(ref mut values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut State loops,bool leave,usize at){
    if(loops.depth==0 || loops.depth>32){return .err(errors::make(2,at));}
    let usize level=loops.depth-1;let Frame frame=loops.frames[level];
    if(!leave && !frame.classic){return repeat(unit,state,paths,loops,at);}
    let usize expected=clean(unit,state,paths,ref frame,at)?;
    if(!leave && state.live!=expected){return .err(invalid(at));}
    let usize saved=branches::save(paths,state,at)?;
    let usize pc=ir::raw(ref mut unit.body,19,0,0,0,at)?;
    loops.owners[pc]=level+1;loops.paths[pc]=saved+1;loops.leaves[pc]=leave;return .ok(pc);
}
// All for-continue edges preserve the header initialized set. Merge their Result
// summaries before emitting the one shared scalar post and backward transfer.
pub fn Result<bool,errors::Error> post(ref mut values::Program unit,ref mut bindings::State state,
    ref vec::Vec<bindings::Snapshot> paths,ref mut State loops,usize at){
    if(loops.depth==0 || loops.depth>32){return .err(invalid(at));}
    let usize target=position(unit);var bool any=false;var usize pc=0;
    while(pc<target){if(loops.owners[pc]==loops.depth && !loops.leaves[pc]){
        let usize saved=loops.paths[pc];if(saved==0 || saved>branches::mark(paths)){return .err(invalid(at));}
        if(!any){let usize selected=branches::select(unit,state,paths,saved-1,at)?;any=true;}
        else{let usize merged=bindings::merge(unit,state,vec::at<bindings::Snapshot>(paths,saved-1),at)?;}
        let usize patched=ir::patch(ref mut unit.body,pc,target,at)?;
        loops.owners[pc]=0;loops.paths[pc]=0;
    }pc+=1;}return .ok(any);
}
fn Result<usize,errors::Error> trim(ref mut values::Program unit,ref mut bindings::State state,usize common,usize at){
    let usize one=1;var usize id=state.next;
    while(id!=0){id-=1;if((state.live&(one<<id))!=0 && (common&(one<<id))==0){
        let usize dropped=bindings::drop(unit,state,id,at)?;
    }}return .ok(state.live);
}
// H = initial pending OR generated at any backedge. There are no cross-bit
// dependencies: every new Result evaluation generates its own obligation.
// Exit(p) = generated OR (p AND NOT kills), so this is the least fixed point.
pub fn Result<usize,errors::Error> finish(ref mut values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut State loops,usize condition,usize guard,usize at){
    if(loops.depth==0 || loops.depth>32 || condition>=branches::mark(paths)){return .err(invalid(at));}
    let usize level=loops.depth-1;let Frame frame=loops.frames[level];
    if(frame.entry>=branches::mark(paths)){return .err(invalid(at));}
    let usize pending=vec::at<bindings::Snapshot>(paths,frame.entry).state.pending|frame.generated;
    if((pending&state.required)!=0){return .err(errors::make(18,at));}
    let usize end=position(unit);var usize common=vec::at<bindings::Snapshot>(paths,condition).state.live;
    var usize pc=0;while(pc<end){if(loops.owners[pc]==loops.depth && loops.leaves[pc]){
        let usize path=loops.paths[pc];if(path==0 || path>branches::mark(paths)){return .err(invalid(at));}
        common&=vec::at<bindings::Snapshot>(paths,path-1).state.live;
    }pc+=1;}
    var usize[256] jumps=[256;256];var usize count=0;var usize merged=128;
    // The condition-false edge is always retained for zero-trip completeness.
    var usize path=condition;var usize jump=guard;pc=0;
    while(true){
        let usize selected=branches::select(unit,state,paths,path,at)?;
        state.pending=state.generated|(pending^(pending&state.kills));
        let usize target=position(unit);let usize patched=ir::patch(ref mut unit.body,jump,target,at)?;
        let usize cleaned=trim(unit,state,common,at)?;
        if(merged==128){merged=branches::save(paths,state,at)?;}
        else{let usize matched=bindings::merge(unit,state,vec::at<bindings::Snapshot>(paths,merged),at)?;
            // Keep the joined summary in its pool slot, outside recursive frames.
            let bindings::Snapshot snapshot=bindings::snapshot(state);
            let ref mut bindings::Snapshot stored=vec::at_mut<bindings::Snapshot>(paths,merged);stored.state=snapshot.state;
        }
        if(count>=256){return .err(errors::make(4,at));}
        jumps[count]=ir::raw(ref mut unit.body,19,0,0,0,at)?;count+=1;
        while(pc<end && (loops.owners[pc]!=loops.depth || !loops.leaves[pc])){pc+=1;}
        if(pc==end){break;}
        path=loops.paths[pc]-1;jump=pc;loops.owners[pc]=0;loops.paths[pc]=0;pc+=1;
    }
    let usize target=position(unit);var usize i=0;while(i<count){let usize patched=ir::patch(ref mut unit.body,jumps[i],target,at)?;i+=1;}
    let usize selected=branches::select(unit,state,paths,merged,at)?;
    let usize kills=state.kills;let usize generated=state.generated|(frame.generated^(frame.generated&kills));
    let usize required=state.required;
    if(frame.outer_tracking){
        state.kills=frame.outer_kills|kills;
        state.generated=generated|(frame.outer_generated^(frame.outer_generated&kills));
        state.required=frame.outer_required|(required^(required&frame.outer_kills));
    }else{state.tracking=false;state.kills=0;state.generated=0;state.required=0;}
    loops.depth-=1;return .ok(common);
}
