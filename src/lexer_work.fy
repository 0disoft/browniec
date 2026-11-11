module lexer_work;
import lexer as raw;
import literal_scan_work as literals;
import cells as cells;
import errors as errors;
import metadata_budget as budget;
// Private token continuation for <=4096 immutable source bytes. At most sixteen
// byte/scan transitions run in a fresh stage; literal decoding has its own leaf.
// Qualified-name lookahead stays private until the same raw commit points.
pub struct Scan { raw::State target; literals::State literal; usize inner; usize depth;
    usize opener; usize magnitude; usize visits; u8 mode; bool done; }
pub struct State { Scan scan; raw::State head; usize limit; u8 phase; bool done; }
fn Scan scan_empty(raw::State current){return Scan{.target=current,.literal=literals::empty(0),
    .inner=0,.depth=0,.opener=0,.magnitude=0,.visits=0,.mode=0,.done=false};}
pub fn State begin(raw::State current){return State{.scan=scan_empty(current),.head=current,.limit=0,.phase=0,.done=false};}
fn raw::State token(ref Scan w){return w.target;}
fn usize literal_end(ref literals::State w){return w.end;}
fn bool literal_text(ref literals::State w){return w.text;}
fn void reset(ref mut Scan w,raw::State current){w.target=current;w.inner=0;w.depth=0;w.opener=0;w.magnitude=0;w.mode=0;w.done=false;}
fn bool letter(u8 ch){return (ch>=65 && ch<=90)||(ch>=97 && ch<=122)||ch==95;}
fn bool digit(u8 ch){return ch>=48 && ch<=57;}
fn bool bom(ref u8[] source,usize at){return at+2<source.len && source[at]==239 && source[at+1]==187 && source[at+2]==191;}
fn Result<bool,errors::Error> punctuation(ref u8[] source,ref mut raw::State s){
    let u8 ch=source[s.cursor];
        if (s.cursor + 1 < source.len) {
            let u8 after = source[s.cursor + 1];
            if((ch==60 || ch==62) && after==ch && s.cursor+2<source.len && source[s.cursor+2]==61){
                s.kind=if(ch==60){141}else{142};s.cursor+=3;s.end=s.cursor;return .ok(true);
            }
            var u8 pair = 0;
            if (ch == 61 && after == 61) { pair = 128; }
            else if (ch == 33 && after == 61) { pair = 129; }
            else if (ch == 60 && after == 61) { pair = 130; }
            else if (ch == 62 && after == 61) { pair = 131; }
            else if (ch == 38 && after == 38) { pair = 132; }
            else if (ch == 124 && after == 124) { pair = 133; }
            else if (ch == 60 && after == 60) { pair = 134; }
            else if (ch == 62 && after == 62) { pair = 135; }
            else if(after==61){
                if(ch==43){pair=136;}else if(ch==45){pair=137;}else if(ch==42){pair=138;}
                else if(ch==47){pair=139;}else if(ch==37){pair=140;}
                else if(ch==38){pair=143;}else if(ch==94){pair=144;}else if(ch==124){pair=145;}
            }
            if (pair != 0) { s.kind = pair; s.cursor += 2; s.end = s.cursor; return .ok(true); }
        }
        if (ch != 40 && ch != 41 && ch != 123 && ch != 125 && ch != 59 &&
            ch != 43 && ch != 45 && ch != 42 && ch != 47 && ch != 37 && ch != 61 && ch != 44 &&
            ch != 33 && ch != 60 && ch != 62 && ch != 46 && ch != 58 && ch != 63 &&
            ch != 38 && ch != 94 && ch != 124 && ch != 126 && ch != 91 && ch != 93) {
            return .err(errors::make(1, s.begin));
        }
        s.kind = ch;
        s.cursor += 1;
    s.end=s.cursor;return .ok(true);
}
fn Result<bool,errors::Error> start(ref u8[] source,ref mut Scan w){
    w.target.begin=w.target.cursor;w.target.tokens+=1;
    if(w.target.tokens>1024){return .err(errors::make(4,w.target.begin));}
    w.target.value=0;w.target.min_magnitude=false;
    if(w.target.cursor==source.len){w.target.kind=0;w.target.end=w.target.cursor;return .ok(true);}
    let u8 ch=source[w.target.cursor];let u8 literal=literals::kind(source,w.target.cursor);
    if(literal!=0){let usize at=w.target.cursor;w.literal=literals::empty(at);w.mode=5;return .ok(false);}
    if(ch==99 && w.target.cursor+1<source.len && source[w.target.cursor+1]==34){return .err(errors::make(1,w.target.begin));}
    if(digit(ch)){w.target.kind=1;w.magnitude=0;w.mode=3;return .ok(false);}
    if(letter(ch)){w.target.kind=2;w.mode=4;return .ok(false);}
    return punctuation(source,ref mut w.target);
}
fn Result<bool,errors::Error> step(ref u8[] source,ref mut Scan w){
    w.visits+=1;
    if(w.mode==0){
        let usize at=w.target.cursor;if(at==source.len){return start(source,w);}
        if(at==(w.target.context as usize&8191) && bom(source,at)){w.target.cursor+=3;return .ok(false);}
        let u8 ch=source[at];if(bom(source,at)||ch==0){return .err(errors::make(1,at));}
        if(ch==32||ch==9||ch==10){w.target.cursor+=1;return .ok(false);}
        if(ch==13){if(at+1<source.len && source[at+1]==10){w.target.cursor+=2;return .ok(false);}return .err(errors::make(1,at));}
        if(ch==47 && at+1<source.len && (source[at+1]==47 || source[at+1]==42)){
            w.inner=at+2;w.opener=at;w.depth=1;w.mode=if(source[at+1]==47){1}else{2};return .ok(false);}
        return start(source,w);
    }
    if(w.mode==1 || w.mode==2){
        let usize at=w.inner;
        if(at==source.len){if(w.mode==2){return .err(errors::make(1,w.opener));}w.target.cursor=at;w.mode=0;return .ok(false);}
        let u8 ch=source[at];if(ch==0||bom(source,at)){return .err(errors::make(1,at));}
        if(ch==13){if(at+1<source.len && source[at+1]==10){w.inner+=2;
            if(w.mode==1){w.target.cursor=w.inner;w.mode=0;}return .ok(false);}return .err(errors::make(1,at));}
        if(w.mode==1){w.inner+=1;if(ch==10){w.target.cursor=w.inner;w.mode=0;}return .ok(false);}
        if(ch==47 && at+1<source.len && source[at+1]==42){if(w.depth==2048){return .err(errors::make(4,at));}w.depth+=1;w.inner+=2;return .ok(false);}
        if(ch==42 && at+1<source.len && source[at+1]==47){w.depth-=1;w.inner+=2;
            if(w.depth==0){w.target.cursor=w.inner;w.mode=0;}return .ok(false);}
        w.inner+=1;return .ok(false);
    }
    if(w.mode==3){let usize at=w.target.cursor;
        if(at<source.len && digit(source[at])){let usize part=(source[at]-48) as usize;
            if(w.magnitude>1844674407370955161 || (w.magnitude==1844674407370955161 && part>5)){return .err(errors::make(3,w.target.begin));}
            w.magnitude=w.magnitude*10+part;w.target.cursor+=1;return .ok(false);}
        w.target.min_magnitude=w.magnitude==9223372036854775808;w.target.value=cells::pack(w.magnitude,w.target.begin)?;
        w.target.end=w.target.cursor;return .ok(true);
    }
    if(w.mode==4){let usize at=w.target.cursor;
        if(at<source.len && (letter(source[at])||digit(source[at]))){w.target.cursor+=1;return .ok(false);}
        w.target.end=at;return .ok(true);
    }
    return .err(errors::make(5,w.target.cursor));
}
fn Result<bool,errors::Error> scan(ref u8[] source,ref mut Scan w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(w.mode==5){let bool done=literals::advance(source,ref mut w.literal,meter)?;
        if(done){let usize end=literal_end(ref w.literal);let bool text=literal_text(ref w.literal);
            w.target.kind=if(text){4}else{3};w.target.cursor=end;w.target.end=end;w.done=true;}return .ok(w.done);}
    if(!budget::admit(meter,4096,w.target.cursor)?){return .ok(false);}
    var usize steps=0;while(steps<16 && w.mode!=5){let bool done=step(source,w)?;
        if(done){w.done=true;return .ok(true);}steps+=1;}return .ok(false);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0){if(!budget::admit(meter,4096,0)?){return .ok(false);}
        if(source.len>4096){return .err(errors::make(4,4096));}
        let raw::State current=token(ref w.scan);w.limit=source.len;
        if(current.context!=0){let usize bits=current.context as usize;let usize start=bits&8191;let usize end=(bits>>13)&8191;
            if((bits>>28)!=0 || (bits&67108864)==0 || start>end || end>source.len || current.cursor<start || current.cursor>end){return .err(errors::make(5,current.cursor));}
            w.limit=end;}
        w.phase=1;return .ok(false);
    }
    let usize limit=w.limit;let bool done=scan(source[..limit],ref mut w.scan,meter)?;if(!done){return .ok(false);}
    let raw::State current=token(ref w.scan);
    if(w.phase==1){w.head=current;
        if(current.context==0 || current.kind!=2 || (raw::equal(source[current.begin..current.end],b"text") && (current.context&134217728)==0)){w.done=true;return .ok(true);}
        reset(ref mut w.scan,current);w.phase=2;return .ok(false);
    }
    if(w.phase==2 || w.phase==3){if(current.kind!=58){w.done=true;return .ok(true);}
        let u8 next=if(w.phase==2){3}else{4};reset(ref mut w.scan,current);w.phase=next;return .ok(false);}
    if(w.phase==4){if(current.kind!=2){return .err(errors::make(2,current.begin));}
        w.head.cursor=current.cursor;w.head.end=current.end;w.head.tokens=current.tokens;w.head.kind=5;
        reset(ref mut w.scan,current);w.phase=2;return .ok(false);}
    return .err(errors::make(5,current.cursor));
}
// Same observable lexer state on a failure, including private lookahead errors.
pub fn raw::State observed(ref State w){if(w.phase==1){return token(ref w.scan);}return w.head;}
pub fn Result<raw::State,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,0));}return .ok(w.head);}

// Compatibility adapter. The parser still drains each token synchronously;
// this does not make semantic statement/expression traversal resumable.
pub fn Result<usize,errors::Error> next(ref u8[] source,ref mut raw::State target){
    var State w=begin(*target);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;
        switch(advance(source,ref mut w,ref mut meter)){
            case .ok(_):{}case .err(e):{*target=observed(ref w);return .err(e);}};}
    *target=prepared(ref w)?;return .ok(0);
}
