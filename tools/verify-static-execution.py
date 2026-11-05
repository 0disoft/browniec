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
    parser.add_argument('--selection', choices=['all', 'statics', 'views', 'ranges', 'range-core', 'call-ir', 'call-proof', 'call-transfer-core', 'call-transfer', 'call-mixed', 'reference-access', 'reference-proof', 'reference-vm', 'reference-return-ir', 'reference-return-lifetimes', 'reference-receipts', 'reference-return-execution', 'reference-source', 'reference-return-source', 'public-program', 'source-snapshot', 'module-index', 'module-entry', 'source-context', 'module-program', 'module-program-core', 'module-retention', 'project-program-core', 'project-program', 'project-names', 'project-manifest', 'project-sources', 'captured-call-stack', 'local-inference', 'aggregate-inference'], default='all',
                        help='statics runs the changed image/proof/VM suites; all adds return and source regressions')
    args = parser.parse_args()
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
    files = selections[args.selection]
    out = ROOT / 'build/static-execution' / profile / args.selection
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
    exact = args.selection in ('reference-access', 'reference-proof', 'reference-vm', 'reference-return-ir', 'reference-return-lifetimes', 'reference-receipts', 'reference-return-execution', 'reference-source', 'reference-return-source', 'public-program')
    for path in files:
        if not exact:
            command.extend(['--file', path])
        source = (ROOT / path).read_text(encoding='utf-8')
        names = re.findall(r'@test\s+fn void (\w+)\(', source)
        if exact and Path(path).stem in focused:
            selected = focused[Path(path).stem]
            assert selected <= set(names)
            names = [name for name in names if name in selected]
        module = re.search(r'\bmodule\s+([\w:]+);', source).group(1)
        expected.update(module + '::' + name for name in names)
    if exact:
        assert len(expected) == 18
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
                       profile=profile, selection=args.selection, startingHead=run(['git', 'rev-parse', 'HEAD']).stdout.strip(),
                       platform=platform.platform(), compilerSha256=compiler_hash,
                       compilerVersion=run([compiler, '--version']).stdout.strip(),
                       inputSnapshotCapturedAt=captured, inputs=inputs, testDiscovery=tree,
                       lfMirror=dict(command=['build/toolchain/fairyc.exe' if os.name == 'nt' else 'build/toolchain/fairyc', 'check', '--locked'],
                                     workingDirectory=mirror.relative_to(ROOT).as_posix(),
                                     productionFiles=len(production), result=checked),
                       command=command, nativeGroups=len(expected), report=report,
                       nativeReportSha256=digest(out / 'native.json'),
                       nativeOverrides=False, historicalResultReuse=False))
    print(f'PASS {profile}: {len(expected)} native groups; {len(inputs)} matching inputs', flush=True)


if __name__ == '__main__':
    main()
