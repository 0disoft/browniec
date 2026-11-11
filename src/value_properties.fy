module value_properties;

import types as scalar;
import array_layout as arrays;
import struct_layout as records;

// Private canonical type DAG, in dependency order. No cached property supplied
// by the compiler is trusted. A node never encodes the active runtime variant.
// 1 scalar(first=tag), 2 scalar array(first=tag,extent=length),
// 3 plain record(first=nominal ID), 4 Buffer, 5 Option(first=child),
// 6 Result(first=ok child,second=err child). All other fields are reserved zero.
pub struct Node { u8 kind; u8 first; u8 second; usize extent; }
pub struct Catalog { usize count; Node[64] nodes; records::Catalog records; }
pub struct Property {
    usize bytes; usize alignment; usize payload_offset; usize wrapper_depth;
    bool copyable; bool contains_buffer;
}
pub struct Plan { usize count; Property[64] properties; }
pub enum Error { Metadata; Type; Depth; Size; }

fn Property blank(){return Property{.bytes=0,.alignment=0,.payload_offset=0,
    .wrapper_depth=0,.copyable=false,.contains_buffer=false};}
pub fn Catalog empty(){return Catalog{.count=0,
    .nodes=[Node{.kind=0,.first=0,.second=0,.extent=0};64],.records=records::empty()};}
fn Property plain(usize size,usize alignment){return Property{.bytes=size,.alignment=alignment,
    .payload_offset=0,.wrapper_depth=0,.copyable=true,.contains_buffer=false};}
pub fn Result<Property,Error> array(u8 element,usize length){
    let arrays::Array shape=switch(arrays::scalar(element,length)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };return .ok(plain(shape.bytes,shape.alignment));
}
// Both payloads determine the whole type, including the inactive alternative.
// Option.none has no payload; it never changes Option<T>'s ownership rule.
fn Result<Property,Error> wrapper(Property first,Property second){
    let usize alignment=if(first.alignment>second.alignment){first.alignment}else{second.alignment};
    let usize payload=if(first.bytes>second.bytes){first.bytes}else{second.bytes};
    let usize depth=if(first.wrapper_depth>second.wrapper_depth){first.wrapper_depth}else{second.wrapper_depth};
    if(depth>=4){return .err(.Depth);}
    // Every child is <=65536 bytes and alignment is 1,4,8. Guard the addition
    // before rounding, without native recursion or active-variant inspection.
    if(payload>65536-alignment){return .err(.Size);}
    let usize used=alignment+payload;
    let usize padding=(alignment-used%alignment)%alignment;
    if(padding>65536-used){return .err(.Size);}
    return .ok(Property{.bytes=used+padding,.alignment=alignment,.payload_offset=alignment,
        .wrapper_depth=depth+1,.copyable=first.copyable && second.copyable,
        .contains_buffer=first.contains_buffer || second.contains_buffer});
}
// Keep failure branches scalar-sized: returning Result<Plan,Error> from the
// row loop materializes a complete Plan temporary for every error edge in the
// native development frame, including edges that this catalog never takes.
fn Result<usize,Error> inspect_into(ref Catalog catalog,ref mut Plan result){
    if(catalog.count>64){return .err(.Metadata);}
    // Reuse the independently checked scalar/plain-record-only field grammar,
    // cycle/depth/size proof. Wrapper depth is independent of record depth.
    let records::Plan record_plan=switch(records::plan(ref catalog.records,4096)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    result.count=catalog.count;
    var usize i=0;while(i<64){
        let Node node=catalog.nodes[i];
        if(i>=catalog.count){
            if(node.kind!=0 || node.first!=0 || node.second!=0 || node.extent!=0){return .err(.Metadata);}
        }else{
            if(node.kind<1 || node.kind>6 || (node.kind!=2 && node.extent!=0) ||
                (node.kind!=6 && node.second!=0)){return .err(.Metadata);}
            if(node.kind==1){
                if(!scalar::scalar(node.first)){return .err(.Type);}
                result.properties[i]=array(node.first,1)?;
            }else if(node.kind==2){result.properties[i]=array(node.first,node.extent)?;}
            else if(node.kind==3){
                let usize id=node.first as usize;
                if(id>=record_plan.count){return .err(.Type);}
                result.properties[i]=plain(record_plan.bytes[id],record_plan.alignments[id]);
            }else if(node.kind==4){
                if(node.first!=0){return .err(.Metadata);}
                var Property owned=plain(8,8);owned.copyable=false;owned.contains_buffer=true;
                result.properties[i]=owned;
            }else{
                let usize first=node.first as usize;let usize second=node.second as usize;
                if(first>=i || (node.kind==6 && second>=i)){return .err(.Type);}
                let Property left=result.properties[first];
                let Property right=if(node.kind==6){result.properties[second]}else{plain(0,1)};
                let Property combined=wrapper(left,right)?;result.properties[i]=combined;
            }
        }i+=1;
    }return .ok(result.count);
}
pub fn Result<Plan,Error> inspect(ref Catalog catalog){
    var Plan result=Plan{.count=0,.properties=[blank();64]};
    let usize checked=inspect_into(catalog,ref mut result)?;return .ok(result);
}
// Existing compact scalar/tagged cells keep their wire encoding and prices.
// This maps their declared types, never their packed active payload, to the
// structural layout used by future wide/resource value storage.
pub fn Result<Property,Error> legacy(u8 tag){
    if(scalar::scalar(tag)){return array(tag,1);}
    if(!scalar::tagged(tag)){return .err(.Type);}
    let Property first=array(scalar::payload(tag,1),1)?;
    let Property second=if(tag<=4){plain(0,1)}else{array(scalar::payload(tag,0),1)?};
    return wrapper(first,second);
}
