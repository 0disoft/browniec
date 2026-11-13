module value_call_source_work;
import value_source_context as context;
import value_ir as values;
import value_source_functions as functions;
import functions as signatures;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;
pub struct Arguments { tokens::State token; context::Value value; usize[8] arguments; usize[8] captures;
    usize target; usize at; usize depth; usize row; usize exact; usize number; u8 phase; u8 request; bool extended; bool lexing; bool done; }
pub fn Arguments arguments(usize target,usize at,usize depth){return Arguments{.token=tokens::begin(lexer::empty()),.value=context::nothing(),.arguments=[0;8],.captures=[16;8],
    .target=target,.at=at,.depth=depth,.row=0,.exact=64,.number=0,.phase=0,.request=0,.extended=false,.lexing=false,.done=false};}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn Result<bool,errors::Error> arg_take(ref lexer::State s,ref mut Arguments w,u8 kind,u8 phase){if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}w.token=tokens::begin(*s);w.lexing=true;w.phase=phase;return .ok(false);}
pub fn Result<usize,errors::Error> resume_argument(ref mut Arguments w,u8 request,context::Value value,usize number){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}w.request=0;w.value=value;w.number=number;return .ok(number);}
pub fn Result<context::Value,errors::Error> arguments_result(ref Arguments w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<bool,errors::Error> advance_arguments(ref u8[] source,ref mut lexer::State s,ref values::Program unit,ref signatures::Table table,ref functions::Plan plan,ref mut Arguments w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}let usize target=w.target;let usize row=w.row;
    if(w.phase==0){if(target>=table.count){return .err(errors::make(3,w.at));}return arg_take(s,w,40,1);}
    if(w.phase==1){if(row==table.arities[target]){return arg_take(s,w,41,8);}if(row!=0){return arg_take(s,w,44,2);}w.phase=2;return .ok(false);}
    if(w.phase==2){w.exact=plan.parameters[target*8+row]-1;if(w.exact==65){if(!word(source,s,b"ref")){return .err(errors::make(2,s.begin));}return arg_take(s,w,0,3);}w.phase=4;return .ok(false);}
    if(w.phase==3){if(word(source,s,b"mut")){return .err(errors::make(3,s.begin));}w.phase=4;return .ok(false);}
    if(w.phase==4){w.request=1;w.phase=5;return .ok(false);}
    if(w.phase==5){if(w.value.bottom){if(row+1!=table.arities[target]){return .err(errors::make(3,s.begin));}return arg_take(s,w,41,9);}w.request=2;w.phase=6;return .ok(false);}
    if(w.phase==6){let usize id=w.number;if(w.exact==65){w.arguments[row]=224+id;w.captures[row]=17+id;w.extended=true;}
        else if(unit.catalog.nodes[w.exact].kind==1){w.arguments[row]=id;}else{w.arguments[row]=208+id;w.captures[row]=id;w.extended=true;}w.row+=1;w.phase=1;return .ok(false);}
    if(w.phase==8){w.request=3;w.phase=10;return .ok(false);}if(w.phase==9 || w.phase==10){w.done=true;return .ok(true);}return .err(errors::make(5,s.begin));
}
pub struct Constructor { tokens::State token; context::Value value; usize exact; usize wrapper; usize payload; usize built; usize number; usize at; usize depth; usize expected;
    u8 phase; u8 request; bool some; bool none; bool ok; bool err; bool lexing; bool done; }
pub fn Constructor constructor(usize exact,usize depth){return Constructor{.token=tokens::begin(lexer::empty()),.value=context::nothing(),.exact=exact,.wrapper=exact,.payload=16,.built=0,.number=0,.at=0,.depth=depth,.expected=64,
    .phase=0,.request=0,.some=false,.none=false,.ok=false,.err=false,.lexing=false,.done=false};}
fn Result<bool,errors::Error> ctor_take(ref lexer::State s,ref mut Constructor w,u8 kind,u8 phase){if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}w.token=tokens::begin(*s);w.lexing=true;w.phase=phase;return .ok(false);}
pub fn Result<usize,errors::Error> resume_constructor(ref mut Constructor w,u8 request,context::Value value,usize number){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}w.request=0;w.value=value;w.number=number;return .ok(number);}
pub fn Result<context::Value,errors::Error> constructor_result(ref Constructor w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<bool,errors::Error> advance_constructor(ref u8[] source,ref mut lexer::State s,ref values::Program unit,ref mut Constructor w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}let usize exact=w.exact;
    if(w.phase==0){w.at=s.begin;return ctor_take(s,w,0,1);}
    if(w.phase==1){w.some=word(source,s,b"some");w.none=word(source,s,b"none");w.ok=word(source,s,b"ok");w.err=word(source,s,b"err");
        if(!w.some && !w.none && !w.ok && !w.err){return .err(errors::make(3,w.at));}if(exact==64 && !w.some){return .err(errors::make(3,w.at));}
        if(exact!=64 && (exact>=unit.catalog.count || unit.catalog.nodes[exact].kind!=if(w.some || w.none){5}else{6})){return .err(errors::make(3,w.at));}return ctor_take(s,w,0,2);}
    if(w.phase==2){if(w.none){w.request=4;w.phase=9;return .ok(false);}return ctor_take(s,w,40,3);}
    if(w.phase==3){w.expected=if(exact==64){64}else if(w.err){unit.catalog.nodes[exact].second as usize}else{unit.catalog.nodes[exact].first as usize};w.request=1;w.phase=4;return .ok(false);}
    if(w.phase==4){return ctor_take(s,w,41,5);}
    if(w.phase==5){if(w.value.bottom){w.done=true;return .ok(true);}if(exact==64){w.request=2;w.phase=6;return .ok(false);}w.phase=7;return .ok(false);}
    if(w.phase==6){w.wrapper=w.number;w.phase=7;return .ok(false);}
    if(w.phase==7){w.request=3;w.phase=8;return .ok(false);}
    if(w.phase==8){w.payload=w.number;w.request=4;w.phase=9;return .ok(false);}
    if(w.phase==9){w.built=w.number;w.phase=10;if(w.payload!=16){w.request=5;}return .ok(false);}
    if(w.phase==10){w.value=context::owned(w.wrapper,w.built);w.done=true;return .ok(true);}return .err(errors::make(5,s.begin));
}
