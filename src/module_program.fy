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

// Only internally rebuilt source/context plus complete canonical admission can
// create this resource. Compiler name tables are not retained at runtime.
// Keep both code and original-source storage out of owning return slots.
resource Stored { sources::Snapshot sources; programs::PublicProgram code; cleanup { } }
pub resource Program { vec::Vec<Stored> stored; cleanup { } }
// Unverified lowering output for the private Engine. Admission still proves
// the complete candidate and associates it with the selected source.
pub struct Lowered { candidate::Program code; images::Builder literals; bool references; }
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
pub fn Result<usize,diagnostics::Error> start_lowered(ref mut vec::Vec<Lowered> storage){
    assert(vec::len<Lowered>(storage)==0);
    let Lowered empty=Lowered{
        .code=candidate::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]},
        .literals=images::full_builder(),.references=false};
    return switch(vec::push<Lowered>(storage,empty)){
        case .ok(v):{.ok(v)}case .err(_):{.err(diagnostics::absent(errors::make(15,0)))}
    };
}
pub fn Result<usize,diagnostics::Error> lower_prepared_until(ref entries::Entry selected,
    ref module_source::State source,ref mut Lowered lowered,usize deadline){
    var images::Builder literals=images::full_builder();
    let bool references=compiler::lower_modules_prepared_until(selected,source,ref mut literals,ref mut lowered.code,false,deadline)?;
    if(clock::expired(deadline)){return .err(diagnostics::absent(errors::absent(errors::deadline_kind(),0)));}
    lowered.literals=literals;lowered.references=references;
    return .ok(0);
}
pub fn Result<Program,diagnostics::Error> admit_lowered_until(ref entries::Entry selected,
    ref Lowered lowered,usize image_limit,ref mut retention::Plan plan,usize deadline){
    if(clock::expired(deadline)){return .err(diagnostics::absent(errors::absent(errors::deadline_kind(),0)));}
    if(lowered.references){return finish_references(selected,ref lowered.literals,ref lowered.code,image_limit,plan,deadline);}
    return finish_legacy(selected,ref lowered.code.body,plan,deadline);
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
