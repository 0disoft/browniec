module value_properties_work;
import value_properties as raw;
import struct_layout_work as records;
import types as scalar;
import metadata_budget as budget;
// Owner pins the exact candidate Catalog. Record shape/dependency/layout work
// resumes in its existing kernel; canonical nodes and reserved tails use one row.
pub struct State { raw::Plan result; records::State records; usize row; usize visits; u8 phase; bool done; }
fn raw::Property blank(){return raw::Property{.bytes=0,.alignment=0,.payload_offset=0,.wrapper_depth=0,.copyable=false,.contains_buffer=false};}
fn raw::Property plain(usize size,usize alignment){return raw::Property{.bytes=size,.alignment=alignment,.payload_offset=0,.wrapper_depth=0,.copyable=true,.contains_buffer=false};}
pub fn State empty(){return State{.result=raw::Plan{.count=0,.properties=[blank();64]},.records=records::empty(),.row=0,.visits=0,.phase=0,.done=false};}
pub fn Result<raw::Plan,raw::Error> prepared(ref State w){if(!w.done){return .err(.Metadata);}return .ok(w.result);}
fn Result<raw::Property,raw::Error> wrapper(raw::Property a,raw::Property b){
    let usize alignment=if(a.alignment>b.alignment){a.alignment}else{b.alignment};
    let usize payload=if(a.bytes>b.bytes){a.bytes}else{b.bytes};
    let usize depth=if(a.wrapper_depth>b.wrapper_depth){a.wrapper_depth}else{b.wrapper_depth};
    if(depth>=4){return .err(.Depth);}if(payload>65536-alignment){return .err(.Size);}
    let usize used=alignment+payload;let usize padding=(alignment-used%alignment)%alignment;
    if(padding>65536-used){return .err(.Size);}
    return .ok(raw::Property{.bytes=used+padding,.alignment=alignment,.payload_offset=alignment,.wrapper_depth=depth+1,
        .copyable=a.copyable && b.copyable,.contains_buffer=a.contains_buffer || b.contains_buffer});
}
pub fn Result<bool,raw::Error> advance(ref raw::Catalog catalog,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==1){let bool done=switch(records::advance(ref mut w.records,ref catalog.records,meter)){
            case .ok(v):{v}case .err(_):{return .err(.Type);}};
        if(done){w.phase=2;}return .ok(false);}
    let bool admitted=switch(budget::admit(meter,4096,0)){case .ok(v):{v}case .err(_):{return .err(.Metadata);}};
    if(!admitted){return .ok(false);}
    if(w.phase==0){if(catalog.count>64){return .err(.Metadata);}w.result.count=catalog.count;
        switch(records::begin(ref mut w.records,4096)){case .ok(_):{}case .err(_):{return .err(.Type);}};w.phase=1;return .ok(false);}
    if(w.phase==2){if(w.row==64){w.done=true;return .ok(true);}let usize i=w.row;let raw::Node node=catalog.nodes[i];w.visits+=1;
        if(i>=catalog.count){if(node.kind!=0 || node.first!=0 || node.second!=0 || node.extent!=0){return .err(.Metadata);}}
        else{if(node.kind<1 || node.kind>6 || (node.kind!=2 && node.extent!=0) || (node.kind!=6 && node.second!=0)){return .err(.Metadata);}
            if(node.kind==1){if(!scalar::scalar(node.first)){return .err(.Type);}let raw::Property p=raw::array(node.first,1)?;w.result.properties[i]=p;}
            else if(node.kind==2){let raw::Property p=raw::array(node.first,node.extent)?;w.result.properties[i]=p;}
            else if(node.kind==3){let usize id=node.first as usize;if(id>=w.records.plan.count){return .err(.Type);}
                let raw::Property p=plain(w.records.plan.bytes[id],w.records.plan.alignments[id]);w.result.properties[i]=p;}
            else if(node.kind==4){if(node.first!=0){return .err(.Metadata);}var raw::Property p=plain(8,8);p.copyable=false;p.contains_buffer=true;w.result.properties[i]=p;}
            else{let usize a=node.first as usize;let usize b=node.second as usize;if(a>=i || (node.kind==6 && b>=i)){return .err(.Type);}
                let raw::Property first=w.result.properties[a];let raw::Property second=if(node.kind==6){w.result.properties[b]}else{plain(0,1)};
                let raw::Property p=wrapper(first,second)?;w.result.properties[i]=p;}}
        w.row+=1;return .ok(false);}
    return .err(.Metadata);
}
