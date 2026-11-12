module value_syntax_work;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import errors as errors;
import metadata_budget as budget;
// Read-only syntax interpreter. Modes: 1 conditional atom, 2 conditional value,
// 4 regular statement, 12 constructor atom. Other frames are private children.
pub struct Frame { lexer::State saved; usize depth; usize left; usize right; usize third;
    usize count; u8 kind; u8 phase; u8 open; u8 close; bool flag; }
pub struct State { Frame[40] frames; u8[32] delimiters; lexer::State look; tokens::State scan;
    usize used; usize visits; usize groups; u8 suffix; bool value; bool waiting; bool done; }
fn Frame frame(lexer::State s,u8 kind,usize depth){return Frame{.saved=s,.depth=depth,.left=0,.right=0,.third=0,.count=0,
    .kind=kind,.phase=0,.open=0,.close=0,.flag=false};}
pub fn State begin(lexer::State s,u8 mode){return State{.frames=[frame(s,mode,0);40],.delimiters=[0;32],.look=s,
    .scan=tokens::begin(s),.used=1,.visits=0,.groups=0,.suffix=0,.value=false,.waiting=false,.done=false};}
pub fn Result<bool,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.look.begin));}return .ok(w.value);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn void next(ref mut State w,u8 phase){let lexer::State s=w.look;let usize i=w.used-1;w.frames[i].phase=phase;w.scan=tokens::begin(s);w.waiting=true;}
fn Result<bool,errors::Error> finish(ref mut State w,bool value){let usize i=w.used-1;
    if(w.frames[i].kind==4){w.look=w.frames[i].saved;}w.value=value;w.used=i;w.done=i==0;return .ok(w.done);}
fn Result<bool,errors::Error> child(ref mut State w,u8 kind,usize depth,u8 resume,u8 open,u8 close){
    if(w.used==40){return .err(errors::make(4,w.look.begin));}let usize i=w.used;let lexer::State s=w.look;
    w.frames[i-1].phase=resume;w.frames[i]=frame(s,kind,depth);w.frames[i].open=open;w.frames[i].close=close;w.used+=1;return .ok(false);}
