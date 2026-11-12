module conditional_evaluation_work;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import functions as functions;
import ir as ir;
import types as types;
import errors as errors;
import patterns as patterns;
import value_join_source as joins;
import value_syntax_work as syntax;
import aggregate_probe_work as aggregates;
import array_source as arrays;
import metadata_budget as budget;
// Actual conditional control/arm execution. Explicit children: 1 head scalar,
// 2 ordinary statement/control, 3 specialized aggregate tail, 4 scalar tail or
// constructor payload, 5 switch pattern. No whole-body scan is a charged step.
pub struct Frame { usize depth; usize structure; usize at; usize inner; usize outer; usize pending;
    usize a; usize b; usize c; usize d; usize groups; usize left; usize arm;
    u8 phase; u8 variant; bool terminal; bool regular; bool option; bool positive; }
pub struct State { Frame[35] frames; locals::Table names; tokens::State token; syntax::State syntax;
    aggregates::State aggregate; patterns::Pattern pattern; usize used; usize value; usize visits;
    usize child_depth; usize child_structure; usize row; usize compared; u8 expected; u8 result_type;
    u8 request; u8 probe; u8 tag; bool lexing; bool stopped; bool done; }
fn Frame frame(usize depth,usize structure,u8 phase,usize count,usize pending){return Frame{.depth=depth,.structure=structure,
    .at=0,.inner=0,.outer=count,.pending=pending,.a=256,.b=256,.c=256,.d=0,.groups=0,.left=0,.arm=0,
    .phase=phase,.variant=2,.terminal=false,.regular=false,.option=false,.positive=false};}
pub fn State begin(ref locals::Table names,usize depth,usize structure,u8 result_type){var State w=State{
    .frames=[frame(0,0,0,0,0);35],.names=locals::snapshot(names),.token=tokens::begin(lexer::empty()),.syntax=syntax::begin(lexer::empty(),1),
    .aggregate=aggregates::begin(lexer::empty(),1),.pattern=patterns::Pattern{.variant=0,.begin=0,.end=0,.binding=false},
    .used=1,.value=0,.visits=0,.child_depth=0,.child_structure=0,.row=0,.compared=0,.expected=0,.result_type=result_type,
    .request=0,.probe=0,.tag=0,.lexing=false,.stopped=false,.done=false};w.frames[0]=frame(depth,structure,0,names.count,names.pending_places);return w;}
pub fn Frame current(ref State w){let ref Frame[] frames=ref w.frames;return frames[w.used-1];}
pub fn Result<bool,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,0));}return .ok(w.stopped);}
pub fn Result<usize,errors::Error> resume(ref mut State w,u8 request,usize value,bool stopped){
    if(w.done || request==0 || request!=w.request){return .err(errors::make(5,0));}w.request=0;w.value=value;w.stopped=stopped;return .ok(value);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}
    let usize i=w.used-1;w.frames[i].phase=phase;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);}
fn Result<bool,errors::Error> ask(ref mut State w,u8 request,u8 phase,usize depth,usize structure,u8 expected){let usize i=w.used-1;
    w.frames[i].phase=phase;w.request=request;w.child_depth=depth;w.child_structure=structure;w.expected=expected;return .ok(false);}
fn Result<bool,errors::Error> push(ref mut State w,usize depth,usize structure,u8 phase,u8 resume){
    if(w.used>=35){return .err(errors::make(4,0));}let usize i=w.used;w.frames[i-1].phase=resume;
    let usize count=w.names.count;let usize pending=w.names.pending_places;w.frames[i]=frame(depth,structure,phase,count,pending);w.used+=1;return .ok(false);}
fn Result<bool,errors::Error> finish(ref mut State w,bool stopped,bool restore){let Frame f=current(w);
    if(restore){w.names.count=f.outer;w.names.pending_places=f.pending;}w.used-=1;w.stopped=stopped;w.done=w.used==0;return .ok(w.done);}
