module signature_type_work;
import value_signature_work as value_signatures;
import value_signature_source as value_types;
import value_properties as value_properties;
import lexer as lexer;
import lexer_work as tokens;
import type_parse_work as primitives;
import source_name_work as names;
import source_context as context;
import locals as locals;
import types as types;
import errors as errors;
import cells as cells;
import std::num as num;
import metadata_budget as budget;

// Untyped signature annotations: primitive/wrapper, nominal, scalar array and
// scalar[] borrow. Token, primitive and scoped-name children resume separately.
// An unscoped nominal yields an explicit discovery request to its owning pass;
// it must never call the atomic declaration scanner inside this continuation.
pub struct Annotation { u8 tag; u8 record; usize length; bool slice; u8 element; }
pub struct State { tokens::State scan; primitives::State primitive; names::State name;
    lexer::State token; Annotation result; usize at; u8 phase; u8 resume;
    bool allow_void; bool exclusive; bool waiting; bool request_record; bool done; }
pub fn State begin(lexer::State token,bool allow_void){return State{.scan=tokens::begin(token),
    .primitive=primitives::begin(token),.name=names::begin(0,0,true),.token=token,
    .result=Annotation{.tag=0,.record=0,.length=0,.slice=false,.element=0},.at=token.begin,
    .phase=0,.resume=0,.allow_void=allow_void,.exclusive=false,.waiting=false,.request_record=false,.done=false};}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] spelling){
    return s.kind==2 && lexer::equal(source[s.begin..s.end],spelling);
}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;
    w.scan=tokens::begin(current);w.resume=phase;w.waiting=true;}
fn Result<u8,errors::Error> code(usize id,usize at){
    return switch(num::u8_from_i64(cells::pack(id+1,at)?)){
        case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
// The owner admits the fixed request/response framing. IDs are source analysis
// results, not an authority receipt. Keep the exact queried source pinned.
pub fn Result<bool,errors::Error> resolved_record(ref mut State w,usize id){
    if(!w.request_record || w.phase!=4 || w.done){return .err(errors::make(5,w.at));}
    if(id>=32){return .err(errors::make(3,w.at));}
    let u8 record=code(id,w.at)?;w.result.record=record;w.request_record=false;next(w,5);return .ok(false);
}
pub fn lexer::State observed(ref State w){return w.token;}
pub fn Result<Annotation,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref context::Table scope,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request_record){return .ok(false);}
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);
        switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(w.phase==3){let Result<bool,errors::Error> result=primitives::advance(source,ref mut w.primitive,meter);
        w.token=primitives::observed(ref w.primitive);
        let bool done=result?;if(done){let u8 tag=primitives::prepared(ref w.primitive)?;
            if(w.result.slice){if(!types::scalar(tag)){return .err(errors::make(3,w.token.begin));}
                w.result.element=tag|if(w.exclusive){128}else{0};w.phase=9;
            }else{w.result.tag=tag;w.phase=7;}}
        return .ok(false);
    }
    if(w.phase==4){let bool done=names::advance(source,scope,ref mut w.name,meter)?;
        if(done){let usize id=w.name.result;if(id>=32){return .err(errors::make(3,w.at));}
            let u8 record=code(id,w.at)?;w.result.record=record;next(w,5);}
        return .ok(false);
    }
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.phase==0){
        if(word(source,ref w.token,b"ref")){w.result.slice=true;next(w,1);}
        else if(w.allow_void && word(source,ref w.token,b"void")){w.result.tag=13;next(w,7);}
        else{w.phase=2;}return .ok(false);
    }
    if(w.phase==1){w.exclusive=word(source,ref w.token,b"mut");
        if(w.exclusive){next(w,2);}else{w.phase=2;}return .ok(false);}
    if(w.phase==2){
        let lexer::State current=w.token;
        if(w.result.slice || (current.kind!=2 && current.kind!=5) || locals::reserved(source[current.begin..current.end])){
            w.primitive=primitives::begin(current);w.phase=3;
        }else{w.at=current.begin;w.name=names::begin(current.begin,current.end,true);w.phase=4;
            if(scope.modules==0){w.request_record=true;}}
        return .ok(false);
    }
    if(w.phase==5){if(w.token.kind==60){return .err(errors::make(3,w.token.begin));}w.phase=7;return .ok(false);}
    if(w.phase==7){if(w.token.kind==91){if(!types::scalar(w.result.tag)){return .err(errors::make(3,w.token.begin));}
            next(w,8);return .ok(false);}w.done=true;return .ok(true);}
    if(w.phase==8){if(w.token.kind!=1 || w.token.value<1 || w.token.value>4096){return .err(errors::make(3,w.token.begin));}
        let usize length=cells::unpack(w.token.value,w.token.begin)?;w.result.length=length;next(w,11);return .ok(false);}
    if(w.phase==9){if(w.token.kind!=91){return .err(errors::make(2,w.token.begin));}next(w,10);return .ok(false);}
    if(w.phase==10){if(w.token.kind!=93){return .err(errors::make(2,w.token.begin));}next(w,7);return .ok(false);}
    if(w.phase==11){if(w.token.kind!=93){return .err(errors::make(2,w.token.begin));}next(w,12);return .ok(false);}
    if(w.phase==12){w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}

// Typed annotations reuse legacy ref/void transitions without enlarging the
// legacy continuation. The owner supplies a separate value parser scratch bank.
pub fn Result<bool,errors::Error> advance_values(ref u8[] source,ref context::Table scope,
    ref mut value_properties::Catalog catalog,ref mut value_signatures::State value,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0 && !word(source,ref w.token,b"ref") && !(w.allow_void && word(source,ref w.token,b"void"))){
        if(!budget::admit(meter,4096,w.at)?){return .ok(false);}let lexer::State token=w.token;*value=value_signatures::begin(token);w.phase=15;return .ok(false);}
    if(w.phase==15){let Result<bool,errors::Error> result=value_signatures::advance(source,catalog,value,meter);w.token=value_signatures::observed(value);
        let bool done=result?;if(done){let value_types::Type type=value_signatures::prepared(value)?;
            w.result.tag=type.tag;w.result.length=type.length;w.result.record=type.record;w.done=true;return .ok(true);}return .ok(false);}
    return advance(source,scope,w,meter);
}
