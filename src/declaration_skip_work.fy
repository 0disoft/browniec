module declaration_skip_work;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import errors as errors;
import metadata_budget as budget;

// Shared syntactic child for untyped declaration scans. This validates the raw
// struct-skip grammar or walks function braces; it does not lower a body.
pub struct State { tokens::State scan; lexer::State token; usize fields; usize depth; usize end;
    u8 mode; u8 phase; u8 resume; bool waiting; bool done; }
fn State seed(lexer::State token,u8 mode){return State{.scan=tokens::begin(token),.token=token,
    .fields=0,.depth=if(mode==3){1}else{0},.end=0,.mode=mode,.phase=if(mode==3){5}else if(mode==4){2}else{0},.resume=0,.waiting=false,.done=false};}
pub fn State structure(lexer::State token){return seed(token,1);}
pub fn State function(lexer::State token){return seed(token,2);}
pub fn State body(lexer::State token){return seed(token,3);}
pub fn State members(lexer::State token){return seed(token,4);}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;
    w.scan=tokens::begin(current);w.resume=phase;w.waiting=true;}
fn bool name(ref u8[] source,ref lexer::State s){return s.kind==2 && !locals::reserved(source[s.begin..s.end]);}
pub fn lexer::State observed(ref State w){return w.token;}
pub fn Result<usize,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.token.begin));}return .ok(w.fields);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);
        switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
    if(w.phase==0){let ref u8[] keyword=if(w.mode==1){b"struct"}else{b"fn"};
        if(w.token.kind!=2 || !lexer::equal(source[w.token.begin..w.token.end],keyword)){return .err(errors::make(2,w.token.begin));}
        let u8 phase=if(w.mode==1){1}else{4};next(w,phase);return .ok(false);}
    if(w.phase==1){if(!name(source,ref w.token)){return .err(errors::make(2,w.token.begin));}next(w,2);return .ok(false);}
    if(w.phase==2){if(w.token.kind!=123){return .err(errors::make(2,w.token.begin));}next(w,3);return .ok(false);}
    if(w.phase==3){if(w.token.kind==125){if(w.fields==0){return .err(errors::make(3,w.token.begin));}
            w.end=w.token.begin;next(w,9);return .ok(false);}
        if(w.token.kind!=2 && w.token.kind!=5){return .err(errors::make(2,w.token.begin));}
        if(w.fields>=16){return .err(errors::make(4,w.token.begin));}next(w,6);return .ok(false);}
    if(w.phase==4){if(w.token.kind==123){w.depth=1;next(w,5);return .ok(false);}
        if(w.token.kind==0 || w.token.kind==125){return .err(errors::make(2,w.token.begin));}next(w,4);return .ok(false);}
    if(w.phase==5){if(w.token.kind==0){return .err(errors::make(2,w.token.begin));}
        if(w.token.kind==123){w.depth+=1;if(w.depth>33){return .err(errors::make(4,w.token.begin));}}
        if(w.token.kind==125){w.depth-=1;if(w.depth==0){w.end=w.token.begin;next(w,9);return .ok(false);}}
        next(w,5);return .ok(false);}
    if(w.phase==6){if(w.token.kind==60 || w.token.kind==91){return .err(errors::make(3,w.token.begin));}
        if(!name(source,ref w.token)){return .err(errors::make(2,w.token.begin));}next(w,7);return .ok(false);}
    if(w.phase==7){if(w.token.kind!=59){return .err(errors::make(2,w.token.begin));}w.fields+=1;next(w,3);return .ok(false);}
    if(w.phase==9){w.done=true;return .ok(true);}
    return .err(errors::make(5,w.token.begin));
}
