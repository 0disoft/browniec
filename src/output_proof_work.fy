module output_proof_work;
import static_call_ir as programs;
import static_image as images;
import output_return_proof as raw;
import output_return_signature_work as signatures;
import output_program_copy_work as copying;
import output_normalize_work as normalizing;
import output_canonical_proof_work as canonical;
import output_borrowed_origins_work as origins;
import output_borrowed_calls_work as borrowed_calls;
import functions as functions;
import types as types;
import errors as errors;
import metadata_budget as budget;
import ir as ir;
import output_return_ir as returns;
import slice_result_origins as grounded_origins;
import struct_layout as layouts;

// Analysis work only. The owning adapter pins exact source and immutable image;
// normalized is a distinct private scratch Program, never retained authority.
// One advance runs one leaf stage. Failed/partial states cannot yield a Proof.
pub struct State {
    signatures::State signature; copying::State copy; normalizing::State normalize;
    canonical::State canonical; origins::State origins; borrowed_calls::State borrowed;
    functions::Table table; u8 phase; bool input; bool done;
}
pub fn State empty(bool input){return State{.signature=signatures::empty(),.copy=copying::empty(),
    .normalize=normalizing::empty(),.canonical=canonical::empty(input),.origins=origins::empty(),
    .borrowed=borrowed_calls::empty(),.table=functions::empty(),.phase=0,.input=input,.done=false};}
fn returns::Signature signature_output(ref signatures::State w){return w.output;}
fn grounded_origins::Summary summary(ref origins::State w){return w.result;}
fn Result<usize,errors::Error> signature(ref programs::Program original,ref signatures::State checked){
    // The independent admitted-loan signature check precedes origin solving.
    // <=16 fixed signature rows and <=256 PCs; no catalog or operand traversal.
    let ref ir::Program p=ref original.body;
    let returns::Signature signature=signature_output(checked);
    if(p.count==0 || p.count>256 || p.function_count==0 || p.function_count>16){return .err(errors::make(5,0));}
    var usize f=0;while(f<16){let u8 tag=signature.elements[f];let u8 selected=signature.parameters[f];
        if((f>=p.function_count && (tag!=0 || selected!=0)) || (tag==0 && selected!=0) ||
            (tag!=0 && (!types::scalar(tag&127) || selected==0 || selected>8 || selected as usize>p.arities[f] || f==p.entry))){return .err(errors::make(5,0));}f+=1;}
    var usize pc=0;while(pc<p.count){if(p.code[pc*8]==9){let usize target=p.code[pc*8+2] as usize;
        if(target<16 && signature.elements[target]!=0){return .err(errors::make(5,pc));}}pc+=1;}
    return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref programs::Program original,ref images::Image image,
    ref mut programs::Program normalized,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==1){let bool done=signatures::advance(ref mut w.signature,original,meter)?;
        if(done){w.phase=if(w.signature.output.borrowed){2}else{4};}return .ok(false);}
    if(w.phase==2){let bool done=copying::advance(original,normalized,ref mut w.copy,meter)?;
        if(done){w.phase=3;}return .ok(false);}
    if(w.phase==3){let returns::Signature signature=signature_output(ref w.signature);
        let bool done=normalizing::advance(normalized,ref signature,ref mut w.normalize,meter)?;
        if(done){w.phase=4;}return .ok(false);}
    if(w.phase==4){
        let bool done=if(w.signature.output.borrowed){canonical::advance(normalized,image,ref mut w.canonical,meter)?}
            else{canonical::advance(original,image,ref mut w.canonical,meter)?};
        if(done){if(w.signature.output.borrowed){w.phase=5;}else{w.done=true;}}return .ok(w.done);
    }
    if(w.phase==6){let functions::Table table=w.table;
        let bool done=origins::advance(ref normalized.body,ref table,ref original.body,ref mut w.origins,meter)?;
        if(done){w.phase=7;}return .ok(false);}
    if(w.phase==7){let returns::Signature signature=signature_output(ref w.signature);
        let grounded_origins::Summary grounded=summary(ref w.origins);
        let layouts::Plan plan=canonical::layout(ref w.canonical);
        let bool done=borrowed_calls::advance(ref normalized.body,ref original.body,ref signature,
        ref grounded,ref plan,ref mut w.borrowed,meter)?;
        if(done){w.done=true;}return .ok(w.done);}
    if(!budget::admit(meter,4096,0)?){return .ok(false);}
    if(w.phase==0){let usize started=signatures::begin(ref mut w.signature,original)?;w.phase=1;}
    else if(w.phase==5){let usize checked=signature(original,ref w.signature)?;
        let ref ir::Program proxy=ref normalized.body;let returns::Signature signature=signature_output(ref w.signature);
        w.table.count=proxy.function_count;w.table.entry=proxy.entry;
        w.table.arities=proxy.arities;w.table.return_slice_elements=signature.elements;w.phase=6;
    }else{return .err(errors::make(5,0));}
    return .ok(false);
}
pub fn Result<raw::Proof,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,0));}
    let returns::Signature signature=signature_output(ref w.signature);
    let grounded_origins::Summary grounded=summary(ref w.origins);
    let raw::Proof proof=raw::Proof{.ordinary=canonical::prepared(ref w.canonical)?,
        .parameters=if(signature.borrowed){grounded.parameters}else{[0;16]},
        .elements=signature.elements};return .ok(proof);
}
// Synchronous compatibility adapters drain exactly these resumable stages.
// They promise no wall-time bound or public Pending compile protocol.
pub fn Result<raw::Proof,errors::Error> inspect(ref programs::Program unit,ref images::Image image,bool input){
    var State w=empty(input);var programs::Program normalized=programs::Program{.body=ir::empty(),
        .parameters=[0;128],.results=[0;16],.origins=[0;16]};var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;
        let bool done=advance(unit,image,ref mut normalized,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}
