module program_image;
import array_list_vm as list_values;
import place_vm as places;
import static_image as images;
import slice_result_ir as ir;
import slice_result_verifier as verifier;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import errors as errors;
import static_call_ir as calls;
import verifier as call_verifier;
import ir as ordinary;
import vm as vm;
import array_source as arrays;
import array_vm as backing;
import array_slices as slices;
import std::bytes as bytes;

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
    switch(verifier::inspect_image(code,ref image)){
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
// Static operations borrow this exact immutable payload; no Static receipt escapes.
pub fn Result<execution::Scalar,errors::Error> run_scalar(ref Program p,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    return execution::execute_image_scalar(ref p.code,ref p.image,function,captures,values,inputs,state,data,fuel);
}

// Private extension using the same image owner and canonical VM coordinator.
// Separate typed storage prevents bare/legacy retention from bypassing proof.
pub resource CallProgram { calls::Program code; images::Image image; cleanup { } }
pub fn Result<CallProgram,Error> retain_calls(ref calls::Program code,images::Image image,usize image_limit){
    switch(call_verifier::verify_static_calls(code,ref image)){
        case .ok(_):{}case .err(e):{return .err(code_error(e));}
    };
    let usize charge=switch(images::charge(ref image)){
        case .ok(v):{v}case .err(e):{return .err(image_error(e));}
    };
    if(charge>image_limit){return .err(image_error(.Quota));}
    return .ok(CallProgram{.code=*code,.image=image});
}
pub fn ref calls::Program call_code(ref CallProgram p){return ref p.code;}
pub fn ref images::Image call_literals(ref CallProgram p){return ref p.image;}
pub fn Result<execution::Scalar,errors::Error> run_call_scalar(ref CallProgram p,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    return execution::execute_static_scalar(ref p.code,ref p.image,function,captures,values,inputs,state,data,fuel);
}

// Independent reference analysis plus the exact immutable image retained behind
// private fields. Existing Program and CallProgram admission remain unchanged.
pub resource ReferenceProgram { calls::Program code; images::Image image; cleanup { } }
pub fn Result<ReferenceProgram,Error> retain_references(ref calls::Program code,images::Image image,usize image_limit){
    switch(call_verifier::inspect_reference_calls(code,ref image)){
        case .ok(_):{}case .err(e):{return .err(code_error(e));}
    };
    let usize charge=switch(images::charge(ref image)){case .ok(v):{v}case .err(e):{return .err(image_error(e));}};
    if(charge>image_limit){return .err(image_error(.Quota));}
    return .ok(ReferenceProgram{.code=*code,.image=image});
}
pub fn ref calls::Program reference_code(ref ReferenceProgram p){return ref p.code;}
pub fn ref images::Image reference_literals(ref ReferenceProgram p){return ref p.image;}
pub fn Result<execution::Scalar,errors::Error> run_reference_scalar(ref ReferenceProgram p,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    return execution::execute_reference_scalar(ref p.code,ref p.image,function,captures,values,inputs,state,data,fuel);
}

// Complete generic returned-reference proof has separate retained authority.
pub resource ReferenceReturnProgram { calls::Program code; images::Image image; cleanup { } }
// Complete admission borrows the candidate. Owning return slots are created only
// after proof, keeping the nested native verifier stack independent of them.
fn Result<usize,Error> reference_return_admission(ref calls::Program code,ref images::Image image,usize image_limit){
    switch(call_verifier::inspect_reference_returns(code,image)){case .ok(_):{}case .err(e):{return .err(code_error(e));}};
    let usize charge=switch(images::charge(image)){case .ok(v):{v}case .err(e):{return .err(image_error(e));}};
    if(charge>image_limit){return .err(image_error(.Quota));}
    return .ok(charge);
}
pub fn Result<ReferenceReturnProgram,Error> retain_reference_returns(ref calls::Program code,images::Image image,usize image_limit){
    let usize admitted=reference_return_admission(code,ref image,image_limit)?;
    return .ok(ReferenceReturnProgram{.code=*code,.image=image});
}
pub fn ref calls::Program reference_return_code(ref ReferenceReturnProgram p){return ref p.code;}
pub fn ref images::Image reference_return_literals(ref ReferenceReturnProgram p){return ref p.image;}
pub fn Result<execution::Scalar,errors::Error> run_reference_returns_scalar(ref ReferenceReturnProgram p,usize function,
    ref runtime::Capture[] captures,ref i64[] values,ref owners::Token[] inputs,
    ref mut runtime::State state,ref mut u8[] data,usize fuel){
    return execution::execute_reference_returns_scalar(ref p.code,ref p.image,function,captures,values,inputs,state,data,fuel);
}

// One retained IR and one optional-empty image owner across both public paths.
// Fields stay private: body borrows cannot change the admitted code/image/mode.
pub resource PublicProgram { ReferenceReturnProgram program; bool reference; cleanup { } }
pub fn Result<PublicProgram,Error> retain_public_legacy(ref ordinary::Program code){
    switch(call_verifier::verify(code)){case .ok(_):{}case .err(e):{return .err(code_error(e));}};
    var images::Builder builder=switch(images::builder(0)){case .ok(v):{v}case .err(e):{return .err(image_error(e));}};
    let images::Image image=switch(images::freeze(ref builder,images::metadata_charge())){
        case .ok(v):{v}case .err(e):{return .err(image_error(e));}
    };
    let usize admitted=legacy_reference_admission(code,ref image)?;
    return .ok(publish_legacy(code,image));
}
fn Result<usize,Error> legacy_reference_admission(ref ordinary::Program code,ref images::Image image){
    let calls::Program unit=calls::Program{.body=*code,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    return reference_return_admission(ref unit,image,images::metadata_charge());
}
fn PublicProgram publish_legacy(ref ordinary::Program code,images::Image image){
    let calls::Program unit=calls::Program{.body=*code,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    return PublicProgram{.program=ReferenceReturnProgram{.code=unit,.image=image},.reference=false};
}
// Consuming a sealed retained resource transfers its exact proved authority.
pub fn PublicProgram retain_public_references(ReferenceReturnProgram p){
    return PublicProgram{.program=p,.reference=true};
}
pub fn ref ordinary::Program public_body(ref PublicProgram p){
    let ref ReferenceReturnProgram retained=ref p.program;
    let ref calls::Program code=ref retained.code;
    return ref code.body;
}
pub fn u8 public_profile(ref PublicProgram p){return if(p.reference){8}else{arrays::profile(public_body(p))};}
pub fn Result<i64,errors::Error> run_public(ref PublicProgram p,usize fuel){
    if(!p.reference){return vm::run(public_body(p),fuel);}
    return run_public_references(ref p.program,fuel);
}
// Keep canonical state off the legacy call stack. Program admission precedes
// this allocation; dispatch repeats complete proof before entering native state.
pub fn Result<i64,errors::Error> run_public_references(ref ReferenceReturnProgram retained,usize fuel){
    let ref calls::Program code=ref retained.code;
    let ref ordinary::Program body=ref code.body;
    let ref images::Image image=ref retained.image;
    let usize capacity=if(body.arrays.count!=0 || body.records.count!=0){65536}else{0};
    let usize preparation=if(capacity==0){0}else{1+capacity};
    let list_values::Requirement list_plan=list_values::requirement(body)?;
    let places::Requirement place_plan=places::requirement(body)?;
    if(fuel<preparation+runtime::cost()+list_plan.cost+place_plan.cost){return .err(errors::make(8,0));}
    var bytes::Buffer payload=if(capacity==0){bytes::empty()}else{backing::prepare(capacity)?};
    var runtime::State state=runtime::empty(capacity);
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    return switch(execution::execute_reference_returns_scalar(code,image,body.entry,
        ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,bytes::view_mut(ref mut payload),fuel-preparation)){
        case .ok(v):{.ok(v.value)}case .err(e):{.err(e)}
    };
}
