module value_type_work;
import value_properties as properties;
import value_properties_work as checking;
import struct_locate_work as discovery;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;
import std::num as num;
// Original Catalog/token remain pinned and unchanged. Candidate is separate
// private scratch. Five explicit frames replace recursive wrapper parsing.
pub struct Frame { usize at; usize end; usize first; usize second; usize extent; u8 kind; u8 tag; u8 resume; }
fn Frame frame(lexer::State token){return Frame{.at=token.begin,.end=token.end,.first=0,.second=0,.extent=0,.kind=0,.tag=0,.resume=0};}
pub struct State { checking::State check; discovery::State locate; tokens::State scan; lexer::State token; lexer::State look;
    Frame[5] frames; usize depth; usize row; usize id; usize visits; usize look_end; u8 phase; u8 resume;
    bool waiting; bool looking; bool qualified; bool full; bool done; }
pub fn State begin(lexer::State token){return State{.check=checking::empty(),.locate=discovery::begin(0,0,32),.scan=tokens::begin(token),.token=token,.look=lexer::empty(),
    .frames=[frame(token);5],.depth=0,.row=0,.id=0,.visits=0,.look_end=0,.phase=0,.resume=0,.waiting=false,.looking=false,.qualified=false,.full=false,.done=false};}
fn errors::Error error(u8 kind,usize at){return errors::make(kind,at);}
fn errors::Error check_error(properties::Error e,usize at){return error(switch(e){case .Metadata:{5}case .Type:{3}case .Depth:{4}case .Size:{4}},at);}
fn Result<u8,errors::Error> byte(usize value,usize at){let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(error(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(error(4,at))}};}
fn u8 scalar(ref u8[] name){return if(lexer::equal(name,b"i32")){1}else if(lexer::equal(name,b"bool")){2}else if(lexer::equal(name,b"i64")){9}
    else if(lexer::equal(name,b"u8")){10}else if(lexer::equal(name,b"u32")){11}else if(lexer::equal(name,b"usize")){12}else{0};}
fn bool word(ref u8[] source,lexer::State token,ref u8[] name){return token.kind==2 && lexer::equal(source[token.begin..token.end],name);}
fn void next(ref mut State w,u8 phase,bool look){let lexer::State token=if(look){w.look}else{w.token};
    w.scan=tokens::begin(token);w.resume=phase;w.looking=look;w.waiting=true;}
