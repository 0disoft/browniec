module module_output_program;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import compiler as compiler;
import source_error as diagnostics;
import errors as errors;
import ir as ir;
import static_call_ir as candidates;
import static_image as images;
import verifier as verifier;
import program_image as program_images;
import std::vec as vec;
import std::bytes as bytes;
import runtime_input as input_bytes;
import runtime_output as output;
import output_execution as output_steps;
import slice_result_execution as execution;
import slice_result_runtime as runtime;
import array_vm as backing;
import array_list_vm as lists;
import place_dispatch as places;
import struct_call_vm as owned_calls;
import fuel as meter;

resource Stored { sources::Snapshot sources; candidates::Program code; images::Image image; bool input; cleanup { } }
pub resource Program { vec::Vec<Stored> stored; cleanup { } }
pub struct Completion { bool success; i64 value; usize remaining; diagnostics::Error diagnostic; usize output_bytes; usize emits; }
pub resource Execution { Completion completion; vec::Vec<output::Published> published; cleanup { } }
fn diagnostics::Error absent(errors::Error e){return diagnostics::absent(e);}
fn diagnostics::Error literal(images::Error e){
    return absent(compiler::public_error(program_images::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e}));
}
pub fn Result<Program,diagnostics::Error> compile(entries::Entry selected,usize image_limit){
    var images::Builder builder=switch(images::builder(4096)){
        case .ok(v):{v}case .err(e):{return .err(literal(e));}
    };
    var candidates::Program code=candidates::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let usize lowered=compiler::lower_output_modules(ref selected,ref mut builder,ref mut code)?;
    return finish(modules::snapshot(entries::index(ref selected)),ref builder,ref code,image_limit,false);
}
pub fn Result<Program,diagnostics::Error> compile_input(input_entries::InputEntry selected,usize image_limit){
    var images::Builder builder=switch(images::builder(4096)){
        case .ok(v):{v}case .err(e):{return .err(literal(e));}
    };
    var candidates::Program code=candidates::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let usize lowered=compiler::lower_input_output_modules(ref selected,ref mut builder,ref mut code)?;
    return finish(modules::snapshot(input_entries::index(ref selected)),ref builder,ref code,image_limit,true);
}
fn Result<Program,diagnostics::Error> finish(ref sources::Snapshot sources,ref images::Builder builder,
    ref candidates::Program code,usize image_limit,bool input){
    let images::Image image=switch(images::freeze(builder,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(literal(e));}
    };
    switch(verifier::inspect_output_returns(code,ref image,input)){
        case .ok(_):{}case .err(e):{
            if(e.offset==0 || e.offset>=code.body.count){return .err(absent(e));}
            return .err(diagnostics::map(sources,errors::make(e.kind,code.body.offsets[e.offset]),16));
        }
    };
    return retain(sources,code,image,input);
}
fn Result<Program,diagnostics::Error> retain(ref sources::Snapshot sources,ref candidates::Program code,images::Image image,bool input){
    var vec::Vec<Stored> retained=vec::empty<Stored>();
    if(!vec::reserve<Stored>(ref mut retained,1).is_ok){return .err(absent(errors::make(15,0)));}
    let sources::Snapshot snapshot=sources::duplicate(sources);
    if(!vec::push<Stored>(ref mut retained,Stored{.sources=snapshot,.code=*code,.image=image,.input=input}).is_ok){return .err(absent(errors::make(15,0)));}
    return .ok(Program{.stored=retained});
}
fn ref Stored stored(ref Program p){return vec::at<Stored>(ref p.stored,0);}
pub fn bool accepts_input(ref Program p){return stored(p).input;}
pub fn ref sources::Snapshot snapshot(ref Program p){return ref stored(p).sources;}
pub fn ref candidates::Program code(ref Program p){return ref stored(p).code;}
pub fn ref images::Image literals(ref Program p){return ref stored(p).image;}
pub fn Completion observe(ref Execution run){return run.completion;}
pub fn bool has_output(ref Execution run){return run.completion.success && vec::len<output::Published>(ref run.published)==1;}
pub fn ref u8[] view(ref Execution run){
    if(!has_output(run)){return b"";}return output::view(vec::at<output::Published>(ref run.published,0));
}
fn Completion failed(diagnostics::Error e,usize remaining,usize emits){
    return Completion{.success=false,.value=0,.remaining=remaining,.diagnostic=e,.output_bytes=0,.emits=emits};
}
fn Execution early(errors::Error e,usize remaining){
    return Execution{.completion=failed(absent(e),remaining,0),.published=vec::empty<output::Published>()};
}
// No caller can seal this invocation's staged owner. VM success, final seal and
// its already-reserved owning result slot form one terminal publication barrier.
pub fn Execution complete(ref Program p,ref input_bytes::Snapshot input,usize budget,usize output_limit,bool allowed){
    if(output_limit>output::hard_limit()){return early(errors::make(20,0),budget);}
    if(!accepts_input(p) && input_bytes::observe(input).length!=0){return early(errors::make(5,0),budget);}
    if(budget<meter::output_prepare(output_limit)){return early(errors::make(8,0),budget);}
    var vec::Vec<output::Published> published=vec::empty<output::Published>();
    if(!vec::reserve<output::Published>(ref mut published,1).is_ok){return early(errors::make(15,0),budget);}
    var usize remaining=budget;
    var output::Transaction staged=switch(output::open_metered(output_limit,allowed,ref mut remaining)){
        case .ok(value):{value}case .err(e):{return early(output_steps::failure(e,0),remaining);}
    };
    let Result<execution::Scalar,errors::Error> result=execute(stored(p),input_bytes::view(input),ref mut staged,ref mut remaining);
    return switch(result){
        case .err(e):{
            let output::Observation final=output::fail(ref mut staged);
            let diagnostics::Error diagnostic=if(e.offset==0){absent(e)}else{diagnostics::map(snapshot(p),e,16)};
            Execution{.completion=failed(diagnostic,remaining,final.emits),.published=published}
        }
        case .ok(value):{finish_success(value.value,ref mut staged,published,remaining)}
    };
}
fn Execution finish_success(i64 value,ref mut output::Transaction staged,vec::Vec<output::Published> slot,usize budget){
    var usize remaining=budget;var vec::Vec<output::Published> published=slot;
    let output::Published bytes=switch(output::seal_metered(staged,ref mut remaining)){
        case .ok(value):{value}case .err(e):{
            let output::Observation final=output::fail(staged);
            return Execution{.completion=failed(absent(output_steps::failure(e,0)),remaining,final.emits),.published=published};
        }
    };
    let output::Observation final=output::published_observation(ref bytes);
    assert(vec::push<output::Published>(ref mut published,bytes).is_ok);
    return Execution{.completion=Completion{.success=true,.value=value,.remaining=remaining,
        .diagnostic=absent(errors::make(0,0)),.output_bytes=final.length,.emits=final.emits},.published=published};
}
fn Result<execution::Scalar,errors::Error> execute(ref Stored retained,ref u8[] input,
    ref mut output::Transaction staged,ref mut usize remaining){
    let ref ir::Program body=ref retained.code.body;
    let usize capacity=if(body.arrays.count!=0 || body.records.count!=0){65536}else{0};
    let usize preparation=if(capacity==0){0}else{1+capacity};
    let lists::Requirement list_plan=lists::requirement(body)?;let places::Requirement place_plan=places::requirement(body)?;
    let usize work=owned_calls::cost(body,body.entry,0)?+body.arities[body.entry];
    let usize input_cost=if(retained.input){meter::input_prepare()}else{0};
    if(*remaining<preparation+input_cost+runtime::cost()+work+list_plan.cost+place_plan.cost){return .err(errors::make(8,0));}
    var bytes::Buffer payload=if(capacity==0){bytes::empty()}else{backing::prepare(capacity)?};*remaining-=preparation;
    var runtime::State state=runtime::empty(capacity);
    return execution::execute_output_scalar_metered(ref retained.code,ref retained.image,input,retained.input,
        ref mut state,bytes::view_mut(ref mut payload),remaining,staged);
}
