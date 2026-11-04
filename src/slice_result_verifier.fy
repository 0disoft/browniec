module slice_result_verifier;
import slice_result_ir as results;
import slice_result_origins as origins;
import ir as ir;
import functions as functions;
import types as types;
import errors as errors;
import slice_result_call_ir as calls;

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
        if(op!=37 && op!=45 && op!=56 && op!=62){return .err(errors::make(5,at));}
        at+=1;
    }
    return .err(errors::make(5,pc));
}

pub fn Result<Proof,errors::Error> inspect(ref results::Program unit){
    if(unit.body.count==0 || unit.body.count>256 || unit.body.function_count==0 ||
        unit.body.function_count>16){return .err(errors::make(5,0));}
    var ir::Program proxy=unit.body;
    var functions::Table signatures=functions::empty();
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
    let usize rewritten=calls::rewrite(ref mut proxy)?;
    var usize pc=0;
    while(pc<proxy.count){
        let u8 op=unit.body.code[pc*8];
        if(op==63){proxy.code[pc*8]=57;}
        else if(op==64){proxy.code[pc*8]=9;}
        else if(op==65){proxy.code[pc*8]=8;}
        else if(op==9){
            let usize callee=proxy.code[pc*8+2] as usize;
            if(callee<16 && unit.elements[callee]!=0){return .err(errors::make(5,pc));}
        }
        pc+=1;
    }
    // This reconstructs CFG/definitions, exact formal/derived loans and recursive
    // origins from the normalized instructions, never trusting selected claims.
    // The normalized Program stays local and is never returned or executed.
    let origins::Summary grounded=origins::inspect_recipes(ref proxy,ref signatures,ref unit.body)?;
    let usize bindings=calls::inspect(ref proxy,ref unit.body,ref unit.elements,ref grounded.parameters)?;
    var Proof proof=Proof{.parameters=grounded.parameters,.preparations=0,.forwards=0,
        .returns=0,.rounds=grounded.rounds};
    var bool[256] matched=[false;256];f=0;
    while(f<16){
        if(grounded.parameters[f]!=unit.parameters[f]){return .err(errors::make(5,0));}
        f+=1;
    }
    // Whole-Program validation above bounds all partitions, registers, CALL maps,
    // source sites and cleanup operations before the recipe-specific reads below.
    f=0;
    while(f<unit.body.function_count){
        pc=unit.body.starts[f];
        while(pc<unit.body.ends[f]){
            let u8 op=unit.body.code[pc*8];
            if(op==8 && unit.elements[f]!=0){return .err(errors::make(5,pc));}
            if(op==65){
                if(unit.elements[f]==0){return .err(errors::make(5,pc));}
                proof.returns+=1;
            }
            if(op==63 || op==64){
                if(unit.elements[f]==0){return .err(errors::make(5,pc));}
                if(op==64){
                    let usize callee=unit.body.code[pc*8+2] as usize;
                    if(callee>=unit.body.function_count || unit.elements[callee]!=unit.elements[f]){
                        return .err(errors::make(5,pc));
                    }
                    proof.forwards+=1;
                }
                let usize end=terminal(ref unit.body,f,pc)?;
                if(matched[end]){return .err(errors::make(5,end));}
                matched[end]=true;proof.preparations+=1;
            }
            pc+=1;
        }
        f+=1;
    }
    pc=0;
    while(pc<unit.body.count){
        if(unit.body.code[pc*8]==65 && !matched[pc]){return .err(errors::make(5,pc));}
        pc+=1;
    }
    return .ok(proof);
}
