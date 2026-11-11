module source_state_work;
import source_context as context;
import source_context_check_work as checking;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
// Resume raw context::state without a synchronous context/name validation loop.
pub struct State { checking::State check; lexer::State result; usize offset; usize row;
    usize caller; usize start; usize end; u8 phase; bool text; bool done; }
pub fn State begin(usize offset){return State{.check=checking::empty(),.result=lexer::empty(),
    .offset=offset,.row=0,.caller=0,.start=0,.end=0,.phase=0,.text=false,.done=false};}
fn usize owner(ref context::Table scope,usize at){var usize i=0;
    while(i<scope.modules){if(at<scope.ends[i] as usize){return i;}i+=1;}return 16;}
pub fn Result<lexer::State,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.offset));}return .ok(w.result);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref context::Table scope,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==1){let bool done=checking::advance(source,scope,ref mut w.check,meter)?;
        if(done){if(!w.check.result){return .err(errors::make(5,w.offset));}w.phase=2;}return .ok(false);}
    if(!budget::admit(meter,4096,w.offset)?){return .ok(false);}
    if(w.phase==0){if(scope.modules==0){w.result.cursor=w.offset;w.done=true;return .ok(true);}w.phase=1;return .ok(false);}
    if(w.phase==2){if(w.offset>=source.len){return .err(errors::make(5,w.offset));}
        if(w.row==scope.modules){return .err(errors::make(5,w.offset));}
        let usize end=scope.ends[w.row] as usize;
        if(w.offset<end){w.caller=w.row;w.start=if(w.row==0){0}else{scope.ends[w.row-1] as usize};w.end=end;w.row=0;w.phase=3;}
        else{w.row+=1;}return .ok(false);}
    if(w.phase==3){if(w.row==scope.imports){w.phase=4;return .ok(false);}
        let u32 item=scope.aliases[w.row];let usize a=context::begin(item);let usize b=context::end(item);
        if(owner(scope,a)==w.caller && lexer::equal(source[a..b],b"text")){w.text=true;w.phase=4;}
        else{w.row+=1;}return .ok(false);}
    if(w.phase==4){let lexer::State result=lexer::scoped(source,w.start,w.end,w.text)?;
        w.result=result;w.result.cursor=w.offset;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.offset));
}
