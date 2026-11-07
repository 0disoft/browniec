module value_source_loops;
import value_source_bindings as bindings;
import value_source_control as branches;
import value_ir as values;
import ir as ir;
import errors as errors;
import std::vec as vec;
import value_view_bindings as views;

// Compiler metadata only. Snapshot indices never restore native owner authority.
pub struct Frame {
    usize entry; usize names; usize head; bool classic;
    bool outer_tracking; usize outer_kills; usize outer_generated; usize outer_required;
    usize generated; usize outer_roots;
}
pub struct State { usize depth; Frame[32] frames; usize[256] owners; usize[256] paths; bool[256] leaves; }
fn Frame empty_frame(){return Frame{.entry=128,.names=0,.head=0,.classic=false,.outer_tracking=false,
    .outer_kills=0,.outer_generated=0,.outer_required=0,.generated=0,.outer_roots=0};}
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
    let usize authenticated=bindings::authenticate(unit,state,at)?;
    if(loops.depth>=32){return .err(errors::make(4,at));}
    let usize level=loops.depth;
    let usize names=state.names.count;
    let bool tracking=state.tracking;let usize kills=state.kills;
    let usize generated=state.generated;let usize required=state.required;
    let usize outer_roots=state.loop_roots;
    if(views::count(ref state.views)!=0){let usize protected=bindings::protect_loop_roots(unit,state,at)?;}
    state.tracking=true;state.kills=0;state.generated=0;state.required=0;
    let usize entry=branches::save(paths,state,at)?;
    loops.frames[level]=Frame{.entry=entry,.names=names,.head=head,.classic=classic,
        .outer_tracking=tracking,.outer_kills=kills,.outer_generated=generated,.outer_required=required,.generated=0,.outer_roots=outer_roots};
    loops.depth+=1;return .ok(level);
}
fn Result<usize,errors::Error> clean(ref mut values::Program unit,ref mut bindings::State state,
    ref vec::Vec<bindings::Snapshot> paths,ref Frame frame,usize at){
    let usize authenticated=bindings::authenticate(unit,state,at)?;
    if(frame.entry>=branches::mark(paths)){return .err(invalid(at));}
    state.reads=vec::at<bindings::Snapshot>(paths,frame.entry).state.reads;
    state.writes=vec::at<bindings::Snapshot>(paths,frame.entry).state.writes;
    let views::State baseline=views::loop_baseline(ref state.views,
        ref vec::at<bindings::Snapshot>(paths,frame.entry).state.views,at)?;
    // An endpoint can leave while its anonymous receiver still pins a local root.
    // Release those captures before lexical cleanup attempts to DROP that root.
    let usize closed=bindings::close_views_since(unit,state,ref baseline,at)?;
    let usize named=bindings::leave_scope(unit,state,frame.names,at)?;
    if(!views::same(ref state.views,ref baseline)){return .err(invalid(at));}
    let usize live=vec::at<bindings::Snapshot>(paths,frame.entry).state.live;
    let usize maybe=vec::at<bindings::Snapshot>(paths,frame.entry).state.maybe;
    let usize one=1;var usize id=state.next;
    while(id!=0){id-=1;if(((state.live|state.maybe)&(one<<id))!=0 && ((live|maybe)&(one<<id))==0){
        let usize dropped=bindings::drop(unit,state,id,at)?;
    }}return .ok(live);
}
// Backedges preserve the exact initialization lattice, including possible-only
// roots inherited from an enclosing conditional expression.
fn bool same_loop(ref bindings::State state,ref bindings::Snapshot entry){
    return state.live==entry.state.live && state.maybe==entry.state.maybe && state.loop_roots==entry.state.loop_roots;
}
pub fn Result<usize,errors::Error> repeat(ref mut values::Program unit,ref mut bindings::State state,
    ref vec::Vec<bindings::Snapshot> paths,ref mut State loops,usize at){
    if(loops.depth==0 || loops.depth>32){return .err(errors::make(2,at));}
    let usize level=loops.depth-1;let Frame frame=loops.frames[level];
    let usize expected=clean(unit,state,paths,ref frame,at)?;
    if(!same_loop(state,vec::at<bindings::Snapshot>(paths,frame.entry))){return .err(invalid(at));}
    loops.frames[level].generated|=state.generated;
    return ir::raw(ref mut unit.body,22,0,frame.head,0,at);
}
pub fn Result<usize,errors::Error> transfer(ref mut values::Program unit,ref mut bindings::State state,
    ref mut vec::Vec<bindings::Snapshot> paths,ref mut State loops,bool leave,usize at){
    if(loops.depth==0 || loops.depth>32){return .err(errors::make(2,at));}
    let usize level=loops.depth-1;let Frame frame=loops.frames[level];
    if(!leave && !frame.classic){return repeat(unit,state,paths,loops,at);}
    let usize expected=clean(unit,state,paths,ref frame,at)?;
    if(!leave && (!same_loop(state,vec::at<bindings::Snapshot>(paths,frame.entry)))){return .err(invalid(at));}
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
// Source-loop inference over already emitted IR, before exit trampolines are
// lowered. No source/body replay, slot rewind or executable effect occurs here.
// Both planes only gain bits: missing retention records an unretained occurrence
// on ANY path containing that origin. This is the per-origin retention meet.
// Keep the bounded PC table on the compiler heap, off recursive parser frames.
struct Origins { usize[16] roots; usize[16] unretained; }
fn Origins no_origins(){return Origins{.roots=[0;16],.unretained=[0;16]};}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn Result<usize,errors::Error> origin_edge(ref mut vec::Vec<Origins> states,
    ref mut bool[] seen,ref mut bool[] pending,usize head,usize end,usize target,
    ref Origins incoming,usize at){
    if(target<head || target>=end){return .err(invalid(at));}
    let ref Origins prior=vec::at<Origins>(states,target-head);var usize i=0;
    while(i<16){if(seen[target] && (prior.roots[i]==0)!=(incoming.roots[i]==0)){
        return .err(invalid(at));}i+=1;}
    var bool changed=!seen[target];let ref mut Origins joined=vec::at_mut<Origins>(states,target-head);
    i=0;while(i<16){
        let usize roots=joined.roots[i]|incoming.roots[i];
        let usize missing=joined.unretained[i]|incoming.unretained[i];
        if(roots!=joined.roots[i] || missing!=joined.unretained[i]){changed=true;}
        joined.roots[i]=roots;joined.unretained[i]=missing;i+=1;
    }
    seen[target]=true;if(changed){pending[target]=true;}return .ok(target);
}
fn Result<usize,errors::Error> view_transfer(ref values::Program unit,ref mut Origins row,usize pc,usize at){
    let ref ir::Program p=ref unit.body;let usize offset=pc*8;let u8 op=p.code[offset];
    let usize dst=p.code[offset+1] as usize;let usize a=p.code[offset+2] as usize;
    let usize map=p.code[offset+3] as usize;
    if(op==105 || op==106 || op==107 || op==108 || op==114){
        if(dst>=16 || row.roots[dst]!=0){return .err(invalid(at));}
        if(op==105){if(a>=16){return .err(invalid(at));}
            row.roots[dst]=bit(a);row.unretained[dst]=bit(a);
        }else{
            var usize source=a;
            if(op==114){
                if(a>=p.function_count || map>=p.call_count || unit.results[a]<17 || unit.results[a]>24){
                    return .err(invalid(at));}
                let usize selected=(unit.results[a] as usize)-17;
                if(selected>=p.call_arities[map] as usize){return .err(invalid(at));}
                let usize actual=p.call_args[map*8+selected] as usize;
                if(actual<224 || actual>=240){return .err(invalid(at));}source=actual-224;
            }
            if(source>=16 || row.roots[source]==0){return .err(invalid(at));}
            let usize roots=row.roots[source];let usize missing=if(op==114){0}else{row.unretained[source]};
            row.roots[dst]=roots;row.unretained[dst]=missing;
            if(op==108){row.roots[source]=0;row.unretained[source]=0;}
        }
    }else if(op==109){
        if(dst>=16 || row.roots[dst]==0){return .err(invalid(at));}
        row.roots[dst]=0;row.unretained[dst]=0;
    }else if(op==110 || op==111 || op==113){
        if(a>=16 || row.roots[a]==0){return .err(invalid(at));}
    }
    return .ok(pc);
}
fn Result<usize,errors::Error> unpinned(ref Origins row,usize owner,usize at){
    if(owner>=16){return .err(invalid(at));}var usize i=0;
    while(i<16){if((row.roots[i]&bit(owner))!=0){return .err(invalid(at));}i+=1;}return .ok(owner);
}
// Recheck EVERY earlier write/move/drop against the converged origins, including
// implicit source cleanup emitted before widening. Native/independent admission
// is still mandatory; this source audit cannot turn an unsafe candidate into IR.
fn Result<usize,errors::Error> audit(ref values::Program unit,ref Origins row,usize pc,usize at){
    let ref ir::Program p=ref unit.body;let usize offset=pc*8;let u8 op=p.code[offset];
    let usize dst=p.code[offset+1] as usize;let usize a=p.code[offset+2] as usize;
    let usize b=p.code[offset+3] as usize;
    if(op==88 || op==89 || op==90 || op==115 || op==101 || op==102 || op==103 || op==104 || op==112 || op==91 || op==92){
        let usize owner=if(op==90 || op==115 || op==101){dst}else{a};
        let usize checked=unpinned(row,owner,at)?;
    }
    if(op==9 || op==93 || op==114){
        if(b>=p.call_count || p.call_arities[b]>8){return .err(invalid(at));}var usize i=0;
        while(i<p.call_arities[b] as usize){let usize actual=p.call_args[b*8+i] as usize;
            if(actual>=208 && actual<224){let usize checked=unpinned(row,actual-208,at)?;}
            else if(actual>=224 && actual<240 && row.roots[actual-224]==0){return .err(invalid(at));}i+=1;
        }
    }
    if(op==8 || op==39 || op==50 || op==82 || op==94 || op==113){
        var usize keep=16;
        if(op==113){
            if(a>=16){return .err(invalid(at));}
            // The caller checks the exact selected formal using the authenticated
            // entry function; later function starts are not installed yet.
            keep=a;
        }
        var usize i=0;while(i<16){if(i!=keep && row.roots[i]!=0){return .err(invalid(at));}i+=1;}
    }
    return .ok(pc);
}
fn Result<usize,errors::Error> infer_exit(ref values::Program unit,ref mut bindings::Snapshot path,
    ref Origins row,usize at){
    let usize inferred=views::inferred(ref mut path.state.views,ref row.roots,ref row.unretained,at)?;
    let usize checked=views::authenticate(unit,ref path.state.views,at)?;
    var usize i=0;while(i<16){let usize roots=views::local_roots(ref path.state.views,i);
        if((roots&(path.state.live|path.state.maybe))!=roots){return .err(invalid(at));}i+=1;
    }return .ok(inferred);
}
pub fn Result<usize,errors::Error> infer(ref values::Program unit,
    ref mut vec::Vec<bindings::Snapshot> paths,ref State loops,usize condition,usize guard,usize at){
    if(loops.depth==0 || loops.depth>32 || condition>=branches::mark(paths)){return .err(invalid(at));}
    let Frame frame=loops.frames[loops.depth-1];let usize head=frame.head;let usize end=position(unit);
    if(frame.entry>=branches::mark(paths) || head>=end || end>256 || guard<head || guard>=end ||
        unit.body.function_count>16 || unit.body.call_count>32 || unit.body.code[guard*8]!=20){return .err(invalid(at));}
    let ref views::State entry=ref vec::at<bindings::Snapshot>(paths,frame.entry).state.views;
    let usize authenticated=views::authenticate(unit,entry,at)?;
    // No header descriptor can evolve when all are Dead. Ordinary lexical view
    // cleanup already prevents body-local descriptors from escaping that shape.
    if(views::count(entry)==0){return .ok(0);}
    var vec::Vec<Origins> states=vec::empty<Origins>();
    if(!vec::reserve<Origins>(ref mut states,end-head).is_ok){return .err(errors::make(15,at));}
    var usize pc=head;while(pc<end){if(!vec::push<Origins>(ref mut states,no_origins()).is_ok){
        return .err(errors::make(15,at));}pc+=1;}
    var Origins seed=no_origins();var usize i=0;while(i<16){if(views::live(entry,i)){
        let usize roots=views::roots(entry,i,at)?;let usize missing=roots^views::retained_roots(entry,i);
        seed.roots[i]=roots;seed.unretained[i]=missing;
    }i+=1;}
    var bool[256] seen=[false;256];var bool[256] pending=[false;256];
    let usize started=origin_edge(ref mut states,ref mut seen,ref mut pending,head,end,head,ref seed,at)?;
    var bool again=true;var usize steps=0;
    while(again){again=false;pc=head;while(pc<end){
        if(!pending[pc]){pc+=1;continue;}pending[pc]=false;again=true;steps+=1;
        if(steps>196864){return .err(errors::make(4,at));} // 256*(1+2*16*24)
        let ref Origins input=vec::at<Origins>(ref states,pc-head);
        var Origins row=Origins{.roots=input.roots,.unretained=input.unretained};
        let usize transferred=view_transfer(unit,ref mut row,pc,at)?;
        let usize offset=pc*8;let u8 op=unit.body.code[offset];
        if((loops.owners[pc]==loops.depth && loops.leaves[pc]) ||
            op==8 || op==39 || op==50 || op==82 || op==94 || op==113 || op==25){pc+=1;continue;}
        if(op==19 || op==20 || op==21 || op==22 || op==24 || op==92){
            if(pc!=guard){
                let usize target=if(op==19 || op==22){unit.body.code[offset+2] as usize}
                    else if(op==24 || op==92){unit.body.code[offset+4] as usize}
                    else{unit.body.code[offset+3] as usize};
                let usize merged=origin_edge(ref mut states,ref mut seen,ref mut pending,head,end,target,ref row,at)?;
            }
            if(op==19 || op==22){pc+=1;continue;}
        }
        let usize merged=origin_edge(ref mut states,ref mut seen,ref mut pending,head,end,pc+1,ref row,at)?;pc+=1;
    }}
    // Audit only after convergence. A later backedge must not make an earlier
    // mutation or compiler-generated anonymous seed DROP silently admissible.
    pc=head;while(pc<end){if(seen[pc]){
        let ref Origins row=vec::at<Origins>(ref states,pc-head);
        let usize checked=audit(unit,row,pc,unit.body.offsets[pc])?;
        if(unit.body.code[pc*8]==113){let usize selected=unit.results[entry.function] as usize;
            let usize source=unit.body.code[pc*8+2] as usize;
            if(selected<17 || selected>24 || row.roots[source]!=bit(selected-1)){return .err(invalid(at));}}
    }pc+=1;}
    if(!seen[guard]){return .err(invalid(at));}
    let usize inferred=infer_exit(unit,vec::at_mut<bindings::Snapshot>(paths,condition),
        vec::at<Origins>(ref states,guard-head),at)?;
    pc=head;while(pc<end){if(loops.owners[pc]==loops.depth && loops.leaves[pc]){
        let usize path=loops.paths[pc];
        if(!seen[pc] || path==0 || path>branches::mark(paths)){return .err(invalid(at));}
        let usize inferred=infer_exit(unit,vec::at_mut<bindings::Snapshot>(paths,path-1),
            vec::at<Origins>(ref states,pc-head),at)?;
    }pc+=1;}return .ok(steps);
}
fn Result<usize,errors::Error> trim(ref mut values::Program unit,ref mut bindings::State state,usize common,usize at){
    var usize kept=common|state.loop_roots;var usize view=0;while(view<16){kept|=views::local_roots(ref state.views,view);view+=1;}
    let usize one=1;var usize id=state.next;
    while(id!=0){id-=1;if(((state.live|state.maybe)&(one<<id))!=0 && (kept&(one<<id))==0){
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
        let usize released=bindings::release_loop_roots(unit,state,frame.outer_roots,at)?;
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
