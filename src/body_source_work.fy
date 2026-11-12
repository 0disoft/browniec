module body_source_work;
import lexer as lexer;
import lexer_work as tokens;
import ir as ir;
import locals as locals;
import loops as loops;
import array_source as arrays;
import place_source as places;
import patterns as patterns;
import types as types;
import errors as errors;
import metadata_budget as budget;

// Up to 65 admitted live frames plus two frames to preserve depth-error order.
// Private control continuation. The owner pins source, IR, names and loop state.
// Expressions/statements are explicit pending semantic children; they
// are never disguised as charged control stages. The owning adapter drains them
// synchronously until their own continuation kernels replace those boundaries.
pub struct Frame { usize depth; usize at; usize outer; usize a; usize b; usize c; usize d; usize e;
    u8 phase; u8 variant; bool terminal; bool flag; }
pub struct State { Frame[67] frames; tokens::State token; patterns::Pattern pattern;
    usize used; usize visits; usize value; u8 request; bool lexing; bool stopped; bool done; }
fn Frame frame(usize depth,u8 phase){return Frame{.depth=depth,.at=0,.outer=0,.a=0,.b=256,.c=256,.d=256,.e=0,
    .phase=phase,.variant=2,.terminal=false,.flag=false};}
pub fn State begin(usize depth,bool block){var State w=State{.frames=[frame(0,0);67],.token=tokens::begin(lexer::empty()),
    .pattern=patterns::Pattern{.variant=0,.begin=0,.end=0,.binding=false},.used=1,.visits=0,.value=0,
    .request=0,.lexing=false,.stopped=false,.done=false};w.frames[0]=frame(depth,if(block){1}else{0});return w;}
pub fn State statement(usize depth){var State w=begin(depth,false);w.frames[0].phase=10;return w;}
pub fn Frame current(ref State w){let ref Frame[] frames=ref w.frames;return frames[w.used-1];}
pub fn Result<bool,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,0));}return .ok(w.stopped);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn void finish(ref mut State w,bool stopped){w.used-=1;w.stopped=stopped;w.done=w.used==0;}
fn Result<bool,errors::Error> push(ref mut State w,usize depth,u8 phase,usize at){
    if(w.used>=67){return .err(errors::make(4,at));}let usize i=w.used;w.frames[i]=frame(depth,phase);w.used+=1;return .ok(false);}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 expected,u8 phase){
    if(expected!=0 && s.kind!=expected){return .err(errors::make(2,s.begin));}
    let usize i=w.used-1;w.frames[i].phase=phase;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);}
fn Result<bool,errors::Error> ask(ref mut State w,u8 request,u8 phase){let usize i=w.used-1;
    w.request=request;w.frames[i].phase=phase;return .ok(false);}
// Only the pinned owner completes a pending child, exactly once.
pub fn Result<usize,errors::Error> resume(ref mut State w,u8 request,usize value,bool stopped){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,0));}
    w.request=0;w.value=value;w.stopped=stopped;return .ok(value);}

