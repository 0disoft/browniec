module value_frame_layout;
import value_codec as codec;
import value_properties as value_properties;

pub enum Error { Metadata; Type; Layout; }
struct Slots {
    u8[16] types; u8[16] functions; usize[16] offsets;
    usize[16] widths; usize count; usize largest;
}
// Immutable native byte-layout metadata, never executable IR authority.
pub resource Plan { codec::Layout layout; Slots slots; cleanup { } }

pub fn Result<Plan,Error> retain(ref value_properties::Catalog catalog,
    ref u8[] types,ref u8[] functions,usize function_count){
    if(types.len!=16 || functions.len!=16 || function_count==0 || function_count>16){return .err(.Metadata);}
    let codec::Layout layout=switch(codec::retain(catalog)){
        case .ok(v):{v}case .err(_):{return .err(.Layout);}
    };
    var Slots slots=Slots{.types=[0;16],.functions=[0;16],.offsets=[0;16],
        .widths=[0;16],.count=function_count,.largest=0};
    var usize[16] alignments=[1;16];var usize i=0;
    while(i<16){
        let usize function=functions[i] as usize;let u8 encoded=types[i];
        if(encoded==0){if(function!=0){return .err(.Metadata);}}
        else{
            if(function>=function_count){return .err(.Metadata);}
            let value_properties::Property shape=switch(codec::shape(ref layout,(encoded as usize)-1)){
                case .ok(v):{v}case .err(_):{return .err(.Type);}
            };
            let usize used=slots.widths[function];
            if(shape.alignment==0 || shape.bytes>1048576 || used>1048576){return .err(.Layout);}
            let usize padding=(shape.alignment-used%shape.alignment)%shape.alignment;
            if(padding>1048576-used){return .err(.Layout);}
            let usize at=used+padding;
            if(shape.bytes>1048576-at){return .err(.Layout);}
            slots.offsets[i]=at;slots.widths[function]=at+shape.bytes;
            slots.types[i]=encoded;slots.functions[i]=functions[i];
            if(shape.alignment>alignments[function]){alignments[function]=shape.alignment;}
            if(shape.bytes>slots.largest){slots.largest=shape.bytes;}
        }i+=1;
    }
    i=0;var usize total=0;while(i<function_count){
        let usize used=slots.widths[i];let usize alignment=alignments[i];
        let usize padding=(alignment-used%alignment)%alignment;
        if(padding>1048576-used){return .err(.Layout);}
        let usize size=used+padding;
        if(size>1048576-total){return .err(.Layout);}
        total+=size;slots.widths[i]=size;i+=1;
    }
    return .ok(Plan{.layout=layout,.slots=slots});
}
pub fn ref codec::Layout layout(ref Plan p){return ref p.layout;}
pub fn usize functions(ref Plan p){return p.slots.count;}
pub fn usize largest(ref Plan p){return p.slots.largest;}
pub fn Result<usize,Error> type_id(ref Plan p,usize slot,usize function){
    if(slot>=16 || function>=p.slots.count){return .err(.Metadata);}
    if(p.slots.types[slot]==0 || p.slots.functions[slot] as usize!=function){return .err(.Type);}
    return .ok((p.slots.types[slot] as usize)-1);
}
pub fn Result<usize,Error> offset(ref Plan p,usize slot){
    if(slot>=16){return .err(.Metadata);}
    if(p.slots.types[slot]==0){return .err(.Type);}
    return .ok(p.slots.offsets[slot]);
}
pub fn Result<usize,Error> width(ref Plan p,usize function){
    if(function>=p.slots.count){return .err(.Metadata);}
    return .ok(p.slots.widths[function]);
}
