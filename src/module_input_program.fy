module module_input_program;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import compiler as compiler;
import source_error as diagnostics;
import errors as errors;
import module_program as ordinary;
import runtime_clock as clock;
import ir as ir;
import static_call_ir as candidates;
import static_image as images;
import output_canonical_proof_work as proof_work;
import program_image as program_images;
import std::vec as vec;
import retention_plan as retention;
import std::bytes as bytes;
import runtime_input as input_bytes;
import slice_result_execution as execution;
import slice_result_runtime as runtime;
import array_vm as backing;
import array_list_vm as lists;
import place_dispatch as places;
import struct_call_vm as owned_calls;
import fuel as meter;

// Separate admitted input ABI. No zero-argument Program or native execution
// authority can be manufactured from this resource's read-only accessors.
resource Stored { sources::Snapshot sources; candidates::Program code; images::Image image; cleanup { } }
pub resource Program { vec::Vec<Stored> stored; cleanup { } }
pub fn Result<Program,diagnostics::Error> compile(entries::InputEntry selected,usize image_limit){
    var retention::Plan plan=retention::unlimited();return compile_with_retention(selected,image_limit,ref mut plan);
}
pub fn Result<Program,diagnostics::Error> compile_with_retention(entries::InputEntry selected,usize image_limit,ref mut retention::Plan plan){
    return compile_with_retention_until(selected,image_limit,plan,0);
}
pub fn Result<Program,diagnostics::Error> compile_with_retention_until(entries::InputEntry selected,usize image_limit,
    ref mut retention::Plan plan,usize deadline){
    var images::Builder builder=switch(images::builder(4096)){
        case .ok(v):{v}case .err(e):{return .err(literal(e));}
    };
    var candidates::Program code=candidates::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let usize lowered=if(deadline==0){compiler::lower_input_modules(ref selected,ref mut builder,ref mut code)?}
        else{compiler::lower_input_modules_until(ref selected,ref mut builder,ref mut code,false,deadline)?};
    return finish(ref selected,ref builder,ref code,image_limit,plan,deadline);
}
pub fn Result<Program,diagnostics::Error> admit_lowered_until(ref entries::InputEntry selected,
    ref ordinary::Lowered lowered,usize image_limit,ref mut retention::Plan plan,usize deadline){
    return finish(selected,ordinary::candidate_literals(lowered),ordinary::candidate_code(lowered),image_limit,plan,deadline);
}
fn diagnostics::Error literal(images::Error e){
    return diagnostics::absent(compiler::public_error(program_images::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e}));
}
fn diagnostics::Error map(ref entries::InputEntry selected,errors::Error e){
    return if(e.offset==0){diagnostics::absent(e)}else{diagnostics::map(modules::snapshot(entries::index(selected)),e,16)};
}
// Keep source lowering, full independent proof and the owning return slots on
// separate native stack frames. Quota is checked before retaining image/code.
fn Result<Program,diagnostics::Error> finish(ref entries::InputEntry selected,ref images::Builder builder,
    ref candidates::Program code,usize image_limit,ref mut retention::Plan plan,usize deadline){
    if(clock::expired(deadline)){return .err(diagnostics::absent(errors::absent(errors::deadline_kind(),0)));}
    let usize payload=switch(images::planned_payload(builder)){case .ok(v):{v}case .err(_):{return .err(diagnostics::absent(errors::make(5,0)));}};
    if(!retention::admit(plan,payload).is_ok){return .err(diagnostics::absent(errors::make(retention::quota_kind(),0)));}
    let images::Image image=switch(images::freeze(builder,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(literal(e));}
    };
    switch(proof_work::inspect_input_until(code,ref image,deadline)){
        case .ok(_):{}case .err(e):{
            if(e.offset==0 || e.offset>=code.body.count){return .err(diagnostics::absent(e));}
            return .err(map(selected,errors::make(e.kind,code.body.offsets[e.offset])));
        }
    };
    return retain(selected,code,image);
}
fn Result<Program,diagnostics::Error> retain(ref entries::InputEntry selected,ref candidates::Program code,images::Image image){
    var vec::Vec<Stored> stored=vec::empty<Stored>();
    if(!vec::reserve<Stored>(ref mut stored,1).is_ok){return .err(diagnostics::absent(errors::make(15,0)));}
    let sources::Snapshot snapshot=sources::duplicate(modules::snapshot(entries::index(selected)));
    if(!vec::push<Stored>(ref mut stored,Stored{.sources=snapshot,.code=*code,.image=image}).is_ok){
        return .err(diagnostics::absent(errors::make(15,0)));
    }
    return .ok(Program{.stored=stored});
}
fn ref Stored stored(ref Program p){return vec::at<Stored>(ref p.stored,0);}
pub fn ref sources::Snapshot snapshot(ref Program p){return ref stored(p).sources;}
pub fn ref candidates::Program code(ref Program p){return ref stored(p).code;}
pub fn ref images::Image literals(ref Program p){return ref stored(p).image;}

// Own no new input payload: this exact immutable Snapshot is borrowed until the
// last native frame has left or invocation failure has drained every owner.
pub struct Run { i64 value; usize remaining; }
// Terminal evidence is invocation-local, including failures. Inactive value and
// diagnostic fields are deterministic; callers select them with success.
pub struct Completion { bool success; i64 value; usize remaining; diagnostics::Error diagnostic; }
pub fn Completion complete(ref Program program,ref input_bytes::Snapshot input,usize fuel){
    let ref Stored retained=stored(program);var usize remaining=fuel;
    return switch(execute(retained,input_bytes::view(input),ref mut remaining)){
        case .ok(v):{Completion{.success=true,.value=v.value,.remaining=remaining,.diagnostic=diagnostics::absent(errors::make(0,0))}}
        case .err(e):{Completion{.success=false,.value=0,.remaining=remaining,
            .diagnostic=if(e.offset==0){diagnostics::absent(e)}else{diagnostics::map(snapshot(program),e,16)}}}
    };
}
pub fn Result<Run,diagnostics::Error> run(ref Program program,ref input_bytes::Snapshot input,usize fuel){
    let Completion result=complete(program,input,fuel);
    return if(result.success){.ok(Run{.value=result.value,.remaining=result.remaining})}else{.err(result.diagnostic)};
}
fn Result<execution::Scalar,errors::Error> execute(ref Stored retained,ref u8[] input,ref mut usize remaining){
    let ref ir::Program body=ref retained.code.body;
    let usize capacity=if(body.arrays.count!=0 || body.records.count!=0){65536}else{0};
    let usize preparation=if(capacity==0){0}else{1+capacity};
    let lists::Requirement list_plan=lists::requirement(body)?;
    let places::Requirement place_plan=places::requirement(body)?;
    let usize work=owned_calls::cost(body,body.entry,0)?+body.arities[body.entry];
    if(*remaining<preparation+meter::input_prepare()+runtime::cost()+work+list_plan.cost+place_plan.cost){return .err(errors::make(8,0));}
    var bytes::Buffer payload=if(capacity==0){bytes::empty()}else{backing::prepare(capacity)?};
    *remaining-=preparation;
    var runtime::State state=runtime::empty(capacity);
    return execution::execute_input_scalar_metered(ref retained.code,ref retained.image,input,
        ref mut state,bytes::view_mut(ref mut payload),remaining);
}
