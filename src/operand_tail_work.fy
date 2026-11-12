module operand_tail_work;
import lexer as lexer;
import lexer_work as tokens;
import type_parse_work as annotations;
import ir as ir;
import types as types;
import locals as locals;
import array_source as arrays;
import errors as errors;
import metadata_budget as budget;
// One active tail in separately pinned scratch. Parents cannot resume until the
// child tail completes; no per-expression-frame lexer/type state is required.
pub struct State { tokens::State scan; annotations::State annotation;
    usize value; usize at; usize slot; usize branch; usize skip; usize temporary;
    usize payload; usize failure; usize row; usize pending; usize visits;
    u8 phase; u8 next; u8 scanning; u8 tag; u8 result_type; bool primary; bool typing; bool done; }
pub fn State begin(lexer::State token,usize value,u8 result_type,bool primary){
    return State{.scan=tokens::begin(token),.annotation=annotations::begin(token),
        .value=value,.at=0,.slot=0,.branch=0,.skip=0,.temporary=0,.payload=0,.failure=0,.row=0,.pending=0,.visits=0,
        .phase=0,.next=0,.scanning=0,.tag=0,.result_type=result_type,.primary=primary,.typing=false,.done=false};
}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
fn void take(ref mut State w,lexer::State token,u8 phase){w.scan=tokens::begin(token);w.scanning=1;w.next=phase;}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] spelling){return s.kind==2 && lexer::equal(source[s.begin..s.end],spelling);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table names,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.scanning!=0){switch(tokens::advance(source,ref mut w.scan,meter)){
        case .err(e):{if(w.scanning==1){*s=tokens::observed(ref w.scan);}return .err(e);}
        case .ok(done):{if(done){let lexer::State token=tokens::prepared(ref w.scan)?;
            if(w.scanning==2 && token.kind==46){w.phase=10;}else{*s=token;w.phase=w.next;}
            w.scanning=0;}return .ok(false);}};}
    if(w.typing){switch(annotations::advance(source,ref mut w.annotation,meter)){
        case .err(e):{*s=annotations::observed(ref w.annotation);return .err(e);}
        case .ok(done):{*s=annotations::observed(ref w.annotation);if(done){w.tag=annotations::prepared(ref w.annotation)?;w.typing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}w.visits+=1;
    let u8 phase=w.phase;let usize value=w.value;let usize at=w.at;
    if(phase==0){if(s.kind==46){w.at=s.begin;w.scan=tokens::begin(*s);w.scanning=2;w.next=2;}
        else if(s.kind==63){w.at=s.begin;take(w,*s,30);}else{w.phase=10;}return .ok(false);}
    if(phase==2){if(!word(source,s,b"is_ok")){return .err(errors::make(3,at));}take(w,*s,3);return .ok(false);}
    if(phase==3){if(value>=128 || p.types[value]<5 || p.types[value]>8){return .err(errors::make(3,at));}w.phase=20;return .ok(false);}
    if(phase==10){if(!w.primary && word(source,s,b"as")){w.at=s.begin;take(w,*s,11);return .ok(false);}w.done=true;return .ok(true);}
    if(phase==11){w.annotation=annotations::begin(*s);w.typing=true;w.phase=12;return .ok(false);}
    if(phase==12){if(!types::widening(p.types[value],w.tag)){return .err(errors::make(3,at));}w.phase=13;return .ok(false);}
    if(phase==13){w.value=ir::widen(p,value,w.tag,at)?;w.phase=10;return .ok(false);}
    if(phase==20){w.slot=ir::slot(p,2,at)?;w.phase=21;return .ok(false);}
    if(phase==21){let ir::Case branch=ir::branch_case(p,value,1,at)?;w.branch=branch.instruction;w.phase=22;return .ok(false);}
    if(phase==22){w.temporary=ir::boolean(p,true,at)?;w.phase=23;return .ok(false);}
    if(phase==23){let usize stored=ir::raw(p,18,w.slot,w.temporary,0,at)?;w.phase=24;return .ok(false);}
    if(phase==24){w.skip=ir::raw(p,19,0,0,0,at)?;w.phase=25;return .ok(false);}
    if(phase==25){let usize target=p.count;let usize patched=ir::patch(p,w.branch,target,at)?;w.phase=26;return .ok(false);}
    if(phase==26){w.temporary=ir::boolean(p,false,at)?;w.phase=27;return .ok(false);}
    if(phase==27){let usize stored=ir::raw(p,18,w.slot,w.temporary,0,at)?;w.phase=28;return .ok(false);}
    if(phase==28){let usize target=p.count;let usize patched=ir::patch(p,w.skip,target,at)?;w.phase=29;return .ok(false);}
    if(phase==29){w.value=ir::emit(p,17,w.slot,0,at)?;w.phase=0;return .ok(false);}
    if(phase==30){let u8 tag=p.types[value];let u8 result=w.result_type;
        let bool option=tag>=3 && tag<=4 && result>=3 && result<=4;
        let bool compatible=tag>=5 && tag<=8 && result>=5 && result<=8 && types::payload(tag,0)==types::payload(result,0);
        if(!option && !compatible){return .err(errors::make(3,at));}w.phase=31;return .ok(false);}
    if(phase==31){let ir::Case success=ir::branch_case(p,value,1,at)?;w.branch=success.instruction;w.payload=success.payload;w.phase=32;return .ok(false);}
    if(phase==32){w.skip=ir::raw(p,19,0,0,0,at)?;w.phase=33;return .ok(false);}
    if(phase==33){let usize target=p.count;let usize patched=ir::patch(p,w.branch,target,at)?;w.phase=34;return .ok(false);}
    if(phase==34){let ir::Case failure=ir::branch_case(p,value,0,at)?;w.failure=failure.instruction;w.temporary=failure.payload;w.phase=35;return .ok(false);}
    if(phase==35){w.temporary=ir::construct(p,w.result_type,0,w.temporary,at)?;w.phase=36;return .ok(false);}
    if(phase==36){if(names.pending_places>65535){return .err(errors::make(3,at));}w.pending=names.pending_places;w.row=16;w.phase=37;return .ok(false);}
    if(phase==37){if(w.row==0){w.row=names.count;w.phase=38;return .ok(false);}let usize row=w.row-1;let usize one=1;
        if((w.pending&(one<<row))!=0){let usize ended=ir::place_end(p,row,at)?;}w.row=row;return .ok(false);}
    if(phase==38){if(w.row==0){w.phase=39;return .ok(false);}let usize row=w.row-1;
        let usize released=arrays::release_at(names,p,row,at)?;w.row=row;return .ok(false);}
    if(phase==39){let usize returned=ir::emit(p,8,w.temporary,0,at)?;w.phase=40;return .ok(false);}
    if(phase==40){let usize target=p.count;let usize patched=ir::patch(p,w.failure,target,at)?;w.phase=41;return .ok(false);}
    if(phase==41){let usize trapped=ir::raw(p,25,0,0,0,at)?;w.phase=42;return .ok(false);}
    if(phase==42){let usize target=p.count;let usize patched=ir::patch(p,w.skip,target,at)?;w.phase=43;return .ok(false);}
    if(phase==43){w.value=w.payload;w.phase=0;return .ok(false);}
    return .err(errors::make(5,s.begin));
}