fn void probe(ref mut State w,lexer::State s,u8 mode,u8 phase){let usize i=w.used-1;w.syntax=syntax::begin(s,mode);w.probe=1;w.frames[i].phase=phase;}
fn void aggregate(ref mut State w,lexer::State s,u8 mode,u8 phase){let usize i=w.used-1;w.aggregate=aggregates::begin(s,mode);w.probe=2;w.frames[i].phase=phase;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref functions::Table signatures,ref mut joins::Join join,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    if(w.probe==1){if(syntax::advance(source,ref mut w.syntax,meter)?){w.probe=0;}return .ok(false);}
    if(w.probe==2){let locals::Table active=locals::snapshot(ref w.names);if(aggregates::advance(source,p,ref active,signatures,ref mut w.aggregate,meter)?){w.probe=0;}return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}w.visits+=1;let usize i=w.used-1;let Frame f=current(w);let usize value=w.value;
    if(f.phase==0){if(f.depth>30 || f.structure>30){return .err(errors::make(4,s.begin));}if(w.result_type==0){return .err(errors::make(3,s.begin));}
        w.frames[i].at=s.begin;if(word(source,s,b"switch")){return take(w,s,0,20);}if(!word(source,s,b"if")){return .err(errors::make(2,s.begin));}return take(w,s,2,1);}
    if(f.phase==1){return take(w,s,40,2);}if(f.phase==2){return ask(w,1,3,f.depth+1,f.structure+1,2);}
    if(f.phase==3){if(p.types[value]!=2){return .err(errors::make(3,f.at));}w.frames[i].d=value;return take(w,s,41,4);}
    if(f.phase==4){w.frames[i].a=ir::raw(p,20,0,f.d,0,f.at)?;return push(w,f.depth+2,f.structure+2,100,5);}
    if(f.phase==5){let bool stopped=w.stopped;w.frames[i].terminal=stopped;
        if(!stopped){w.frames[i].b=ir::raw(p,19,0,0,0,f.at)?;}if(!word(source,s,b"else")){return .err(errors::make(2,s.begin));}return take(w,s,2,6);}
    if(f.phase==6){let usize target=p.count;let usize patched=ir::patch(p,f.a,target,f.at)?;
        w.names.count=f.outer;w.names.pending_places=f.pending;w.frames[i].phase=7;return .ok(false);}
    if(f.phase==7){let bool nested=word(source,s,b"if");return push(w,f.depth+if(nested){1}else{2},f.structure+if(nested){1}else{2},if(nested){0}else{100},8);}
    if(f.phase==8){if(f.b!=256){let usize target=p.count;let usize patched=ir::patch(p,f.b,target,f.at)?;}let bool stopped=f.terminal && w.stopped;return finish(w,stopped,true);}
    // Switch dispatch and exact two-arm patch order.
    if(f.phase==20){return take(w,s,40,21);}if(f.phase==21){return ask(w,1,22,f.depth+1,f.structure+1,0);}
    if(f.phase==22){if(!types::tagged(p.types[value])){return .err(errors::make(3,f.at));}w.tag=p.types[value];w.frames[i].d=value;return take(w,s,41,23);}
    if(f.phase==23){return take(w,s,123,24);}
    if(f.phase==24){if(f.arm==2){return take(w,s,125,30);}if(s.kind==125){return .err(errors::make(3,f.at));}return ask(w,5,25,f.depth,f.structure,p.types[f.d]);}
    if(f.phase==25){let patterns::Pattern pattern=w.pattern;if(f.arm==1 && pattern.variant==f.variant){return .err(errors::make(3,f.at));}
        if(f.arm==0){w.frames[i].variant=pattern.variant;}else{let usize target=p.count;let usize patched=ir::patch(p,f.a,target,f.at)?;}
        let ir::Case branch=ir::branch_case(p,f.d,pattern.variant,f.at)?;w.frames[i].a=branch.instruction;w.frames[i].inner=branch.payload;
        w.names.count=f.outer;w.names.pending_places=f.pending;w.row=0;w.compared=0;w.frames[i].phase=26;return .ok(false);}
    if(f.phase==26){if(!w.pattern.binding || w.row==w.names.count){w.frames[i].phase=28;return .ok(false);}
        let usize a=w.names.begins[w.row];let usize b=w.names.ends[w.row];if(b-a!=w.pattern.end-w.pattern.begin){w.row+=1;return .ok(false);}
        var usize stop=w.compared+64;if(stop>b-a){stop=b-a;}while(w.compared<stop){if(source[a+w.compared]!=source[w.pattern.begin+w.compared]){w.row+=1;w.compared=0;return .ok(false);}w.compared+=1;}
        if(w.compared==b-a){return .err(errors::make(3,w.pattern.begin));}return .ok(false);}
    if(f.phase==28){let patterns::Pattern pattern=w.pattern;if(pattern.binding){let usize binding=locals::declare(ref mut w.names,pattern.begin,pattern.end,f.inner,false)?;}
        return push(w,f.depth+2,f.structure+2,100,29);}
    if(f.phase==29){if(!w.stopped){let usize skip=ir::raw(p,19,0,0,0,f.at)?;if(f.arm==0){w.frames[i].b=skip;}else{w.frames[i].c=skip;}}
        w.frames[i].arm=f.arm+1;w.frames[i].phase=24;return .ok(false);}
    if(f.phase==30){let usize failure=ir::raw(p,25,0,0,0,f.at)?;w.frames[i].inner=failure;w.frames[i].phase=31;return .ok(false);}
    if(f.phase==31){let usize patched=ir::patch(p,f.a,f.inner,f.at)?;w.frames[i].phase=32;return .ok(false);}
    if(f.phase==32){if(f.b!=256){let usize target=p.count;let usize patched=ir::patch(p,f.b,target,f.at)?;}w.frames[i].phase=33;return .ok(false);}
    if(f.phase==33){if(f.c!=256){let usize target=p.count;let usize patched=ir::patch(p,f.c,target,f.at)?;}return finish(w,f.b==256 && f.c==256,true);}
    // Actual arm body, with independent pending statements and scalar children.
    if(f.phase==100){if(f.depth>32 || f.structure>32){return .err(errors::make(4,s.begin));}return take(w,s,123,101);}
    if(f.phase==101){let usize count=w.names.count;w.frames[i].outer=count;w.frames[i].phase=102;return .ok(false);}
    if(f.phase==102){if(word(source,s,b"_")){w.frames[i].regular=true;w.frames[i].phase=104;}else{probe(w,*s,4,103);}return .ok(false);}
    if(f.phase==103){let bool regular=syntax::prepared(ref w.syntax)?;w.frames[i].regular=regular;
        if(word(source,s,b"if")){probe(w,*s,2,104);}else{w.stopped=false;w.frames[i].phase=104;}return .ok(false);}
    if(f.phase==104){let bool conditional=word(source,s,b"if") && syntax::prepared(ref w.syntax)?;
        let bool structured=s.kind==123 || word(source,s,b"if") && !conditional || word(source,s,b"while") || word(source,s,b"for") || word(source,s,b"return") || word(source,s,b"break") || word(source,s,b"continue");
        if(f.regular || structured){return ask(w,2,105,f.depth,f.structure,0);}w.frames[i].inner=s.begin;probe(w,*s,1,110);return .ok(false);}
    if(f.phase==105){if(w.stopped){return take(w,s,125,109);}w.frames[i].phase=102;return .ok(false);}
    if(f.phase==109){return finish(w,true,false);}
    if(f.phase==110){if(word(source,s,b"ref")){return .err(errors::make(3,f.inner));}
        if(syntax::prepared(ref w.syntax)? && w.syntax.suffix==125){let usize groups=w.syntax.groups;
            if(f.depth>32 || groups>32-f.depth){return .err(errors::make(4,f.inner));}w.frames[i].groups=groups;w.frames[i].left=groups;w.frames[i].phase=111;return .ok(false);}
        if(join.kind<=1 && join.tag==0){probe(w,*s,12,114);}else{aggregate(w,*s,1,120);}return .ok(false);}
    if(f.phase==111){if(f.left!=0){w.frames[i].left=f.left-1;return take(w,s,0,111);}return push(w,f.depth+f.groups,f.structure,0,112);}
    if(f.phase==112){let bool stopped=w.stopped;w.frames[i].terminal=stopped;w.frames[i].left=f.groups;w.frames[i].phase=113;return .ok(false);}
    if(f.phase==113){if(f.left!=0){w.frames[i].left=f.left-1;return take(w,s,41,113);}w.stopped=f.terminal;w.frames[i].phase=159;return .ok(false);}
    if(f.phase==114){if(syntax::prepared(ref w.syntax)?){w.frames[i].groups=0;w.frames[i].phase=140;}else{aggregate(w,*s,1,120);}return .ok(false);}
    if(f.phase==120){let aggregates::Plan plan=aggregates::prepared(ref w.aggregate)?;
        if(plan.kind!=0 && plan.tag==0 && plan.suffix==125){return ask(w,3,159,f.depth,f.structure,0);}aggregate(w,*s,2,121);return .ok(false);}
    if(f.phase==121){let aggregates::Plan plan=aggregates::prepared(ref w.aggregate)?;
        if(plan.kind!=0 && plan.suffix==125){return ask(w,3,159,f.depth,f.structure,0);}
        let u8 expected=if(join.kind==0 || join.kind==1){join.tag}else{0};return ask(w,4,150,f.depth,f.structure,expected);}
    // Untyped constructor tails retain the join's missing-domain constraints.
    if(f.phase==140){if(s.kind==40){if(f.depth>32 || f.groups>=32-f.depth){return .err(errors::make(4,s.begin));}w.frames[i].groups=f.groups+1;return take(w,s,40,140);}return take(w,s,46,141);}
    if(f.phase==141){let bool option=word(source,s,b"some") || word(source,s,b"none");let bool positive=word(source,s,b"some") || word(source,s,b"ok");
        if(!option && !word(source,s,b"ok") && !word(source,s,b"err")){return .err(errors::make(3,f.inner));}
        w.frames[i].option=option;w.frames[i].positive=positive;return take(w,s,0,142);}
    if(f.phase==142){if(!f.option || f.positive){return take(w,s,40,143);}w.value=0;w.frames[i].left=f.groups;w.frames[i].phase=145;return .ok(false);}
    if(f.phase==143){return ask(w,4,144,f.depth+f.groups+1,f.structure,0);}
    if(f.phase==144){w.frames[i].left=f.groups;return take(w,s,41,145);}
    if(f.phase==145){if(f.left!=0){w.frames[i].left=f.left-1;return take(w,s,41,145);}if(s.kind!=125){return .err(errors::make(2,s.begin));}
        let usize accepted=joins::constructor(p,join,f.option,if(f.positive){1}else{0},value,f.inner)?;w.stopped=false;w.frames[i].phase=159;return .ok(false);}
    if(f.phase==150){let usize accepted=joins::scalar(p,join,value,f.inner)?;w.stopped=false;w.frames[i].phase=159;return .ok(false);}
    if(f.phase==159){if(w.stopped){return take(w,s,125,109);}let usize count=w.names.count;w.frames[i].left=count;w.frames[i].phase=160;return .ok(false);}
    if(f.phase==160){if(f.left>f.outer){let usize row=f.left-1;let usize dropped=arrays::release_at(ref mut w.names,p,row,s.begin)?;w.frames[i].left=row;return .ok(false);}return take(w,s,125,161);}
    if(f.phase==161){return finish(w,false,false);}
    return .err(errors::make(5,s.begin));
}
