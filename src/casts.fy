module casts;

import lexer as lexer;
import errors as errors;

// Detect an as suffix on this unary/postfix operand before typing its literals.
// An explicit cast supplies no expected type to its source. Nested parentheses,
// calls and switch arms own their own suffixes. The copied lexer shares existing
// source/token bounds without changing the real parser's position or counters.
pub fn Result<bool,errors::Error> follows(ref u8[] source,ref lexer::State state) {
    var lexer::State look=lexer::snapshot(state);
    var usize parens=0;
    var usize braces=0;
    var bool started=false;
    while(true) {
        if(look.kind==0) {return .ok(false);}
        if(parens==0 && braces==0) {
            if(look.kind==59 || look.kind==44 || look.kind==41 || look.kind==125) {return .ok(false);}
            if(look.kind==2 && lexer::equal(source[look.begin..look.end],b"as")) {return .ok(true);}
            if(started && (look.kind==43 || look.kind==45 || look.kind==42 || look.kind==47 || look.kind==37 ||
                look.kind==60 || look.kind==62 || look.kind==38 || look.kind==94 || look.kind==124 ||
                (look.kind>=128 && look.kind<=135))) {return .ok(false);}
        }
        if(look.kind==40) {parens+=1; started=true;}
        else if(look.kind==41) {if(parens==0) {return .ok(false);} parens-=1;}
        else if(look.kind==123) {braces+=1; started=true;}
        else if(look.kind==125) {if(braces==0) {return .ok(false);} braces-=1;}
        else if(look.kind==1 || look.kind==2 || look.kind==46) {started=true;}
        let usize next=lexer::next(source,ref mut look)?;
    }
    return .ok(false);
}
