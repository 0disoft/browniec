module main;
import runtime_engine as engine;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import source_error as diagnostics;
import errors as errors;
import engine_input_tests as input_tests;
import engine_output_tests as output_tests;
import engine_control_tests as control_tests;
import engine_retention_tests as retention_engine_tests;
import engine_compile_tests as compile_engine_tests;
import retention_plan_contracts as retention_tests;
import program_compile_contracts as compile_contracts;
import live_memory_contracts as live_contracts;
import engine_instance_memory as instance_memory_tests;
import output_memory_contracts as output_memory_tests;
import execution_memory_contracts as execution_memory_tests;
import engine_execution_memory as engine_execution_tests;
import dispatch_cursor_contracts as cursor_tests;
import dispatch_quantum_contracts as quantum_tests;
import engine_pending_tests as pending_tests;
import engine_prepared_tests as prepared_tests;
import engine_preparation_cache_tests as cache_tests;
import engine_preparation_reuse_tests as reuse_tests;
import engine_step_tests as step_tests;
import output_chunk_contracts as output_chunk_tests;
import engine_output_chunk_tests as engine_chunk_tests;
import pending_memory_contracts as pending_memory_tests;
unsafe extern C fn void bc_runtime_engine_test_closed_allocations();
unsafe extern C fn void bc_runtime_engine_test_seed(ptr mut void e,u32 kind);
unsafe extern C fn void bc_runtime_engine_test_guards(ptr mut void e);
fn sources::Builder builder(){return switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);builder()}};}
fn entries::Entry entry(ref u8[] source){
    var sources::Builder b=builder();assert(sources::add(ref mut b,b"app.brc",source).is_ok);
    let sources::Snapshot snapshot=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{assert(false);return entry(b"module app;pub fn i32 chosen(){return 0;}");}};
    let modules::Index index=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return entry(b"module app;pub fn i32 chosen(){return 0;}");}};
    return switch(entries::select_i32(index,b"app",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);entry(b"module app;pub fn i32 chosen(){return 0;}")}};
}
fn engine::Engine create(usize programs,usize instances){return switch(engine::create(engine::Limits{.programs=programs,.instances=instances,.fuel=16000000})){
    case .ok(e):{e}case .err(_):{assert(false);create(programs,instances)}
};}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,engine::Error> r,u32 status){switch(r){case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}};}
fn diagnostics::Error absent(){return diagnostics::absent(errors::make(0,0));}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){case .ok(e):{e}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.diagnostic=absent(),.remaining=0,.fuel_known=false}}};}
fn void counts(ref mut engine::Engine e,usize programs,usize instances,usize pins){switch(engine::inspect(e)){
    case .ok(s):{assert(s.programs==programs && s.instances==instances && s.pins==pins && !s.closed);}case .err(_):{assert(false);}
};}
fn i32 main(){
    engine::retain_native_bindings();
    pending_tests::run();
    prepared_tests::run();
    cache_tests::run();
    reuse_tests::run();
    step_tests::run();
    engine_chunk_tests::run();
    output_chunk_tests::multi_chunk_commits_once_after_the_last_byte_and_prepays_once();
    output_chunk_tests::fuel_and_quota_preflight_sample_without_copying_or_debit_on_rejection();
    output_chunk_tests::invalid_chunks_and_interleaved_operations_cannot_mutate_a_pending_emit();
    output_chunk_tests::cancel_and_fail_discard_partial_bytes_and_freeze_first_cause_and_spent_fuel();
    output_chunk_tests::empty_emit_commits_immediately_and_sealed_disabled_and_legacy_states_are_inactive();
    output_chunk_tests::exact_byte_chunk_and_one_mebibyte_boundaries_preserve_prices_and_header_size();
    output_chunk_tests::pending_transactions_interleave_and_move_without_losing_their_copy_cursor();
    output_chunk_tests::begin_chunks_and_seal_make_zero_allocation_attempts_after_reservation();
    pending_memory_tests::fixed_oracles_count_cached_scratch_exact_core_and_eight_inline_machines();
    pending_memory_tests::output_payload_zero_and_limit_boundaries_keep_the_fixed_header();
    pending_memory_tests::either_zero_native_size_is_invalid_even_with_valid_output();
    pending_memory_tests::machine_capacity_multiplication_and_combined_overflow_are_checked();
    pending_memory_tests::each_addition_rejects_overflow_without_wrapping();
    pending_memory_tests::exact_usize_totals_succeed_and_one_more_byte_fails();
    pending_memory_tests::trusted_native_sizes_and_scratch_have_no_extra_policy_cap();
    {
        var engine::Engine e=create(2,3);counts(ref mut e,0,0,0);
        unsafe{bc_runtime_engine_test_guards(ref mut e as ptr mut void)};
        let usize p=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){var i32[1] a=[41];a[0]+=1;return a[0];}"),65536));assert(p==1);
        let usize first=id(engine::create_instance(ref mut e,p,16000000));let usize second=id(engine::create_instance(ref mut e,p,16000000));
        let usize starved=id(engine::create_instance(ref mut e,p,0));counts(ref mut e,1,3,3);
        rejected(engine::create_instance(ref mut e,p,1),8);rejected(engine::destroy(ref mut e),3);
        assert(id(engine::release_program(ref mut e,p))==p);rejected(engine::create_instance(ref mut e,p,1),2);counts(ref mut e,1,3,3);
        let engine::Event a=event(engine::execute_once(ref mut e,first));assert(a.kind==1 && a.value==42);
        let engine::Event b=event(engine::execute_once(ref mut e,second));assert(b.kind==1 && b.value==42);
        switch(engine::execute_once(ref mut e,first)){case .ok(_):{assert(false);}case .err(e):{assert(e.status==11);}};
        assert(event(engine::observe(ref mut e,first)).value==42 && event(engine::cancel_ready(ref mut e,first)).kind==1);
        let engine::Event trap=event(engine::execute_once(ref mut e,starved));assert(trap.kind==2 && trap.diagnostic.code.kind==8);
        assert(id(engine::destroy_instance(ref mut e,second))==second);counts(ref mut e,1,2,2);
        assert(id(engine::destroy_instance(ref mut e,first))==first);counts(ref mut e,1,1,1);
        assert(id(engine::destroy_instance(ref mut e,starved))==starved);counts(ref mut e,0,0,0);
        rejected(engine::release_program(ref mut e,p),2);rejected(engine::destroy_instance(ref mut e,first),2);
        switch(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return missing;}"),65536)){
            case .ok(_):{assert(false);}case .err(e):{assert(e.status==4 && e.diagnostic.code.kind==3);}
        };counts(ref mut e,0,0,0);
        let usize next=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return 1/0;}"),65536));assert(next==5);
        let usize cancelled=id(engine::create_instance(ref mut e,next,100));assert(event(engine::cancel_ready(ref mut e,cancelled)).kind==3);
        switch(engine::execute_once(ref mut e,cancelled)){case .ok(_):{assert(false);}case .err(e):{assert(e.status==11);}};
        assert(id(engine::destroy_instance(ref mut e,cancelled))==cancelled);assert(id(engine::release_program(ref mut e,next))==next);
        assert(id(engine::destroy(ref mut e))==0);unsafe{bc_runtime_engine_test_closed_allocations()};rejected(engine::destroy(ref mut e),2);
    }
    {
        var engine::Engine e=create(1,1);let usize p=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return 42;}"),65536));
        rejected(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return 0;}"),65536),8);
        rejected(engine::create_instance(ref mut e,p,16000001),5);
        assert(id(engine::release_program(ref mut e,p))==p);counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
    }
    {
        var engine::Engine original=create(1,1);
        let usize p=id(engine::compile(ref mut original,entry(b"module app;pub fn i32 chosen(){let ref u8[] b=b\"*\";return b[0] as i32;}"),65536));
        let usize i=id(engine::create_instance(ref mut original,p,16000000));assert(id(engine::release_program(ref mut original,p))==p);
        var engine::Engine moved=original;counts(ref mut moved,1,1,1);
        assert(event(engine::execute_once(ref mut moved,i)).value==42);
        assert(id(engine::destroy_instance(ref mut moved,i))==i);counts(ref mut moved,0,0,0);assert(id(engine::destroy(ref mut moved))==0);
        unsafe{bc_runtime_engine_test_closed_allocations()};
    }
    {
        var engine::Engine e=create(1,1);unsafe{bc_runtime_engine_test_seed(ref mut e as ptr mut void,1)};
        let usize p=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return 42;}"),65536));assert(p==18446744073709551615);
        rejected(engine::create_instance(ref mut e,p,256),8);counts(ref mut e,1,0,0);
        assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy(ref mut e))==0);
    }
    {
        var engine::Engine e=create(1,1);
        let usize p=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return 42;}"),65536));
        let usize i=id(engine::create_instance(ref mut e,p,256));assert(event(engine::execute_once(ref mut e,i)).value==42);
        unsafe{bc_runtime_engine_test_seed(ref mut e as ptr mut void,2)};counts(ref mut e,1,1,1);
        assert(event(engine::observe(ref mut e,i)).value==42);rejected(engine::create_instance(ref mut e,p,256),8);
        switch(engine::execute_once(ref mut e,i)){case .ok(_):{assert(false);}case .err(e):{assert(e.status==8);}};
        rejected(engine::destroy(ref mut e),3);assert(id(engine::release_program(ref mut e,p))==p);
        assert(id(engine::destroy_instance(ref mut e,i))==i);counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
    }
    {
        var engine::Engine e=create(4,2);
        let usize a=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return 0;}"),65536));
        let usize b=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){let ref u8[] b=b\"*\";return b[0] as i32;}"),65536));
        let usize trash=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){return 7;}"),65536));
        let usize c=id(engine::compile(ref mut e,entry(b"module app;pub fn i32 chosen(){let ref u8[] b=b\"+\";return b[0] as i32;}"),65536));
        let usize bi=id(engine::create_instance(ref mut e,b,16000000));let usize ci=id(engine::create_instance(ref mut e,c,16000000));
        assert(id(engine::release_program(ref mut e,trash))==trash);counts(ref mut e,3,2,2);
        assert(id(engine::release_program(ref mut e,a))==a);counts(ref mut e,2,2,2);
        assert(id(engine::release_program(ref mut e,b))==b);assert(event(engine::execute_once(ref mut e,bi)).value==42);
        assert(id(engine::destroy_instance(ref mut e,bi))==bi);counts(ref mut e,1,1,1);
        assert(event(engine::execute_once(ref mut e,ci)).value==43);
        // Leave the last live Instance and unreleased Program to owning cleanup.
    }
    unsafe{bc_runtime_engine_test_closed_allocations()};
    input_tests::run();
    output_tests::run();
    retention_tests::exact_and_one_less_are_atomic_and_rejection_allows_retry();
    retention_tests::maximum_usize_rejects_overflow_before_addition_without_mutation();
    retention_tests::double_admit_is_state_even_for_zero_unlimited_and_overquota_payload();
    retention_tests::creation_invalid_precedes_quota_and_private_diagnostic_is_stable();
    retention_engine_tests::run();
    compile_engine_tests::run();
    compile_contracts::defaults_and_private_working_limits_preserve_existing_limits();
    compile_contracts::overhead_plus_scratch_exact_and_one_less_limits_return_original_phase_zero();
    compile_contracts::overflow_and_rejected_baselines_preserve_every_budget_field();
    compile_contracts::published_peers_share_combined_allowance_and_release_restores_headroom();
    compile_contracts::compilation_and_program_high_water_marks_are_independent_histories();
    compile_contracts::aborted_work_and_admitted_oom_preserve_reservations_without_publishing();
    compile_contracts::successful_phase_records_before_separate_program_publication();
    compile_contracts::direct_program_record_and_publish_track_actual_aggregate_and_reject_atomically();
    compile_contracts::moves_and_close_release_control_preserve_peaks_and_reject_further_operations();
    compile_contracts::external_exact_and_one_less_combined_limits_reject_without_mutation();
    compile_contracts::external_current_is_in_compile_phase_zero_baseline_and_combined_admission();
    compile_contracts::external_current_limits_retained_publication_and_survives_program_release();
    compile_contracts::external_owner_blocks_close_and_refunds_and_moves_preserve_all_peaks();
    live_contracts::limits_caps_and_detached_flat_observation();
    live_contracts::per_instance_exact_and_one_less_include_transient();
    live_contracts::aggregate_exact_and_one_less_preserve_peer_charges();
    live_contracts::replacement_grows_shrinks_and_removes_only_old_owner();
    live_contracts::prepare_failure_recorded_failed_allocation_and_commit_are_distinct();
    live_contracts::maximum_arithmetic_stale_and_invalid_state_fail_without_mutation();
    live_contracts::release_close_and_zero_byte_owners_preserve_historical_peak();
    output_memory_tests::early_limit_input_and_prepare_fuel_failures_retain_zero_heap();
    output_memory_tests::result_reserve_header_and_backing_oom_release_every_prepared_owner();
    output_memory_tests::late_vm_and_seal_failures_keep_empty_vec8_capacity_without_payload();
    output_memory_tests::success_counts_reserved_backing_even_for_empty_emit_and_no_emit();
    output_memory_tests::detached_results_move_without_allocating_and_cleanup_returns_to_baseline();
    output_memory_tests::published_and_transaction_queries_follow_seal_transfer_and_cancel_cleanup();
    execution_memory_tests::empty_variants_keep_input_metadata_and_reserved_output_independent();
    execution_memory_tests::declared_arrays_and_records_share_one_arena_without_per_owner_or_depth_heap();
    execution_memory_tests::list_values_use_vec_minimum_and_power_two_capacity_but_exact_encoded_bytes();
    execution_memory_tests::separate_list_maxima_cover_creation_replacement_and_aggregate_list_replacement();
    execution_memory_tests::all_place_formats_round_vector_capacity_at_minimum_boundaries_and_maximum();
    execution_memory_tests::mixed_places_use_one_selected_format_and_all_maximum_components_overlap();
    execution_memory_tests::invalid_output_controls_and_all_size_header_overflows_fail_without_wrapping();
    execution_memory_tests::original_list_and_place_errors_preserve_instruction_offsets_and_precedence();
    cursor_tests::cursor_empty_moves_and_resets_only_resume_control();
    cursor_tests::quantum_boundaries_and_begin_rejections_preserve_every_counter();
    cursor_tests::finish_aggregates_pending_complete_and_error_histories_once_per_batch();
    cursor_tests::begin_reserves_full_quantum_headroom_and_finish_overflow_is_atomic();
    cursor_tests::malformed_states_and_compatibility_helpers_obey_atomic_bounds();
    quantum_tests::loop_and_nested_void_output_resumes_without_replaying_emits();
    quantum_tests::returned_input_and_static_ranges_keep_frame_maps_and_binary_loans();
    quantum_tests::array_list_indexed_places_and_record_calls_preserve_owners_between_batches();
    quantum_tests::runtime_errors_and_fuel_exhaustion_keep_exact_diagnostics_and_no_partial_output();
    quantum_tests::invalid_quanta_reject_before_output_prepare_without_touching_stats_fuel_or_heap();
    quantum_tests::detached_quantized_publications_outlive_program_and_input_and_move_without_replay();
    engine_execution_tests::run();
    instance_memory_tests::run();
    control_tests::run();
    unsafe{bc_runtime_engine_test_closed_allocations()};
    return 0;
}
