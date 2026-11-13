"""Verify ordinary grouped, CALL, unary and postfix/cast continuations."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('semantic_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/operand-source-work'
bottom.MODULES = {'expression_lowering': None, 'semantic_lowering': None, 'body_lowering': None, 'body_source_work': None, 'call_operand_kernel': None, 'tail_lowering': None}
bottom.EXTRA_INPUTS = {'tools/verify-operand-source-work.py'}
# Narrow recheck for completion guards and mixed depth after a composed snapshot.
if '--kernel-only' in sys.argv:
    sys.argv.remove('--kernel-only')
    bottom.DIRECTORY = 'build/operand-completion-work'
    bottom.MODULES = {'call_operand_kernel': None, 'body_lowering': ['nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics', 'captured_scalar_results_keep_prefix_order_and_lexical_cleanup']}
if '--unary-only' in sys.argv:
    sys.argv.remove('--unary-only')
    bottom.DIRECTORY = 'build/operand-unary-work'
    bottom.MODULES = {'expression_lowering': ['unary_children_defer_tokens_checks_and_emission_on_shared_frames'],
                      'body_lowering': ['unary_operands_keep_raw_precedence_context_minima_and_errors',
                                        'unary_depth_and_mixed_capture_exits_preserve_raw_limits_on_default_stack']}
if '--tail-only' in sys.argv:
    sys.argv.remove('--tail-only')
    bottom.DIRECTORY = 'build/operand-tail-work'
    bottom.MODULES = {'tail_lowering': None, 'semantic_lowering': None,
                      'body_lowering': ['postfix_and_cast_operands_preserve_raw_ir_precedence_and_diagnostics',
                                        'postfix_capture_failures_ranges_and_register_limits_preserve_raw_prefixes',
                                        'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics',
                                        'unary_depth_and_mixed_capture_exits_preserve_raw_limits_on_default_stack']}
if '--preflight-only' in sys.argv:
    sys.argv.remove('--preflight-only')
    bottom.DIRECTORY = 'build/operand-preflight-work'
    bottom.MODULES = {'preflight_lowering': None, 'expression_lowering': ['expression_depth_rejects_before_requesting_an_operand'],
                      'body_lowering': ['postfix_and_cast_operands_preserve_raw_ir_precedence_and_diagnostics',
                                        'grouped_operands_match_raw_ir_and_preserve_postfix_cast_context',
                                        'scalar_call_operands_preserve_raw_arguments_suffixes_and_errors',
                                        'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics',
                                        'unary_depth_and_mixed_capture_exits_preserve_raw_limits_on_default_stack',
                                        'preflight_legacy_boundaries_and_record_binary_groups_keep_raw_ir_and_errors']}
if '--preflight-boundary-only' in sys.argv:
    sys.argv.remove('--preflight-boundary-only')
    bottom.DIRECTORY = 'build/operand-preflight-boundary'
    bottom.MODULES = {'body_lowering': ['preflight_legacy_boundaries_and_record_binary_groups_keep_raw_ir_and_errors']}
if '--syntax-only' in sys.argv:
    sys.argv.remove('--syntax-only')
    bottom.DIRECTORY = 'build/operand-syntax-work'
    bottom.MODULES = {'value_syntax_lowering': None, 'aggregate_probe_lowering': None, 'body_lowering': ['preflight_legacy_boundaries_and_record_binary_groups_keep_raw_ir_and_errors', 'staged_conditional_and_aggregate_projections_keep_raw_ir_and_failure_prefixes', 'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics']}
if '--syntax-boundary-only' in sys.argv:
    sys.argv.remove('--syntax-boundary-only')
    bottom.DIRECTORY = 'build/operand-syntax-boundary'
    bottom.MODULES = {'value_syntax_lowering': ['conditional_group_body_and_index_depth_boundaries_keep_raw_error_order'],
                      'aggregate_probe_lowering': ['long_field_names_resume_across_chunks_in_single_and_scoped_catalogs']}
if '--evaluation-only' in sys.argv:
    sys.argv.remove('--evaluation-only')
    bottom.DIRECTORY = 'build/operand-evaluation-work'
    bottom.MODULES = {'evaluation_lowering': None, 'static_bindings_source': ['owned_projection_temporaries_survive_index_exits_without_leaking'], 'body_lowering': ['staged_record_field_evaluation_keeps_slot_order_shorthand_and_failures', 'staged_static_index_and_cleanup_keep_complete_raw_ir', 'staged_static_length_keeps_raw_ir', 'staged_static_conditional_index_keeps_raw_ir', 'staged_static_bad_index_keeps_raw_error', 'staged_static_bad_member_keeps_raw_error', 'staged_conditional_bodies_keep_scope_joins_control_and_error_prefixes', 'staged_switch_constructor_and_aggregate_tails_keep_raw_domains', 'staged_array_evaluation_preserves_nested_values_wide_lists_and_failure_prefixes', 'staged_conditional_and_aggregate_projections_keep_raw_ir_and_failure_prefixes', 'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics', 'nested_conditional_heads_keep_depth_30_and_31_on_default_stack']}
if '--static-evaluation-only' in sys.argv:
    sys.argv.remove('--static-evaluation-only')
    bottom.DIRECTORY = 'build/operand-static-evaluation'
    bottom.MODULES = {'body_lowering': ['staged_static_index_and_cleanup_keep_complete_raw_ir', 'staged_static_length_keeps_raw_ir', 'staged_static_conditional_index_keeps_raw_ir', 'staged_static_bad_index_keeps_raw_error', 'staged_static_bad_member_keeps_raw_error']}
if '--evaluation-entry-only' in sys.argv:
    sys.argv.remove('--evaluation-entry-only')
    bottom.DIRECTORY = 'build/operand-evaluation-entry'
    bottom.MODULES = {'evaluation_entry': None}
if '--evaluation-depth-only' in sys.argv:
    sys.argv.remove('--evaluation-depth-only')
    bottom.DIRECTORY = 'build/operand-evaluation-depth'
    bottom.MODULES = {'body_lowering': ['nested_conditional_heads_keep_depth_30_and_31_on_default_stack']}
if '--aggregate-call-only' in sys.argv:
    sys.argv.remove('--aggregate-call-only')
    bottom.DIRECTORY = 'build/operand-aggregate-call'
    bottom.MODULES = {'aggregate_call_lowering': None, 'body_lowering': ['specialized_aggregate_calls_preserve_destinations_and_execute', 'captured_scalar_results_keep_prefix_order_and_lexical_cleanup', 'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics', 'staged_switch_constructor_and_aggregate_tails_keep_raw_domains']}
if '--aggregate-copy-only' in sys.argv:
    sys.argv.remove('--aggregate-copy-only')
    bottom.DIRECTORY = 'build/operand-aggregate-copy'
    bottom.MODULES = {'aggregate_copy_lowering': None, 'static_bindings_source': ['owned_projection_temporaries_survive_index_exits_without_leaking'], 'body_lowering': ['staged_aggregate_copy_bodies_preserve_snapshots_and_owned_children', 'staged_record_field_evaluation_keeps_slot_order_shorthand_and_failures', 'specialized_aggregate_calls_preserve_destinations_and_execute', 'captured_scalar_results_keep_prefix_order_and_lexical_cleanup', 'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics']}
if '--aggregate-special-only' in sys.argv:
    sys.argv.remove('--aggregate-special-only')
    bottom.DIRECTORY = 'build/operand-aggregate-special'
    bottom.MODULES = {'aggregate_call_lowering': None, 'aggregate_copy_lowering': None, 'static_bindings_source': ['owned_projection_temporaries_survive_index_exits_without_leaking'], 'body_lowering': ['staged_aggregate_copy_bodies_preserve_snapshots_and_owned_children', 'specialized_aggregate_calls_preserve_destinations_and_execute', 'staged_record_field_evaluation_keeps_slot_order_shorthand_and_failures', 'captured_scalar_results_keep_prefix_order_and_lexical_cleanup', 'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics', 'staged_switch_constructor_and_aggregate_tails_keep_raw_domains']}
if '--acquisition-only' in sys.argv:
    sys.argv.remove('--acquisition-only')
    bottom.DIRECTORY = 'build/operand-acquisition'
    bottom.MODULES = {'argument_acquisition_lowering': None, 'body_lowering': ['specialized_aggregate_calls_preserve_destinations_and_execute', 'staged_aggregate_copy_bodies_preserve_snapshots_and_owned_children', 'captured_scalar_results_keep_prefix_order_and_lexical_cleanup', 'nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics']}
if '--returned-dependencies-only' in sys.argv:
    sys.argv.remove('--returned-dependencies-only')
    bottom.DIRECTORY = 'build/operand-returned-dependencies'
    bottom.MODULES = {'returned_dependency_lowering': None}
if '--record-metadata-only' in sys.argv:
    sys.argv.remove('--record-metadata-only')
    bottom.DIRECTORY = 'build/operand-record-metadata'
    bottom.MODULES = {'record_metadata_lowering': None, 'record_declaration_lowering': None, 'body_lowering': ['staged_record_field_evaluation_keeps_slot_order_shorthand_and_failures', 'staged_aggregate_copy_bodies_preserve_snapshots_and_owned_children']}
if '--copy-metadata-only' in sys.argv:
    sys.argv.remove('--copy-metadata-only')
    bottom.DIRECTORY = 'build/operand-copy-metadata'
    bottom.MODULES = {'record_copy_metadata_lowering': None, 'record_metadata_edges': None, 'initializer_metadata_lowering': None,
                      'aggregate_copy_lowering': ['materialization_and_extraction_match_raw_failure_prefixes', 'child_staging_preserves_slots_delimiters_and_error_order', 'copy_rows_wait_for_metadata_and_emit_one_operation_per_step'],
                      'body_lowering': ['nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics']}
if '--destination-record-only' in sys.argv:
    sys.argv.remove('--destination-record-only')
    bottom.DIRECTORY = 'build/operand-destination-record'
    bottom.MODULES = {'destination_record_lowering': None}
if '--destination-place-only' in sys.argv:
    sys.argv.remove('--destination-place-only')
    bottom.DIRECTORY = 'build/operand-destination-place'
    bottom.MODULES = {'destination_record_lowering': None, 'destination_place_lowering': None,
                      'body_lowering': ['nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics']}
if '--declaration-name-only' in sys.argv:
    sys.argv.remove('--declaration-name-only')
    bottom.DIRECTORY = 'build/operand-declaration-name'
    bottom.MODULES = {'declaration_name_lowering': None}
if '--declaration-header-only' in sys.argv:
    sys.argv.remove('--declaration-header-only')
    bottom.DIRECTORY = 'build/operand-declaration-header'
    bottom.MODULES = {'declaration_name_lowering': None, 'declaration_header_lowering': None,
                      'semantic_lowering': ['annotated_bindings_publish_only_after_initializer_and_terminator'],
                      'body_lowering': ['nested_call_depth_32_and_33_preserve_default_stack_and_raw_diagnostics', 'annotated_semantics_keep_raw_ir_publication_and_diagnostics']}
if '--typed-probe-only' in sys.argv:
    sys.argv.remove('--typed-probe-only')
    bottom.DIRECTORY = 'build/operand-typed-probe'
    bottom.MODULES = {'value_probe_lowering': None}
if '--typed-walk-only' in sys.argv:
    sys.argv.remove('--typed-walk-only')
    bottom.DIRECTORY = 'build/operand-typed-walk'
    bottom.MODULES = {'value_walk_lowering': None, 'value_probe_lowering': None,
                      'value_source_control': ['admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
                      'value_bottom_source': ['nested_bottom_tails_and_else_if_suffixes_compose', 'all_terminal_loop_value_arms_retain_break_continue_and_outer_mutations'],
                      'value_source_loops_source': ['classic_for_headers_post_transfers_nested_loops_and_terminal_value_arms_execute']}
if '--typed-ownership-only' in sys.argv:
    sys.argv.remove('--typed-ownership-only')
    bottom.DIRECTORY = 'build/operand-typed-ownership'
    bottom.MODULES = {'value_ownership_lowering': None, 'value_source_bindings': ['whole_types_select_copy_or_move_including_inactive_buffer_and_verify_actual_ir', 'cleanup_is_reverse_live_only_and_capacity_rejection_is_atomic', 'alternatives_restore_entry_liveness_keep_distinct_slots_and_verify_exclusive_cfg_moves']}
if '--typed-evaluation-only' in sys.argv:
    sys.argv.remove('--typed-evaluation-only')
    bottom.DIRECTORY = 'build/operand-typed-evaluation'
    bottom.MODULES = {'value_evaluation_lowering': None, 'value_walk_lowering': None,
                      'value_ownership_lowering': None, 'value_source_control': ['admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
                      'value_bottom_source': ['operand_and_last_call_argument_bottom_skip_enclosing_work', 'short_circuit_bottom_keeps_skip_edge_and_never_replays_effects']}
if '--typed-call-evaluation-only' in sys.argv:
    sys.argv.remove('--typed-call-evaluation-only')
    bottom.DIRECTORY = 'build/operand-typed-call-evaluation'
    bottom.MODULES = {'value_call_lowering': None, 'value_evaluation_lowering': None, 'value_ownership_lowering': None,
                      'value_walk_lowering': ['typed_source_walks_preserve_raw_ir_catalogs_calls_scopes_and_owned_control', 'typed_source_walk_failures_keep_raw_partial_candidates_and_diagnostics', 'typed_calls_keep_depth_32_and_33_on_default_stack_and_match_raw_prefixes'],
                      'value_source_control': ['admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
                      'value_view_call_source': ['shared_formals_mix_with_owned_and_scalar_actuals_and_release_after_calls', 'returned_selected_ranges_forward_multiple_inputs_and_survive_caller_capture_cleanup', 'wrong_origin_mutable_local_escape_and_overlapping_owning_actuals_reject'],
                      'value_bottom_source': ['operand_and_last_call_argument_bottom_skip_enclosing_work', 'short_circuit_bottom_keeps_skip_edge_and_never_replays_effects']}
if '--typed-depth-only' in sys.argv:
    sys.argv.remove('--typed-depth-only')
    bottom.DIRECTORY = 'build/operand-typed-depth'
    bottom.MODULES = {'value_depth_probe': None}
if '--typed-properties-only' in sys.argv:
    sys.argv.remove('--typed-properties-only')
    bottom.DIRECTORY = 'build/operand-typed-properties'
    bottom.MODULES = {'value_source_properties': None, 'value_properties_work': None,
                      'value_walk_lowering': ['typed_source_walks_preserve_raw_ir_catalogs_calls_scopes_and_owned_control', 'typed_source_walk_failures_keep_raw_partial_candidates_and_diagnostics', 'typed_calls_keep_depth_32_and_33_on_default_stack_and_match_raw_prefixes'],
                      'value_view_call_source': ['returned_selected_ranges_forward_multiple_inputs_and_survive_caller_capture_cleanup'],
                      'value_source_bindings': ['whole_types_select_copy_or_move_including_inactive_buffer_and_verify_actual_ir'],
                      'value_bottom_source': ['short_circuit_bottom_keeps_skip_edge_and_never_replays_effects']}
if __name__ == '__main__':
    bottom.main()
