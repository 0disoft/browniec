module value_expression_work;
import value_source_context as context;
import value_source_boolean as boolean;
import value_source_propagation as propagation;
import value_ir as values;
import types as types;
import type_parse_work as annotations;
import lexer as lexer;
import lexer_work as tokens;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
// Modes: precedence expression, casts, postfix atom, primary/unary/group.
// Recursive operands, ownership and CFG services are explicit children.
pub struct State { context::Value left; context::Value child; tokens::State token; annotations::State annotation;
    boolean::Pending pending; propagation::Expanded expanded; usize exact; usize depth; usize at; usize a; usize number;
    usize expected; usize child_depth; u8 child_mode; u8 child_minimum; u8 minimum; u8 mode; u8 phase; u8 resume;
    u8 request; u8 operation; u8 priority; u8 tag; bool lexing; bool typing; bool done; }
pub fn State begin(usize exact,u8 minimum,usize depth,u8 mode){return State{.left=context::nothing(),.child=context::nothing(),
    .token=tokens::begin(lexer::empty()),.annotation=annotations::begin(lexer::empty()),.pending=boolean::Pending{.slot=0,.guard=0,.entry=0,.pool=0},
    .expanded=propagation::Expanded{.payload=0,.exact=0},.exact=exact,.depth=depth,.at=0,.a=0,.number=0,.expected=64,.child_depth=0,.child_mode=0,.child_minimum=1,
    .minimum=minimum,.mode=mode,.phase=0,.resume=0,.request=0,.operation=0,.priority=0,.tag=0,.lexing=false,.typing=false,.done=false};}
pub fn Result<context::Value,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.left);}
fn Result<bool,errors::Error> finish(ref mut State w,context::Value value){w.left=value;w.done=true;return .ok(true);}
fn Result<bool,errors::Error> ask(ref mut State w,u8 request,u8 phase){w.request=request;w.phase=phase;return .ok(false);}
fn Result<bool,errors::Error> child(ref mut State w,u8 mode,usize exact,u8 minimum,usize depth,u8 phase){w.child_mode=mode;w.expected=exact;w.child_minimum=minimum;w.child_depth=depth;return ask(w,1,phase);}
fn Result<bool,errors::Error> take(ref lexer::State s,ref mut State w,u8 kind,u8 phase){if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}
    w.token=tokens::begin(*s);w.lexing=true;w.phase=phase;return .ok(false);}
