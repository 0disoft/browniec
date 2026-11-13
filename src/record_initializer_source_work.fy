module record_initializer_source_work;
import struct_value_source as values;
import record_field_source_work as fields;
import record_location_work as location;
import lexer_work as tokens;
import lexer as lexer;
import ir as ir;
import source_context as context;
import errors as errors;
import metadata_budget as budget;
// The initializer and cursor are caller-owned: every mutation happens at the
// same point as next_leaf_raw/advance_raw, including failed punctuation.
pub struct State { fields::State field; location::State name; tokens::State scan;
    lexer::State member; lexer::State peek; usize at; usize record; usize selected; usize child;
    usize level; u8 phase; u8 resume; u8 result; bool short; bool waiting; bool look; bool only_advance; bool done; }
fn State base(usize at,bool only){return State{.field=fields::begin(0,0,0),.name=location::begin(0,0,32),
    .scan=tokens::begin(lexer::empty()),.member=lexer::empty(),.peek=lexer::empty(),.at=at,.record=0,.selected=0,
    .child=0,.level=0,.phase=if(only){20}else{0},.resume=0,.result=0,.short=false,.waiting=false,.look=false,.only_advance=only,.done=false};}
pub fn State begin_next(usize at){return base(at,false);}
pub fn State begin_advance(){return base(0,true);}
pub fn Result<u8,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);}
fn void next(ref mut State w,ref lexer::State s,u8 resume,bool look){w.scan=tokens::begin(*s);w.resume=resume;w.look=look;w.waiting=true;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref ir::Program p,ref mut values::Initializer init,
    ref context::Table scope,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.scan,meter)){
        case .err(e):{if(!w.look){*s=tokens::observed(ref w.scan);}return .err(e);}
        case .ok(done):{if(done){let lexer::State token=tokens::prepared(ref w.scan)?;
            if(w.look){w.peek=token;}else{*s=token;}w.waiting=false;w.phase=w.resume;}return .ok(false);}};}
    if(w.phase==4){let bool done=fields::advance(source,p,scope,ref mut w.field,meter)?;
        if(done){let usize found=fields::prepared(ref w.field)?;if(s.kind!=2 || found!=w.selected){return .err(errors::make(3,s.begin));}
            w.member=*s;next(w,s,5,false);}return .ok(false);}
    if(w.phase==11 || w.phase==14){let bool done=location::advance(source,scope,ref mut w.name,meter)?;
        if(done){let usize found=w.name.record;if(w.phase==11 && found!=w.child){w.result=255;w.done=true;return .ok(true);}
            if(w.phase==14 && found!=w.child){return .err(errors::make(3,s.begin));}
            if(w.phase==11){w.phase=12;}else{next(w,s,15,false);}}return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.phase==20){init.is_shorthand=false;init.shorthand=lexer::empty();
        let usize level=init.depth-1;init.fields[level]+=1;
        if(init.fields[level]<p.records.layouts.fields[init.records[level]] as usize){
            if(s.kind!=44){return .err(errors::make(2,s.begin));}next(w,s,21,false);return .ok(false);}
        w.phase=21;return .ok(false);}
    if(w.phase==21){if(w.only_advance){w.done=true;return .ok(true);}w.phase=0;return .ok(false);}
    if(w.phase==0){if(init.depth==0){w.result=0;w.done=true;return .ok(true);}
        w.level=init.depth-1;w.record=init.records[w.level];w.selected=init.fields[w.level];
        if(w.selected>=p.records.layouts.fields[w.record] as usize){if(s.kind==44){next(w,s,1,false);}else{w.phase=1;}return .ok(false);}
        if(s.kind!=46){return .err(errors::make(2,s.begin));}next(w,s,3,false);return .ok(false);}
    if(w.phase==1){if(s.kind!=125){return .err(errors::make(2,s.begin));}next(w,s,2,false);return .ok(false);}
    if(w.phase==2){init.depth-=1;if(init.depth>0){w.phase=20;}else{w.phase=0;}return .ok(false);}
    if(w.phase==3){w.field=fields::begin(w.record,s.begin,s.end);w.phase=4;return .ok(false);}
    if(w.phase==5){w.short=false;if(s.kind==61){next(w,s,6,false);}else if(s.kind==44 || s.kind==125){w.short=true;w.phase=6;}
        else{return .err(errors::make(2,s.begin));}return .ok(false);}
    if(w.phase==6){let usize slot=w.record*16+w.selected;if(p.records.layouts.kinds[slot]==0){init.shorthand=w.member;init.is_shorthand=w.short;
            w.result=p.records.layouts.types[slot];w.done=true;return .ok(true);}
        w.child=p.records.layouts.types[slot] as usize;
        if(w.short){init.shorthand=w.member;init.is_shorthand=true;w.result=255;w.done=true;return .ok(true);}
        if(s.kind==40){w.result=255;w.done=true;return .ok(true);}
        if(s.kind==2 || s.kind==5){next(w,s,10,true);return .ok(false);}w.phase=12;return .ok(false);}
    if(w.phase==10){if(w.peek.kind==123){w.name=location::begin(s.begin,s.end,32);w.phase=11;}else{w.phase=12;}return .ok(false);}
    if(w.phase==12){if(s.kind!=2 && s.kind!=5){return .err(errors::make(3,s.begin));}next(w,s,13,true);return .ok(false);}
    if(w.phase==13){if(w.peek.kind!=123){w.result=255;w.done=true;return .ok(true);}
        w.name=location::begin(s.begin,s.end,32);w.phase=14;return .ok(false);}
    if(w.phase==15){if(s.kind!=123){return .err(errors::make(2,s.begin));}next(w,s,16,false);return .ok(false);}
    if(w.phase==16){if(init.depth>=16){return .err(errors::make(4,w.at));}
        let usize depth=init.depth;init.records[depth]=w.child;init.fields[depth]=0;init.depth+=1;w.phase=0;return .ok(false);}
    return .err(errors::make(5,w.at));
}
