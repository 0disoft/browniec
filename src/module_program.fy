module module_program;
import module_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import compiler as compiler;
import program_image as programs;
import source_error as diagnostics;
import errors as errors;
import runtime_clock as clock;
import ir as ir;
import static_call_ir as candidate;
import static_image as images;
import std::vec as vec;
import retention_plan as retention;
import module_source_work as module_source;
import function_scan_work as signature_scan;
import lexer as lexer;
import locals as locals;
import loops as loops;
import body_source_work as body_work;
import metadata_budget as budget;
import output_canonical_proof_work as proof_work;

// Only internally rebuilt source/context plus complete canonical admission can
// create this resource. Compiler name tables are not retained at runtime.
// Keep both code and original-source storage out of owning return slots.
resource Stored { sources::Snapshot sources; programs::PublicProgram code; cleanup { } }
pub resource Program { vec::Vec<Stored> stored; cleanup { } }
// Unverified lowering output for the private Engine. Admission still proves
// the complete candidate and associates it with the selected source.
pub resource Lowered {
    candidate::Program code; images::Builder literals; bool references; signature_scan::State signatures;
    compiler::BodyProgress progress; lexer::State token; locals::Table names; loops::State flow; body_work::State cursor;
    vec::Vec<proof_work::State> proof; vec::Vec<images::Image> image; cleanup { }
}
pub fn Result<Program,diagnostics::Error> compile(entries::Entry selected,usize image_limit){
    var retention::Plan plan=retention::unlimited();return compile_with_retention(selected,image_limit,ref mut plan);
}
pub fn Result<Program,diagnostics::Error> compile_with_retention(entries::Entry selected,usize image_limit,ref mut retention::Plan plan){
    return compile_with_retention_until(selected,image_limit,plan,0);
}
pub fn Result<Program,diagnostics::Error> compile_with_retention_until(entries::Entry selected,usize image_limit,
    ref mut retention::Plan plan,usize deadline){
    // Finish indexed source preparation before entering lowering/admission.
    if(deadline!=0){
        var module_source::State source=module_source::begin(true);
        let usize prepared=module_source::finish_until(entries::index(ref selected),ref mut source,deadline)?;
        return compile_prepared_until(ref selected,ref source,image_limit,plan,deadline);
    }
    var images::Builder builder=switch(images::builder(4096)){
        case .ok(v):{v}case .err(_):{return .err(diagnostics::absent(errors::make(5,0)));}
    };
    var candidate::Program code=candidate::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let bool references=compiler::lower_modules(ref selected,ref mut builder,ref mut code)?;
    if(references){return finish_references(ref selected,ref builder,ref code,image_limit,plan,0);}
    return finish_legacy(ref selected,ref code.body,plan,0);
}
// Called with completed source work built from this exact Entry.
pub fn Result<Program,diagnostics::Error> compile_prepared_until(ref entries::Entry selected,
    ref module_source::State source,usize image_limit,ref mut retention::Plan plan,usize deadline){
    var images::Builder builder=images::full_builder();
    var candidate::Program code=candidate::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let bool references=compiler::lower_modules_prepared_until(selected,source,ref mut builder,ref mut code,false,deadline)?;
    if(clock::expired(deadline)){return .err(diagnostics::absent(errors::absent(errors::deadline_kind(),0)));}
    if(references){return finish_references(selected,ref builder,ref code,image_limit,plan,deadline);}
    return finish_legacy(selected,ref code.body,plan,deadline);
}
@link_name("bc_runtime_engine_reserve_compile_candidate") unsafe extern C fn u32 reserve_candidate_raw(ptr mut void storage);
pub fn Result<usize,diagnostics::Error> start_lowered(ref mut vec::Vec<Lowered> storage,usize entry,bool references){
    assert(vec::len<Lowered>(storage)==0 && vec::capacity<Lowered>(storage)==0);
    if(unsafe{reserve_candidate_raw(storage as ptr mut void)}!=0){
        return .err(diagnostics::absent(errors::make(15,0)));
    }
    let Lowered empty=Lowered{
        .code=candidate::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]},
        .literals=images::full_builder(),.references=references,.signatures=signature_scan::indexed(entry,references),
        .progress=compiler::begin_module_bodies(),.token=lexer::empty(),.names=locals::empty(),
        .flow=loops::empty(),.cursor=body_work::begin(0,false),.proof=vec::empty<proof_work::State>(),.image=vec::empty<images::Image>()};
    return switch(vec::push<Lowered>(storage,empty)){
        case .ok(v):{.ok(v)}case .err(_):{.err(diagnostics::absent(errors::make(15,0)))}
    };
}
pub fn bool signatures_done(ref Lowered lowered){return lowered.signatures.done;}
@link_name("bc_runtime_engine_compile_proof_storage")
unsafe extern C fn usize proof_storage_raw(ptr void candidate);
pub fn usize proof_storage_bytes(ref Lowered lowered){return unsafe{proof_storage_raw(lowered as ptr void)};}
pub fn Result<usize,diagnostics::Error> proof_payload(ref Lowered lowered){
    if(!lowered.references){return .ok(0);}
    return switch(images::planned_payload(ref lowered.literals)){
        case .ok(v):{.ok(v)}case .err(_):{.err(diagnostics::absent(errors::absent(5,0)))}
    };
}
fn Result<usize,programs::Error> open_proof(ref candidate::Program code,ref images::Builder builder,
    ref mut vec::Vec<images::Image> storage,bool references,usize image_limit,usize deadline){
    let usize limit=if(references){image_limit}else{images::metadata_charge()};
    let images::Image image=switch(images::freeze(builder,limit)){
        case .ok(v):{v}case .err(e):{return .err(programs::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e});}
    };
    return programs::begin_pending(storage,code,image,references,deadline);
}
@link_name("bc_runtime_engine_begin_compile_proof")
unsafe extern C fn u32 open_proof_raw(ptr mut void candidate,ptr void selected,usize image_limit,usize deadline,ptr mut void failure);
fn bool seed_proof(ref mut vec::Vec<proof_work::State> proof){
    if(vec::len<proof_work::State>(proof)!=0 || vec::capacity<proof_work::State>(proof)!=1){return false;}
    return vec::push<proof_work::State>(proof,proof_work::empty_ordinary()).is_ok;
}
fn u32 open_proof_inner(ref candidate::Program code,ref images::Builder builder,ref mut vec::Vec<images::Image> storage,
    bool references,ref entries::Entry selected,usize image_limit,usize deadline,ref mut diagnostics::Error failure){
    return switch(open_proof(code,builder,storage,references,image_limit,deadline)){
        case .ok(_):{0}case .err(e):{*failure=admission_error(selected,e,ref code.body);1}
    };
}
fn diagnostics::Error missing_proof(){return diagnostics::absent(errors::absent(5,0));}
pub fn Result<usize,diagnostics::Error> begin_proof(ref entries::Entry selected,ref mut Lowered lowered,
    usize image_limit,usize deadline){
    var diagnostics::Error failure=missing_proof();
    let u32 status=unsafe{open_proof_raw(lowered as ptr mut void,selected as ptr void,
        image_limit,deadline,ref mut failure as ptr mut void)};
    return if(status==0){.ok(0)}else{.err(if(status==2){diagnostics::absent(errors::make(15,0))}else{failure})};
}
@link_name("bc_runtime_engine_advance_compile_proof")
unsafe extern C fn u32 advance_proof_raw(ptr mut void candidate,ptr void selected,ptr mut void meter,ptr mut void failure);
fn u32 advance_proof_inner(ref candidate::Program code,ref vec::Vec<images::Image> storage,
    ref mut proof_work::State proof,ref entries::Entry selected,ref mut budget::State meter,ref mut diagnostics::Error failure){
    return switch(programs::advance_pending(code,storage,proof,meter)){
        case .ok(done):{if(done){1}else{0}}case .err(e):{*failure=admission_error(selected,e,ref code.body);2}
    };
}
pub fn Result<bool,diagnostics::Error> advance_proof(ref entries::Entry selected,ref mut Lowered lowered,ref mut budget::State meter){
    var diagnostics::Error failure=missing_proof();
    let u32 status=unsafe{advance_proof_raw(lowered as ptr mut void,selected as ptr void,
        meter as ptr mut void,ref mut failure as ptr mut void)};
    return if(status<=1){.ok(status==1)}else{.err(failure)};
}
@link_name("bc_runtime_engine_reserve_proved_program")
unsafe extern C fn u32 reserve_proved_raw(ptr mut void candidate,ptr void selected,ptr mut void outgoing,ptr mut void failure);
fn u32 finish_proof_inner(ref candidate::Program code,ref mut vec::Vec<images::Image> storage,
    ref proof_work::State proof,bool references,ref entries::Entry selected,ref mut vec::Vec<Program> outgoing,
    ref mut diagnostics::Error failure){
    let programs::PublicProgram sealed=switch(programs::seal_pending(code,storage,proof,references)){
        case .ok(v):{v}case .err(e):{*failure=admission_error(selected,e,ref code.body);return 1;}
    };
    let Program retained=switch(retain(selected,sealed)){
        case .ok(v):{v}case .err(e):{*failure=e;return 1;}
    };
    if(!vec::push<Program>(outgoing,retained).is_ok){*failure=diagnostics::absent(errors::make(15,0));return 1;}
    return 0;
}
pub fn Result<usize,diagnostics::Error> finish_proof(ref entries::Entry selected,ref mut Lowered lowered,
    ref mut vec::Vec<Program> outgoing){
    var diagnostics::Error failure=diagnostics::absent(errors::absent(5,0));
    let u32 status=unsafe{reserve_proved_raw(lowered as ptr mut void,selected as ptr void,
        outgoing as ptr mut void,ref mut failure as ptr mut void)};
    return if(status==0){.ok(0)}else{.err(failure)};
}
@link_name("bc_runtime_engine_binding") unsafe extern C fn void binding_raw(u32 number);
pub fn void retain_proof_binding(ref entries::Entry selected){
    let candidate::Program code=candidate::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let images::Builder builder=images::full_builder();var proof_work::State proof=proof_work::empty_ordinary();
    var vec::Vec<images::Image> storage=vec::empty<images::Image>();
    var vec::Vec<Program> outgoing=vec::empty<Program>();
    var budget::State meter=budget::empty();
    var diagnostics::Error diagnostic=diagnostics::absent(errors::absent(5,0));
    unsafe{binding_raw(50)};discard advance_proof_inner(ref code,ref storage,ref mut proof,selected,ref mut meter,ref mut diagnostic);
    unsafe{binding_raw(51)};discard open_proof_inner(ref code,ref builder,ref mut storage,true,selected,0,0,ref mut diagnostic);
    retain_seed_binding();
    unsafe{binding_raw(52)};discard finish_proof_inner(ref code,ref mut storage,ref proof,true,selected,ref mut outgoing,ref mut diagnostic);
}
fn void retain_seed_binding(){
    var vec::Vec<proof_work::State> storage=vec::empty<proof_work::State>();
    unsafe{binding_raw(53)};discard seed_proof(ref mut storage);
}
fn diagnostics::Error error(ref entries::Entry selected,errors::Error e){
    return if(e.offset==0){diagnostics::absent(e)}else{diagnostics::map(modules::snapshot(entries::index(selected)),e,16)};
}
// Verifier offsets are instruction indices; source-lowering offsets are bytes.
// Header-wide failures and image quotas have no authenticated source location.
fn diagnostics::Error admission_error(ref entries::Entry selected,programs::Error failure,ref ir::Program code){
    let errors::Error e=compiler::public_error(failure);
    return switch(failure.kind){
        case .Literal:{diagnostics::absent(e)}
        case .Code:{if(e.offset==0 || e.offset>=code.count){diagnostics::absent(e)}
            else{error(selected,errors::make(e.kind,code.offsets[e.offset]))}}
    };
}
fn Result<Program,diagnostics::Error> finish_legacy(ref entries::Entry selected,ref ir::Program code,ref mut retention::Plan plan,usize deadline){
    if(!retention::admit(plan,0).is_ok){return .err(diagnostics::absent(errors::make(retention::quota_kind(),0)));}
    return switch(programs::retain_public_legacy_until(code,deadline)){
        case .ok(v):{retain(selected,v)}case .err(e):{.err(admission_error(selected,e,code))}
    };
}
fn Result<Program,diagnostics::Error> finish_references(ref entries::Entry selected,ref images::Builder builder,
    ref candidate::Program code,usize image_limit,ref mut retention::Plan plan,usize deadline){
    let usize payload=switch(images::planned_payload(builder)){case .ok(v):{v}case .err(_):{return .err(diagnostics::absent(errors::make(5,0)));}};
    if(!retention::admit(plan,payload).is_ok){return .err(diagnostics::absent(errors::make(retention::quota_kind(),0)));}
    let images::Image image=switch(images::freeze(builder,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(error(selected,compiler::public_error(programs::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e})));}
    };
    return switch(programs::retain_reference_returns_until(code,image,image_limit,deadline)){
        case .ok(v):{retain(selected,programs::retain_public_references(v))}
        case .err(e):{.err(admission_error(selected,e,ref code.body))}
    };
}
// Source duplication and final owning construction happen after compiler scratch
// and complete admission have returned; none of these slots burden that stack.
fn Result<Program,diagnostics::Error> retain(ref entries::Entry selected,programs::PublicProgram code){
    var vec::Vec<Stored> stored=vec::empty<Stored>();
    let usize reserved=switch(vec::reserve<Stored>(ref mut stored,1)){
        case .ok(v):{v}case .err(_):{return .err(diagnostics::absent(errors::make(15,0)));}
    };
    let sources::Snapshot retained=sources::duplicate(modules::snapshot(entries::index(selected)));
    let usize placed=switch(vec::push<Stored>(ref mut stored,Stored{.sources=retained,.code=code})){
        case .ok(v):{v}case .err(_):{return .err(diagnostics::absent(errors::make(15,0)));}
    };
    return .ok(Program{.stored=stored});
}
fn ref Stored stored(ref Program program){return vec::at<Stored>(ref program.stored,0);}
pub fn ref sources::Snapshot snapshot(ref Program program){return ref stored(program).sources;}
pub fn ref ir::Program body(ref Program program){return programs::public_body(ref stored(program).code);}
pub fn u8 profile(ref Program program){return programs::public_profile(ref stored(program).code);}
pub fn Result<i64,diagnostics::Error> run(ref Program program,usize fuel){
    return switch(programs::run_public(ref stored(program).code,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(if(e.offset==0){diagnostics::absent(e)}else{diagnostics::map(ref stored(program).sources,e,16)})}
    };
}
