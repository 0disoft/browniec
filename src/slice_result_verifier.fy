module slice_result_verifier;
import slice_result_ir as results;
import slice_result_origins as origins;
import ir as ir;
import functions as functions;
import types as types;
import errors as errors;
import slice_result_call_ir as calls;
import static_ir as statics;
import static_image as images;

pub struct Proof {
    u8[16] parameters;
    usize preparations;
    usize forwards;
    usize returns;
    usize rounds;
}

// A prepared result cannot be observed as a scalar, written through, or routed
// through another branch/call. Only existing cleanup and its terminal may follow.
fn Result<usize,errors::Error> terminal(ref ir::Program p,usize f,usize pc){
    let u8 identity=p.code[pc*8+1];var usize at=pc+1;
    while(at<p.ends[f]){
        let u8 op=p.code[at*8];
        if(op==65){
            if(p.code[at*8+2]!=identity){return .err(errors::make(5,at));}
            return .ok(at);
        }
        if(op!=37 && op!=45 && op!=56 && op!=62 && op!=70){return .err(errors::make(5,at));}
        at+=1;
    }
    return .err(errors::make(5,pc));
}

fn Result<usize,errors::Error> prepare(ref results::Program unit,ref mut ir::Program proxy,ref mut functions::Table signatures){
    let ref ir::Program body=ref unit.body;
    if(body.count==0 || body.count>256 || body.function_count==0 ||
        body.function_count>16){return .err(errors::make(5,0));}
    signatures.count=proxy.function_count;signatures.entry=proxy.entry;
    signatures.arities=proxy.arities;signatures.return_slice_elements=unit.elements;
    var usize f=0;
    while(f<16){
        let u8 tag=unit.elements[f];let u8 selected=unit.parameters[f];
        if((f>=proxy.function_count && (tag!=0 || selected!=0)) ||
            (tag==0 && selected!=0) || (tag!=0 && (!types::scalar(tag & 127) ||
            selected==0 || selected>8 || selected as usize>proxy.arities[f] || f==proxy.entry))){
            return .err(errors::make(5,0));
        }
        f+=1;
    }
    let usize rewritten=calls::rewrite(proxy)?;
    var usize pc=0;
    while(pc<proxy.count){
        let u8 op=body.code[pc*8];
        if(op==63){proxy.code[pc*8]=57;}
        else if(op==64){proxy.code[pc*8]=9;}
        else if(op==65){proxy.code[pc*8]=8;}
        else if(op==9){
            let usize callee=proxy.code[pc*8+2] as usize;
            if(callee<16 && unit.elements[callee]!=0){return .err(errors::make(5,pc));}
        }
        pc+=1;
    }
    return .ok(proxy.count);
}
fn Result<Proof,errors::Error> finish(ref results::Program unit,ref ir::Program proxy,ref origins::Summary grounded){
    let ref ir::Program body=ref unit.body;
    let usize bindings=calls::inspect(proxy,body,ref unit.elements,ref grounded.parameters)?;
    var Proof proof=Proof{.parameters=grounded.parameters,.preparations=0,.forwards=0,
        .returns=0,.rounds=grounded.rounds};
    var bool[256] matched=[false;256];var usize f=0;var usize pc=0;
    while(f<16){
        if(grounded.parameters[f]!=unit.parameters[f]){return .err(errors::make(5,0));}
        f+=1;
    }
    // Whole-Program validation above bounds all partitions, registers, CALL maps,
    // source sites and cleanup operations before the recipe-specific reads below.
    f=0;
    while(f<body.function_count){
        pc=body.starts[f];
        while(pc<body.ends[f]){
            let u8 op=body.code[pc*8];
            if(op==8 && unit.elements[f]!=0){return .err(errors::make(5,pc));}
            if(op==65){
                if(unit.elements[f]==0){return .err(errors::make(5,pc));}
                proof.returns+=1;
            }
            if(op==63 || op==64){
                if(unit.elements[f]==0){return .err(errors::make(5,pc));}
                if(op==64){
                    let usize callee=body.code[pc*8+2] as usize;
                    if(callee>=body.function_count || unit.elements[callee]!=unit.elements[f]){
                        return .err(errors::make(5,pc));
                    }
                    proof.forwards+=1;
                }
                let usize end=terminal(body,f,pc)?;
                if(matched[end]){return .err(errors::make(5,end));}
                matched[end]=true;proof.preparations+=1;
            }
            pc+=1;
        }
        f+=1;
    }
    pc=0;
    while(pc<body.count){
        if(body.code[pc*8]==65 && !matched[pc]){return .err(errors::make(5,pc));}
        pc+=1;
    }
    return .ok(proof);
}

pub fn Result<Proof,errors::Error> inspect(ref results::Program unit){
    let ref ir::Program body=ref unit.body;
    var ir::Program proxy=*body;var functions::Table signatures=functions::empty();
    let usize ready=prepare(unit,ref mut proxy,ref mut signatures)?;
    let origins::Summary grounded=origins::inspect_recipes(ref proxy,ref signatures,body)?;
    return finish(unit,ref proxy,ref grounded);
}
pub struct ImageProof { Proof borrowed; statics::Sites statics; }
pub fn Result<ImageProof,errors::Error> inspect_image(ref results::Program unit,ref images::Image image){
    let ref ir::Program body=ref unit.body;
    var ir::Program proxy=*body;var functions::Table signatures=functions::empty();
    let usize ready=prepare(unit,ref mut proxy,ref mut signatures)?;
    let origins::ImageSummary grounded=origins::inspect_recipes_image(ref proxy,ref signatures,body,image)?;
    let Proof borrowed=finish(unit,ref proxy,ref grounded.origins)?;
    return .ok(ImageProof{.borrowed=borrowed,.statics=grounded.statics});
}
