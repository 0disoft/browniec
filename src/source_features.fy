module source_features;
import lexer as lexer;
import errors as errors;

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