pub fn Result<usize,errors::Error> resume_scalar(ref mut State w,u8 request,usize result){if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}w.number=result;w.request=0;return .ok(result);}
pub fn Result<usize,errors::Error> resume_value(ref mut State w,u8 request,context::Value value){if(w.done || request==0 || request!=w.request){return .err(errors::make(5,w.at));}w.child=value;w.request=0;return .ok(0);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut values::Program unit,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(w.typing){let Result<bool,errors::Error> result=annotations::advance(source,ref mut w.annotation,meter);*s=annotations::observed(ref w.annotation);
        let bool done=result?;if(done){w.tag=annotations::prepared(ref w.annotation)?;w.typing=false;}return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}let u8 phase=w.phase;let usize depth=w.depth;let usize exact=w.exact;
    if(phase==0){w.at=s.begin;if((w.mode==0 || w.mode==3) && depth>32){return .err(errors::make(4,s.begin));}
        if(w.mode==0){let u8 minimum=w.minimum;return child(w,1,exact,minimum,depth,1);}w.phase=if(w.mode==1){20}else if(w.mode==2){40}else{60};return .ok(false);}
    if(phase==1){w.left=w.child;w.phase=2;return .ok(false);}
    if(phase==2){let u8 priority=context::precedence(s.kind);if(priority<w.minimum || priority==0){let context::Value result=context::expected(w.left,exact,s.begin)?;return finish(w,result);}
        w.operation=s.kind;w.priority=priority;w.at=s.begin;return ask(w,8,3);}
    if(phase==3){w.a=w.number;return take(s,w,0,4);}
    if(phase==4){if(w.operation==132 || w.operation==133){return ask(w,10,5);}let usize expected=w.left.exact;let u8 minimum=w.priority+1;return child(w,0,expected,minimum,depth+1,6);}
    if(phase==5){let u8 minimum=w.priority+1;return child(w,0,64,minimum,depth+1,6);}
    if(phase==6){if(w.child.bottom){if(w.operation==132 || w.operation==133){return ask(w,12,8);}let context::Value result=w.child;return finish(w,result);}return ask(w,8,7);}
    if(phase==7){if(w.operation==132 || w.operation==133){return ask(w,11,8);}
        if(w.left.exact!=w.child.exact || (!types::integer(unit.body.types[w.a]) && w.operation!=128 && w.operation!=129)){return .err(errors::make(3,w.at));}
        let usize result=ir::emit(ref mut unit.body,context::opcode(w.operation),w.a,w.number,w.at)?;w.a=result;
        if(w.operation==128 || w.operation==129 || w.operation==60 || w.operation==62 || w.operation==130 || w.operation==131){w.tag=2;return ask(w,9,9);}
        w.left=context::scalar(w.left.exact,result);w.phase=2;return .ok(false);}
    if(phase==8){w.left=context::scalar(w.left.exact,w.number);w.phase=2;return .ok(false);}
    if(phase==9){w.left=context::scalar(w.number,w.a);w.phase=2;return .ok(false);}
    if(phase==20){return ask(w,6,21);}
    if(phase==21){let usize expected=if(w.number==1){64}else{exact};return child(w,2,expected,1,depth,22);}
    if(phase==22){w.left=w.child;w.phase=23;return .ok(false);}
    if(phase==23){if(!word(source,s,b"as")){let context::Value result=w.left;return finish(w,result);}w.at=s.begin;return take(s,w,0,24);}
    if(phase==24){w.annotation=annotations::begin(*s);w.typing=true;w.phase=25;return .ok(false);}
    if(phase==25){if(!types::scalar(w.tag)){return .err(errors::make(3,w.at));}if(w.left.bottom){w.phase=23;return .ok(false);}return ask(w,8,26);}
    if(phase==26){w.a=ir::widen(ref mut unit.body,w.number,w.tag,w.at)?;return ask(w,9,29);}
    if(phase==29){w.left=context::scalar(w.number,w.a);w.phase=23;return .ok(false);}
    if(phase==40){return ask(w,7,41);}
    if(phase==41){let usize expected=if(w.number==1){64}else{exact};return child(w,3,expected,1,depth,42);}
    if(phase==42){w.left=w.child;w.phase=43;return .ok(false);}
    if(phase==43){if(s.kind!=46 && s.kind!=63 && s.kind!=91){let context::Value result=w.left;return finish(w,result);}if(w.left.bottom){return .err(errors::make(3,s.begin));}
        if(s.kind==46){return ask(w,13,44);}w.phase=44;w.number=0;return .ok(false);}
    if(phase==44){if(s.kind==46 && w.number==1){let context::Value result=w.left;return finish(w,result);}
        if(s.kind==91){return ask(w,14,45);}if(s.kind==46){return ask(w,15,45);}w.at=s.begin;return take(s,w,0,46);}
    if(phase==45){w.left=w.child;w.phase=43;return .ok(false);}
    if(phase==46){if(w.left.nothing || !w.left.typed){return .err(errors::make(3,w.at));}return ask(w,17,47);}
    if(phase==47){w.a=w.number;return ask(w,16,48);}
    if(phase==48){if(unit.catalog.nodes[w.expanded.exact].kind==1){return ask(w,18,49);}w.left=context::owned(w.expanded.exact,w.expanded.payload);w.phase=43;return .ok(false);}
    if(phase==49){w.a=w.number;return ask(w,19,51);}
    if(phase==51){w.left=context::scalar(w.expanded.exact,w.a);w.phase=43;return .ok(false);}
    if(phase==60){if(word(source,s,b"ref")){return take(s,w,0,64);}if(s.kind==40){return take(s,w,0,61);}
        if(s.kind==45 || s.kind==33 || s.kind==126){w.operation=s.kind;return take(s,w,0,66);}return ask(w,5,73);}
    if(phase==61){return child(w,0,exact,1,depth+1,62);}
    if(phase==62){w.left=w.child;return take(s,w,41,63);}
    if(phase==63){let context::Value result=w.left;return finish(w,result);}
    if(phase==64){if(word(source,s,b"mut")){return .err(errors::make(3,w.at));}return child(w,2,65,1,depth+1,65);}
    if(phase==65){let context::Value result=context::expected(w.child,exact,w.at)?;return finish(w,result);}
    if(phase==66){if(w.operation==45 && s.kind==1){let u8 tag=if(exact<unit.catalog.count && unit.catalog.nodes[exact].kind==1){unit.catalog.nodes[exact].first}else{1};
            if(!types::signed(tag)){return .err(errors::make(3,w.at));}
            if(s.min_magnitude || s.value==2147483648){if(s.min_magnitude && tag!=9){return .err(errors::make(3,w.at));}
                w.a=ir::integer(ref mut unit.body,if(s.min_magnitude){-9223372036854775808}else{-2147483648},tag,w.at)?;w.tag=tag;return ask(w,9,68);}}
        return child(w,2,exact,1,depth+1,70);}
    if(phase==68){w.left=context::scalar(w.number,w.a);return take(s,w,0,63);}
    if(phase==70){if(w.child.bottom){let context::Value result=w.child;return finish(w,result);}return ask(w,8,71);}
    if(phase==71){let u8 tag=unit.body.types[w.number];if((w.operation==33 && tag!=2) || (w.operation==45 && !types::signed(tag)) || (w.operation==126 && !types::integer(tag))){return .err(errors::make(3,w.at));}
        let usize result=ir::emit(ref mut unit.body,if(w.operation==45){7}else if(w.operation==33){10}else{27},w.number,0,w.at)?;let context::Value value=context::scalar(w.child.exact,result);return finish(w,value);}
    if(phase==73){let context::Value result=w.child;return finish(w,result);}return .err(errors::make(5,s.begin));
}
