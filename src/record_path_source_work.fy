module record_path_source_work;
import struct_value_source as values;
import record_field_source_work as fields;
import record_leaf_source_work as leaves;
import lexer as lexer;
import lexer_work as tokens;
import source_context as context;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
// Mode 0 preserves path's unchecked ordinal accumulation; mode 1 preserves
// project()'s explicit 127 limit and its distinct leaf-count error offset.
pub struct State { fields::State field; leaves::State leaf; tokens::State scan;
    values::Leaf result; usize record; usize ordinal; usize depth; usize at; usize begin; usize end;
    usize selected; usize row; usize slot; u8 mode; u8 phase; u8 resume; bool waiting; bool look; bool done; }
fn State base(usize record,usize at){return State{.field=fields::begin(record,0,0),.leaf=leaves::begin(0,at),
    .scan=tokens::begin(lexer::empty()),.result=values::Leaf{.ordinal=0,.tag=0,.record=record},
    .record=record,.ordinal=0,.depth=0,.at=at,.begin=0,.end=0,.selected=0,.row=0,.slot=0,
    .mode=0,.phase=0,.resume=0,.waiting=false,.look=false,.done=false};}
pub fn State begin_path(usize root,usize at){return base(root,at);}
pub fn State begin_project(values::Leaf parent,usize begin,usize end){var State w=base(parent.record,begin);
    w.mode=1;w.ordinal=parent.ordinal;w.result=parent;w.begin=begin;w.end=end;return w;}
pub fn Result<values::Leaf,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);}
fn void next(ref mut State w,ref lexer::State s,u8 phase,bool look){w.scan=tokens::begin(*s);w.resume=phase;w.look=look;w.waiting=true;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref ir::Program p,
    ref context::Table scope,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.scan,meter)){
        case .err(e):{if(!w.look){*s=tokens::observed(ref w.scan);}return .err(e);}
        case .ok(done):{if(done){let lexer::State found=tokens::prepared(ref w.scan)?;
            if(w.look){if(found.kind!=46){return .err(errors::make(2,s.begin));}w.done=true;}
            else{*s=found;w.phase=w.resume;}w.waiting=false;}return .ok(w.done);}};}
    if(w.phase==2){let bool done=fields::advance(source,p,scope,ref mut w.field,meter)?;
        if(done){w.selected=fields::prepared(ref w.field)?;w.row=0;w.phase=3;}return .ok(false);}
    if(w.phase==4){let bool done=leaves::advance(p,ref mut w.leaf,meter)?;
        if(done){let usize count=leaves::prepared(ref w.leaf)?;
            if(w.mode==1 && count>127-w.ordinal){return .err(errors::make(3,w.begin));}
            w.ordinal+=count;w.row+=1;w.phase=3;}return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.phase==0){if(w.mode==1){if(w.result.tag!=0 || w.ordinal>=128 || w.begin>=w.end || w.end>source.len || w.record>=p.records.layouts.count){return .err(errors::make(3,w.begin));}
            w.field=fields::begin(w.record,w.begin,w.end);w.phase=2;return .ok(false);}
        if(s.kind!=46){w.result=values::Leaf{.ordinal=w.ordinal,.tag=0,.record=w.record};w.done=true;return .ok(true);}
        if(w.depth>=16){return .err(errors::make(4,s.begin));}w.depth+=1;next(w,s,1,false);return .ok(false);}
    if(w.phase==1){if(s.kind!=2){return .err(errors::make(2,s.begin));}
        w.field=fields::begin(w.record,s.begin,s.end);w.phase=2;return .ok(false);}
    if(w.phase==3){if(w.row<w.selected){let usize slot=w.record*16+w.row;
            if(p.records.layouts.kinds[slot]==0){if(w.mode==1 && 1>127-w.ordinal){return .err(errors::make(3,w.begin));}w.ordinal+=1;w.row+=1;}
            else{w.leaf=leaves::begin(p.records.layouts.types[slot] as usize,w.at);w.phase=4;}return .ok(false);}
        w.slot=w.record*16+w.selected;
        if(w.mode==1){let bool scalar=p.records.layouts.kinds[w.slot]==0;
            w.result=values::Leaf{.ordinal=w.ordinal,.tag=if(scalar){p.records.layouts.types[w.slot]}else{0},
                .record=if(scalar){w.record}else{p.records.layouts.types[w.slot] as usize}};w.done=true;return .ok(true);}
        next(w,s,5,false);return .ok(false);}
    if(w.phase==5){if(p.records.layouts.kinds[w.slot]==0){w.result=values::Leaf{.ordinal=w.ordinal,.tag=p.records.layouts.types[w.slot],.record=w.record};
            if(s.kind==46){next(w,s,0,true);return .ok(false);}w.done=true;return .ok(true);}
        w.record=p.records.layouts.types[w.slot] as usize;w.phase=0;return .ok(false);}
    return .err(errors::make(5,w.at));
}
