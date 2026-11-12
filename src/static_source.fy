module static_source;
import lexer as lexer;
import aggregate_probe_work as probes;
import locals as locals;
import ir as ir;
import errors as errors;
import literal_collection as literals;
import static_builders as builders;

// Compiler-only namespace: bytes 192..207, validated text 208..223.
// These are lexical descriptors, never scalar cells or mutable owner tickets.
pub fn u8 kind(usize value){return if(value>=192 && value<208){1}else if(value>=208 && value<224){2}else{0};}
pub fn usize site(usize value){return if(kind(value)==1){value-192}else if(kind(value)==2){value-208}else{16};}
pub fn bool binding(ref locals::Table names,usize index){return index<names.count && kind(names.registers[index])!=0;}
pub struct View { usize site; u8 kind; bool owned; }
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}

// Bounded lookahead chooses Static initializers without diverting existing
// rooted/formal/returned slice declarations to another authority path.
pub fn Result<bool,errors::Error> candidate(ref u8[] source,ref lexer::State s,ref locals::Table names){
    var lexer::State look=lexer::snapshot(s);let usize keyword=lexer::next(source,ref mut look)?;
    if(word(source,ref look,b"mut")){let usize access=lexer::next(source,ref mut look)?;}
    if(word(source,ref look,b"str")){return .ok(true);}
    if(!word(source,ref look,b"u8")){return .ok(false);}
    let usize tag=lexer::next(source,ref mut look)?;
    if(look.kind!=91){return .ok(false);}let usize open=lexer::next(source,ref mut look)?;
    if(look.kind!=93){return .ok(false);}let usize close=lexer::next(source,ref mut look)?;
    if(look.kind!=2){return .ok(false);}let usize name=lexer::next(source,ref mut look)?;
    if(look.kind!=61){return .ok(false);}let usize equal=lexer::next(source,ref mut look)?;
    if(look.kind==3 || look.kind==4 || look.kind==40){return .ok(true);}
    if(word(source,ref look,b"ref")){let usize reference=lexer::next(source,ref mut look)?;}
    if(look.kind!=2){return .ok(false);}
    if(binding(names,locals::find(source,names,look.begin,look.end))){return .ok(true);}
    if(!word(source,ref look,b"text")){return .ok(false);}
    let usize module_name=lexer::next(source,ref mut look)?;return .ok(look.kind==58);
}

