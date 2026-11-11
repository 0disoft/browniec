module value_catalog_work;
import value_source_functions as raw;
import value_properties as properties;
import value_properties_work as checking;
import value_signature_source as signature;
import functions as functions;
import types as scalar;
import errors as errors;
import metadata_budget as budget;
// Map complete source signatures to exact canonical IDs. One function/parameter
// header or one canonical candidate per stage, after independent catalog proof.
pub struct State { checking::State check; raw::Plan result; usize function; usize parameter; usize row; usize first; usize extent; usize at;
    usize visits; u8 kind; u8 phase; bool returning; bool done; }
pub fn State empty(){return State{.check=checking::empty(),.result=raw::Plan{.results=[0;16],.parameters=[0;128]},
    .function=0,.parameter=0,.row=0,.first=0,.extent=0,.at=0,.visits=0,.kind=0,.phase=0,.returning=false,.done=false};}
fn errors::Error wrong(usize at){return errors::make(3,at);}
pub fn Result<raw::Plan,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,0));}return .ok(w.result);}
fn Result<usize,errors::Error> reference(u8 element,u8 tag,usize length,u8 record,usize at){
    if(element!=10 || tag!=0 || length!=0 || record!=0){return .err(wrong(at));}return .ok(66);}
fn void publish(ref mut State w,usize id){let usize f=w.function;let usize p=f*8+w.parameter;
    if(w.returning){w.result.results[f]=id;}else{w.result.parameters[p]=id;w.parameter+=1;}w.phase=3;}
fn Result<bool,errors::Error> exact(ref properties::Catalog catalog,ref mut State w,u8 tag,usize length,u8 record,bool result,usize at){
    w.returning=result;w.at=at;
    if(tag==13 && result && length==0 && record==0){publish(w,0);return .ok(false);}
    if(signature::typed(tag)){if(length!=0 || record!=0){return .err(wrong(at));}let usize id=signature::type_id(tag,catalog,at)?;publish(w,id+1);return .ok(false);}
    if((record!=0 && (tag!=0 || length!=0)) || (record==0 && !scalar::scalar(tag))){return .err(wrong(at));}
    w.kind=if(record!=0){3}else if(length!=0){2}else{1};w.first=if(record!=0){(record as usize)-1}else{tag as usize};w.extent=length;w.row=0;w.phase=4;return .ok(false);
}
pub fn Result<bool,errors::Error> advance(ref properties::Catalog catalog,ref functions::Table table,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0){let bool done=switch(checking::advance(catalog,ref mut w.check,meter)){case .ok(v):{v}case .err(e):{
                let u8 kind=switch(e){case .Metadata:{5}case .Type:{3}case .Depth:{4}case .Size:{4}};return .err(errors::make(kind,0));}};
        if(done){w.phase=1;}return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.phase==1){if(table.count>16){return .err(errors::make(4,0));}if(table.count==0 || table.entry>=table.count){return .err(wrong(0));}w.phase=2;return .ok(false);}
    let usize f=w.function;
    if(w.phase==2){if(f==16){w.phase=5;return .ok(false);}w.parameter=0;
        if(f>=table.count){if(table.arities[f]!=0 || table.return_types[f]!=0 || table.return_lengths[f]!=0 || table.return_records[f]!=0 || table.return_slice_elements[f]!=0){return .err(wrong(0));}w.phase=3;return .ok(false);}
        let usize at=table.begins[f];if(table.arities[f]>8){return .err(errors::make(4,at));}
        if(table.return_slice_elements[f]!=0){let usize id=reference(table.return_slice_elements[f],table.return_types[f],table.return_lengths[f],table.return_records[f],at)?;
            let usize input=table.return_slice_inputs[f] as usize;
            if(input==0 || input>table.arities[f] || input>8 || !table.param_slices[f*8+input-1] || table.param_slice_elements[f*8+input-1]!=10){return .err(wrong(at));}
            w.returning=true;publish(w,id);return .ok(false);}
        if(table.return_slice_inputs[f]!=0 || table.return_slice_candidates[f]!=0){return .err(wrong(at));}
        return exact(catalog,w,table.return_types[f],table.return_lengths[f],table.return_records[f],true,at);
    }
    if(w.phase==3){if(w.parameter==8){w.function+=1;w.phase=2;return .ok(false);}let usize p=f*8+w.parameter;
        if(f>=table.count || w.parameter>=table.arities[f]){if(table.param_types[p]!=0 || table.param_lengths[p]!=0 || table.param_records[p]!=0 || table.param_slices[p] || table.param_slice_elements[p]!=0){return .err(wrong(0));}
            w.parameter+=1;return .ok(false);}
        let usize at=table.param_begins[p];if(table.param_slices[p]){let usize id=reference(table.param_slice_elements[p],table.param_types[p],table.param_lengths[p],table.param_records[p],at)?;
            w.returning=false;publish(w,id);return .ok(false);}
        if(table.param_slice_elements[p]!=0){return .err(wrong(at));}
        return exact(catalog,w,table.param_types[p],table.param_lengths[p],table.param_records[p],false,at);
    }
    if(w.phase==4){if(w.row==catalog.count){return .err(wrong(w.at));}let usize i=w.row;let properties::Node node=catalog.nodes[i];w.visits+=1;
        if(node.kind==w.kind && node.first as usize==w.first && node.second==0 && node.extent==w.extent){publish(w,i+1);}else{w.row+=1;}return .ok(false);}
    if(w.phase==5){let usize entry=table.entry;if(table.arities[entry]!=0 || table.return_types[entry]!=1 || table.return_lengths[entry]!=0 || table.return_records[entry]!=0){return .err(wrong(table.begins[entry]));}
        w.done=true;return .ok(true);}
    return .err(errors::make(5,0));
}
