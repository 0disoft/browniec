module value_walk_work;
import value_ir as values;
import value_source_functions as functions;
import value_source_context as context;
import functions as signatures;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;
// The owner pins one candidate. These are source traversal continuations;
// semantic/ownership/metadata children are explicit requests, never charged
// as if a complete child body were one bounded visit.
pub struct Outcome { bool terminal; bool produced; }
pub fn Outcome outcome(bool terminal,bool produced){return Outcome{.terminal=terminal,.produced=produced};}
pub struct Scope { usize depth; usize mark; u8 phase; u8 request; bool yields; bool terminal; bool produced; bool done; }
pub fn Scope scope(usize depth,bool yields){return Scope{.depth=depth,.mark=0,.phase=0,.request=0,.yields=yields,.terminal=false,.produced=false,.done=false};}
pub fn Result<bool,errors::Error> scope_result(ref Scope w){if(!w.done){return .err(errors::make(5,0));}return .ok(w.terminal);}
pub fn Result<usize,errors::Error> resume_scope(ref mut Scope w,u8 request,Outcome result){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,0));}
    if(request==1){w.terminal=result.terminal;w.produced=result.produced;if(result.produced){w.phase=2;}}
    w.request=0;return .ok(0);
}
pub fn Result<bool,errors::Error> advance_scope(ref lexer::State s,usize names,ref mut Scope w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    if(w.phase==0){if(w.depth>32){return .err(errors::make(4,s.begin));}w.mark=names;w.phase=1;return .ok(false);}
    if(w.phase==1){if(s.kind==125){w.phase=2;return .ok(false);}if(w.terminal || s.kind==0){return .err(errors::make(2,s.begin));}
        w.request=1;return .ok(false);}
    if(w.phase==2){if(w.yields && !w.terminal && !w.produced){return .err(errors::make(3,s.begin));}
        w.phase=3;if(!w.terminal){w.request=2;}return .ok(false);}
    if(w.phase==3){w.done=true;return .ok(true);}return .err(errors::make(5,s.begin));
}
pub struct Program { tokens::State token; usize row; u8 phase; u8 request; bool terminal; bool lexing; bool done; }
pub fn Program program(){return Program{.token=tokens::begin(lexer::empty()),.row=0,.phase=0,.request=0,.terminal=false,.lexing=false,.done=false};}
pub fn Result<usize,errors::Error> resume_program(ref mut Program w,u8 request,bool terminal){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,0));}w.request=0;if(request==3){w.terminal=terminal;}return .ok(w.row);
}
pub fn Result<bool,errors::Error> advance_program(ref u8[] source,ref mut values::Program unit,ref signatures::Table table,ref functions::Plan plan,
    ref mut lexer::State cursor,ref mut Program w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*cursor=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*cursor=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,cursor.begin)?){return .ok(false);}
    let usize f=w.row;
    if(w.phase==0){unit.body.function_count=table.count;unit.body.entry=table.entry;w.phase=1;return .ok(false);}
    if(w.phase==1){if(f==table.count){w.row=0;w.request=1;w.phase=2;return .ok(false);}
        let usize result=plan.results[f];let u8 tag=if(result==0){13}else if(result==66){0}else if(unit.catalog.nodes[result-1].kind==1){unit.catalog.nodes[result-1].first}else{0};
        if(result==66){unit.results[f]=context::byte(16+table.return_slice_inputs[f] as usize);}unit.body.return_types[f]=tag;w.row+=1;return .ok(false);}
    if(w.phase==2){if(f==table.count){w.done=true;return .ok(true);}w.request=2;w.phase=3;return .ok(false);}
    if(w.phase==3){*cursor=lexer::empty();cursor.cursor=table.bodies[f];w.token=tokens::begin(*cursor);w.lexing=true;w.phase=4;return .ok(false);}
    if(w.phase==4){w.request=3;w.phase=5;return .ok(false);}
    if(w.phase==5){if(cursor.begin!=table.body_ends[f]){return .err(errors::make(2,cursor.begin));}
        if(!w.terminal){if(plan.results[f]!=0){return .err(errors::make(2,cursor.begin));}w.request=4;}w.phase=6;return .ok(false);}
    if(w.phase==6){w.request=5;w.phase=7;return .ok(false);}
    if(w.phase==7){w.row+=1;w.phase=2;return .ok(false);}return .err(errors::make(5,cursor.begin));
}
