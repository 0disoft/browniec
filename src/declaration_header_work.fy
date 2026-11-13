module declaration_header_work;
import declaration_name_work as names_work;
import type_parse_work as annotations;
import lexer_work as tokens;
import lexer as lexer;
import locals as locals;
import types as types;
import array_source as arrays;
import cells as cells;
import errors as errors;
import metadata_budget as budget;
// modes 1 typed scalar/wrapper/array, 2 slice, 3 static byte/text, 4 record.
// Record layout validation is an explicit child request, before token changes.
pub struct Prepared { usize begin; usize end; usize length; u8 tag; bool exclusive; }
pub struct State { names_work::State name; annotations::State annotation; tokens::State token;
    Prepared result; usize at; u8 mode; u8 phase; u8 resume; u8 request; u8 terminator; u8 result_type;
    bool mutable; bool full; bool waiting; bool typing; bool naming; bool done; }
pub fn State begin(lexer::State s,u8 mode,bool mutable,u8 terminator,u8 result_type,bool full){return State{
    .name=names_work::begin(s,full,0),.annotation=annotations::begin(s),.token=tokens::begin(s),
    .result=Prepared{.begin=0,.end=0,.length=0,.tag=0,.exclusive=false},.at=s.begin,.mode=mode,.phase=0,.resume=0,.request=0,
    .terminator=terminator,.result_type=result_type,.mutable=mutable,.full=full,.waiting=false,.typing=false,.naming=false,.done=false};}
pub fn Result<Prepared,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);}
pub fn Result<usize,errors::Error> resume(ref mut State w){if(w.done || w.request!=1){return .err(errors::make(5,w.at));}w.request=0;return .ok(0);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){
    if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}w.token=tokens::begin(*s);w.resume=phase;w.waiting=true;return .ok(false);}
fn void typing(ref mut State w,ref lexer::State s,u8 phase){w.annotation=annotations::begin(*s);w.typing=true;w.phase=phase;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref locals::Table names,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.waiting=false;w.phase=w.resume;}return .ok(false);}};}
    if(w.typing){let Result<bool,errors::Error> r=annotations::advance(source,ref mut w.annotation,meter);*s=annotations::observed(ref w.annotation);
        switch(r){case .err(e):{return .err(e);}case .ok(done):{if(done){w.result.tag=annotations::prepared(ref w.annotation)?;w.typing=false;}return .ok(false);}};}
    if(w.naming){let bool done=names_work::advance(source,s,names,ref mut w.name,meter)?;
        if(done){w.result.begin=names_work::prepared(ref w.name)?;w.result.end=w.name.end;w.naming=false;w.done=true;}return .ok(w.done);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    if(w.phase==0){if(w.mode==1){typing(w,s,1);return .ok(false);}
        if(w.mode==4){w.request=1;w.phase=40;return .ok(false);}
        if(w.mode!=2 && w.mode!=3){return .err(errors::make(5,w.at));}
        if(w.mutable || w.terminator!=59 || w.result_type==0){return .err(errors::make(3,s.begin));}
        if(!word(source,s,b"ref")){return .err(errors::make(2,s.begin));}let u8 phase=if(w.mode==2){20}else{30};return take(w,s,0,phase);}
    if(w.phase==1){if(s.kind==91){return take(w,s,91,2);}w.phase=4;return .ok(false);}
    if(w.phase==2){if(s.kind!=1 || s.value<1 || s.value>4096){return .err(errors::make(3,s.begin));}
        w.result.length=cells::unpack(s.value,s.begin)?;return take(w,s,0,3);}
    if(w.phase==3){return take(w,s,93,4);}
    if(w.phase==4){if(w.result.length!=0 && (w.result_type==0 || w.terminator!=59 || !types::scalar(w.result.tag))){return .err(errors::make(3,s.begin));}
        w.phase=50;return .ok(false);}
    if(w.phase==20){w.result.exclusive=word(source,s,b"mut");if(w.result.exclusive){return take(w,s,0,24);}typing(w,s,21);return .ok(false);}
    if(w.phase==24){typing(w,s,21);return .ok(false);}
    if(w.phase==21){if(!types::scalar(w.result.tag)){return .err(errors::make(3,s.begin));}return take(w,s,91,22);}
    if(w.phase==22){return take(w,s,93,50);}
    if(w.phase==30){if(word(source,s,b"str")){w.result.tag=2;return take(w,s,0,50);}
        if(!word(source,s,b"u8")){return .err(errors::make(2,s.begin));}w.result.tag=1;return take(w,s,0,31);}
    if(w.phase==31){return take(w,s,91,32);}if(w.phase==32){return take(w,s,93,50);}
    if(w.phase==40){return take(w,s,0,50);}
    if(w.phase==50){w.name=names_work::begin(*s,w.full,0);w.naming=true;return .ok(false);}
    return .err(errors::make(5,s.begin));
}
pub fn Result<Prepared,errors::Error> prepare(ref u8[] source,ref mut lexer::State s,ref locals::Table names,
    u8 mode,bool mutable,u8 terminator,u8 result_type){if(source.len>4096 && mode==1){return typed_raw(source,s,names,terminator,result_type);}
    var State w=begin(*s,mode,mutable,terminator,result_type,false);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;let bool done=advance(source,s,names,ref mut w,ref mut meter)?;
        if(w.request!=0){return .err(errors::make(5,w.at));}}return prepared(ref w);
}
// Original ordinary annotated-header sequence, independent of the staged paths.
pub fn Result<Prepared,errors::Error> typed_raw(ref u8[] source,ref mut lexer::State s,ref locals::Table names,u8 terminator,u8 result_type){
    let u8 tag=types::parse_raw(source,s)?;let usize length=if(s.kind==91){arrays::length(source,s)?}else{0};
    if(length!=0 && (result_type==0 || terminator!=59 || !types::scalar(tag))){return .err(errors::make(3,s.begin));}
    if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .err(errors::make(2,s.begin));}let usize begin=s.begin;let usize end=s.end;
    if(locals::find(source,names,begin,end)!=64){return .err(errors::make(3,begin));}if(names.count>=64){return .err(errors::make(4,begin));}
    let usize name=lexer::next(source,s)?;let usize equal=lexer::punctuation(source,s,61)?;
    return .ok(Prepared{.begin=begin,.end=end,.length=length,.tag=tag,.exclusive=false});
}
