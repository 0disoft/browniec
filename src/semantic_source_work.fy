module semantic_source_work;
import lexer as lexer;
import lexer_work as tokens;
import type_parse_work as annotations;
import expression_source_work as expressions;
import ir as ir;
import locals as locals;
import errors as errors;
import metadata_budget as budget;
// Annotated scalar/wrapper declarations only. Unsupported statements request an
// explicit legacy child outside this allowance; no initializer is replayed.
pub struct State { lexer::State start; tokens::State token; annotations::State annotation;
    expressions::State expression; usize depth; usize at; usize begin; usize end; usize target;
    usize value; u8 kind; u8 phase; u8 request;
    u8 tag; u8 terminator; bool mutable; bool lexing; bool typing; bool evaluating;
    bool stopped; bool done; }
// kind 0 legacy, 1 ordinary statement (annotated declarations at this checkpoint).
pub fn State begin(lexer::State token,u8 kind,u8 tag,u8 terminator,usize depth){
    return State{.start=token,.token=tokens::begin(token),.annotation=annotations::begin(token),
        .expression=expressions::begin(depth,1,tag),.depth=depth,.at=token.begin,.begin=0,.end=0,.target=0,
        .value=0,.kind=kind,.phase=0,.request=0,.tag=tag,
        .terminator=terminator,.mutable=false,.lexing=false,.typing=false,
        .evaluating=false,.stopped=false,.done=false};
}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] text){return s.kind==2 && lexer::equal(source[s.begin..s.end],text);}
fn bool typed(ref u8[] source,ref lexer::State s){return word(source,s,b"i32") || word(source,s,b"i64") ||
    word(source,s,b"u8") || word(source,s,b"u32") || word(source,s,b"usize") || word(source,s,b"bool") ||
    word(source,s,b"Option") || word(source,s,b"Result");}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){
    if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}
    w.token=tokens::begin(*s);w.lexing=true;w.phase=phase;return .ok(false);}
fn Result<bool,errors::Error> legacy(ref mut State w,ref mut lexer::State s){*s=w.start;w.request=2;return .ok(false);}
fn void evaluate(ref mut State w,u8 phase){let usize depth=w.depth;let u8 tag=w.tag;
    w.expression=expressions::begin(depth,1,tag);w.evaluating=true;w.phase=phase;}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,u8 request,usize value,bool stopped){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}
    w.request=0;
    if(request==1){return expressions::resume(ref mut w.expression,value);}
    if(request!=2){return .err(errors::make(5,w.at));}
    w.value=value;w.stopped=stopped;w.done=true;return .ok(value);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table names,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){let lexer::State token=tokens::prepared(ref w.token)?;
            *s=token;w.lexing=false;}return .ok(false);}};}
    if(w.typing){switch(annotations::advance(source,ref mut w.annotation,meter)){
        case .err(e):{*s=annotations::observed(ref w.annotation);return .err(e);}
        case .ok(done):{if(done){w.tag=annotations::prepared(ref w.annotation)?;*s=annotations::observed(ref w.annotation);w.typing=false;}return .ok(false);}};}
    if(w.evaluating){let bool done=expressions::advance(source,s,p,ref mut w.expression,meter)?;
        if(w.expression.waiting){w.request=1;}
        if(done){w.value=expressions::prepared(ref w.expression)?;w.evaluating=false;}return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    let u8 phase=w.phase;let usize value=w.value;
    if(phase==0){if(w.kind==0){return legacy(w,s);}
        if(word(source,s,b"let") || word(source,s,b"var")){w.mutable=word(source,s,b"var");return take(w,s,0,10);}
        return legacy(w,s);
    }
    if(phase==10){if(!typed(source,s)){return legacy(w,s);}w.annotation=annotations::begin(*s);w.typing=true;w.phase=11;return .ok(false);}
    if(phase==11){if(s.kind==91){return legacy(w,s);}
        if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .err(errors::make(2,s.begin));}
        if(locals::find(source,names,s.begin,s.end)!=64){return .err(errors::make(3,s.begin));}
        if(names.count>=64){return .err(errors::make(4,s.begin));}
        w.begin=s.begin;w.end=s.end;return take(w,s,0,12);}
    if(phase==12){return take(w,s,61,13);}
    if(phase==13){evaluate(w,14);return .ok(false);}
    if(phase==14){if(p.types[value]!=w.tag){return .err(errors::make(3,w.begin));}let u8 terminator=w.terminator;return take(w,s,terminator,15);}
    if(phase==15){if(w.mutable){w.target=ir::slot(p,w.tag,w.begin)?;}else{w.target=value;}w.phase=16;return .ok(false);}
    if(phase==16){if(w.mutable){let usize stored=ir::raw(p,18,w.target,value,0,w.begin)?;}w.phase=17;return .ok(false);}
    if(phase==17){w.value=locals::declare(names,w.begin,w.end,w.target,w.mutable)?;w.done=true;return .ok(true);}
    return .err(errors::make(5,s.begin));
}
