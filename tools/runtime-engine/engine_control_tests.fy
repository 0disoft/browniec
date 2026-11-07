module engine_control_tests;
import runtime_engine as engine;
import runtime_control_budget as budget;
import control_budget_contracts as contracts;
unsafe extern C fn void bc_runtime_engine_test_control_begin();
unsafe extern C fn void bc_runtime_engine_test_control_no_allocations();
unsafe extern C fn void bc_runtime_engine_test_control_storage(ptr void owner,usize required,u32 kind);
unsafe extern C fn void bc_runtime_engine_test_control_report();
unsafe extern C fn void bc_runtime_engine_test_closed_allocations();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
fn usize amount(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void denied(Result<engine::Engine,engine::Error> r,u32 expected){
    switch(r){case .ok(_):{assert(false);}case .err(e):{assert(e.status==expected);}};
}
fn void checked(usize programs,usize instances,u32 kind){
    let engine::Limits limits=engine::Limits{.programs=programs,.instances=instances,.fuel=16000000};
    unsafe{bc_runtime_engine_test_control_begin()};
    let usize required=amount(engine::required_control_bytes(limits));assert(required>0&&required<=4194304);
    unsafe{bc_runtime_engine_test_fail(0)};
    denied(engine::create_with_control_budget(limits,required-1),8);
    unsafe{bc_runtime_engine_test_control_no_allocations()};
    denied(engine::create_with_control_budget(limits,required),6);
    unsafe{bc_runtime_engine_test_fail(-1)};
    unsafe{bc_runtime_engine_test_control_begin()};
    {
        var engine::Engine e=switch(engine::create_with_control_budget(limits,required)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let budget::Observation before=switch(engine::control_memory(ref e)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };assert(before.limit==required&&before.reserved==required&&before.peak==required&&!before.closed);
        unsafe{bc_runtime_engine_test_control_storage(ref e as ptr void,required,kind)};
        let engine::Engine moved=e;
        // The immutable observation follows the moved owning resource.
        var engine::Engine ready=moved;assert(amount(engine::destroy(ref mut ready))==0);
        let budget::Observation after=switch(engine::control_memory(ref ready)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };assert(after.limit==required&&after.reserved==0&&after.peak==required&&after.closed);
        unsafe{bc_runtime_engine_test_closed_allocations()};
    }
}
pub fn void run(){
    contracts::creation_validates_limits_and_reports_initial_reservation();
    contracts::exact_budget_succeeds_and_one_less_rejects_without_mutation();
    contracts::maximum_usize_reservations_reject_overflow_and_preserve_state();
    contracts::peak_survives_release_and_only_grows_on_a_new_high_water_mark();
    contracts::overrelease_and_nonempty_close_reject_without_poisoning_the_budget();
    contracts::closed_budget_rejects_even_zero_operations_and_stays_observable();

    denied(engine::create_with_control_budget(engine::Limits{.programs=1,.instances=1,.fuel=1},0),1);
    denied(engine::create_with_control_budget(engine::Limits{.programs=1,.instances=1,.fuel=1},4194305),1);
    checked(1,1,1);checked(8,8,2);checked(9,9,3);checked(64,64,4);checked(1,64,5);checked(64,1,6);
    unsafe{bc_runtime_engine_test_control_report()};
}
