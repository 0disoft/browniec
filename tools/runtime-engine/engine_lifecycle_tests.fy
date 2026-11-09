module engine_lifecycle_tests;
import runtime_engine as engine;
import metadata_budget as metadata;
import source_error as diagnostics;
import errors as errors;

unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
fn engine::Event event(Result<engine::Event,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.remaining=0,
        .fuel_known=false,.diagnostic=diagnostics::absent(errors::make(0,0))}}
};}
fn usize phase(ref engine::Engine e,usize i){return switch(engine::lifecycle_phase(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn metadata::State progress(ref engine::Engine e,usize i){return switch(engine::authority_metadata_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);metadata::empty()}
};}
fn usize memory(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v.current}case .err(_):{assert(false);0}
};}
fn void bounded(metadata::State before,metadata::State after){
    assert(after.total>=before.total && after.total-before.total<=4096);
    assert(after.last==after.total-before.total && after.last<=4096);
    assert(after.stages>=before.stages && after.stages-before.stages<=1);
}
// Real proof/buffer/input/Core/entry resumes precede payload-specific counts.
// Only entry consumes Fuel; setup never dispatches a guest instruction.
pub fn void warm(ref mut engine::Engine e,usize i){
    var usize n=0;
    while(phase(e,i)<5 && n<8192){
        let usize stage=phase(e,i);let engine::Event before=event(engine::observe(e,i));
        let metadata::State prior=progress(e,i);let usize charge=memory(e);
        let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
        let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
        let Result<engine::Event,engine::Error> result=engine::step_instance(e,i,1);
        unsafe{bc_runtime_engine_test_fail(-1)};let engine::Event after=event(result);
        assert(unsafe{probe_attempts()}==attempts && unsafe{probe_live()}==blocks && unsafe{probe_live_bytes()}==bytes);
        assert(before.kind==4 && after.kind==4 && after.fuel_known && memory(e)==charge);
        assert(phase(e,i)>=stage && phase(e,i)<=5);bounded(prior,progress(e,i));
        if(stage<4){assert(after.remaining==before.remaining);}
        else{assert(phase(e,i)==5 && after.remaining<before.remaining);}
        n+=1;
    }
    assert(phase(e,i)==5);
}
// Alternate cancel and step to drain the same latched cleanup without replay.
// Retained backing stays stable until the terminal cancellation frees it.
pub fn engine::Event stop(ref mut engine::Engine e,usize i){
    var engine::Event state=event(engine::observe(e,i));let usize fuel=state.remaining;
    var usize n=0;
    while(state.kind==4 && n<8192){
        let metadata::State prior=progress(e,i);let usize charge=memory(e);
        let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
        let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
        let Result<engine::Event,engine::Error> result=if(n%2==0){engine::cancel_ready(e,i)}else{engine::step_instance(e,i,1)};
        unsafe{bc_runtime_engine_test_fail(-1)};state=event(result);
        assert(unsafe{probe_attempts()}==attempts && state.fuel_known && state.remaining==fuel);
        assert(state.kind==4 || state.kind==3);
        if(state.kind==4){
            assert(phase(e,i)>=7 && phase(e,i)<=10);bounded(prior,progress(e,i));
            assert(memory(e)==charge && unsafe{probe_live()}==blocks && unsafe{probe_live_bytes()}==bytes);
        }
        n+=1;
    }
    assert(state.kind==3 && state.value==0 && state.diagnostic.code.kind==0);
    return state;
}
