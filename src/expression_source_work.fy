module expression_source_work;
import lexer as lexer;
import lexer_work as tokens;
import ir as ir;
import types as types;
import errors as errors;
import metadata_budget as budget;
// Pratt traversal only. A converted unary/postfix operand is an explicit pending
// child, never charged as a bounded stage. Source, names and candidate IR are pinned.
pub struct Frame { usize depth; usize left; usize slot; usize jump; usize at;
    u8 context; u8 minimum; u8 expected; u8 kind; u8 operation; u8 phase; }
pub struct State { Frame[34] frames; tokens::State token; usize used; usize value;
    usize visits; u8 request; bool waiting; bool lexing; bool done; }
fn Frame frame(usize depth,u8 minimum,u8 expected){return Frame{.depth=depth,.left=0,.slot=0,.jump=0,.at=0,
    .context=expected,.minimum=minimum,.expected=expected,.kind=0,.operation=0,.phase=0};}
pub fn State begin(usize depth,u8 minimum,u8 expected){var State w=State{.frames=[frame(0,1,0);34],
    .token=tokens::begin(lexer::empty()),.used=1,.value=0,.visits=0,.request=0,.waiting=false,.lexing=false,.done=false};
    w.frames[0]=frame(depth,minimum,expected);return w;}
pub fn Frame current(ref State w){let ref Frame[] frames=ref w.frames;return frames[w.used-1];}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,0));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,usize value){
    if(w.done || !w.waiting){return .err(errors::make(5,0));}w.waiting=false;w.request=0;w.value=value;return .ok(value);}
// Child classification does not evaluate or consume the grouped expression.
pub fn Result<usize,errors::Error> group(ref mut State w,u8 context){
    if(w.done || !w.waiting || w.request!=1){return .err(errors::make(5,0));}
    let usize i=w.used-1;w.frames[i].context=context;w.frames[i].phase=10;w.waiting=false;w.request=0;return .ok(0);
}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){
    if(s.kind!=kind){return .err(errors::make(2,s.begin));}
    let usize i=w.used-1;w.frames[i].phase=phase;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);
}
fn u8 precedence(u8 kind) {
    if (kind == 133) { return 1; }
    if (kind == 132) { return 2; }
    if (kind == 124) { return 3; }
    if (kind == 94) { return 4; }
    if (kind == 38) { return 5; }
    if (kind == 128 || kind == 129) { return 6; }
    if (kind == 60 || kind == 62 || kind == 130 || kind == 131) { return 7; }
    if (kind == 134 || kind == 135) { return 8; }
    if (kind == 43 || kind == 45) { return 9; }
    if (kind == 42 || kind == 47 || kind == 37) { return 10; }
    return 0;
}
fn u8 opcode(u8 kind) {
    if (kind == 134) { return 31; }
    if (kind == 135) { return 32; }
    if (kind == 38) { return 28; }
    if (kind == 94) { return 29; }
    if (kind == 124) { return 30; }
    if (kind == 128) { return 11; }
    if (kind == 129) { return 12; }
    if (kind == 60) { return 13; }
    if (kind == 130) { return 14; }
    if (kind == 62) { return 15; }
    if (kind == 131) { return 16; }
    if (kind == 43) { return 2; }
    if (kind == 45) { return 3; }
    if (kind == 42) { return 4; }
    if (kind == 47) { return 5; }
    return 6;
}

pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.waiting){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    let usize i=w.used-1;let Frame f=current(w);let usize value=w.value;w.visits+=1;
    if(f.phase==0){if(f.depth>32){return .err(errors::make(4,s.begin));}
        w.frames[i].phase=1;w.waiting=true;w.request=1;return .ok(false);}
    if(f.phase==1){w.frames[i].left=value;w.frames[i].phase=2;return .ok(false);}
    if(f.phase==2){if(precedence(s.kind)<f.minimum){w.value=f.left;w.used-=1;w.done=w.used==0;return .ok(w.done);}
        w.frames[i].kind=s.kind;w.frames[i].operation=opcode(s.kind);w.frames[i].at=s.begin;
        w.frames[i].phase=3;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);}
    if(f.phase==3){let bool logical=f.kind==132 || f.kind==133;
        if(logical){if(p.types[f.left]!=2){return .err(errors::make(3,f.at));}
            let usize slot=ir::slot(p,2,f.at)?;let usize initial=ir::raw(p,18,slot,f.left,0,f.at)?;
            let usize jump=ir::raw(p,if(f.kind==132){20}else{21},0,f.left,0,f.at)?;
            w.frames[i].slot=slot;w.frames[i].jump=jump;}
        if(w.used>=34){return .err(errors::make(4,s.begin));}
        let usize next=w.used;let u8 expected=if(logical){f.expected}else{p.types[f.left]};
        w.frames[i].phase=4;w.frames[next]=frame(f.depth+1,precedence(f.kind)+1,expected);w.used+=1;return .ok(false);}
    if(f.phase==4){var usize result=0;
        if(f.kind==132 || f.kind==133){if(p.types[value]!=2){return .err(errors::make(3,f.at));}
            let usize stored=ir::raw(p,18,f.slot,value,0,f.at)?;let usize target=p.count;
            let usize patched=ir::patch(p,f.jump,target,f.at)?;result=ir::emit(p,17,f.slot,0,f.at)?;
        }else{
            if(!types::scalar(p.types[f.left]) || p.types[f.left]!=p.types[value] ||
                ((f.operation<11 || f.operation>12) && !types::integer(p.types[f.left]))){return .err(errors::make(3,f.at));}
            result=ir::emit(p,f.operation,f.left,value,f.at)?;
        }w.frames[i].left=result;w.frames[i].phase=2;return .ok(false);}
    if(f.phase==10){return take(w,s,40,11);}
    if(f.phase==11){if(w.used>=34){return .err(errors::make(4,s.begin));}
        let usize next=w.used;w.frames[i].phase=12;w.frames[next]=frame(f.depth+1,1,f.context);w.used+=1;return .ok(false);}
    if(f.phase==12){w.frames[i].left=value;return take(w,s,41,13);}
    if(f.phase==13){w.value=f.left;w.frames[i].phase=1;w.waiting=true;w.request=2;return .ok(false);}
    return .err(errors::make(5,s.begin));
}
