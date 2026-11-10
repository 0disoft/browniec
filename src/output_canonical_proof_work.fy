module output_canonical_proof_work;
import static_call_ir as programs;
import static_image as images;
import verifier as verifier;
import errors as errors;
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
pub fn State empty_input(){var State w=empty(true);w.output=false;return w;}
pub fn Result<bool,errors::Error> advance(ref programs::Program unit,ref images::Image image,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==1){let bool done=recipes::advance(ref mut w.recipes,unit,image,meter)?;
        if(done){w.phase=2;}return .ok(false);}
    if(w.phase==2){let call_ir::Proof proof=w.recipes.result;
        let bool done=sites::advance(unit,ref proof,image,ref mut w.sites,meter)?;
        if(done){w.sites.result.output=w.output;w.phase=3;}return .ok(false);}
    if(w.phase==3){let static_ir::Sites catalog=w.sites.result;
        let bool done=metadata::advance(ref unit.body,ref catalog,ref mut w.metadata,meter)?;
        if(done){w.phase=4;}return .ok(false);}
    if(w.phase==5){
        if(w.flow.task!=0 && !w.flow.approved){
            if(!budget::admit(meter,4096,w.flow.pc)?){return .ok(false);}
            let tasks::Request request=tasks::Request{.function=w.flow.function,.pc=w.flow.pc,
                .live=w.flow.live,.defined=w.flow.defined,.kind=w.flow.task};
            let usize started=tasks::begin(ref mut w.task,request)?;w.phase=6;return .ok(false);
        }
        // Explicit immutable projections avoid overlapping whole-state borrows.
        // 2064 shapes + 33 loans + <=512 sites + 1280 CFG initialization
        // entries remain below 4096 including the leaf's fixed framing.
        let records::Prepared shapes=w.metadata.records.result;
        let loans::Sites forest=w.metadata.loans;let static_ir::Sites catalog=w.sites.result;
        let bool done=flow::advance(ref unit.body,ref shapes,ref forest,
            ref catalog,ref mut w.flow,meter)?;
        if(done){w.function+=1;w.phase=4;}return .ok(false);
    }
    if(w.phase==6){let records::Prepared shapes=w.metadata.records.result;
        let layouts::Plan plan=w.metadata.records.layout.plan;let static_ir::Sites catalog=w.sites.result;
        let bool done=tasks::advance(ref unit.body,ref shapes,ref plan,ref catalog,ref mut w.task,meter)?;
        if(done){let usize live=w.task.output;let usize provided=flow::provide(ref mut w.flow,live)?;w.phase=5;}return .ok(false);}
    if(w.phase==7){let bool done=places::advance(ref unit.body,ref mut w.places,meter)?;
        if(done){w.phase=8;w.pc=0;}return .ok(false);}
    if(w.phase==10){let static_ir::Sites catalog=w.sites.result;
        let bool done=references::advance(ref unit.body,ref catalog,ref mut w.references,meter)?;
        if(done){w.done=true;}return .ok(w.done);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    if(w.phase==0){let bool input=w.input;let usize started=if(w.output){recipes::begin(ref mut w.recipes,unit,image,input)?}
        else{recipes::begin_input(ref mut w.recipes,unit,image)?};w.phase=1;}
    else if(w.phase==4){
        if(w.function==unit.body.function_count){w.phase=7;}
        else{let usize function=w.function;let usize started=flow::begin(ref mut w.flow,function)?;w.phase=5;}
    }else if(w.phase==8){
        if(w.pc==unit.body.call_count){w.phase=9;w.pc=0;}
        else{if(!w.flow.calls[w.pc]){return .err(errors::make(5,0));}w.pc+=1;}
    }else if(w.phase==9){
        if(w.metadata.loans.count==0 || w.pc==unit.body.count){w.phase=10;}
        else{let u8 op=unit.body.code[w.pc*8];if(op==9 || op==78){
            let usize checked=executable::call(ref unit.body,ref w.metadata.loans,w.pc)?;}w.pc+=1;}
    }else{return .err(errors::make(5,0));}
    return .ok(false);
}
pub fn Result<verifier::ReferenceReturnProof,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,0));}
    return .ok(verifier::ReferenceReturnProof{.recipes=w.recipes.result,.statics=w.sites.result,
        .loans=w.metadata.loans,.owner_roots=w.references.roots});
}
// Keep the separate input ABI/output gate while draining the same stages for
// the existing synchronous owning compiler. This does not admit raw callbacks.
pub fn Result<verifier::ReferenceReturnProof,errors::Error> inspect_input(ref programs::Program unit,ref images::Image image){
    var State w=empty_input();var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;
        let bool done=advance(unit,image,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}
