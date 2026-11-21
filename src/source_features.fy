module source_features;
import lexer as lexer;
import errors as errors;
import source_context as context;
import source_state_work as states;
import lexer_work as tokens;
import metadata_budget as budget;
import runtime_clock as clock;

// Select by syntax, never by retrying a failed compiler or VM. Literal tokens
// include their complete escaped contents; comments/identifiers cannot opt in.
pub fn Result<bool,errors::Error> retained(ref u8[] source){
    if(source.len>4096){return .err(errors::make(4,4096));}
    var lexer::State s=lexer::empty();var bool function=false;
    while(true){let usize next=lexer::next(source,ref mut s)?;
        if(s.kind==0){return .ok(false);}if(s.kind==3 || s.kind==4){return .ok(true);}
        if(function && s.kind==2 && lexer::equal(source[s.begin..s.end],b"ref")){return .ok(true);}
        function=s.kind==2 && lexer::equal(source[s.begin..s.end],b"fn");
    }return .ok(false);
}

// The caller pins the exact source and scope for the life of this cursor.
pub struct State {
    states::State context; tokens::State token; usize file;
    bool scanning; bool function; bool result; bool done;
}
pub fn State begin(){
    return State{.context=states::begin(0),.token=tokens::begin(lexer::empty()),
        .file=0,.scanning=false,.function=false,.result=false,.done=false};
}
pub fn Result<bool,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,0));}
    return .ok(w.result);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref context::Table scope,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(meter.last!=0){return .ok(false);}
    if(scope.modules==0){return .err(errors::make(5,0));}
    if(!w.scanning){
        let bool ready=states::advance(source,scope,ref mut w.context,meter)?;
        if(ready){w.token=tokens::begin(states::prepared(ref w.context)?);w.scanning=true;}
        return .ok(false);
    }
    let bool ready=tokens::advance(source,ref mut w.token,meter)?;
    if(!ready){return .ok(false);}
    let lexer::State next=tokens::prepared(ref w.token)?;
    if(next.kind==0){
        w.file+=1;
        if(w.file==scope.modules){w.done=true;return .ok(true);}
        w.context=states::begin(scope.ends[w.file-1] as usize);
        w.scanning=false;w.function=false;
        return .ok(false);
    }
    if(next.kind==3 || next.kind==4 || (w.function && next.kind==2 &&
        lexer::equal(source[next.begin..next.end],b"ref"))){
        w.result=true;w.done=true;return .ok(true);
    }
    w.function=next.kind==2 && lexer::equal(source[next.begin..next.end],b"fn");
    w.token=tokens::begin(next);
    return .ok(false);
}

pub fn Result<bool,errors::Error> retained_scoped(ref u8[] source,ref context::Table scope){
    return retained_scoped_until(source,scope,0);
}

pub fn Result<bool,errors::Error> retained_scoped_until(ref u8[] source,ref context::Table scope,usize deadline){
    var State w=begin();var budget::State meter=budget::empty();
    while(!w.done){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize allowance=budget::reset(ref mut meter,0)?;
        let bool done=advance(source,scope,ref mut w,ref mut meter)?;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return prepared(ref w);
}
