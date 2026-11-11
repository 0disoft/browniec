module value_signature_work;
import value_type_work as parsing;
import value_properties as properties;
import value_signature_source as raw;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
import std::num as num;
// Separate candidate/control banks retain the caller catalog and lexer on error.
pub struct State { parsing::State parser; properties::Catalog candidate; raw::Type result; lexer::State token; usize at; u8 phase; bool done; }
pub fn State begin(lexer::State token){return State{.parser=parsing::begin(token),.candidate=properties::empty(),
    .result=raw::Type{.tag=0,.length=0,.record=0},.token=token,.at=token.begin,.phase=0,.done=false};}
fn Result<u8,errors::Error> byte(usize value,usize at){let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};}
pub fn lexer::State observed(ref State w){return w.token;}
pub fn Result<raw::Type,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut properties::Catalog catalog,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0){var parsing::State frame=w.parser;
        let Result<bool,errors::Error> result=parsing::advance(source,catalog,ref mut w.candidate,ref mut frame,meter);w.parser=frame;
        w.token=parsing::observed(ref w.parser);let bool done=result?;if(done){w.phase=1;}return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.phase==1){let usize id=parsing::prepared(ref w.parser)?;if(id>=w.candidate.count || id>=64){return .err(errors::make(5,w.at));}
        let properties::Node node=w.candidate.nodes[id];var raw::Type result=raw::Type{.tag=0,.length=0,.record=0};
        if(node.kind==1){result.tag=node.first;}else if(node.kind==2){result.tag=node.first;result.length=node.extent;}
        else if(node.kind==3){result.record=byte((node.first as usize)+1,w.at)?;}
        else if(node.kind>=4 && node.kind<=6){result.tag=byte(128+id,w.at)?;}else{return .err(errors::make(5,w.at));}
        w.result=result;*catalog=w.candidate;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