fn u8 closing(u8 kind){return if(kind==40){41}else if(kind==91){93}else if(kind==123){125}else{0};}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.scan,meter)){
        case .err(e):{return .err(e);}case .ok(done):{if(done){w.look=tokens::prepared(ref w.scan)?;w.waiting=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,w.look.begin)?){return .ok(false);}w.visits+=1;
    let usize i=w.used-1;let Frame f=w.frames[i];let lexer::State s=w.look;let u8 phase=f.phase;
    if(f.kind==1 || f.kind==12){
        if(phase==0){if(s.kind==40){if(f.left>=32){return .err(errors::make(4,s.begin));}w.frames[i].left=f.left+1;next(w,0);return .ok(false);}
            if(f.kind==12){if(s.kind!=46){return finish(w,false);}next(w,20);return .ok(false);}
            if(word(source,ref s,b"switch")){next(w,1);return .ok(false);}
            if(!word(source,ref s,b"if")){return finish(w,false);}return child(w,2,f.left,4,0,0);}
        if(phase==1){return child(w,5,0,2,40,41);}if(phase==2){return child(w,5,0,4,123,125);}
        if(phase==20){if(word(source,ref s,b"none")){next(w,4);return .ok(false);}
            if(!word(source,ref s,b"some") && !word(source,ref s,b"ok") && !word(source,ref s,b"err")){return finish(w,false);}next(w,21);return .ok(false);}
        if(phase==21){return child(w,5,0,4,40,41);}
        if(phase==4){if(f.right==f.left){if(f.kind==1){w.groups=f.left;w.suffix=s.kind;return finish(w,true);}return finish(w,s.kind==125);}
            if(s.kind!=41){return finish(w,false);}w.frames[i].right=f.right+1;next(w,4);return .ok(false);}
    }
    if(f.kind==2){
        if(phase==0){if(f.depth>32){return .err(errors::make(4,s.begin));}if(!word(source,ref s,b"if")){return .err(errors::make(2,s.begin));}next(w,1);return .ok(false);}
        if(phase==1){return child(w,5,0,2,40,41);}if(phase==2){return child(w,3,f.depth+1,3,0,0);}
        if(phase==3){if(!word(source,ref s,b"else")){let bool value=w.value;return finish(w,value);}let bool value=w.value;w.frames[i].flag=value;next(w,4);return .ok(false);}
        if(phase==4){let u8 kind=if(word(source,ref s,b"if")){2}else{3};return child(w,kind,f.depth+1,5,0,0);}
        if(phase==5){let bool value=f.flag || w.value;return finish(w,value);}
    }
    if(f.kind==3){
        if(phase==0){if(f.depth>32){return .err(errors::make(4,s.begin));}if(s.kind!=123){return .err(errors::make(2,s.begin));}next(w,1);return .ok(false);}
        if(phase==1){if(s.kind==125){next(w,9);return .ok(false);}if(s.kind==0){return .err(errors::make(2,s.begin));}
            if(word(source,ref s,b"if")){return child(w,2,f.depth+1,2,0,0);}
            if(word(source,ref s,b"while") || word(source,ref s,b"for")){next(w,4);return .ok(false);}
            if(s.kind==123){return child(w,5,0,6,123,125);}return child(w,4,0,7,0,0);}
        if(phase==2){if(w.value){return child(w,7,0,3,0,0);}w.frames[i].phase=1;return .ok(false);}
        if(phase==3){return finish(w,true);}if(phase==4){return child(w,5,0,5,40,41);}
        if(phase==5){return child(w,5,0,6,123,125);}if(phase==6 || phase==8){w.frames[i].phase=1;return .ok(false);}
        if(phase==7){if(w.value || word(source,ref s,b"return") || word(source,ref s,b"break") || word(source,ref s,b"continue")){return child(w,6,0,8,0,0);}
            return child(w,7,0,3,0,0);}if(phase==9){return finish(w,false);}
    }
    if(f.kind==4){
        if(phase==0){if(s.kind==40){return child(w,8,0,4,0,0);}if(word(source,ref s,b"let") || word(source,ref s,b"var")){return finish(w,true);}return child(w,11,0,1,0,0);}
        if(phase==1){if(w.value){return finish(w,true);}w.look=f.saved;
            if(f.saved.kind!=2 || locals::reserved(source[f.saved.begin..f.saved.end])){return finish(w,false);}next(w,2);return .ok(false);}
        if(phase==2){if(lexer::assignment(s.kind)){return finish(w,true);}if(s.kind==91){return child(w,9,0,4,0,0);}if(s.kind==46){return child(w,10,0,4,0,0);}return finish(w,false);}
        if(phase==4){let bool value=w.value;return finish(w,value);}
    }
    if(f.kind==5){if(phase==0){if(s.kind!=f.open){return .err(errors::make(2,s.begin));}w.frames[i].left=1;next(w,1);return .ok(false);}
        if(phase==2){if(f.left==0){return finish(w,true);}w.frames[i].phase=1;return .ok(false);}
        if(s.kind==0){return .err(errors::make(2,s.begin));}if(s.kind==f.open){w.frames[i].left=f.left+1;}else if(s.kind==f.close){w.frames[i].left=f.left-1;}next(w,2);return .ok(false);}
    if(f.kind==6){if(phase==1){return finish(w,true);}if(s.kind==0 || s.kind==125 && f.right==0){return .err(errors::make(2,s.begin));}
        if(s.kind==59 && f.left==0 && f.right==0 && f.third==0){next(w,1);return .ok(false);}
        if(s.kind==40){w.frames[i].left=f.left+1;}else if(s.kind==41 && f.left!=0){w.frames[i].left=f.left-1;}
        else if(s.kind==123){w.frames[i].right=f.right+1;}else if(s.kind==125 && f.right!=0){w.frames[i].right=f.right-1;}
        else if(s.kind==91){w.frames[i].third=f.third+1;}else if(s.kind==93 && f.third!=0){w.frames[i].third=f.third-1;}next(w,0);return .ok(false);}
    if(f.kind==7){if(phase==0){w.frames[i].left=1;w.frames[i].phase=1;return .ok(false);}
        if(phase==2){if(f.left==0){return finish(w,true);}w.frames[i].phase=1;return .ok(false);}
        if(s.kind==0){return .err(errors::make(2,s.begin));}if(s.kind==123){w.frames[i].left=f.left+1;}else if(s.kind==125){w.frames[i].left=f.left-1;}next(w,2);return .ok(false);}
    if(f.kind==8){
        if(phase==0){if(source.len>4096){return .err(errors::make(4,s.begin));}
            if(s.begin>s.end || s.end>source.len || s.cursor<s.end || s.cursor>source.len || s.tokens>1024){return .err(errors::make(5,s.begin));}w.frames[i].phase=1;return .ok(false);}
        if(phase==1){if(s.kind==40){if(f.left==32){return .err(errors::make(4,s.begin));}w.frames[i].left=f.left+1;next(w,1);return .ok(false);}
            if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return finish(w,false);}next(w,2);return .ok(false);}
        if(phase==2){if(s.kind==46 || s.kind==91){if(f.count==16){return .err(errors::make(4,s.begin));}next(w,if(s.kind==46){3}else{4});return .ok(false);}
            if(s.kind==41 && f.left!=0){w.frames[i].left=f.left-1;next(w,2);return .ok(false);}return finish(w,f.left==0 && lexer::assignment(s.kind));}
        if(phase==3){if(s.kind!=2){return finish(w,false);}w.frames[i].count=f.count+1;next(w,2);return .ok(false);}
        if(phase==4){if(s.kind==93){return .err(errors::make(2,s.begin));}w.delimiters[0]=93;w.frames[i].right=1;w.frames[i].phase=5;return .ok(false);}
        if(phase==5){if(s.kind==0){return .err(errors::make(2,s.begin));}let u8 close=closing(s.kind);
            if(close!=0){if(f.right==32){return .err(errors::make(4,s.begin));}w.delimiters[f.right]=close;w.frames[i].right=f.right+1;}
            else if(s.kind==41 || s.kind==93 || s.kind==125){if(s.kind!=w.delimiters[f.right-1]){return .err(errors::make(2,s.begin));}w.frames[i].right=f.right-1;
                if(f.right==1){w.frames[i].count=f.count+1;next(w,2);return .ok(false);}}
            next(w,5);return .ok(false);}
    }
    if(f.kind==9){if(phase==1){return finish(w,lexer::assignment(s.kind));}if(s.kind==0){return finish(w,false);}
        if(s.kind==91){w.frames[i].left=f.left+1;}else if(s.kind==93){if(f.left==0){return finish(w,false);}w.frames[i].left=f.left-1;if(f.left==1){next(w,1);return .ok(false);}}next(w,0);return .ok(false);}
    if(f.kind==10){if(phase==0){if(s.kind!=46){return finish(w,f.left!=0 && lexer::assignment(s.kind));}if(f.left>=16){return .err(errors::make(4,s.begin));}w.frames[i].left=f.left+1;next(w,1);return .ok(false);}
        if(s.kind!=2){return finish(w,false);}next(w,0);return .ok(false);}
    if(f.kind==11){if(phase==0){if((s.kind!=2 && s.kind!=5) || locals::reserved(source[s.begin..s.end])){return finish(w,false);}next(w,1);return .ok(false);}
        if(phase==1){if(s.kind!=40){return finish(w,false);}return child(w,5,0,2,40,41);}return finish(w,s.kind==59);}
    return .err(errors::make(5,s.begin));
}
// Compatibility owners drain only this kernel; callers needing yields use advance.
pub fn Result<State,errors::Error> inspect(ref u8[] source,lexer::State s,u8 mode){var State w=begin(s,mode);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;let bool done=advance(source,ref mut w,ref mut meter)?;}return .ok(w);}
