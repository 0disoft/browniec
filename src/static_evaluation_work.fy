module static_evaluation_work;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import static_builders as builders;
import array_source as arrays;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
// The owner has acquired/published a view and any retained parents. Only the
// index is an expression child; scalar emission and each cleanup row resume.
pub struct State { tokens::State token; usize site; usize at; usize outer; usize depth;
    usize row; usize value; usize visits; u8 phase; u8 request; bool length; bool owned; bool captured; bool lexing; bool done; }
pub fn State begin(usize site,usize at,usize depth,usize outer,bool owned,bool captured){return State{.token=tokens::begin(lexer::empty()),
    .site=site,.at=at,.outer=outer,.depth=depth,.row=0,.value=0,.visits=0,.phase=0,.request=0,.length=false,.owned=owned,.captured=captured,.lexing=false,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,usize value){if(w.done || w.request!=1){return .err(errors::make(5,w.at));}w.request=0;w.value=value;return .ok(value);}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){if(s.kind!=kind){return .err(errors::make(2,s.begin));}
    w.phase=phase;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref locals::Table names,
    ref mut State w,ref mut budget::State meter){if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){w.length=s.kind==46;return take(w,s,if(s.kind==46){46}else{91},if(s.kind==46){1}else{2});}
    if(w.phase==1){if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"len")){return .err(errors::make(2,s.begin));}return take(w,s,2,5);}
    if(w.phase==2){w.request=1;w.phase=3;return .ok(false);}
    if(w.phase==3){if(p.types[w.value]!=12){return .err(errors::make(3,w.at));}return take(w,s,93,5);}
    if(w.phase==5){w.value=builders::scalar(p,w.site,w.value,w.length,w.at)?;w.row=names.count;w.phase=6;return .ok(false);}
    if(w.phase==6){if(w.captured && w.row>w.outer){let usize row=w.row-1;let usize dropped=arrays::release_at(names,p,row,w.at)?;w.row=row;return .ok(false);}
        if(w.owned && !w.captured){let usize closed=builders::close(p,w.site,w.at)?;}w.done=true;return .ok(true);}
    return .err(errors::make(5,s.begin));
}
