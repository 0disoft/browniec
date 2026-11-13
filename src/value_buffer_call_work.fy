module value_buffer_call_work;
import value_source_context as context;
import value_buffer_source as buffers;
import value_view_source as views;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;
// Requests: expression, type, first/second loan, scalar, shadow lookup,
// view capture, view copy, finalization and empty construction. No IR publication.
pub struct State { tokens::State token; context::Value child; buffers::Reference first; buffers::Reference second;
    usize at; usize prefix_at; usize exact; usize depth; usize type; usize expected; usize number; usize index; usize value;
    u8 phase; u8 request; u8 op; u8 kind; u8 tag; bool writing; bool lexing; bool done; }
pub fn State begin(usize exact,usize depth,usize at){return State{.token=tokens::begin(lexer::empty()),.child=context::nothing(),.first=buffers::none(),.second=buffers::none(),
    .at=at,.prefix_at=at,.exact=exact,.depth=depth,.type=64,.expected=64,.number=0,.index=0,.value=0,.phase=0,.request=0,.op=0,.kind=0,.tag=0,.writing=false,.lexing=false,.done=false};}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] text){return s.kind==2 && lexer::equal(source[s.begin..s.end],text);}
fn Result<bool,errors::Error> ask(ref mut State w,u8 request,u8 phase){w.request=request;w.phase=phase;return .ok(false);}
fn Result<bool,errors::Error> take(ref lexer::State s,ref mut State w,u8 kind,u8 phase){if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}
    w.token=tokens::begin(*s);w.lexing=true;w.phase=phase;return .ok(false);}
pub fn Result<usize,errors::Error> resume(ref mut State w,u8 request,context::Value value,usize number){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}w.request=0;w.child=value;w.number=number;return .ok(number);}
pub fn Result<context::Value,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.child);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}let u8 phase=w.phase;
    if(phase==0){return ask(w,7,1);}
    if(phase==1){if(w.number!=64){return .err(errors::make(3,w.at));}if(word(source,s,b"brownie")){return take(s,w,0,2);}w.phase=5;return .ok(false);}
    if(phase==2){return take(s,w,58,3);}if(phase==3){return take(s,w,58,5);}
    if(phase==5){if(!word(source,s,b"bytes")){return .err(errors::make(2,s.begin));}return take(s,w,0,6);}
    if(phase==6){return take(s,w,58,7);}if(phase==7){return take(s,w,58,8);}
    if(phase==8){w.op=if(word(source,s,b"empty")){95}else if(word(source,s,b"len")){99}else if(word(source,s,b"read")){100}else if(word(source,s,b"write")){101}
        else if(word(source,s,b"push")){102}else if(word(source,s,b"reserve")){103}else if(word(source,s,b"append")){104}else if(word(source,s,b"copy")){105}else if(word(source,s,b"view")){106}else{0};
        if(w.op==0){return .err(errors::make(3,s.begin));}return take(s,w,0,9);}
    if(phase==9){return take(s,w,40,10);}
    if(phase==10){if(w.op==95){return take(s,w,41,80);}w.kind=4;w.tag=0;return ask(w,2,11);}
    if(phase==11){w.type=w.number;w.writing=w.op>=101 && w.op<=104;w.phase=12;return .ok(false);}
    if(phase==12 || phase==21){w.prefix_at=s.begin;if(!word(source,s,b"ref")){return .err(errors::make(3,s.begin));}return take(s,w,0,if(phase==12){13}else{22});}
    if(phase==13){if(w.writing!=word(source,s,b"mut")){return .err(errors::make(3,w.prefix_at));}if(w.writing){return take(s,w,0,14);}w.phase=14;return .ok(false);}
    if(phase==14){w.expected=if(w.op==105){64}else{w.type};return ask(w,1,15);}
    if(phase==15){if(w.child.bottom){if(w.op!=99 && w.op!=105 && w.op!=106){return .err(errors::make(3,w.at));}return take(s,w,41,90);}
        if(w.op==105 && views::reference(w.child)){return take(s,w,41,60);}return ask(w,3,16);}
    if(phase==16){if(w.op==99 || w.op==105 || w.op==106){return take(s,w,41,70);}return take(s,w,44,20);}
    if(phase==20){if(w.op==104){w.phase=21;return .ok(false);}w.kind=1;w.tag=if(w.op==102){10}else{12};return ask(w,2,25);}
    if(phase==22){if(word(source,s,b"mut")){return .err(errors::make(3,w.prefix_at));}w.expected=w.type;return ask(w,1,23);}
    if(phase==23){if(w.child.bottom){return take(s,w,41,90);}return ask(w,4,24);}
    if(phase==24){return take(s,w,41,70);}
    if(phase==25 || phase==31){w.expected=w.number;return ask(w,1,if(phase==25){26}else{32});}
    if(phase==26 || phase==32){if(w.child.bottom){if(phase==26 && w.op==101){return .err(errors::make(3,w.at));}return take(s,w,41,90);}return ask(w,5,if(phase==26){27}else{33});}
    if(phase==27){let u8 op=w.op;if(op==100 || op==101){w.index=w.number;}else{w.value=w.number;}return take(s,w,if(op==101){44}else{41},if(op==101){30}else{70});}
    if(phase==30){w.kind=1;w.tag=10;return ask(w,2,31);}
    if(phase==33){w.value=w.number;return take(s,w,41,70);}
    if(phase==60){return ask(w,8,61);}if(phase==61){return ask(w,9,81);}
    if(phase==70){return ask(w,10,81);}if(phase==80){return ask(w,11,81);}
    if(phase==81 || phase==90){w.done=true;return .ok(true);}return .err(errors::make(5,s.begin));
}
