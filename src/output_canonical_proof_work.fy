module output_canonical_proof_work;
import static_call_ir as programs;
import static_image as images;
import verifier as verifier;
import errors as errors;
import runtime_clock as clock;
import metadata_budget as budget;
import output_static_recipe_work as recipes;
import output_static_sites_work as sites;
import output_verifier_metadata_work as metadata;
import output_verifier_flow_work as flow;
import output_verifier_tasks_work as tasks;
import output_place_lifetimes_work as places;
import output_reference_lifetimes_work as references;
import slice_reborrow_admission_ir as executable;
import static_call_ir as call_ir;
import static_ir as static_ir;
import struct_meta as records;
import struct_layout as layouts;
import slice_reborrow_ir as loans;
import ir as ir;
import output_record_metadata_work as record_work;
import struct_layout_work as layout_work;

// Private complete canonical proof. The owner pins the exact immutable code
// and image until completion. A task result never escapes this coordinator.
// Each advance executes at most one fresh bounded leaf or framing stage.
pub struct State {
    recipes::State recipes; sites::State sites; metadata::State metadata;
    flow::State flow; tasks::State task; places::State places;
    references::State references; usize function; usize pc; u8 phase;
    bool input; bool output; bool done;
}
pub fn State empty(bool input){return State{.recipes=recipes::empty(),.sites=sites::empty(),
    .metadata=metadata::empty(input),.flow=flow::empty(),.task=tasks::empty(),
    .places=places::empty(),.references=references::empty(),.function=0,.pc=0,.phase=0,.input=input,.output=true,.done=false};}
fn State empty_without_output(bool input){var State w=empty(input);w.output=false;return w;}
pub fn State empty_input(){return empty_without_output(true);}
pub fn State empty_ordinary(){return empty_without_output(false);}
// Narrow references prevent the bootstrap emitter from materializing every
// enclosing fixed bank when projecting one immutable prepared field.
fn records::Prepared shapes(ref metadata::State w){let ref record_work::State records=ref w.records;return records.result;}
fn layouts::Plan record_plan(ref metadata::State w){let ref record_work::State records=ref w.records;
    let ref layout_work::State layout=ref records.layout;return layout.plan;}
fn loans::Sites forest(ref metadata::State w){return w.loans;}
fn static_ir::Sites catalog(ref sites::State w){return w.result;}
fn bool requested(ref flow::State w){return w.task!=0 && !w.approved;}
fn tasks::Request request(ref flow::State w){return tasks::Request{.function=w.function,.pc=w.pc,
    .live=w.live,.defined=w.defined,.kind=w.task};}
fn bool used(ref flow::State w,usize call){return w.calls[call];}
fn usize live(ref tasks::State w){return w.output;}
fn usize[16] roots(ref references::State w){return w.roots;}
pub fn layouts::Plan layout(ref State w){return record_plan(ref w.metadata);}
pub fn Result<bool,errors::Error> advance(ref programs::Program unit,ref images::Image image,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    let ref ir::Program p=ref unit.body;
    if(w.phase==1){let bool done=recipes::advance(ref mut w.recipes,unit,image,meter)?;
        if(done){w.phase=2;}return .ok(false);}
    if(w.phase==2){let call_ir::Proof proof=recipes::prepared(ref w.recipes)?;
        let bool done=sites::advance(unit,ref proof,image,ref mut w.sites,meter)?;
        if(done){w.sites.result.output=w.output;w.phase=3;}return .ok(false);}
    if(w.phase==3){let static_ir::Sites catalog=catalog(ref w.sites);
        let bool done=metadata::advance(p,ref catalog,ref mut w.metadata,meter)?;
        if(done){w.phase=4;}return .ok(false);}
    if(w.phase==5){
        if(requested(ref w.flow)){
            let tasks::Request request=request(ref w.flow);
            if(!budget::admit(meter,4096,request.pc)?){return .ok(false);}
            let usize started=tasks::begin(ref mut w.task,request)?;w.phase=6;return .ok(false);
        }
        // Explicit immutable projections avoid overlapping whole-state borrows.
        // 2064 shapes + 33 loans + <=512 sites + 1280 CFG initialization
        // entries remain below 4096 including the leaf's fixed framing.
        let records::Prepared shapes=shapes(ref w.metadata);
        let loans::Sites forest=forest(ref w.metadata);let static_ir::Sites catalog=catalog(ref w.sites);
        let bool done=flow::advance(p,ref shapes,ref forest,
            ref catalog,ref mut w.flow,meter)?;
        if(done){w.function+=1;w.phase=4;}return .ok(false);
    }
    if(w.phase==6){let records::Prepared shapes=shapes(ref w.metadata);
        let layouts::Plan plan=record_plan(ref w.metadata);let static_ir::Sites catalog=catalog(ref w.sites);
        let bool done=tasks::advance(p,ref shapes,ref plan,ref catalog,ref mut w.task,meter)?;
        if(done){let usize live=live(ref w.task);let usize provided=flow::provide(ref mut w.flow,live)?;w.phase=5;}return .ok(false);}
    if(w.phase==7){let bool done=places::advance(p,ref mut w.places,meter)?;
        if(done){w.phase=8;w.pc=0;}return .ok(false);}
    if(w.phase==10){let static_ir::Sites catalog=catalog(ref w.sites);
        let bool done=references::advance(p,ref catalog,ref mut w.references,meter)?;
        if(done){w.done=true;}return .ok(w.done);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    if(w.phase==0){let bool input=w.input;let usize started=if(w.output){recipes::begin(ref mut w.recipes,unit,image,input)?}
        else{recipes::begin_without_output(ref mut w.recipes,unit,image,input)?};w.phase=1;}
    else if(w.phase==4){
        if(w.function==p.function_count){w.phase=7;}
        else{let usize function=w.function;let usize started=flow::begin(ref mut w.flow,function)?;w.phase=5;}
    }else if(w.phase==8){
        if(w.pc==p.call_count){w.phase=9;w.pc=0;}
        else{if(!used(ref w.flow,w.pc)){return .err(errors::make(5,0));}w.pc+=1;}
    }else if(w.phase==9){
        let loans::Sites forest=forest(ref w.metadata);
        if(forest.count==0 || w.pc==p.count){w.phase=10;}
        else{let u8 op=p.code[w.pc*8];if(op==9 || op==78){
            let usize checked=executable::call(p,ref forest,w.pc)?;}w.pc+=1;}
    }else{return .err(errors::make(5,0));}
    return .ok(false);
}
pub fn Result<verifier::ReferenceReturnProof,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,0));}
    return .ok(verifier::ReferenceReturnProof{.recipes=recipes::prepared(ref w.recipes)?,.statics=catalog(ref w.sites),
        .loans=forest(ref w.metadata),.owner_roots=roots(ref w.references)});
}
// Keep the separate input ABI/output gate while draining the same stages for
// the existing synchronous owning compiler. This does not admit raw callbacks.
pub fn Result<verifier::ReferenceReturnProof,errors::Error> inspect_input(ref programs::Program unit,ref images::Image image){
    return inspect_input_until(unit,image,0);
}
pub fn Result<verifier::ReferenceReturnProof,errors::Error> inspect_input_until(ref programs::Program unit,ref images::Image image,usize deadline){
    var State w=empty_input();var budget::State meter=budget::empty();
    while(!w.done){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize allowance=budget::reset(ref mut meter,0)?;
        let bool done=advance(unit,image,ref mut w,ref mut meter)?;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return prepared(ref w);
}
