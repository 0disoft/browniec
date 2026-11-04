module program_image;
import static_image as images;
import slice_result_ir as ir;
import slice_result_verifier as verifier;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import errors as errors;
import vm as vm;

pub enum Failure { Code; Literal; }
pub struct Error { Failure kind; errors::Error code; images::Error literal; }
fn Error code_error(errors::Error e){return Error{.kind=.Code,.code=e,.literal=.State};}
fn Error image_error(images::Error e){return Error{.kind=.Literal,.code=errors::make(0,0),.literal=e};}
// The proof IR stays copyable. Only this private-field resource owns the native
// literal allocation. Read-only borrows cannot mutate either admitted snapshot.
pub resource Program { ir::Program code; images::Image image; cleanup { } }

// Consumes image on success AND failure, just like other owning resource APIs.
// The caller's candidate IR remains untouched. image_limit covers the image's
// logical metadata+payload charge, not total Program/Engine/process memory.
pub fn Result<Program,Error> retain(ref ir::Program code,images::Image image,usize image_limit){
    switch(verifier::inspect(code)){
        case .ok(_):{}case .err(e):{return .err(code_error(e));}
    };
    switch(images::inspect(ref image)){
        case .ok(_):{}case .err(e):{return .err(image_error(e));}
    };
    let usize charge=switch(images::charge(ref image)){
        case .ok(value):{value}case .err(e):{return .err(image_error(e));}
    };
    if(charge>image_limit){return .err(image_error(.Quota));}
    return .ok(Program{.code=*code,.image=image});
}

pub fn ref ir::Program code(ref Program p){return ref p.code;}
pub fn ref images::Image literals(ref Program p){return ref p.image;}

// Native scalar execution borrows the entire retained Program for the call.
// Existing admission, Fuel, ownership and cleanup remain the VM's responsibility.
// No Static opcode, returned Static receipt or authenticated handle is admitted.
pub fn Result<execution::Scalar,errors::Error> run_scalar(ref Program p,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    return vm::run_slice_scalar(ref p.code,function,captures,values,inputs,state,data,fuel);
}
