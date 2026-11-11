module struct_locate_work;
import lexer as lexer;
import lexer_work as tokens;
import declaration_skip_work as skipping;
import errors as errors;
import metadata_budget as budget;

// Untyped single-source nominal discovery. The query span and source stay
// pinned. Header parsing, declaration skipping and <=64-byte comparisons yield.
pub struct Location { usize record; usize body; }
pub struct State { tokens::State scan; skipping::State skip; lexer::State token; lexer::State saved;
    Location result; usize begin; usize end; usize selected; usize record; usize compared;
    usize candidate; usize width; usize visits; u8 phase; u8 resume;
    bool waiting; bool skipping; bool structure; bool done; }
pub fn State begin(usize a,usize b,usize selected){return State{.scan=tokens::begin(lexer::empty()),
    .skip=skipping::structure(lexer::empty()),.token=lexer::empty(),.saved=lexer::empty(),
    .result=Location{.record=32,.body=0},.begin=a,.end=b,.selected=selected,.record=0,.compared=0,
    .candidate=0,.width=0,.visits=0,.phase=0,.resume=0,.waiting=false,.skipping=false,.structure=false,.done=false};}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;
    w.scan=tokens::begin(current);w.waiting=true;w.resume=phase;}
fn void skip(ref mut State w,bool structure){let lexer::State current=if(structure){w.saved}else{w.token};
    w.skip=if(structure){skipping::structure(current)}else{skipping::function(current)};w.skipping=true;w.structure=structure;}
pub fn Result<Location,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.begin));}return .ok(w.result);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);
        switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(w.skipping){let Result<bool,errors::Error> result=skipping::advance(source,ref mut w.skip,meter);
        w.token=skipping::observed(ref w.skip);let bool done=result?;
        if(done){if(w.structure){w.record+=1;}w.skipping=false;w.phase=4;}return .ok(false);}
    if(!budget::admit(meter,4096,w.begin)?){return .ok(false);}
    if(w.phase==0){next(w,1);return .ok(false);}
    if(w.phase==1){if(!word(source,ref w.token,b"module")){return .err(errors::make(2,w.token.begin));}next(w,2);return .ok(false);}
    if(w.phase==2){if(!word(source,ref w.token,b"main")){return .err(errors::make(2,w.token.begin));}next(w,3);return .ok(false);}
    if(w.phase==3){if(w.token.kind!=59){return .err(errors::make(2,w.token.begin));}next(w,4);return .ok(false);}
    if(w.phase==4){if(w.token.kind==0){w.done=true;return .ok(true);}
        if(word(source,ref w.token,b"struct")){w.saved=w.token;next(w,5);}else{skip(w,false);}return .ok(false);}
    if(w.phase==5){if(w.selected<32){if(w.record==w.selected){next(w,6);}else{skip(w,true);}return .ok(false);}
        if(w.token.end-w.token.begin!=w.end-w.begin){skip(w,true);return .ok(false);}
        w.candidate=w.token.begin;w.width=w.end-w.begin;w.compared=0;w.phase=8;return .ok(false);}
    if(w.phase==6){if(w.token.kind!=123){return .err(errors::make(2,w.token.begin));}next(w,7);return .ok(false);}
    if(w.phase==7){w.result=Location{.record=w.record,.body=w.token.begin};w.done=true;return .ok(true);}
    if(w.phase==8){var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){w.visits+=1;if(source[w.begin+w.compared]!=source[w.candidate+w.compared]){skip(w,true);return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){next(w,6);}return .ok(false);}
    return .err(errors::make(5,w.begin));
}
