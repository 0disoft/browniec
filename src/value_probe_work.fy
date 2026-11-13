module value_probe_work;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;
// Private advisory walks: 0 postfix, 1 tail control, 2 tail expression,
// 3 assignment, 4 pure for header. No real lexer, names or IR are published.
pub struct State { tokens::State token; lexer::State look; usize parens; usize braces; usize value;
    u8 mode; u8 phase; u8 terminator; bool started; bool control; bool body; bool name; bool waiting; bool done; }
pub fn State begin(lexer::State s,u8 mode,u8 terminator){return State{.token=tokens::begin(s),.look=s,
    .parens=0,.braces=0,.value=0,.mode=mode,.phase=0,.terminator=terminator,.started=false,.control=false,
    .body=false,.name=false,.waiting=false,.done=false};}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn bool binary(u8 k){return (k>=128 && k<=135) || k==124 || k==94 || k==38 || k==60 || k==62 || k==43 || k==45 || k==42 || k==47 || k==37;}
fn Result<bool,errors::Error> finish(ref mut State w,bool value){w.value=if(value){1}else{0};w.done=true;return .ok(true);}
fn Result<bool,errors::Error> next(ref mut State w,u8 phase){w.token=tokens::begin(w.look);w.waiting=true;w.phase=phase;return .ok(false);}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.look.begin));}return .ok(w.value);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let bool done=tokens::advance(source,ref mut w.token,meter)?;
        if(done){w.look=tokens::prepared(ref w.token)?;w.waiting=false;}return .ok(false);}
    if(!budget::admit(meter,4096,w.look.begin)?){return .ok(false);}let lexer::State s=w.look;let u8 k=s.kind;
    if(w.phase==1){if(k==46){return finish(w,false);}
        if(word(source,ref s,b"len") || word(source,ref s,b"is_some") || word(source,ref s,b"is_none") || word(source,ref s,b"is_ok") || word(source,ref s,b"is_err")){return finish(w,true);}
        w.phase=0;return .ok(false);}
    if(w.phase==2){if(word(source,ref s,b"else")){w.body=false;w.phase=0;return .ok(false);}
        return finish(w,k==125 || k==41 || k==44 || k==93 || k==46 || k==63 || word(source,ref s,b"as") || binary(k));}
    if(w.phase==3){return finish(w,k==61 || (k>=136 && k<=145));}
    if(w.mode==3){if(k!=2 || word(source,ref s,b"_")){return finish(w,false);}return next(w,3);}
    if(k==0){if(w.mode==4){return .err(errors::make(2,s.begin));}return finish(w,false);}
    if(w.mode==4){
        if(w.parens==0 && k==w.terminator){w.value=s.begin;w.done=true;return .ok(true);}
        if(k==63 || k==46 || k==58 || k==91 || k==123 || word(source,ref s,b"if") || word(source,ref s,b"switch") || word(source,ref s,b"while") ||
            word(source,ref s,b"for") || word(source,ref s,b"return") || word(source,ref s,b"break") || word(source,ref s,b"continue") || word(source,ref s,b"ref")){return .err(errors::make(3,s.begin));}
        if(k==40){if(w.name){return .err(errors::make(3,s.begin));}w.parens+=1;}
        else if(k==41){if(w.parens==0){return .err(errors::make(2,s.begin));}w.parens-=1;}
        w.name=k==2;return next(w,0);
    }
    if(w.mode==1){
        if(k==40){w.parens+=1;}else if(k==41 && w.parens!=0){w.parens-=1;}
        if(k==123 && (w.body || w.parens==0)){w.braces+=1;w.body=true;}
        else if(k==125 && w.body){w.braces-=1;if(w.braces==0){return next(w,2);}}
        return next(w,0);
    }
    if(w.mode==0 && w.parens==0 && w.braces==0){
        if(word(source,ref s,b"if") || word(source,ref s,b"switch")){w.control=true;}
        if(k==63){return finish(w,true);}if(k==46 && w.started){return next(w,1);}if(k==91 && w.started){return finish(w,true);}
        if(k==59 || k==44 || k==41 || k==125 || k==93 || (k==123 && !w.control)){return finish(w,false);}
        if(w.started && binary(k)){return finish(w,false);}
    }
    if(w.mode==2 && w.parens==0 && w.braces==0){if(k==59){return finish(w,false);}if(k==125){return finish(w,true);}}
    if(k==123){w.braces+=1;}else if(k==125){if(w.braces==0){return finish(w,false);}w.braces-=1;}
    if(k==40){w.parens+=1;}else if(k==41){if(w.parens==0){return finish(w,false);}w.parens-=1;}
    w.started=true;return next(w,0);
}
pub fn Result<usize,errors::Error> prepare(ref u8[] source,ref lexer::State s,u8 mode,u8 terminator){
    var State w=begin(*s,mode,terminator);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;let bool done=advance(source,ref mut w,ref mut meter)?;}return prepared(ref w);
}