fn void intern(ref mut State w){w.row=0;w.phase=40;}
pub fn lexer::State observed(ref State w){return w.token;}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(error(5,w.frames[0].at));}return .ok(w.id);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref properties::Catalog original,ref mut properties::Catalog candidate,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0 || w.phase==41){let bool initial=w.phase==0;
        let Result<bool,properties::Error> result=if(initial){checking::advance(original,ref mut w.check,meter)}else{checking::advance(candidate,ref mut w.check,meter)};
        let bool done=switch(result){case .ok(v):{v}case .err(e):{return .err(check_error(e,w.frames[w.depth].at));}};
        if(done){w.phase=if(initial){1}else{45};}return .ok(false);}
    if(w.waiting){let usize end=if(w.looking && w.qualified){w.look_end}else{source.len};
        let Result<bool,errors::Error> result=tokens::advance(source[..end],ref mut w.scan,meter);
        let lexer::State token=tokens::observed(ref w.scan);if(w.looking){w.look=token;}else{w.token=token;}
        let bool done=result?;if(done){w.waiting=false;w.phase=w.resume;}return .ok(false);}
    if(w.phase==39){let bool done=discovery::advance(source,ref mut w.locate,meter)?;
        if(done){let discovery::Location found=discovery::prepared(ref w.locate)?;
            if(found.record>=candidate.records.count){return .err(error(3,w.frames[w.depth].at));}
            let u8 nominal=byte(found.record,w.frames[w.depth].at)?;let usize d=w.depth;w.frames[d].kind=3;w.frames[d].tag=nominal;w.row=0;next(w,40,false);}
        return .ok(false);}
    if(!budget::admit(meter,4096,w.frames[w.depth].at)?){return .ok(false);}
    if(w.phase==1){candidate.count=original.count;candidate.records.count=original.records.count;w.row=0;w.phase=2;return .ok(false);}
    if(w.phase==2){if(w.row==64){w.row=0;w.phase=3;return .ok(false);}let usize i=w.row;candidate.nodes[i]=original.nodes[i];w.row+=1;w.visits+=1;return .ok(false);}
    if(w.phase==3){if(w.row==32){w.row=0;w.phase=4;return .ok(false);}let usize i=w.row;candidate.records.fields[i]=original.records.fields[i];w.row+=1;return .ok(false);}
    if(w.phase==4){var usize n=0;while(n<16){let usize i=w.row;candidate.records.kinds[i]=original.records.kinds[i];candidate.records.types[i]=original.records.types[i];w.row+=1;n+=1;}
        if(w.row==512){w.phase=10;}return .ok(false);}
    let usize d=w.depth;var Frame f=w.frames[d];
    if(w.phase==10){let lexer::State token=w.token;if(token.kind!=2 && token.kind!=5){return .err(error(2,f.at));}
        let bool option=word(source,token,b"Option");let bool result=word(source,token,b"Result");
        if(option || result){if(d>=4){return .err(error(4,f.at));}f.kind=if(option){5}else{6};w.frames[d]=f;next(w,11,false);return .ok(false);}
        let u8 tag=if(token.kind==2){scalar(source[token.begin..token.end])}else{0};
        if(tag!=0){f.kind=1;f.tag=tag;w.frames[d]=f;next(w,20,false);return .ok(false);}
        w.qualified=token.kind==5;w.look_end=token.end;w.full=false;
        if(w.qualified){var lexer::State look=lexer::empty();look.cursor=token.begin;w.look=look;next(w,30,true);}
        else{w.look=token;w.phase=30;}return .ok(false);}
    if(w.phase==11){if(w.token.kind!=60){return .err(error(2,w.token.begin));}f.resume=12;w.frames[d]=f;next(w,15,false);return .ok(false);}
    if(w.phase==15){w.depth+=1;let usize child=w.depth;let lexer::State token=w.token;w.frames[child]=frame(token);w.phase=10;return .ok(false);}
    if(w.phase==12 && f.kind==6){if(w.token.kind!=44){return .err(error(2,w.token.begin));}f.resume=13;w.frames[d]=f;next(w,15,false);return .ok(false);}
    if(w.phase==12 || w.phase==13){if(w.token.kind==135){w.token.begin+=1;w.token.kind=62;w.phase=14;}
        else{if(w.token.kind!=62){return .err(error(2,w.token.begin));}next(w,14,false);}return .ok(false);}
    if(w.phase==14){f.tag=byte(f.first,f.at)?;w.frames[d]=f;intern(w);return .ok(false);}
    if(w.phase==20){if(w.token.kind==91){f.kind=2;w.frames[d]=f;next(w,21,false);}else{intern(w);}return .ok(false);}
    if(w.phase==21){if(w.token.kind!=1 || w.token.value<1 || w.token.value>4096){return .err(error(3,w.token.begin));}
        f.extent=switch(num::usize_from_i64(w.token.value)){case .ok(v):{v}case .err(_):{return .err(error(3,w.token.begin));}};w.frames[d]=f;next(w,22,false);return .ok(false);}
    if(w.phase==22){if(w.token.kind!=93){return .err(error(2,w.token.begin));}w.row=0;next(w,40,false);return .ok(false);}
    if(w.phase==30){if(word(source,w.look,b"Buffer")){next(w,37,true);return .ok(false);}
        w.full=word(source,w.look,b"brownie");if(!w.full && !word(source,w.look,b"bytes")){w.phase=38;}else{next(w,31,true);}return .ok(false);}
    if(w.phase==31){if(w.look.kind!=58){w.phase=38;}else{next(w,32,true);}return .ok(false);}
    if(w.phase==32 || w.phase==34 || w.phase==35){if(w.look.kind!=58){return .err(error(2,w.look.begin));}
        let u8 resume=if(w.phase==32){33}else if(w.phase==34){35}else{36};next(w,resume,true);return .ok(false);}
    if(w.phase==33 && w.full){if(!word(source,w.look,b"bytes")){return .err(error(2,w.look.begin));}next(w,34,true);return .ok(false);}
    if(w.phase==33 || w.phase==36){if(!word(source,w.look,b"Buffer")){return .err(error(2,w.look.begin));}next(w,37,true);return .ok(false);}
    if(w.phase==37){if(w.qualified){if(w.look.kind!=0){w.phase=38;return .ok(false);}f.kind=4;f.tag=0;w.frames[d]=f;w.row=0;next(w,40,false);}
        else{w.token=w.look;f.kind=4;f.tag=0;w.frames[d]=f;intern(w);}return .ok(false);}
    if(w.phase==38){if(w.token.kind!=2 || candidate.records.count==0){return .err(error(3,f.at));}w.locate=discovery::begin(f.at,f.end,32);w.phase=39;return .ok(false);}
    if(w.phase==40){let u8 second=byte(f.second,f.at)?;
        if(w.row<candidate.count){let properties::Node node=candidate.nodes[w.row];w.visits+=1;
            if(node.kind==f.kind && node.first==f.tag && node.second==second && node.extent==f.extent){w.id=w.row;w.phase=45;}else{w.row+=1;}return .ok(false);}
        if(candidate.count>=64){return .err(error(4,f.at));}let usize id=candidate.count;
        candidate.nodes[id]=properties::Node{.kind=f.kind,.first=f.tag,.second=second,.extent=f.extent};candidate.count+=1;w.id=id;
        w.check=checking::empty();w.phase=41;return .ok(false);}
    if(w.phase==45){if(w.token.kind==91){return .err(error(3,w.token.begin));}
        if(d==0){w.done=true;return .ok(true);}w.depth-=1;let usize parent=w.depth;let u8 resume=w.frames[parent].resume;
        let usize id=w.id;if(resume==12){w.frames[parent].first=id;}else{w.frames[parent].second=id;}w.phase=resume;return .ok(false);}
    return .err(error(5,f.at));
}
