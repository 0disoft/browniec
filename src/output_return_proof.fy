module output_return_proof;
import static_call_ir as programs;
import static_image as images;
import verifier as verifier;
import output_return_ir as recipes;
import slice_result_ir as borrowed;
import slice_result_verifier as loans;
import errors as errors;
import ir as ir;

pub struct Proof { verifier::ReferenceReturnProof ordinary; u8[16] parameters; u8[16] elements; }
// The canonical output verifier remains an independent pass. Its input differs
// only by the checked borrowed-result normalization; original recipe/terminal
// and origin proof follows before any retained Program may be published.
pub fn Result<Proof,errors::Error> inspect(ref programs::Program unit,ref images::Image image,bool input){
    let recipes::Signature signature=recipes::signature(unit)?;
    if(!signature.borrowed){
        let verifier::ReferenceReturnProof ordinary=verifier::inspect_output_returns(unit,image,input)?;
        return .ok(Proof{.ordinary=ordinary,.parameters=[0;16],.elements=[0;16]});
    }
    return inspect_borrowed(unit,image,input,ref signature);
}
fn Result<Proof,errors::Error> inspect_borrowed(ref programs::Program unit,ref images::Image image,bool input,ref recipes::Signature signature){
    var programs::Program normalized=*unit;
    let usize rewritten=recipes::normalize(ref mut normalized,signature)?;
    let verifier::ReferenceReturnProof ordinary=verifier::inspect_output_returns(ref normalized,image,input)?;
    let loans::Proof grounded=inspect_recipes(unit,ref normalized,signature)?;
    return .ok(Proof{.ordinary=ordinary,.parameters=grounded.parameters,.elements=signature.elements});
}
fn Result<loans::Proof,errors::Error> inspect_recipes(ref programs::Program unit,ref programs::Program normalized,ref recipes::Signature signature){
    let ref ir::Program body=ref unit.body;
    let borrowed::Program original=borrowed::Program{.body=*body,.elements=signature.elements,.parameters=signature.parameters};
    return loans::inspect_output_admitted(ref original,ref normalized.body);
}
