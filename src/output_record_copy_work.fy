module output_record_copy_work;
import ir as ir;
import copy_ir as copying;
import aggregate_copy as windows;
import struct_layout as layouts;
import output_record_range_work as ranges;
import errors as errors;
import metadata_budget as budget;

// Compose only with the completed plan for this exact immutable catalog. The
// canonical metadata pass proves that plan before any copy instruction. Reusing
// it avoids replanning inside a CFG PC; both nominal walks remain resumable.
pub struct Arguments {
    usize destination; usize source; usize destination_function; usize source_function;
    bool fresh; bool same_frame; bool subtree; usize nominal;
    usize destination_leaf; usize source_leaf; usize pc;
}
pub struct Plan { usize destination; usize source; usize bytes; usize destination_offset; usize source_offset; u8 relation; bool fresh; bool same_frame; }
pub struct State {
    Arguments args; ranges::State range; Plan output;
    usize target; usize origin; usize selected; usize to; usize from;
    u8 phase; bool active; bool done;
}
pub fn State empty(){return State{
    .args=Arguments{.destination=0,.source=0,.destination_function=0,.source_function=0,.fresh=false,.same_frame=false,
        .subtree=false,.nominal=0,.destination_leaf=0,.source_leaf=0,.pc=0},
    .range=ranges::empty(),.output=Plan{.relation=0,
        .destination=0,.source=0,.bytes=0,.destination_offset=0,.source_offset=0,.fresh=false,.same_frame=false},
    .target=0,.origin=0,.selected=0,.to=0,.from=0,.phase=0,.active=false,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<usize,errors::Error> begin(ref mut State w,Arguments args){
    if(w.active){return .err(invalid(args.pc));}
    w.args=args;w.target=0;w.origin=0;w.selected=0;w.to=0;w.from=0;w.phase=0;w.active=true;w.done=false;
    return .ok(0);
}
fn Result<bool,errors::Error> walk(ref ir::Program p,ref layouts::Plan plan,ref mut State w,ref mut budget::State meter){
    let bool finished=switch(ranges::advance(ref mut w.range,ref p.records.layouts,plan,meter)){
        case .ok(v):{v}case .err(_):{w.active=false;return .err(invalid(w.args.pc));}
    };
    if(!finished){return .ok(false);}
    if(w.phase==1){
        let usize value=w.range.output;w.to=value;
        let usize origin=w.origin;let usize selected=w.selected;let usize ordinal=w.args.source_leaf;
        let usize started=ranges::begin_offset(ref mut w.range,origin,selected,ordinal)?;w.phase=2;
    }else{let usize value=w.range.output;w.from=value;w.phase=3;}
    return .ok(false);
}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref layouts::Plan plan,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(!w.active || w.phase>3){return .err(invalid(w.args.pc));}
    if(w.phase==1 || w.phase==2){return walk(p,plan,w,meter);}
    let Arguments a=w.args;
    if(!budget::admit(meter,4096,a.pc)?){return .ok(false);}
    if(w.phase==0){
        if(p.records.count>16 || a.destination>=p.records.count || a.source>=p.records.count ||
            p.record_functions[a.destination] as usize!=a.destination_function ||
            p.record_functions[a.source] as usize!=a.source_function || (!a.fresh && !p.records.mutable[a.destination])){
            w.active=false;return .err(invalid(a.pc));
        }
        let usize target=p.records.records[a.destination] as usize;let usize origin=p.records.records[a.source] as usize;
        let usize selected=if(a.subtree){a.nominal}else{target};
        if(target>=plan.count || origin>=plan.count || selected>=plan.count ||
            plan.bytes[target]>128 || plan.bytes[origin]>128 || plan.bytes[selected]>128 || (!a.subtree && target!=origin)){
            w.active=false;return .err(invalid(a.pc));
        }
        w.target=target;w.origin=origin;w.selected=selected;
        let usize started=ranges::begin_offset(ref mut w.range,target,selected,a.destination_leaf)?;w.phase=1;
        return .ok(false);
    }
    let usize size=plan.bytes[w.selected];var windows::Relation relation=.Disjoint;
    if(a.same_frame && !a.fresh && a.destination==a.source){
        relation=switch(windows::relation(w.to,w.from,size,plan.bytes[w.target])){
            case .ok(v):{v}case .err(_):{w.active=false;return .err(invalid(a.pc));}
        };
    }
    let usize to=w.to;let usize from=w.from;
    let u8 relation_code=switch(relation){case .Disjoint:{0}case .Identical:{1}case .Overlap:{2}};
    w.output=Plan{.relation=relation_code,
        .destination=a.destination,.source=a.source,.bytes=size,.destination_offset=to,.source_offset=from,
        .fresh=a.fresh,.same_frame=a.same_frame};
    w.active=false;w.done=true;return .ok(true);
}

// Reconstruct enum-bearing output only after completion. Invocation state stays
// a plain graph so Fairy C can borrow its nested mutable continuation fields.
pub fn Result<copying::Plan,errors::Error> prepared(ref State w){
    if(!w.done || w.active){return .err(invalid(w.args.pc));}
    let ref Plan p=ref w.output;
    let windows::Relation relation=if(p.relation==0){.Disjoint}else if(p.relation==1){.Identical}else{.Overlap};
    return .ok(copying::Plan{.domain=.Record,.mode=.Snapshot,.relation=relation,.destination=p.destination,.source=p.source,
        .bytes=p.bytes,.destination_offset=p.destination_offset,.source_offset=p.source_offset,.fresh=p.fresh,.same_frame=p.same_frame});
}
