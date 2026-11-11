module value_signature_source;
import value_type_source as syntax;
import value_properties as properties;
import lexer as lexer;
import errors as errors;
import std::num as num;
import value_signature_work as staged;
import metadata_budget as budget;

// Source candidates only. Tags128..191 encode a canonical type ID for the
// typed body lowerer; they are never ordinary scalar IR register tags.
pub struct Type { u8 tag; usize length; u8 record; }
fn Result<u8,errors::Error> byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}
    };
    return switch(num::u8_from_i64(wide)){
        case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}
    };
}
pub fn Result<Type,errors::Error> parse_raw(ref u8[] source,ref mut lexer::State cursor,
    ref mut properties::Catalog catalog){
    let usize at=cursor.begin;let usize id=syntax::parse_raw(source,cursor,catalog)?;
    if(id>=catalog.count || id>=64){return .err(errors::make(5,at));}
    let properties::Node node=catalog.nodes[id];
    if(node.kind==1){return .ok(Type{.tag=node.first,.length=0,.record=0});}
    if(node.kind==2){return .ok(Type{.tag=node.first,.length=node.extent,.record=0});}
    if(node.kind==3){return .ok(Type{.tag=0,.length=0,.record=byte((node.first as usize)+1,at)?});}
    if(node.kind>=4 && node.kind<=6){return .ok(Type{.tag=byte(128+id,at)?,.length=0,.record=0});}
    return .err(errors::make(5,at));
}
pub fn bool typed(u8 tag){return tag>=128 && tag<192;}
pub fn Result<usize,errors::Error> type_id(u8 tag,ref properties::Catalog catalog,usize at){
    if(!typed(tag)){return .err(errors::make(3,at));}
    let usize id=(tag as usize)-128;
    if(id>=catalog.count || id>=64 || catalog.nodes[id].kind<4 || catalog.nodes[id].kind>6){return .err(errors::make(5,at));}
    return .ok(id);
}

// Owning compatibility adapter. No public Pending compile protocol.
pub fn Result<Type,errors::Error> parse(ref u8[] source,ref mut lexer::State cursor,ref mut properties::Catalog catalog){
    if(source.len>4096){return parse_raw(source,cursor,catalog);}
    var staged::State w=staged::begin(*cursor);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,cursor.begin)?;let bool done=staged::advance(source,catalog,ref mut w,ref mut meter)?;}
    let Type result=staged::prepared(ref w)?;*cursor=staged::observed(ref w);return .ok(result);
}
