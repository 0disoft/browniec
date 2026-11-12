module operand_preflight_work;
import lexer as lexer;
import lexer_work as tokens;
import types as types;
import errors as errors;
import metadata_budget as budget;
// Read-only converted -> primary lookahead. Source and the caller's real lexer
// remain pinned; every private token request delegates one lexical advance.
pub struct State { lexer::State start; lexer::State look; tokens::State scan;
    usize parens; usize braces; usize brackets; usize visits; u8 context; u8 phase; u8 next;
    bool started; bool waiting; bool done; }
pub fn State begin(lexer::State token,u8 expected,bool primary){return State{
    .start=token,.look=token,.scan=tokens::begin(token),.parens=0,.braces=0,.brackets=0,.visits=0,
    .context=expected,.phase=if(primary){10}else{0},.next=0,.started=false,.waiting=false,.done=false};}
pub fn Result<u8,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.start.begin));}return .ok(w.context);}
fn void next(ref mut State w,u8 phase){let lexer::State token=w.look;w.scan=tokens::begin(token);w.next=phase;w.waiting=true;}
fn void result(ref mut State w,bool cast){if(cast){w.context=0;}w.look=w.start;w.parens=0;w.braces=0;w.brackets=0;w.started=false;w.phase=10;}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn bool boundary(u8 kind){return kind==59 || kind==44 || kind==41 || kind==125 || kind==93;}
fn bool binary(u8 kind){return kind==43 || kind==45 || kind==42 || kind==47 || kind==37 || kind==60 || kind==62 ||
    kind==38 || kind==94 || kind==124 || (kind>=128 && kind<=135);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.scan,meter)){
        case .err(e):{return .err(e);}case .ok(done):{if(done){w.look=tokens::prepared(ref w.scan)?;w.waiting=false;w.phase=w.next;}return .ok(false);}};}
    if(!budget::admit(meter,4096,w.start.begin)?){return .ok(false);}w.visits+=1;
    let lexer::State s=w.look;let bool cast=w.phase==0;
    if(w.phase==11){if(s.kind==46){w.done=true;return .ok(true);}
        if(word(source,ref s,b"is_ok")){w.context=0;w.done=true;return .ok(true);}w.phase=10;return .ok(false);}
    if(!cast && (w.context==0 || types::tagged(w.context))){w.done=true;return .ok(true);}
    if(s.kind==0){if(cast){result(w,false);return .ok(false);}w.done=true;return .ok(true);}
    if(w.parens==0 && w.braces==0 && w.brackets==0){
        if(!cast && s.kind==46 && w.started){next(w,11);return .ok(false);}
        if(boundary(s.kind)){if(cast){result(w,false);return .ok(false);}w.done=true;return .ok(true);}
        if(cast && word(source,ref s,b"as")){result(w,true);return .ok(false);}
        if(w.started && (binary(s.kind) || (!cast && word(source,ref s,b"as")))){
            if(cast){result(w,false);return .ok(false);}w.done=true;return .ok(true);}
    }
    if(s.kind==40){w.parens+=1;}else if(s.kind==41){if(w.parens==0){if(cast){result(w,false);return .ok(false);}w.done=true;return .ok(true);}w.parens-=1;}
    else if(s.kind==123){w.braces+=1;}else if(s.kind==125){if(w.braces==0){if(cast){result(w,false);return .ok(false);}w.done=true;return .ok(true);}w.braces-=1;}
    else if(s.kind==91){w.brackets+=1;}else if(s.kind==93){if(w.brackets==0){if(cast){result(w,false);return .ok(false);}w.done=true;return .ok(true);}w.brackets-=1;}
    if(!cast || s.kind==40 || s.kind==123 || s.kind==91 || s.kind==1 || s.kind==2 || s.kind==46){w.started=true;}
    next(w,if(cast){0}else{10});return .ok(false);
}
