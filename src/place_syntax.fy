module place_syntax;
import lexer as lexer;
import locals as locals;
import errors as errors;

// Read-only source scratch, never typed/executable authority. Parentheses carry
// no selector. Fields retain original name spans; indices retain a lexer copy
// at their first token and the original closing-bracket offset. No source bytes
// are rewritten and no expression is evaluated by this probe.
pub struct Plan {
    bool valid; usize begin; usize end; usize groups; usize count;
    u8[16] kinds; usize[16] begins; usize[16] ends;
    lexer::State[16] operands; lexer::State operation;
}
fn Plan empty(ref lexer::State state){
    let lexer::State zero=lexer::empty();
    return Plan{.valid=false,.begin=state.begin,.end=state.end,.groups=0,.count=0,
        .kinds=[0;16],.begins=[0;16],.ends=[0;16],.operands=[zero;16],.operation=lexer::snapshot(state)};
}
fn u8 closing(u8 kind){return if(kind==40){41}else if(kind==91){93}else if(kind==123){125}else{0};}
fn bool closed(u8 kind){return kind==41 || kind==93 || kind==125;}
// The outer bracket is stack entry zero. Matching all three delimiter families
// prevents an inner expression's bracket/brace from ending this selector.
fn Result<usize,errors::Error> index_end(ref u8[] source,ref mut lexer::State s){
    var u8[32] stack=[0;32];stack[0]=93;var usize depth=1;
    if(s.kind==93){return .err(errors::make(2,s.begin));}
    while(depth!=0){
        if(s.kind==0){return .err(errors::make(2,s.begin));}
        let u8 end=closing(s.kind);
        if(end!=0){if(depth==32){return .err(errors::make(4,s.begin));}stack[depth]=end;depth+=1;}
        else if(closed(s.kind)){
            if(s.kind!=stack[depth-1]){return .err(errors::make(2,s.begin));}
            depth-=1;if(depth==0){let usize at=s.begin;let usize next=lexer::next(source,s)?;return .ok(at);}
        }
        let usize next=lexer::next(source,s)?;
    }
    return .err(errors::make(2,s.begin));
}
pub fn Result<Plan,errors::Error> inspect(ref u8[] source,ref lexer::State state){
    if(source.len>4096){return .err(errors::make(4,state.begin));}
    if(state.begin>state.end || state.end>source.len || state.cursor<state.end ||
        state.cursor>source.len || state.tokens>1024){return .err(errors::make(5,state.begin));}
    var Plan plan=empty(state);var lexer::State s=lexer::snapshot(state);var usize depth=0;
    while(s.kind==40){if(depth==32){return .err(errors::make(4,s.begin));}
        depth+=1;let usize next=lexer::next(source,ref mut s)?;}
    plan.groups=depth;
    if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .ok(plan);}
    plan.begin=s.begin;plan.end=s.end;let usize root=lexer::next(source,ref mut s)?;
    while(true){
        if(s.kind==46){
            if(plan.count==16){return .err(errors::make(4,s.begin));}
            let usize dot=lexer::next(source,ref mut s)?;if(s.kind!=2){return .ok(plan);}
            let usize i=plan.count;plan.kinds[i]=1;plan.begins[i]=s.begin;plan.ends[i]=s.end;plan.count+=1;
            let usize next=lexer::next(source,ref mut s)?;continue;
        }
        if(s.kind==91){
            if(plan.count==16){return .err(errors::make(4,s.begin));}
            let usize open=lexer::next(source,ref mut s)?;let usize i=plan.count;
            plan.kinds[i]=2;plan.begins[i]=s.begin;plan.operands[i]=lexer::snapshot(ref s);
            plan.ends[i]=index_end(source,ref mut s)?;plan.count+=1;continue;
        }
        if(s.kind==41 && depth!=0){depth-=1;let usize next=lexer::next(source,ref mut s)?;continue;}
        plan.operation=lexer::snapshot(ref s);
        plan.valid=depth==0 && lexer::assignment(s.kind);return .ok(plan);
    }
    return .ok(plan);
}
