module call_operand_work;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import functions as functions;
import ir as ir;
import array_source as arrays;
import reference_call_source as references;
import metadata_budget as budget;
import errors as errors;
// Scalar-result CALLs with capturing formals. Each scalar or aggregate argument
// is an explicit child; the owner pins this lexical capture table until cleanup.
pub struct State { locals::Table names; tokens::State token; usize[8] arguments;
    usize target; usize at; usize depth; usize outer; usize arity; usize parameter;
    usize length; usize record; usize value; usize pc; usize row; u8 tag; u8 phase;
    u8 request; bool sliced; bool scalar; bool prefix; bool lexing; bool done; }
pub struct Frame { tokens::State token; usize names_count; usize names_function; usize names_pending; usize target; usize at; usize depth; usize outer; usize arity; usize parameter; usize length; usize record; usize value; usize pc; usize row; u8 tag; u8 phase; u8 request; bool sliced; bool scalar; bool prefix; bool lexing; bool done; }
pub fn Frame empty_frame(){return Frame{.token=tokens::begin(lexer::empty()),.names_count=0,.names_function=0,.names_pending=0,.target=0,.at=0,.depth=0,.outer=0,.arity=0,.parameter=0,.length=0,.record=0,.value=0,.pc=0,.row=0,.tag=0,.phase=0,.request=0,.sliced=false,.scalar=false,.prefix=false,.lexing=false,.done=false};}
pub fn Frame framing(ref State w){return Frame{.token=w.token,.names_count=w.names.count,.names_function=w.names.function,.names_pending=w.names.pending_places,.target=w.target,.at=w.at,.depth=w.depth,.outer=w.outer,.arity=w.arity,.parameter=w.parameter,.length=w.length,.record=w.record,.value=w.value,.pc=w.pc,.row=w.row,.tag=w.tag,.phase=w.phase,.request=w.request,.sliced=w.sliced,.scalar=w.scalar,.prefix=w.prefix,.lexing=w.lexing,.done=w.done};}
pub fn void restore(ref mut State w,Frame f){w.token=f.token;w.names.count=f.names_count;w.names.function=f.names_function;w.names.pending_places=f.names_pending;w.target=f.target;w.at=f.at;w.depth=f.depth;w.outer=f.outer;w.arity=f.arity;w.parameter=f.parameter;w.length=f.length;w.record=f.record;w.value=f.value;w.pc=f.pc;w.row=f.row;w.tag=f.tag;w.phase=f.phase;w.request=f.request;w.sliced=f.sliced;w.scalar=f.scalar;w.prefix=f.prefix;w.lexing=f.lexing;w.done=f.done;}
pub fn State empty(){var locals::Table names=locals::empty();return begin(ref names,lexer::empty(),0,0,0);}
// Copy into caller-owned scratch; no aggregate-valued borrow escapes the bank.
pub fn Result<usize,errors::Error> names_into(ref State w,ref mut locals::Table names){*names=locals::snapshot(ref w.names);return .ok(0);}
pub fn Result<usize,errors::Error> argument(ref mut State w,ref locals::Table names,usize value,bool prefix){
    if(w.done || w.request!=2){return .err(errors::make(5,w.at));}
    w.names=locals::snapshot(names);w.prefix=prefix;return resume(w,2,value);
}
pub fn State begin(ref locals::Table names,lexer::State token,usize target,usize at,usize depth){
    return State{.names=locals::snapshot(names),.token=tokens::begin(token),.arguments=[0;8],
        .target=target,.at=at,.depth=depth,.outer=names.count,.arity=0,.parameter=128,.length=0,
        .record=0,.value=0,.pc=0,.row=0,.tag=0,.phase=0,.request=0,.sliced=false,.scalar=false,
        .prefix=true,.lexing=false,.done=false};
}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,u8 request,usize value){
    if(w.done || request==0 || w.request!=request){return .err(errors::make(5,w.at));}
    w.request=0;w.value=value;return .ok(value);
}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){
    if(s.kind!=kind){return .err(errors::make(2,s.begin));}w.phase=phase;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref functions::Table signatures,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    let usize target=w.target;let usize arity=w.arity;let usize value=w.value;
    if(w.phase==0){if(w.depth>32){return .err(errors::make(4,w.at));}return take(w,s,40,1);}
    if(w.phase==1){if(s.kind==41){w.phase=5;return .ok(false);}if(arity>=8){return .err(errors::make(4,s.begin));}
        let bool known=arity<signatures.arities[target];let usize parameter=target*8+arity;w.parameter=if(known){parameter}else{128};
        w.tag=if(known){signatures.param_types[parameter]}else{0};w.length=if(known){signatures.param_lengths[parameter]}else{0};
        w.record=if(known){signatures.param_records[parameter] as usize}else{0};w.sliced=known && signatures.param_slices[parameter];
        if(!known || w.sliced){w.prefix=false;}w.scalar=!w.sliced && w.length==0 && w.record==0;
        w.request=if(w.scalar){1}else{2};w.phase=2;return .ok(false);}
    if(w.phase==2){if(w.scalar && (arity>=signatures.arities[target] || p.types[value]!=w.tag)){return .err(errors::make(3,w.at));}
        w.arguments[arity]=value;w.arity=arity+1;w.phase=3;return .ok(false);}
    if(w.phase==3){if(s.kind==41){w.phase=5;return .ok(false);}return take(w,s,44,4);}
    if(w.phase==4){if(s.kind==41){return .err(errors::make(2,s.begin));}w.phase=1;return .ok(false);}
    if(w.phase==5){if(arity!=signatures.arities[target]){return .err(errors::make(3,w.at));}return take(w,s,41,6);}
    if(w.phase==6){let usize pc=p.count;w.value=ir::call(p,target,ref w.arguments[..arity],w.at)?;w.pc=pc;w.phase=7;return .ok(false);}
    if(w.phase==7){if(references::target(signatures,target)){let usize promoted=references::promote(p,w.pc,w.at)?;}
        w.row=w.names.count;w.phase=8;return .ok(false);}
    if(w.phase==8){if(w.row==w.outer){w.done=true;return .ok(true);}let usize row=w.row-1;
        let usize released=arrays::release_at(ref w.names,p,row,w.at)?;w.row=row;return .ok(false);}
    return .err(errors::make(5,w.at));
}
