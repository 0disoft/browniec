"""Verify immutable-image Static execution and affected Program/IR/return behavior."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
FILES = [f'tests/m2/{name}.fy' for name in
         ['static_execution', 'static_ir', 'program_image', 'slice_scalar_entry', 'slice_result_call_execution', 'slice_result_call_ir']] + ['tests/core.fy', 'tests/functions.fy']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--shard', type=int, default=1, help='one-based native test shard')
    parser.add_argument('--shards', type=int, default=1, help='partition the complete selected identity set')
    parser.add_argument('--selection', choices=['all', 'statics', 'views', 'ranges', 'range-core', 'call-ir', 'call-proof', 'call-transfer-core', 'call-transfer', 'call-mixed', 'reference-access', 'reference-proof', 'reference-vm', 'reference-return-ir', 'reference-return-lifetimes', 'reference-receipts', 'reference-return-execution', 'reference-source', 'reference-return-source', 'public-program', 'source-snapshot', 'module-index', 'module-entry', 'source-context', 'module-program', 'module-program-core', 'module-retention', 'project-program-core', 'project-program', 'project-names', 'project-manifest', 'project-sources', 'captured-call-stack', 'local-inference', 'aggregate-inference', 'reference-inference', 'reference-inference-shadow', 'option-inference', 'array-list-storage', 'array-list-execution', 'array-list-source', 'array-list-contexts', 'array-list-replace-storage', 'array-list-replace-execution', 'array-list-assignment', 'array-literal-projections', 'array-expression-projections', 'record-expression-projections', 'if-expressions', 'aggregate-if-expressions', 'void-functions', 'aggregate-switch-expressions', 'constructor-join-inference', 'array-places', 'array-place-ir', 'array-place-storage', 'array-place-execution', 'array-place-cleanup', 'array-place-assignment', 'slice-places', 'slice-place-ir', 'slice-place-vm', 'slice-place-execution', 'slice-place-assignment', 'record-places', 'record-place-ir', 'record-place-vm', 'record-place-execution', 'record-place-assignment', 'scalar-assignment', 'place-syntax'], default='all',
                        help='statics runs the changed image/proof/VM suites; all adds return and source regressions')
    args = parser.parse_args()
    if not 1 <= args.shard <= args.shards <= 16:
        parser.error('require 1 <= shard <= shards <= 16')
    profile = args.profile
    selections = {'all': FILES + ['tests/m2/static_views.fy', 'tests/m2/static_ranges.fy', 'tests/m2/static_call_ir.fy', 'tests/m2/static_call_admission.fy', 'tests/m2/static_call_execution.fy', 'tests/m2/static_call_mixed.fy', 'tests/m2/reference_access.fy', 'tests/m2/reference_call_admission.fy', 'tests/m2/reference_words.fy', 'tests/m2/reference_call_execution.fy', 'tests/m2/reference_call_mixed.fy', 'tests/m2/reference_return_ir.fy', 'tests/m2/reference_return_lifetimes.fy', 'tests/m2/reference_receipts.fy', 'tests/m2/reference_return_execution.fy', 'tests/m2/reference_call_source.fy', 'tests/m2/reference_return_source.fy'],
                  'statics': FILES[:3], 'views': ['tests/m2/static_views.fy'],
                  'ranges': ['tests/m2/static_ranges.fy'] + FILES[:2],
                  'range-core': ['tests/m2/static_ranges.fy'],
                  'call-ir': ['tests/m2/static_call_ir.fy', FILES[2]],
                  'call-proof': ['tests/m2/static_call_admission.fy', 'tests/m2/static_ranges.fy', FILES[0], FILES[3]],
                  'call-transfer-core': ['tests/m2/static_call_execution.fy'],
                  'call-transfer': ['tests/m2/static_call_execution.fy', 'tests/m2/static_ranges.fy', FILES[3]],
                  'call-mixed': ['tests/m2/static_call_mixed.fy'],
                  'reference-access': ['tests/m2/reference_access.fy', FILES[0],
                                       'tests/m2/static_call_execution.fy',
                                       'tests/m2/static_call_mixed.fy', FILES[3]],
                  'reference-proof': ['tests/m2/reference_call_admission.fy',
                                      'tests/m2/static_call_admission.fy',
                                      'tests/m2/static_call_execution.fy'],
                  'reference-return-source': ['tests/m2/reference_return_source.fy',
                                              'tests/m2/reference_return_execution.fy',
                                              'tests/m2/reference_call_source.fy'],
                  'project-sources': ['tests/m2/project_sources.fy', 'tests/m2/project_manifest.fy', 'tests/m2/module_entry.fy', 'tests/m2/source_snapshot.fy'],
                  'project-manifest': ['tests/m2/json_tokens.fy', 'tests/m2/project_names.fy', 'tests/m2/project_manifest.fy'],
                  'project-names': ['tests/m2/json_tokens.fy', 'tests/m2/project_names.fy'],
                  'project-program-core': ['tests/m2/project_program.fy', 'tests/m2/project_sources.fy'],
                  'project-program': ['tests/m2/project_program.fy', 'tests/m2/project_sources.fy', 'tests/m2/module_index.fy', 'tests/m2/module_program.fy'],
                  'module-retention': ['tests/m2/module_index.fy', 'tests/m2/module_program.fy'],
                  'module-program-core': ['tests/m2/module_program.fy', 'tests/m2/struct_metadata.fy'],
                  'module-program': ['tests/m2/module_program.fy', 'tests/m2/public_program.fy', 'tests/m2/struct_call_assignment.fy', 'tests/m2/struct_child_call_paths.fy', 'tests/m2/struct_metadata.fy'],
                  'source-context': ['tests/m2/source_context.fy', 'tests/m2/module_entry.fy', 'tests/functions.fy', 'tests/lexer_compatibility.fy'],
                  'module-entry': ['tests/m2/module_entry.fy', 'tests/m2/module_index.fy', 'tests/m2/source_snapshot.fy'],
                  'module-index': ['tests/m2/module_index.fy', 'tests/m2/source_snapshot.fy'],
                  'source-snapshot': ['tests/m2/source_snapshot.fy'],
                  'public-program': ['tests/m2/public_program.fy', 'tests/m2/reference_return_source.fy',
                                     'tests/m2/static_bindings_source.fy'],
                  'reference-source': ['tests/m2/reference_call_source.fy', 'tests/m2/static_bindings_source.fy',
                                       'tests/m2/reference_call_mixed.fy'],
                  'reference-return-execution': ['tests/m2/reference_return_execution.fy',
                                                 'tests/m2/reference_receipts.fy',
                                                 'tests/m2/reference_call_execution.fy'],
                  'reference-receipts': ['tests/m2/reference_receipts.fy', 'tests/m2/reference_words.fy',
                                         'tests/m2/slice_result_bindings.fy', 'tests/m2/reference_call_execution.fy'],
                  'reference-return-lifetimes': ['tests/m2/reference_return_lifetimes.fy',
                                                 'tests/m2/reference_return_ir.fy',
                                                 'tests/m2/reference_call_execution.fy'],
                  'reference-return-ir': ['tests/m2/reference_return_ir.fy',
                                          'tests/m2/reference_call_admission.fy',
                                          'tests/m2/static_call_execution.fy'],
                  'reference-vm': ['tests/m2/reference_call_execution.fy',
                                   'tests/m2/reference_words.fy', 'tests/m2/reference_call_mixed.fy',
                                   'tests/m2/static_call_execution.fy', FILES[3]]}
    selections['captured-call-stack'] = ['tests/m2/captured_call_stack.fy', 'tests/m2/array_literal_arguments.fy',
                                         'tests/m2/struct_constructor_arguments.fy', 'tests/m2/module_program.fy']
    selections['local-inference'] = ['tests/m2/local_inference.fy', 'tests/functions.fy',
                                     'tests/loops.fy', 'tests/m2/module_program.fy']
    selections['aggregate-inference'] = ['tests/m2/aggregate_inference.fy', 'tests/m2/local_inference.fy',
                                         'tests/m2/module_program.fy', 'tests/m2/array_scopes.fy']
    selections['reference-inference'] = ['tests/m2/reference_inference.fy', 'tests/m2/local_inference.fy',
                                         'tests/m2/aggregate_inference.fy', 'tests/m2/static_bindings_source.fy',
                                         'tests/m2/reference_return_source.fy', 'tests/m2/module_program.fy']
    selections['reference-inference-shadow'] = ['tests/m2/reference_inference_shadow.fy']
    selections['option-inference'] = ['tests/m2/option_constructor_inference.fy', 'tests/tagged.fy', 'tests/m2/local_inference.fy']
    selections['array-list-storage'] = ['tests/m2/array_list_storage.fy', 'tests/m2/array_storage.fy', 'tests/m2/array_owners.fy']
    selections['array-list-execution'] = ['tests/m2/array_list_execution.fy', 'tests/m2/array_vm.fy', 'tests/m2/module_program.fy']
    selections['array-list-source'] = ['tests/m2/array_list_source.fy', 'tests/m2/aggregate_inference.fy', 'tests/m2/array_list_execution.fy', 'tests/m2/module_program.fy']
    selections['array-list-contexts'] = ['tests/m2/array_list_contexts.fy', 'tests/m2/array_list_source.fy',
                                         'tests/m2/array_literal_arguments.fy', 'tests/m2/array_return_literals.fy',
                                         'tests/m2/slice_temporary_arguments.fy', 'tests/m2/module_program.fy']
    selections['array-list-replace-storage'] = ['tests/m2/array_list_replace_storage.fy',
                                                'tests/m2/array_list_storage.fy', 'tests/m2/array_list_execution.fy']
    selections['array-list-replace-execution'] = ['tests/m2/array_list_replace_execution.fy',
        'tests/m2/array_list_replace_storage.fy', 'tests/m2/array_list_execution.fy',
        'tests/m2/reference_return_lifetimes.fy']
    selections['array-list-assignment'] = ['tests/m2/array_list_assignment.fy', 'tests/m2/module_program.fy',
        'tests/m2/array_list_source.fy', 'tests/m2/array_list_contexts.fy', 'tests/m2/array_list_replace_execution.fy']
    selections['array-literal-projections'] = ['tests/m2/array_literal_projections.fy', 'tests/m2/module_program.fy',
        'tests/m2/array_list_assignment.fy', 'tests/m2/array_list_source.fy', 'tests/m2/array_list_contexts.fy',
        'tests/m2/array_utf8_literals.fy', 'tests/m2/array_utf8_temporary_computed_ranges.fy']
    selections['array-expression-projections'] = ['tests/m2/array_expression_projections.fy', 'tests/m2/array_literal_projections.fy', 'tests/m2/captured_call_stack.fy', 'tests/m2/module_program.fy']
    selections['record-expression-projections'] = ['tests/m2/record_expression_projections.fy', 'tests/m2/module_program.fy', 'tests/m2/captured_call_stack.fy', 'tests/m2/struct_constructor_arguments.fy', 'tests/m2/struct_return_constructors.fy', 'tests/m2/struct_call_assignment.fy', 'tests/m2/struct_call_path_arguments.fy']
    selections['if-expressions'] = ['tests/m2/if_expressions.fy', 'tests/switch_arm_statements.fy', 'tests/m2/module_program.fy', 'tests/m2/local_inference.fy']
    selections['aggregate-if-expressions'] = ['tests/m2/aggregate_if_expressions.fy', 'tests/m2/value_joins.fy', 'tests/m2/if_expressions.fy', 'tests/m2/module_program.fy', 'tests/m2/local_inference.fy', 'tests/m2/captured_call_stack.fy', 'tests/m2/record_expression_projections.fy']
    selections['void-functions'] = ['tests/m2/void_source.fy', 'tests/m2/void_execution.fy', 'tests/m2/module_program.fy', 'tests/m2/local_inference.fy', 'tests/m2/captured_call_stack.fy', 'tests/m2/if_expressions.fy', 'tests/m2/aggregate_if_expressions.fy']
    selections['aggregate-switch-expressions'] = ['tests/m2/aggregate_switch_expressions.fy', 'tests/m2/aggregate_if_expressions.fy', 'tests/switch_arm_statements.fy', 'tests/m2/value_joins.fy', 'tests/m2/module_program.fy', 'tests/m2/local_inference.fy', 'tests/m2/captured_call_stack.fy', 'tests/m2/void_source.fy']
    selections['constructor-join-inference'] = ['tests/m2/constructor_joins.fy', 'tests/m2/constructor_join_source.fy', 'tests/m2/option_constructor_inference.fy', 'tests/tagged.fy', 'tests/m2/if_expressions.fy', 'tests/switch_arm_statements.fy', 'tests/m2/aggregate_switch_expressions.fy', 'tests/m2/module_program.fy', 'tests/m2/local_inference.fy', 'tests/m2/captured_call_stack.fy']
    selections['array-places'] = ['tests/m2/array_places.fy', 'tests/m2/array_owners.fy',
                                 'tests/m2/array_storage.fy', 'tests/m2/array_layout.fy']
    selections['array-place-ir'] = ['tests/m2/place_ir.fy', 'tests/m2/array_ir.fy', 'tests/m2/void_execution.fy']
    selections['array-place-storage'] = ['tests/m2/place_vm.fy', 'tests/m2/array_places.fy']
    selections['array-place-execution'] = ['tests/m2/place_execution.fy', 'tests/m2/place_ir.fy', 'tests/m2/reference_return_lifetimes.fy', 'tests/m2/slice_result_call_ir.fy', 'tests/m2/void_execution.fy', 'tests/m2/captured_call_stack.fy']
    selections['array-place-cleanup'] = ['tests/m2/place_cleanup.fy', 'tests/m2/place_execution.fy', 'tests/m2/array_write.fy', 'tests/m2/void_execution.fy', 'tests/m2/captured_call_stack.fy', 'tests/switch_arm_statements.fy']
    selections['array-place-assignment'] = ['tests/m2/place_assignment.fy', 'tests/m2/array_write.fy', 'tests/m2/place_cleanup.fy', 'tests/m2/place_execution.fy', 'tests/m2/void_execution.fy', 'tests/m2/captured_call_stack.fy', 'tests/switch_arm_statements.fy', 'tests/m2/module_program.fy']
    selections['slice-places'] = ['tests/m2/slice_places.fy', 'tests/m2/slice_reborrow.fy',
                                  'tests/m2/slice_handoff.fy']
    selections['slice-place-ir'] = ['tests/m2/slice_place_ir.fy', 'tests/m2/place_ir.fy',
                                    'tests/m2/place_vm.fy', 'tests/m2/place_assignment.fy',
                                    'tests/m2/captured_call_stack.fy']
    selections['slice-place-vm'] = ['tests/m2/slice_place_vm.fy', 'tests/m2/place_vm.fy',
                                    'tests/m2/slice_places.fy', 'tests/m2/slice_reborrow.fy',
                                    'tests/m2/slice_handoff.fy']
    selections['slice-place-execution'] = ['tests/m2/slice_place_execution.fy', 'tests/m2/slice_place_ir.fy',
        'tests/m2/place_execution.fy', 'tests/m2/reference_return_lifetimes.fy', 'tests/m2/captured_call_stack.fy']
    selections['slice-place-assignment'] = ['tests/m2/slice_place_assignment.fy', 'tests/m2/place_assignment.fy',
        'tests/m2/slice_exclusive_source.fy', 'tests/m2/slice_mutable_parameters_source.fy',
        'tests/m2/slice_reborrow_source.fy', 'tests/m2/public_fuel.fy', 'tests/m2/captured_call_stack.fy']
    selections['record-places'] = ['tests/m2/record_places.fy', 'tests/m2/struct_owners.fy',
        'tests/m2/struct_nested_storage.fy', 'tests/m2/array_places.fy']
    selections['record-place-ir'] = ['tests/m2/record_place_ir.fy', 'tests/m2/place_ir.fy',
        'tests/m2/slice_place_ir.fy', 'tests/m2/captured_call_stack.fy']
    selections['record-place-vm'] = ['tests/m2/record_place_vm.fy', 'tests/m2/place_vm.fy',
        'tests/m2/slice_place_vm.fy', 'tests/m2/record_place_ir.fy', 'tests/m2/captured_call_stack.fy']
    selections['record-place-execution'] = ['tests/m2/record_place_execution.fy', 'tests/m2/record_place_ir.fy',
        'tests/m2/record_place_vm.fy', 'tests/m2/slice_place_execution.fy',
        'tests/m2/reference_return_lifetimes.fy', 'tests/m2/captured_call_stack.fy']
    selections['record-place-assignment'] = ['tests/m2/record_place_assignment.fy', 'tests/m2/struct_write.fy',
        'tests/m2/record_place_execution.fy', 'tests/m2/place_assignment.fy',
        'tests/m2/slice_place_assignment.fy', 'tests/m2/module_program.fy', 'tests/m2/captured_call_stack.fy']
    selections['scalar-assignment'] = ['tests/m2/scalar_assignment.fy', 'tests/core.fy', 'tests/loops.fy',
        'tests/m2/captured_call_stack.fy', 'tests/m2/record_place_assignment.fy']
    selections['place-syntax'] = ['tests/m2/place_syntax.fy']
    files = selections[args.selection]
    out = ROOT / 'build/static-execution' / profile / args.selection
    if args.shards != 1:
        out = out / f'shard-{args.shard}-of-{args.shards}'
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / 'receipt.json'
    write(receipt, {'status': 'incomplete'})
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_hash = digest(compiler)
    assert compiler_hash == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    production = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy'))
    assert all(b'\r' not in (ROOT / p).read_bytes() for p in production)
    paths = sorted(production + files + ['fairy.toml', 'fairy.lock', 'toolchain.json',
                                       'tools/verify-static-execution.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]

    def discovery():
        tree = [(p.relative_to(ROOT).as_posix(), digest(p)) for p in sorted((ROOT / 'tests').rglob('*.fy'))]
        value = hashlib.sha256(''.join(p + ' ' + h + '\n' for p, h in tree).encode()).hexdigest()
        return dict(count=len(tree), sha256=value)

    tree = discovery()
    captured = datetime.now(timezone.utc).isoformat()

    def run(command, cwd=ROOT):
        result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True,
                                text=True, encoding='utf-8', timeout=1200)
        if result.returncode:
            raise RuntimeError(f'{command}\n{result.stdout[-8000:]}\n{result.stderr[-3000:]}')
        return result

    starting_head = run(['git', 'rev-parse', 'HEAD']).stdout.strip()
    mirror = out / 'lf-workspace'
    for path in production + ['fairy.toml', 'fairy.lock']:
        destination = mirror / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes((ROOT / path).read_bytes())
    checked = run([compiler, 'check', '--locked'], mirror).stdout.strip()
    command = [compiler.relative_to(ROOT).as_posix(), 'test', '--native',
               '--capture-output', '--json', '--locked']
    if profile == 'release':
        command.append('--release')
    expected = set()
    focused = {
        'static_execution': {'static_fuel_matches_driver_added_prices_exactly',
                             'static_read_42_widens_to_i32_without_guest_backing',
                             'static_site_zero_coexists_with_mutable_guest_slice_and_helper_frame',
                             'bounds_failure_preserves_image_and_zero_backing_for_valid_retry'},
        'static_call_execution': {'retained_calls_execute_narrowed_bytes_and_exact_text_at_exact_fuel',
                                  'short_entry_call_and_return_budgets_abort_and_retained_code_cannot_be_rewritten',
                                  'static_calls_copy_and_drop_owned_array_arguments_through_canonical_ownership',
                                  'all_eight_actuals_scalar_prefixes_and_recursive_actual_words_use_separate_frames'},
        'static_call_mixed': {'static_arguments_coexist_with_record_values_and_owned_array_and_record_results',
                              'static_arguments_coexist_with_shared_and_exclusive_runtime_loans'},
        'slice_scalar_entry': {'ordinary_entries_execute_nested_scalar_array_and_record_calls',
                               'successful_scalar_return_restores_retained_inputs_or_closes_and_drops',
                               'exact_terminal_budget_and_failures_preserve_first_errors_and_prior_writes'},
    }
    if args.selection in ('reference-proof', 'reference-return-ir'):
        focused = {'static_call_execution': {
            'retained_calls_execute_narrowed_bytes_and_exact_text_at_exact_fuel',
            'short_entry_call_and_return_budgets_abort_and_retained_code_cannot_be_rewritten'}}
    if args.selection == 'reference-vm':
        focused = {
            'static_call_execution': {'retained_calls_execute_narrowed_bytes_and_exact_text_at_exact_fuel',
                                      'short_entry_call_and_return_budgets_abort_and_retained_code_cannot_be_rewritten'},
            'slice_scalar_entry': {'ordinary_entries_execute_nested_scalar_array_and_record_calls',
                                   'successful_scalar_return_restores_retained_inputs_or_closes_and_drops'}}
    if args.selection in ('reference-return-lifetimes', 'reference-return-execution'):
        focused = {'reference_call_execution': {
            'the_same_formal_executes_image_and_runtime_bytes_at_exact_fuel',
            'aliases_and_narrowed_ranges_survive_logical_parent_close_and_forwarding'}}
    if args.selection == 'reference-receipts':
        focused = {
            'slice_result_bindings': {'mutable_result_close_publishes_the_fresh_parent_binding',
                                      'terminal_forward_consumes_held_bindings_after_canonical_handoff',
                                      'seventeen_nested_receipts_share_one_slot_without_losing_outer_generations',
                                      'failed_final_root_drop_preserves_the_live_binding_and_runtime'},
            'reference_call_execution': {'the_same_formal_executes_image_and_runtime_bytes_at_exact_fuel',
                                         'aliases_and_narrowed_ranges_survive_logical_parent_close_and_forwarding'}}
    if args.selection == 'reference-return-source':
        focused = {'reference_call_source': {'image_and_runtime_values_keep_distinct_backings',
                                            'arguments_and_endpoints_evaluate_left_to_right_with_early_exit_cleanup'}}
    if args.selection == 'public-program':
        focused = {'static_bindings_source': {
            'byte_and_text_locals_aliases_and_explicit_conversion_preserve_kinds',
            'aggregate_returns_close_static_locals_and_existing_runtime_slices_stay_distinct'}}
    if args.selection == 'reference-inference':
        focused = {
            'static_bindings_source': {'byte_and_text_locals_aliases_and_explicit_conversion_preserve_kinds',
                                      'aggregate_returns_close_static_locals_and_existing_runtime_slices_stay_distinct'},
            'reference_return_source': {'returned_aliases_narrowed_and_empty_windows_support_read_and_length',
                                        'agreeing_branches_forwarding_and_grounded_recursion_reject_conflicts_and_cycles',
                                        'selected_temporaries_cleanup_across_return_propagation_break_continue_and_later_arguments'},
            'module_program': {'inferred_reference_aliases_and_return_origins_keep_qualified_resolution',
                               'shared_byte_returns_literals_ranges_and_text_cross_real_module_calls',
                               'both_compiler_routes_keep_the_32_deep_call_limit_without_native_stack_overrides'}}
    if args.selection == 'option-inference':
        focused = {
            'tagged': {'wrapper_types_copies_and_calls', 'guarded_case_initialization_fuel_and_failure'},
            'local_inference': {'complete_tagged_expression_types_survive_inference_and_reassignment'}}
    if args.selection == 'array-list-storage':
        focused = {
            'array_storage': {'alignment_is_zeroed_and_failed_initialization_rolls_back'},
            'array_owners': {'quota_value_and_owner_pressure_fail_without_publication'}}
    if args.selection == 'array-list-execution':
        focused = {
            'array_vm': {'exact_fuel_bounds_quota_and_fresh_program_reuse', 'metered_loop_recreation_reuses_owners_until_fuel_exhaustion'},
            'module_program': {'both_compiler_routes_keep_the_32_deep_call_limit_without_native_stack_overrides'}}
    if args.selection == 'array-list-source':
        focused = {
            'aggregate_inference': {'aggregate_calls_and_repeated_fillers_evaluate_once_in_source_order',
                                    'early_initializer_exits_do_not_publish_pending_array_or_record_owners'},
            'array_list_execution': {'six_scalar_domains_execute_at_independently_computed_exact_fuel'},
            'module_program': {'both_compiler_routes_keep_the_32_deep_call_limit_without_native_stack_overrides'}}
    if args.selection == 'array-list-contexts':
        focused = {
            'array_list_source': {'source_list_ir_has_one_complete_pool_span_and_exact_independent_fuel',
                                  'lists_keep_existing_source_register_and_32_deep_call_limits'},
            'array_literal_arguments': {'pending_and_prior_captures_cleanup_on_early_exits'},
            'array_return_literals': {'literals_mix_with_named_and_direct_returns_at_existing_fuel_and_frame_limits'},
            'slice_temporary_arguments': {'early_exits_release_only_published_owners_and_views'},
            'module_program': {'both_compiler_routes_keep_the_32_deep_call_limit_without_native_stack_overrides',
                               'scalar_element_lists_cross_qualified_calls_and_owned_results'}}
    if args.selection == 'array-list-replace-storage':
        focused = {'array_list_execution': {'six_scalar_domains_execute_at_independently_computed_exact_fuel'}}
    if args.selection == 'array-list-replace-execution':
        focused = {
            'array_list_replace_storage': {'replacements_preserve_six_domains_owner_identity_padding_and_neighbors',
                'replacement_succeeds_at_full_quota_and_all_sixteen_owner_slots_without_reallocation'},
            'array_list_execution': {'six_scalar_domains_execute_at_independently_computed_exact_fuel',
                'instruction_shortage_bad_cells_and_quota_do_not_publish_or_allocate_again',
                'retained_coordinator_uses_exact_setup_prices_and_keeps_its_separate_dispatch'},
            'reference_return_lifetimes': {'writes_fill_and_assignment_reject_at_the_exact_effect_while_result_is_live',
                'last_close_allows_mutation_and_an_unrelated_owner_remains_writable'}}
    if args.selection == 'array-list-assignment':
        focused = {
            'module_program': {'scalar_list_replacements_cross_qualified_calls_with_existing_destinations'},
            'array_list_source': {'annotated_and_inferred_lists_preserve_all_six_exact_scalar_domains',
                'lookahead_ignores_nested_separators_literals_and_comments_without_evaluation',
                'lists_keep_existing_source_register_and_32_deep_call_limits'},
            'array_list_contexts': {'literal_contexts_match_named_ir_and_independent_exact_fuel',
                'borrow_endpoints_and_following_arguments_preserve_nonlocal_exit_cleanup'},
            'array_list_replace_execution': {'retained_replacement_prepays_setup_and_existing_owner_work_at_exact_fuel'}}
    if args.selection == 'array-literal-projections':
        focused = {
            'module_program': {'array_literal_projections_execute_across_both_qualified_compiler_routes'},
            'array_list_assignment': {'nonlocal_exits_preserve_unreplaced_values_rhs_effects_and_outer_owners'},
            'array_list_source': {'lists_keep_existing_source_register_and_32_deep_call_limits'},
            'array_list_contexts': {'literal_contexts_match_named_ir_and_independent_exact_fuel'},
            'array_utf8_literals': {'immediate_cleanup_and_exact_fuel_match_a_named_array'},
            'array_utf8_temporary_computed_ranges': {'endpoint_exits_drop_published_temporaries_in_reverse_order'}}
    if args.selection == 'array-expression-projections':
        focused = {
            'array_literal_projections': {'cells_fillers_lengths_and_indices_preserve_once_only_order_and_short_circuiting',
                'completed_temporaries_join_return_propagation_and_loop_exit_cleanup',
                'immediate_projection_costs_match_independent_ordinary_and_retained_oracles'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'leading_immutable_array_arguments_keep_the_same_depth_boundary'},
            'module_program': {'grouped_array_values_and_projections_cross_both_qualified_compiler_routes'}}
    if args.selection == 'record-expression-projections':
        focused = {
            'module_program': {'grouped_record_values_and_projections_cross_both_qualified_compiler_routes'},
            'captured_call_stack': {'immutable_record_arguments_keep_the_same_depth_boundary_in_both_positions',
                'actual_captures_still_obey_the_original_owner_catalog_capacity'},
            'struct_constructor_arguments': {'field_order_child_calls_and_mixed_argument_effects',
                'pending_constructor_and_prior_captures_cleanup_on_early_exits'},
            'struct_return_constructors': {'early_returns_and_loop_transfers_never_publish_or_drop_a_pending_constructor',
                'constructor_and_named_returns_emit_identical_instructions_and_keep_payload_bounds'},
            'struct_call_assignment': {'old_values_remain_visible_and_mutable_mixed_arguments_capture_left_to_right',
                'early_scalar_record_and_propagated_returns_keep_the_pending_result_dead'},
            'struct_call_path_arguments': {'early_exits_loop_reuse_and_drop_before_creation'}}
    if args.selection == 'if-expressions':
        focused = {
            'switch_arm_statements': {'branches_blocks_and_terminal_arms',
                'conditional_join_initialization_and_exact_fuel', 'while_condition_owns_transfers_and_propagation'},
            'module_program': {'conditional_values_cross_both_qualified_compiler_routes'},
            'local_inference': {'inferred_initializers_keep_32_deep_captured_calls_without_native_stack_overrides'}}
    if args.selection == 'aggregate-if-expressions':
        focused = {
            'record_expression_projections': {'grouping_preserves_instruction_bytes_owner_counts_and_exact_backing'},
            'module_program': {'conditional_values_cross_both_qualified_compiler_routes', 'aggregate_conditionals_cross_both_qualified_compiler_routes'},
            'local_inference': {'inferred_initializers_keep_32_deep_captured_calls_without_native_stack_overrides'},
            'captured_call_stack': {'leading_immutable_array_arguments_keep_the_same_depth_boundary', 'immutable_record_arguments_keep_the_same_depth_boundary_in_both_positions'}}
    if args.selection == 'void-functions':
        focused = {
            'module_program': {'void_statements_cross_both_qualified_compiler_routes'},
            'local_inference': {'inferred_initializers_keep_32_deep_captured_calls_without_native_stack_overrides'},
            'captured_call_stack': {'immutable_record_arguments_keep_the_same_depth_boundary_in_both_positions'},
            'if_expressions': {'nested_tail_conditionals_coexist_with_statement_blocks_loops_and_else_if',
                'return_propagation_and_loop_transfers_preserve_capture_and_owner_cleanup'},
            'aggregate_if_expressions': {'branches_and_nested_tails_initialize_one_site_at_exact_backing',
                'return_propagation_break_and_continue_close_only_published_values'}}
    if args.selection == 'aggregate-switch-expressions':
        focused = {
            'aggregate_if_expressions': {'branches_and_nested_tails_initialize_one_site_at_exact_backing',
                'return_propagation_break_and_continue_close_only_published_values'},
            'module_program': {'aggregate_switch_values_cross_both_qualified_compiler_routes'},
            'local_inference': {'inferred_initializers_keep_32_deep_captured_calls_without_native_stack_overrides'},
            'captured_call_stack': {'leading_immutable_array_arguments_keep_the_same_depth_boundary',
                'immutable_record_arguments_keep_the_same_depth_boundary_in_both_positions'},
            'void_source': {'call_statements_precede_if_and_switch_value_tails_without_becoming_values'}}
    if args.selection == 'constructor-join-inference':
        focused = {
            'tagged': {'wrapper_types_copies_and_calls'},
            'if_expressions': {'inferred_typed_tagged_and_all_scalar_domains_compose_with_operators_and_calls'},
            'switch_arm_statements': {'conditional_join_initialization_and_exact_fuel'},
            'aggregate_switch_expressions': {'mixed_if_switch_tails_share_destinations_in_both_drivers'},
            'module_program': {'constructor_join_constraints_cross_both_qualified_compiler_routes'},
            'local_inference': {'inferred_initializers_keep_32_deep_captured_calls_without_native_stack_overrides'},
            'captured_call_stack': {'immutable_record_arguments_keep_the_same_depth_boundary_in_both_positions'}}
    if args.selection == 'array-place-execution':
        focused = {
            'reference_return_lifetimes': {'selected_places_respect_returned_owner_protection_at_select_read_and_store',
                'writes_fill_and_assignment_reject_at_the_exact_effect_while_result_is_live',
                'aliases_and_ranges_keep_the_owner_until_every_returned_view_is_closed'},
            'slice_result_call_ir': {'bindings_prove_shared_and_exclusive_six_scalar_types',
                'opaque_call_id_cannot_be_observed_as_a_scalar',
                'opaque_result_selectors_cannot_become_place_indices_or_store_values'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    if args.selection in ('array-place-cleanup', 'array-place-assignment'):
        focused = {
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33',
                'leading_immutable_array_arguments_keep_the_same_depth_boundary',
                'immutable_record_arguments_keep_the_same_depth_boundary_in_both_positions'},
            'switch_arm_statements': {'outer_loop_transfers_skip_pending_expression_work',
                'while_condition_owns_transfers_and_propagation'}}
    if args.selection == 'array-place-assignment':
        focused['module_program'] = {'selected_array_assignments_cross_both_qualified_compiler_routes'}
    if args.selection == 'slice-places':
        focused = {
            'slice_reborrow': {'six_scalar_subranges_write_relative_elements_and_restore_only_fresh_parent_tickets',
                'restore_authenticates_the_selected_range_session_and_latest_nested_ticket_atomically'},
            'slice_handoff': {'six_scalar_ranges_transfer_actual_writes_and_return_only_fresh_caller_tickets',
                'restore_checks_every_receipt_before_publication_and_accepts_fresh_nested_returns'}}
    if args.selection == 'slice-place-ir':
        focused = {
            'place_vm': {'six_scalar_domains_match_independent_prices_and_preflight_each_effect',
                'corrupt_snapshot_phase_shape_and_vector_extent_fail_before_payload'},
            'place_assignment': {'index_and_old_scalar_are_captured_once_before_rhs_mutations_and_calls',
                'propagation_and_all_return_kinds_close_pending_places_before_handoff',
                'plain_and_compound_source_have_independent_exact_fuel_boundaries'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    if args.selection == 'slice-place-vm':
        focused = {
            'slice_places': {'completed_call_and_lexical_rotations_accept_current_full_views',
                'full_owner_pool_and_backing_need_no_extra_slot_or_reservation'},
            'slice_reborrow': {'six_scalar_subranges_write_relative_elements_and_restore_only_fresh_parent_tickets',
                'restore_authenticates_the_selected_range_session_and_latest_nested_ticket_atomically'},
            'slice_handoff': {'six_scalar_ranges_transfer_actual_writes_and_return_only_fresh_caller_tickets',
                'restore_checks_every_receipt_before_publication_and_accepts_fresh_nested_returns'}}
    if args.selection == 'slice-place-execution':
        focused = {
            'reference_return_lifetimes': {'selected_places_respect_returned_owner_protection_at_select_read_and_store'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    if args.selection == 'slice-place-assignment':
        focused = {
            'place_assignment': {'index_and_old_scalar_are_captured_once_before_rhs_mutations_and_calls',
                'propagation_and_all_return_kinds_close_pending_places_before_handoff',
                'plain_and_compound_source_have_independent_exact_fuel_boundaries'},
            'slice_exclusive_source': {'six_scalar_tags_whole_computed_open_and_empty_ranges_lower_to_owned_exclusive_sites',
                'endpoints_and_store_operands_run_once_in_order_with_no_extra_owner_or_scalar_store'},
            'slice_mutable_parameters_source': {'source_errors_abort_all_receipts_and_preserve_prior_payload_writes'},
            'slice_reborrow_source': {'computed_bounds_evaluate_once_and_exit_before_child_publication'},
            'public_fuel': {'eight_writer_call_is_executable_under_the_public_ceiling',
                'rooted_shared_and_exclusive_operations_keep_their_exact_prices'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    if args.selection in ('record-place-ir', 'record-place-vm', 'record-place-execution', 'record-place-assignment'):
        focused = {'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
            'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    if args.selection == 'record-place-execution':
        focused = {
            'record_place_vm': {'six_scalar_domains_prepay_each_effect_at_independent_exact_prices',
                'maximum_depth_leaves_and_full_owner_backing_capacity_keep_constant_prices'},
            'reference_return_lifetimes': {'selected_places_respect_returned_owner_protection_at_select_read_and_store'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    if args.selection == 'record-place-assignment':
        focused = {
            'record_place_execution': {'ordinary_and_retained_record_compounds_match_independent_exact_fuel',
                'caller_and_callee_share_place_ids_without_losing_original_record_tokens',
                'post_store_fuel_abort_preserves_payload_drains_owners_and_allows_explicit_retry'},
            'place_assignment': {'index_and_old_scalar_are_captured_once_before_rhs_mutations_and_calls',
                'propagation_and_all_return_kinds_close_pending_places_before_handoff'},
            'slice_place_assignment': {'slice_source_ir_and_independent_exact_fuel_cover_plain_and_compound'},
            'module_program': {'selected_record_fields_and_compounds_cross_qualified_modules'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    if args.selection == 'scalar-assignment':
        focused = {
            'core': {'local_values_and_assignments', 'local_traps_fuel_and_reuse'},
            'loops': {'classic_for_order_and_scope', 'classic_for_fuel_and_failures'},
            'record_place_assignment': {'selected_source_ir_and_independent_plain_compound_fuel_are_exact'},
            'captured_call_stack': {'captured_calls_keep_the_32_deep_limit_and_reject_33',
                'retained_captured_calls_keep_the_32_deep_limit_and_reject_33'}}
    exact = args.selection in ('array-list-replace-storage', 'array-list-contexts', 'array-list-source', 'option-inference', 'array-list-storage', 'array-list-execution') or args.selection in ('reference-access', 'reference-proof', 'reference-vm', 'reference-return-ir', 'reference-return-lifetimes', 'reference-receipts', 'reference-return-execution', 'reference-source', 'reference-return-source', 'public-program', 'reference-inference')
    exact = exact or args.selection in ('array-place-execution', 'array-place-cleanup', 'array-place-assignment', 'slice-places', 'slice-place-ir', 'slice-place-vm', 'slice-place-execution', 'slice-place-assignment', 'record-places', 'record-place-ir', 'record-place-vm', 'record-place-execution', 'record-place-assignment', 'scalar-assignment')
    exact = exact or args.selection in ('record-expression-projections', 'if-expressions', 'aggregate-if-expressions', 'void-functions', 'aggregate-switch-expressions', 'constructor-join-inference')
    exact = exact or args.selection in ('array-list-replace-execution', 'array-list-assignment', 'array-literal-projections', 'array-expression-projections')
    for path in files:
        if not exact and args.shards == 1:
            command.extend(['--file', path])
        source = (ROOT / path).read_text(encoding='utf-8')
        names = re.findall(r'@test\s+fn void (\w+)\(', source)
        if exact and Path(path).stem in focused:
            selected = focused[Path(path).stem]
            assert selected <= set(names)
            names = [name for name in names if name in selected]
        module = re.search(r'\bmodule\s+([\w:]+);', source).group(1)
        expected.update(module + '::' + name for name in names)
    complete = sorted(expected)
    if args.shards > len(complete):
        parser.error('shards must not exceed selected tests')
    if exact:
        assert len(expected) == (13 if args.selection == 'scalar-assignment' else 21 if args.selection == 'record-place-assignment' else 27 if args.selection == 'record-place-execution' else 34 if args.selection == 'record-place-vm' else 28 if args.selection == 'record-place-ir' else 28 if args.selection == 'record-places' else 17 if args.selection == 'slice-place-assignment' else 22 if args.selection == 'slice-place-execution' else 20 if args.selection == 'slice-place-vm' else 24 if args.selection == 'slice-place-ir' else 13 if args.selection == 'slice-places' else 30 if args.selection == 'array-place-assignment' else 21 if args.selection == 'array-place-cleanup' else 23 if args.selection == 'array-place-execution' else 18 if args.selection == 'constructor-join-inference' else 24 if args.selection == 'aggregate-switch-expressions' else 17 if args.selection == 'void-functions' else 21 if args.selection == 'aggregate-if-expressions' else 11 if args.selection == 'if-expressions' else 17 if args.selection == 'record-expression-projections' else 14 if args.selection in ('array-list-assignment', 'array-literal-projections', 'array-expression-projections') else 13 if args.selection == 'array-list-replace-execution' else 10 if args.selection == 'array-list-replace-storage' else 14 if args.selection == 'array-list-contexts' else 13 if args.selection == 'array-list-source' else 9 if args.selection == 'array-list-execution' else 5 if args.selection in ('option-inference', 'array-list-storage') else 36 if args.selection == 'reference-inference' else 18)
    if args.shards != 1:
        expected = set(complete[args.shard - 1::args.shards])
    if exact or args.shards != 1:
        for identity in sorted(expected):
            command.extend(['--exact', identity])
    result = run(command)
    (out / 'native.json').write_text(result.stdout, encoding='utf-8', newline='\n')
    (out / 'native-stderr.txt').write_text(result.stderr, encoding='utf-8', newline='\n')
    report = json.loads(result.stdout)
    assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
    assert report['status'] == 'ok' and report['profile'] == profile and report['lock'] == 'verified'
    assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
    assert {t['identity'] for t in report['tests']} == expected
    assert all(t['outcome'] == 'passed' and t['trapCategory'] is None and
               not t['stdoutBase64'] and not t['stderrBase64'] for t in report['tests'])
    assert all(digest(ROOT / i['path']) == i['sha256'] for i in inputs)
    assert discovery() == tree and digest(compiler) == compiler_hash
    write(receipt, dict(schema='browniec.static-execution-verification/v1', status='passed',
                       profile=profile, selection=args.selection, startingHead=starting_head,
                       platform=platform.platform(), compilerSha256=compiler_hash,
                       compilerVersion=run([compiler, '--version']).stdout.strip(),
                       inputSnapshotCapturedAt=captured, inputs=inputs, testDiscovery=tree,
                       partition=dict(shard=args.shard, shards=args.shards, completeIdentities=complete),
                       lfMirror=dict(command=['build/toolchain/fairyc.exe' if os.name == 'nt' else 'build/toolchain/fairyc', 'check', '--locked'],
                                     workingDirectory=mirror.relative_to(ROOT).as_posix(),
                                     productionFiles=len(production), result=checked),
                       command=command, nativeGroups=len(expected), report=report,
                       nativeReportSha256=digest(out / 'native.json'),
                       nativeOverrides=False, historicalResultReuse=False))
    print(f'PASS {profile}: {len(expected)} native groups; {len(inputs)} matching inputs', flush=True)


if __name__ == '__main__':
    main()