fn Result<usize,errors::Error> target(ref mut ir::Program p,usize pc,usize at){let usize end=p.count;return ir::patch(p,pc,end,at);}
fn Result<usize,errors::Error> resolve(ref mut loops::State flow,ref mut ir::Program p,bool leave,usize at){let usize end=p.count;return loops::resolve(flow,p,leave,end,at);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table names,ref mut loops::State flow,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    let usize i=w.used-1;let Frame f=current(w);let usize value=w.value;let bool stopped=w.stopped;w.visits+=1;
    if(f.phase==0 || f.phase==2){
        if(f.depth>32){return .err(errors::make(4,s.begin));}
        if(s.kind==125){if(f.phase==0){finish(w,f.terminal);return .ok(w.done);}
            w.frames[i].a=names.count;w.frames[i].phase=if(f.terminal){5}else{4};return .ok(false);}
        if(s.kind==0 || f.terminal){return .err(errors::make(2,s.begin));}
        w.frames[i].phase=if(f.phase==0){7}else{3};return push(w,f.depth,10,s.begin);
    }
    if(f.phase==1){if(f.depth>32){return .err(errors::make(4,s.begin));}
        w.frames[i].outer=names.count;return take(w,s,123,2);}
    if(f.phase==3 || f.phase==7){w.frames[i].terminal=stopped;w.frames[i].phase=if(f.phase==7){0}else{2};return .ok(false);}
    if(f.phase==4){if(f.a==f.outer){w.frames[i].phase=5;return .ok(false);}
        let usize row=f.a-1;let usize released=arrays::release_at(names,p,row,s.begin)?;w.frames[i].a=row;return .ok(false);}
    if(f.phase==5){names.count=f.outer;return take(w,s,0,6);}
    if(f.phase==6){finish(w,f.terminal);return .ok(w.done);}
    if(f.phase==10){
        if(f.depth>32){return .err(errors::make(4,s.begin));}w.frames[i].at=s.begin;
        if(word(source,s,b"break") || word(source,s,b"continue")){w.frames[i].flag=word(source,s,b"break");return take(w,s,0,80);}
        if(word(source,s,b"return")){return ask(w,2,11);}
        if(word(source,s,b"if")){return take(w,s,0,20);}
        if(word(source,s,b"while")){return take(w,s,0,30);}
        if(word(source,s,b"for")){w.frames[i].outer=names.count;w.frames[i].d=p.call_count;return take(w,s,0,40);}
        if(word(source,s,b"switch")){return take(w,s,0,50);}
        if(s.kind==123){w.frames[i]=frame(f.depth+1,1);return .ok(false);}
        return ask(w,1,11);
    }
    if(f.phase==11){finish(w,stopped);return .ok(w.done);}
    // if / else-if: keep each branch's exact old patch/emission order.
    if(f.phase==20){return take(w,s,40,21);}
    if(f.phase==21){return ask(w,4,22);}
    if(f.phase==22){if(p.types[value]!=2){return .err(errors::make(3,f.at));}
        w.frames[i].a=value;return take(w,s,41,23);}
    if(f.phase==23){let usize branch=ir::raw(p,20,0,f.a,0,f.at)?;
        w.frames[i].a=branch;w.frames[i].phase=24;return push(w,f.depth+1,1,s.begin);}
    if(f.phase==24){w.frames[i].terminal=stopped;
        if(!word(source,s,b"else")){let usize patched=target(p,f.a,f.at)?;finish(w,false);return .ok(w.done);}
        let usize skip=if(stopped){256}else{ir::raw(p,19,0,0,0,f.at)?};
        let usize patched=target(p,f.a,f.at)?;w.frames[i].b=skip;return take(w,s,0,25);}
    if(f.phase==25){w.frames[i].phase=26;return push(w,f.depth+1,if(word(source,s,b"if")){10}else{1},s.begin);}
    if(f.phase==26){if(f.b!=256){let usize patched=target(p,f.b,f.at)?;}finish(w,f.terminal && stopped);return .ok(w.done);}
    // while: enter before lowering the condition, as in the independent path.
    if(f.phase==30){return take(w,s,40,31);}
    if(f.phase==31){w.frames[i].a=p.count;let usize level=loops::enter(flow,p.count,false,f.at)?;
        flow.bindings[level]=places::scope(names);return ask(w,5,32);}
    if(f.phase==32){if(p.types[value]!=2){return .err(errors::make(3,f.at));}w.frames[i].b=value;return take(w,s,41,33);}
    if(f.phase==33){let usize exit=ir::raw(p,20,0,f.b,0,f.at)?;w.frames[i].b=exit;
        w.frames[i].phase=34;return push(w,f.depth+1,1,s.begin);}
    if(f.phase==34){if(!stopped){let usize back=ir::raw(p,22,0,f.a,0,f.at)?;}
        let usize patched=target(p,f.b,f.at)?;let usize breaks=resolve(flow,p,true,f.at)?;
        flow.depth-=1;finish(w,false);return .ok(w.done);}
    // for: header probes and post replay remain explicit pending children.
    if(f.phase==40){return take(w,s,40,41);}
    if(f.phase==41){if(s.kind==59){return take(w,s,0,43);}return ask(w,6,42);}
    if(f.phase==42){if(!types::scalar(p.types[names.registers[value]])){return .err(errors::make(3,f.at));}w.frames[i].phase=43;return .ok(false);}
    if(f.phase==43){w.frames[i].a=p.count;
        if(s.kind==59){w.value=ir::boolean(p,true,f.at)?;w.frames[i].phase=45;return .ok(false);}return ask(w,7,45);}
    if(f.phase==45){if(p.types[value]!=2 || p.call_count!=f.d){return .err(errors::make(3,f.at));}
        w.frames[i].b=value;return take(w,s,59,46);}
    if(f.phase==46){w.frames[i].b=ir::raw(p,20,0,f.b,0,f.at)?;
        w.frames[i].flag=s.kind!=41;w.frames[i].c=s.begin;
        if(s.kind!=41){return ask(w,8,47);}return take(w,s,0,47);}
    if(f.phase==47){let usize level=loops::enter(flow,f.a,true,f.at)?;flow.bindings[level]=places::scope(names);
        w.frames[i].phase=48;return push(w,f.depth+1,1,s.begin);}
    if(f.phase==48){let usize continues=resolve(flow,p,false,f.at)?;
        if(!stopped || continues!=0){if(f.flag){return ask(w,9,49);}let usize back=ir::raw(p,22,0,f.a,0,f.at)?;}
        w.frames[i].phase=60;return .ok(false);}
    if(f.phase==49){let usize back=ir::raw(p,22,0,f.a,0,f.at)?;w.frames[i].phase=60;return .ok(false);}
    if(f.phase==60){let usize patched=target(p,f.b,f.at)?;
        let usize breaks=resolve(flow,p,true,f.at)?;flow.depth-=1;names.count=f.outer;finish(w,false);return .ok(w.done);}
    // switch: precisely two variants, with separate arm entry/exit stages.
    if(f.phase==50){return take(w,s,40,51);}
    if(f.phase==51){return ask(w,10,52);}
    if(f.phase==52){if(!types::tagged(p.types[value])){return .err(errors::make(3,f.at));}
        w.frames[i].a=value;w.frames[i].terminal=true;return take(w,s,41,53);}
    if(f.phase==53){return take(w,s,123,54);}
    if(f.phase==54){if(s.kind==125){return .err(errors::make(3,f.at));}
        if(!word(source,s,b"case")){return .err(errors::make(2,s.begin));}return take(w,s,0,70);}
    if(f.phase==55){let patterns::Pattern pattern=w.pattern;
        if(f.e==1 && pattern.variant==f.variant){return .err(errors::make(3,f.at));}
        if(f.e==0){w.frames[i].variant=pattern.variant;}else{let usize patched=target(p,f.b,f.at)?;}
        let ir::Case branch=ir::branch_case(p,f.a,pattern.variant,f.at)?;
        w.frames[i].b=branch.instruction;w.frames[i].outer=names.count;
        if(pattern.binding){if(locals::find(source,names,pattern.begin,pattern.end)!=64){return .err(errors::make(3,pattern.begin));}
            let usize binding=locals::declare(names,pattern.begin,pattern.end,branch.payload,false)?;}
        w.frames[i].phase=56;return push(w,f.depth+2,1,s.begin);}
    if(f.phase==56){names.count=f.outer;w.frames[i].terminal=f.terminal && stopped;
        if(!stopped){let usize skip=ir::raw(p,19,0,0,0,f.at)?;if(f.e==0){w.frames[i].c=skip;}else{w.frames[i].d=skip;}}
        if(f.e==0){w.frames[i].e=1;w.frames[i].phase=54;return .ok(false);}return take(w,s,125,57);}
    if(f.phase==57){let usize failure=p.count;let usize trap=ir::raw(p,25,0,0,0,f.at)?;
        let usize patched=ir::patch(p,f.b,failure,f.at)?;
        if(f.c!=256){let usize skip=target(p,f.c,f.at)?;}if(f.d!=256){let usize skip=target(p,f.d,f.at)?;}
        finish(w,f.terminal);return .ok(w.done);}
    // Pattern tokens resume independently, before branch allocation or binding.
    if(f.phase==70){return take(w,s,46,71);}
    if(f.phase==71){let u8 tag=p.types[f.a];let bool positive=word(source,s,b"some") || word(source,s,b"ok");
        if(tag<=4){if(!word(source,s,b"some") && !word(source,s,b"none")){return .err(errors::make(3,s.begin));}}
        else if(!word(source,s,b"ok") && !word(source,s,b"err")){return .err(errors::make(3,s.begin));}
        w.pattern=patterns::Pattern{.variant=if(positive){1}else{0},.begin=0,.end=0,.binding=false};return take(w,s,0,72);}
    if(f.phase==72){let patterns::Pattern pattern=w.pattern;
        if(types::payload(p.types[f.a],pattern.variant)==0){return take(w,s,58,55);}return take(w,s,40,73);}
    if(f.phase==73){let bool ignored=word(source,s,b"_");
        if(s.kind!=2 || (!ignored && locals::reserved(source[s.begin..s.end]))){return .err(errors::make(2,s.begin));}
        w.pattern.begin=s.begin;w.pattern.end=s.end;w.pattern.binding=!ignored;return take(w,s,0,74);}
    if(f.phase==74){return take(w,s,41,75);}
    if(f.phase==75){return take(w,s,58,55);}
    // Transfers preserve lexical construction state and release one local/stage.
    if(f.phase==80){return take(w,s,59,81);}
    if(f.phase==81){if(flow.depth==0){return .err(errors::make(2,f.at));}
        let usize packed=flow.bindings[flow.depth-1];let usize first=places::leave_loop(names,p,packed,f.at)?;
        w.frames[i].a=first;w.frames[i].b=names.count;w.frames[i].phase=82;return .ok(false);}
    if(f.phase==82){if(f.b==f.a){w.frames[i].phase=83;return .ok(false);}
        let usize row=f.b-1;let usize released=arrays::release_at(names,p,row,f.at)?;w.frames[i].b=row;return .ok(false);}
    if(f.phase==83){let usize transferred=loops::transfer(flow,p,f.flag,f.at)?;finish(w,true);return .ok(w.done);}
    return .err(errors::make(5,s.begin));
}
