module output_return_ir;
import ir as ir;
import static_call_ir as images;
import functions as functions;
import reference_call_source as references;
import slice_result_call_ir as calls;
import errors as errors;
import types as types;

// Construction/normalization only. These descriptors contain no proof or live
// tickets. The output adapter must prove the exact normalized CFG and then
// independently ground every original borrowed-result recipe.
pub struct Signature { u8[16] elements; u8[16] parameters; bool borrowed; }
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Signature empty(){return Signature{.elements=[0;16],.parameters=[0;16],.borrowed=false};}

// The source lowerer already emits CALL66 recipes. Convert only terminal
// borrowed-result identities; shared image/input returns retain their dialect.
pub fn Result<usize,errors::Error> lower(ref mut ir::Program p,ref functions::Table signatures){
    if(p.count>256 || p.function_count>16 || signatures.count!=p.function_count){return .err(invalid(0));}
    var usize count=0;var usize f=0;
    while(f<p.function_count){
        if(p.starts[f]>=p.ends[f] || p.ends[f]>p.count){return .err(invalid(0));}
        if(signatures.return_slice_elements[f]!=0 && !references::result(signatures,f)){
            var usize pc=p.starts[f];
            while(pc<p.ends[f]){if(p.code[pc*8]==8){
                let u8 identity=p.code[pc*8+2];var usize definition=256;var usize at=p.starts[f];
                while(at<pc){if((p.code[at*8]==57 || p.code[at*8]==9) && p.code[at*8+1]==identity){definition=at;}at+=1;}
                if(definition==256){return .err(errors::make(5,p.offsets[pc]));}
                let u8 prepared=if(p.code[definition*8]==57){63}else{64};
                p.code[definition*8]=prepared;p.code[pc*8]=65;count+=1;
            }pc+=1;}
        }f+=1;
    }return .ok(count);
}
// Bound all reads before the complete canonical proof. Infer exact result tags
// from PREPARE_VIEW and propagate through forwarding edges; cycles without a
// grounded producer fail. Claimed input positions are rechecked independently.
pub fn Result<Signature,errors::Error> signature(ref images::Program unit){
    let ref ir::Program p=ref unit.body;
    if(p.count==0 || p.count>256 || p.function_count==0 || p.function_count>16 || p.entry>=p.function_count){return .err(invalid(0));}
    // Populate local arrays before assembling the returned descriptor.
    var u8[16] elements=[0;16];var u8[16] parameters=[0;16];var bool borrowed=false;var bool[16] used=[false;16];var usize f=0;
    while(f<p.function_count){
        if(p.starts[f]>=p.ends[f] || p.ends[f]>p.count){return .err(invalid(0));}
        var usize pc=p.starts[f];
        while(pc<p.ends[f]){let usize at=pc*8;let u8 op=p.code[at];
            if(op==63 || op==64 || op==65){used[f]=true;borrowed=true;}
            if(op==63){let usize site=p.code[at+2] as usize;
                if(site>=16){return .err(invalid(pc));}let u8 tag=p.slice_elements[site];
                if(!types::scalar(tag&127) || (elements[f]!=0 && elements[f]!=tag)){return .err(invalid(pc));}
                elements[f]=tag;
            }
            if(op==64 && p.code[at+2] as usize>=p.function_count){return .err(invalid(pc));}
            pc+=1;
        }f+=1;
    }
    if(!borrowed){return .ok(Signature{.elements=elements,.parameters=parameters,.borrowed=borrowed});}
    var usize round=0;var bool changed=true;while(round<16 && changed){changed=false;f=0;while(f<p.function_count){var usize pc=p.starts[f];
        while(pc<p.ends[f]){if(p.code[pc*8]==64){let usize target=p.code[pc*8+2] as usize;let u8 tag=elements[target];
            if(!used[target] || (tag!=0 && elements[f]!=0 && tag!=elements[f])){return .err(invalid(pc));}
            if(tag!=0 && elements[f]==0){elements[f]=tag;changed=true;}
        }pc+=1;}f+=1;}round+=1;}
    f=0;while(f<16){if(used[f]){
        let u8 selected=unit.origins[f];
        if(f==p.entry || elements[f]==0 || selected==0 || selected>8 || selected as usize>p.arities[f] ||
            unit.results[f]!=0 || p.return_types[f]!=12){return .err(invalid(p.starts[f]));}
        parameters[f]=selected;
    }f+=1;}return .ok(Signature{.elements=elements,.parameters=parameters,.borrowed=borrowed});
}
// The caller retains the original immutable recipes. Only this private copy
// goes through the existing full output CFG/type/loan/image/input verifier.
pub fn Result<usize,errors::Error> normalize(ref mut images::Program unit,ref Signature signature){
    let usize rewritten=calls::rewrite(ref mut unit.body)?;var usize pc=0;
    while(pc<unit.body.count){let usize at=pc*8;let u8 op=unit.body.code[at];
        if(op==63){unit.body.code[at]=57;}else if(op==64){unit.body.code[at]=9;}else if(op==65){unit.body.code[at]=8;}
        pc+=1;
    }
    var usize f=0;while(f<16){if(signature.elements[f]!=0){unit.origins[f]=0;}f+=1;}return .ok(rewritten);
}
