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

pub fn Result<bool,errors::Error> retained_scoped(ref u8[] source,ref context::Table scope){
    return retained_scoped_until(source,scope,0);
}

pub fn Result<bool,errors::Error> retained_scoped_until(ref u8[] source,ref context::Table scope,usize deadline){
    if(scope.modules==0){return .err(errors::make(5,0));}
    var usize file=0;var usize base=0;
    while(file<scope.modules){var lexer::State s=scoped_state(source,scope,base,deadline)?;var bool function=false;
        while(true){s=next_token(source,s,deadline)?;
            if(s.kind==0){break;}if(s.kind==3 || s.kind==4){return .ok(true);}
            if(function && s.kind==2 && lexer::equal(source[s.begin..s.end],b"ref")){return .ok(true);}
            function=s.kind==2 && lexer::equal(source[s.begin..s.end],b"fn");
        }base=scope.ends[file] as usize;file+=1;
    }return .ok(false);
}

fn Result<lexer::State,errors::Error> scoped_state(ref u8[] source,ref context::Table scope,usize base,usize deadline){
    var states::State w=states::begin(base);var budget::State meter=budget::empty();
    while(!w.done){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize allowance=budget::reset(ref mut meter,base)?;
        let bool done=states::advance(source,scope,ref mut w,ref mut meter)?;
    }
    return states::prepared(ref w);
}

fn Result<lexer::State,errors::Error> next_token(ref u8[] source,lexer::State current,usize deadline){
    var tokens::State w=tokens::begin(current);var budget::State meter=budget::empty();
    while(!w.done){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize allowance=budget::reset(ref mut meter,current.cursor)?;
        let bool done=tokens::advance(source,ref mut w,ref mut meter)?;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return tokens::prepared(ref w);
}
