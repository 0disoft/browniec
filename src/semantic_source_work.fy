module semantic_source_work;
import lexer as lexer;
import functions as functions;
import lexer_work as tokens;
import type_parse_work as annotations;
import expression_source_work as expressions;
import ir as ir;
import types as types;
import locals as locals;
import array_source as arrays;
import errors as errors;
import metadata_budget as budget;
// Annotated declarations and ordinary scalar/void returns. Unsupported forms
// request an explicit legacy child outside this allowance; no operand is replayed.
pub struct State { lexer::State start; tokens::State token; annotations::State annotation;
    expressions::State expression; usize depth; usize at; usize begin; usize end; usize target;
    usize value; usize row; usize pending; u8 kind; u8 phase; u8 request;
    u8 tag; u8 terminator; bool mutable; bool lexing; bool typing; bool evaluating;
    bool stopped; bool done; }
// kind 0 legacy, 1 ordinary statement, 2 scalar return, 3 void return.
pub fn State begin(lexer::State token,u8 kind,u8 tag,u8 terminator,usize depth){
    return State{.start=token,.token=tokens::begin(token),.annotation=annotations::begin(token),
        .expression=expressions::begin(depth,1,tag),.depth=depth,.at=token.begin,.begin=0,.end=0,.target=0,
        .value=0,.row=0,.pending=0,.kind=kind,.phase=0,.request=0,.tag=tag,
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
// Header preparation remains an explicit child without enlarging semantic State.
pub fn Result<usize,errors::Error> resume_header(ref mut State w,usize begin,usize end){
    if(w.done || w.request!=3){return .err(errors::make(5,w.at));}w.begin=begin;w.end=end;w.request=0;return .ok(begin);
}
// The owning operand service has either installed a continuation or resumed it.
pub fn Result<usize,errors::Error> continue_operand(ref mut State w){
    if(w.done || w.request!=1 || w.expression.waiting){return .err(errors::make(5,w.at));}
    w.request=0;return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table names,ref functions::Table signatures,ref mut expressions::Bank bank,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){let lexer::State token=tokens::prepared(ref w.token)?;
            *s=token;w.lexing=false;}return .ok(false);}};}
    if(w.typing){switch(annotations::advance(source,ref mut w.annotation,meter)){
        case .err(e):{*s=annotations::observed(ref w.annotation);return .err(e);}
        case .ok(done):{if(done){w.tag=annotations::prepared(ref w.annotation)?;*s=annotations::observed(ref w.annotation);w.typing=false;}return .ok(false);}};}
    if(w.evaluating){let bool done=expressions::advance(source,s,p,names,signatures,bank,ref mut w.expression,meter)?;
        if(w.expression.waiting){w.request=1;}
        if(done){w.value=expressions::prepared(ref w.expression)?;w.evaluating=false;}return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    let u8 phase=w.phase;let usize value=w.value;
    if(phase==0){if(w.kind==0){return legacy(w,s);}
        if(w.kind==2 || w.kind==3){return take(w,s,0,30);}
        if(word(source,s,b"let") || word(source,s,b"var")){w.mutable=word(source,s,b"var");return take(w,s,0,10);}
        return legacy(w,s);
    }
    if(phase==10){if(!typed(source,s)){return legacy(w,s);}
        w.begin=s.begin;w.annotation=annotations::begin(*s);w.typing=true;w.phase=11;return .ok(false);}
    if(phase==11){if(s.kind==91){return legacy(w,s);}
        if(signatures.semantic_depth<2 && types::tagged(w.tag)){return .err(errors::make(4,w.begin));}
        w.request=3;w.phase=13;return .ok(false);}
    if(phase==13){evaluate(w,14);return .ok(false);}
    if(phase==14){if(p.types[value]!=w.tag){return .err(errors::make(3,w.begin));}let u8 terminator=w.terminator;return take(w,s,terminator,15);}
    if(phase==15){if(w.mutable){w.target=ir::slot(p,w.tag,w.begin)?;}else{w.target=value;}w.phase=16;return .ok(false);}
    if(phase==16){if(w.mutable){let usize stored=ir::raw(p,18,w.target,value,0,w.begin)?;}w.phase=17;return .ok(false);}
    if(phase==17){w.value=locals::declare(names,w.begin,w.end,w.target,w.mutable)?;w.done=true;return .ok(true);}
    if(phase==30){if(w.kind==3){if(s.kind!=59){return .err(errors::make(3,s.begin));}return take(w,s,0,34);}
        evaluate(w,31);return .ok(false);}
    if(phase==31){if(p.types[value]!=w.tag){return .err(errors::make(3,w.at));}return take(w,s,59,34);}
    if(phase==34){if(names.pending_places>65535){return .err(errors::make(3,w.at));}w.pending=names.pending_places;w.row=16;w.phase=35;return .ok(false);}
    if(phase==35){if(w.row==0){w.row=names.count;w.phase=36;return .ok(false);}
        let usize row=w.row-1;let usize one=1;if((w.pending&(one<<row))!=0){let usize ended=ir::place_end(p,row,w.at)?;}w.row=row;return .ok(false);}
    if(phase==36){if(w.row==0){w.phase=37;return .ok(false);}let usize row=w.row-1;
        let usize released=arrays::release_at(names,p,row,w.at)?;w.row=row;return .ok(false);}
    if(phase==37){if(w.kind==3){let usize returned=ir::raw(p,82,0,0,0,w.at)?;}else{let usize returned=ir::emit(p,8,value,0,w.at)?;}
        w.value=0;w.stopped=true;w.done=true;return .ok(true);}
    return .err(errors::make(5,s.begin));
}
