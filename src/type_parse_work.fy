module type_parse_work;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;

// Private primitive/wrapper grammar continuation for immutable <=4096-byte
// lowering input. Every token request resumes the lexical kernel independently.
// Nominal, array, reference and value annotations belong to their parent passes.
pub struct State { tokens::State scan; lexer::State token;
    u8 phase; u8 resume; u8 wrapper; u8 first; u8 second; u8 tag; bool waiting; bool done; }
pub fn State begin(lexer::State token){return State{.scan=tokens::begin(token),.token=token,
    .phase=0,.resume=0,.wrapper=0,.first=0,.second=0,.tag=0,.waiting=false,.done=false};}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;
    w.scan=tokens::begin(current);w.resume=phase;w.waiting=true;}
fn Result<u8,errors::Error> base(ref u8[] source,ref lexer::State s){
    if(s.kind!=2){return .err(errors::make(2,s.begin));}
    let ref u8[] spelling=source[s.begin..s.end];
    let u8 tag=if(lexer::equal(spelling,b"i32")){1}else if(lexer::equal(spelling,b"bool")){2}
        else if(lexer::equal(spelling,b"i64")){9}else if(lexer::equal(spelling,b"u8")){10}
        else if(lexer::equal(spelling,b"u32")){11}else if(lexer::equal(spelling,b"usize")){12}else{0};
    if(tag==0){return .err(errors::make(3,s.begin));}return .ok(tag);
}
pub fn Result<u8,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.token.begin));}return .ok(w.tag);
}
pub fn lexer::State observed(ref State w){return w.token;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);
        switch(result){case .ok(done):{if(done){w.phase=w.resume;w.waiting=false;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
    if(w.phase==0){
        if(w.token.kind!=2){return .err(errors::make(2,w.token.begin));}
        let ref u8[] spelling=source[w.token.begin..w.token.end];
        w.wrapper=if(lexer::equal(spelling,b"Option")){1}else if(lexer::equal(spelling,b"Result")){2}else{0};
        if(w.wrapper!=0){next(w,1);}else{w.tag=base(source,ref w.token)?;next(w,8);}return .ok(false);
    }
    if(w.phase==1){if(w.token.kind!=60){return .err(errors::make(2,w.token.begin));}next(w,2);return .ok(false);}
    if(w.phase==2){w.first=base(source,ref w.token)?;next(w,3);return .ok(false);}
    if(w.phase==3){if(w.first!=1 && w.first!=2){return .err(errors::make(3,w.token.begin));}
        w.tag=if(w.first==1){3}else{4};
        if(w.wrapper==2){if(w.token.kind!=44){return .err(errors::make(2,w.token.begin));}next(w,4);}
        else{w.phase=6;}return .ok(false);}
    if(w.phase==4){w.second=base(source,ref w.token)?;next(w,5);return .ok(false);}
    if(w.phase==5){if(w.second!=1 && w.second!=2){return .err(errors::make(3,w.token.begin));}
        w.tag=if(w.first==1){if(w.second==1){5}else{6}}else{if(w.second==1){7}else{8}};w.phase=6;return .ok(false);}
    if(w.phase==6){if(w.token.kind!=62){return .err(errors::make(2,w.token.begin));}next(w,8);return .ok(false);}
    if(w.phase==8){w.done=true;return .ok(true);}
    return .err(errors::make(5,w.token.begin));
}

// Owning compatibility adapter. Parent semantic traversal remains synchronous.
pub fn Result<u8,errors::Error> parse(ref u8[] source,ref mut lexer::State target){
    var State w=begin(*target);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;
        switch(advance(source,ref mut w,ref mut meter)){
            case .ok(_):{}case .err(e):{*target=observed(ref w);return .err(e);}};}
    *target=observed(ref w);return prepared(ref w);
}
