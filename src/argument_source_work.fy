module argument_source_work;
import lexer as lexer;
import lexer_work as tokens;
import ir as ir;
import array_source as arrays;
import cells as cells;
import errors as errors;
import metadata_budget as budget;
// Repeated fixed array (1), temporary slice backing (2), slice endpoints (3).
// Requests 1/2 explicitly delegate expression evaluation / completed acquisition.
pub struct State { tokens::State token; usize at; usize length; usize function;
    usize root; usize parent; usize lo; usize hi; usize value; usize destination;
    u8 element; u8 mode; u8 phase; u8 request; bool exclusive; bool waiting; bool done; }
pub fn State begin(lexer::State s,u8 mode,u8 element,usize length,usize function,usize at){
    return State{.token=tokens::begin(s),.at=at,.length=length,.function=function,
        .root=16,.parent=16,.lo=0,.hi=0,.value=0,.destination=16,.element=element,
        .mode=mode,.phase=0,.request=0,.exclusive=false,.waiting=false,.done=false};
}
pub fn Result<usize,errors::Error> resume(ref mut State w,u8 request,usize value){
    if(w.done || request==0 || w.request!=request){return .err(errors::make(5,w.at));}
    w.request=0;w.value=value;return .ok(value);
}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){
    if(s.kind!=kind){return .err(errors::make(2,s.begin));}w.phase=phase;w.token=tokens::begin(*s);w.waiting=true;return .ok(false);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.waiting=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.mode==3){
        if(w.phase==0){if(s.kind==44 || s.kind==41){w.phase=20;return .ok(false);}return take(w,s,91,1);}
        if(w.phase==1){if(s.kind==46){w.value=ir::integer(p,0,12,w.at)?;}else{w.request=1;}w.phase=2;return .ok(false);}
        if(w.phase==2){w.lo=w.value;if(p.types[w.lo]!=12){return .err(errors::make(3,w.at));}return take(w,s,46,3);}
        if(w.phase==3){return take(w,s,46,4);}
        if(w.phase==4){if(s.kind==93){w.value=if(w.parent<16){ir::slice_length(p,w.parent,w.at)?}else{arrays::length_value(p,w.root,w.at)?};}
            else{w.request=1;}w.phase=5;return .ok(false);}
        if(w.phase==5){w.hi=w.value;if(p.types[w.hi]!=12){return .err(errors::make(3,w.at));}return take(w,s,93,6);}
        if(w.phase==6){if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}w.phase=22;return .ok(false);}
        if(w.phase==20){w.lo=ir::integer(p,0,12,w.at)?;w.phase=21;return .ok(false);}
        if(w.phase==21){w.hi=arrays::length_value(p,w.root,w.at)?;w.phase=22;return .ok(false);}
        if(w.phase==22){w.request=2;w.phase=23;return .ok(false);}
        if(w.phase==23){w.done=true;return .ok(true);}
        return .err(errors::make(5,w.at));
    }
    if(w.phase==0){return take(w,s,91,1);}
    if(w.phase==1){w.request=1;w.phase=2;return .ok(false);}
    if(w.phase==2){if(p.types[w.value]!=w.element){return .err(errors::make(3,w.at));}return take(w,s,59,3);}
    if(w.phase==3){if(s.kind!=1 || s.value<1 || s.value>4096){return .err(errors::make(3,s.begin));}
        w.hi=cells::unpack(s.value,s.begin)?;w.token=tokens::begin(*s);w.waiting=true;w.phase=4;return .ok(false);}
    if(w.phase==4){if(w.mode==1 && w.hi!=w.length){return .err(errors::make(3,w.at));}return take(w,s,93,5);}
    if(w.phase==5){if(w.mode==1 && s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
        w.destination=ir::array_in(p,w.function,w.element,w.hi,w.exclusive,w.at)?;w.phase=6;return .ok(false);}
    if(w.phase==6){let usize initialized=ir::array_init(p,w.destination,w.value,w.at)?;w.value=w.destination;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