// Pure atoms stay separate from effectful endpoint parsing in compiler.
pub fn Result<View,errors::Error> atom(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref literals::Index index,usize depth){
    let usize at=s.begin;if(depth>32 || !index.enabled){return .err(errors::make(4,at));}
    if(s.kind==3 || s.kind==4){
        let usize row=literals::find(index,s.begin,s.end)?;
        let usize made=builders::open(p,index.literals[row],index.kinds[row],index.lengths[row],at)?;
        let usize next=lexer::next(source,s)?;
        return .ok(View{.site=made,.kind=index.kinds[row],.owned=true});
    }
    if(word(source,s,b"ref")){let usize reference=lexer::next(source,s)?;}
    if(s.kind!=2){return .err(errors::make(3,at));}
    let usize local=locals::find(source,names,s.begin,s.end);
    if(!binding(names,local)){return .err(errors::make(3,at));}
    let usize encoded=names.registers[local];let usize next=lexer::next(source,s)?;
    return .ok(View{.site=site(encoded),.kind=kind(encoded),.owned=false});
}
// Lookahead never lowers/evaluates endpoints. Ignore dots in nested expressions.
pub fn Result<bool,errors::Error> range_follows(ref u8[] source,ref lexer::State s){
    if(s.kind!=91){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);var usize brackets=1;var usize groups=0;
    while(brackets!=0){let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==0){return .err(errors::make(2,s.begin));}
        if(look.kind==91){brackets+=1;}else if(look.kind==93){brackets-=1;}
        else if(look.kind==40 || look.kind==123){groups+=1;}
        else if(look.kind==41 || look.kind==125){if(groups==0){return .err(errors::make(2,look.begin));}groups-=1;}
        else if(look.kind==46 && brackets==1 && groups==0){
            let usize dot=lexer::next(source,ref mut look)?;if(look.kind==46){return .ok(true);}
        }
    }return .ok(false);
}
// A parenthesized view needs a following projection in scalar context. Preserve
// ordinary scalar grouping, including groups that merely contain view reads.
pub fn Result<bool,errors::Error> grouped_projection_raw(ref u8[] source,ref lexer::State s,ref locals::Table names){
    if(s.kind!=40){return .ok(false);}var lexer::State look=lexer::snapshot(s);
    var usize depth=0;
    while(look.kind==40){depth+=1;if(depth>32){return .err(errors::make(4,s.begin));}let usize next=lexer::next(source,ref mut look)?;}
    if(word(source,ref look,b"ref")){let usize next=lexer::next(source,ref mut look)?;}
    let bool possible=look.kind==3 || look.kind==4 || (look.kind==2 &&
        (binding(names,locals::find(source,names,look.begin,look.end)) || word(source,ref look,b"text")));
    if(!possible){return .ok(false);}
    look=lexer::snapshot(s);depth=1;
    while(depth!=0){let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==0){return .err(errors::make(2,s.begin));}
        if(look.kind==40){depth+=1;}else if(look.kind==41){depth-=1;}
    }
    let usize after=lexer::next(source,ref mut look)?;return .ok(look.kind==91 || look.kind==46);
}
pub struct Header { usize begin; usize end; u8 kind; }
pub fn Result<Header,errors::Error> header(ref u8[] source,ref mut lexer::State s,
    ref locals::Table names,
    bool mutable,u8 terminator,u8 result_type){
    if(mutable || terminator!=59 || result_type==0){return .err(errors::make(3,s.begin));}
    let usize keyword=lexer::word(source,s,b"ref")?;
    var u8 expected=1;
    if(word(source,s,b"str")){expected=2;let usize tag=lexer::next(source,s)?;}
    else{let usize tag=lexer::word(source,s,b"u8")?;
        let usize open=lexer::punctuation(source,s,91)?;let usize close=lexer::punctuation(source,s,93)?;}
    if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .err(errors::make(2,s.begin));}
    let usize begin=s.begin;let usize end=s.end;
    if(locals::find(source,names,begin,end)!=64){return .err(errors::make(3,begin));}
    if(names.count>=64){return .err(errors::make(4,begin));}
    let usize name=lexer::next(source,s)?;let usize equal=lexer::punctuation(source,s,61)?;
    return .ok(Header{.begin=begin,.end=end,.kind=expected});
}
pub fn Result<usize,errors::Error> bind(ref mut ir::Program p,ref mut locals::Table names,
    ref Header header,ref View value){
    if(value.kind!=header.kind){return .err(errors::make(3,header.begin));}
    let usize made=if(value.owned){value.site}else{builders::alias(p,value.site,header.begin)?};
    return locals::declare(names,header.begin,header.end,192+(header.kind as usize-1)*16+made,false);
}
pub fn Result<usize,errors::Error> equal_head(ref u8[] source,ref mut lexer::State s){
    let usize at=s.begin;let usize module_name=lexer::word(source,s,b"text")?;
    let usize first=lexer::punctuation(source,s,58)?;let usize second=lexer::punctuation(source,s,58)?;
    let usize method=lexer::word(source,s,b"equal")?;let usize open=lexer::punctuation(source,s,40)?;return .ok(at);
}

pub fn Result<bool,errors::Error> grouped_projection(ref u8[] source,ref lexer::State s,ref locals::Table names){
    let probes::Plan plan=probes::inspect_syntax(source,*s,names,4)?;return .ok(plan.kind!=0);
}
