module slice_result_ir;
import ir as ir;
import functions as functions;
import slice_result_origins as origins;
import errors as errors;

// Private, NON-EXECUTABLE extension. Ordinary Program layout/opcodes stay fixed.
// 63 PREPARE_VIEW: dst=result identity, a=live slice site, b=0.
// 64 PREPARE_FORWARD: dst=result identity, a=callee, b=CALL argument-map ID.
// 65 RETURN_VIEW: dst=0, a=prepared result identity, b=0.
// All reserved bytes are zero. Result identities are not guest usize values.
// Cleanup may follow preparation; runtime ownership/ticket transfer is NOT proved.
pub struct Program {
    ir::Program body;
    u8[16] elements;   // Exact scalar tag, bit128 exclusive; zero ordinary result.
    u8[16] parameters; // Claimed one-based input origin, independently rechecked.
}

// Bridge the existing source lowerer, preserving PC/register/cleanup identities.
// Construction is not admission: inspect with slice_result_verifier afterwards.
pub fn Result<Program,errors::Error> from_proxy(ir::Program p,ref functions::Table t){
    let origins::Summary summary=origins::inspect(ref p,t)?;
    var Program result=Program{.body=p,.elements=t.return_slice_elements,.parameters=summary.parameters};
    var usize f=0;
    while(f<p.function_count){
        if(result.elements[f]!=0){
            var usize pc=p.starts[f];
            while(pc<p.ends[f]){
                if(p.code[pc*8]==8){
                    let u8 identity=p.code[pc*8+2];
                    var usize definition=256;var usize at=p.starts[f];
                    while(at<pc){
                        if((p.code[at*8]==57 || p.code[at*8]==9) && p.code[at*8+1]==identity){definition=at;}
                        at+=1;
                    }
                    if(definition==256){return .err(errors::make(5,pc));}
                    result.body.code[definition*8]=if(p.code[definition*8]==57){63}else{64};
                    result.body.code[pc*8]=65;
                }
                pc+=1;
            }
        }
        f+=1;
    }
    return .ok(result);
}
