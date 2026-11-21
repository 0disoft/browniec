module array_expression_source;
import lexer as lexer;
import aggregate_probe_work as probes;
import locals as locals;
import functions as functions;
import ir as ir;
import array_source as arrays;
import errors as errors;

// Source-only atoms: 1 literal, 2 existing owner, 3 owned CALL result.
// This is advisory classification, never authority or guest evaluation.
pub struct Plan { usize groups; u8 kind; u8 suffix; }
pub struct Value { usize id; bool owned; usize depth; }
fn Plan none(){return Plan{.groups=0,.kind=0,.suffix=0};}
pub fn Result<Plan,errors::Error> inspect_raw(ref u8[] source,ref lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    var lexer::State look=lexer::snapshot(s);var usize groups=0;
    while(look.kind==40){if(groups>=32){return .err(errors::make(4,look.begin));}
        groups+=1;let usize next=lexer::next(source,ref mut look)?;}
    var u8 kind=0;var u8 open=0;var u8 close=0;
    if(look.kind==91){kind=1;open=91;close=93;}
    else if(look.kind==2 || look.kind==5){
        let usize index=locals::find(source,names,look.begin,look.end);
        let usize target=functions::find(source,signatures,look.begin,look.end);
        let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==40){
            if(index!=64 || target>=signatures.count || signatures.return_lengths[target]==0){return .ok(none());}
            kind=3;open=40;close=41;
        }else if(arrays::binding(names,index)){
            let usize id=names.registers[index]-128;
            if(id>=16 || id>=p.arrays.count || p.array_functions[id] as usize!=names.function){return .err(errors::make(3,s.begin));}
            kind=2;
        }else{return .ok(none());}
    }else{return .ok(none());}
    if(open!=0){var usize depth=1;let usize first=lexer::next(source,ref mut look)?;
        while(depth!=0){if(look.kind==0){return .err(errors::make(2,look.begin));}
            if(look.kind==open){depth+=1;}else if(look.kind==close){depth-=1;}
            let usize next=lexer::next(source,ref mut look)?;}
    }
    var usize i=0;while(i<groups){if(look.kind!=41){return .ok(none());}
        let usize next=lexer::next(source,ref mut look)?;i+=1;}
    return .ok(Plan{.groups=groups,.kind=kind,.suffix=look.kind});
}
// Keep the advisory Plan and its error payload off the recursive scalar
// operand frame when a grouped array projection is absent.
pub fn Result<bool,errors::Error> projected(ref u8[] source,ref lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    let Plan plan=inspect(source,s,p,names,signatures)?;
    return .ok(plan.kind>1 && (plan.suffix==91 || plan.suffix==46));
}
pub fn Result<usize,errors::Error> open(ref u8[] source,ref mut lexer::State s,usize depth,usize limit){
    if(depth>limit){return .err(errors::make(4,s.begin));}
    var usize groups=0;while(s.kind==40){if(groups>=limit-depth){return .err(errors::make(4,s.begin));}
        let usize next=lexer::next(source,s)?;groups+=1;}
    if(groups==0){return .err(errors::make(3,s.begin));}return .ok(groups);
}
pub fn Result<usize,errors::Error> close(ref u8[] source,ref mut lexer::State s,usize groups){
    var usize i=0;while(i<groups){let usize next=lexer::punctuation(source,s,41)?;i+=1;}return .ok(groups);
}

pub fn Result<Plan,errors::Error> inspect(ref u8[] source,ref lexer::State s,ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    let probes::Plan plan=probes::inspect(source,*s,p,names,signatures,2)?;
    return .ok(Plan{.kind=plan.kind,.groups=plan.groups,.suffix=plan.suffix});
}
