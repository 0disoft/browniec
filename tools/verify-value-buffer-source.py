"""Verify private Buffer/boolean source and native lowering in isolated batches."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def discover():
    source = {
        'value_buffer_source': None,
        'value_source_boolean': None,
        'value_source_control': [
            'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
        'value_source_loops_source': [
            'loop_header_invariants_pure_for_syntax_and_result_pending_fixedpoints_are_enforced'],
    }
    runner.MODULES = source
    source_tests = runner.discover()
    assert len(source_tests) == 7
    helper = ROOT / 'tests/m2/value_buffer_source_ops.fy'
    if not helper.is_file():
        return {'source': (source, source_tests)}, [helper.relative_to(ROOT).as_posix()]
    # The parallel helper owns these names: discover its real declarations.
    runner.MODULES = {'value_buffer_source_ops': None}
    helper_tests = runner.discover()
    assert len(helper_tests) == 2, 'value_buffer_source_ops must declare exactly two native groups'
    native = {
        'value_buffer_source_ops': None,
        'value_buffer_execution': [
            'all_six_buffer_opcodes_preserve_owners_copy_results_and_extract_usize_payload',
            'verifier_rejects_malformed_buffer_operands_reserved_bytes_scalar_and_result_shapes',
            'fuel_exact_boundary_bounds_and_quota_traps_allow_fresh_owner_cleanup_retry'],
    }
    runner.MODULES = native
    native_tests = runner.discover()
    assert len(native_tests) == 5 and source_tests.isdisjoint(native_tests)
    return {'source': (source, source_tests), 'native': (native, native_tests)}, []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['source', 'native', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    batches, pending = discover()
    if args.discover:
        print(json.dumps(dict(
            status='pending' if pending else 'ready', pending=pending,
            groupsPerProfile=sum(len(tests) for _, tests in batches.values()),
            batches={name: sorted(tests) for name, (_, tests) in batches.items()}), indent=2))
        return
    if pending:
        raise SystemExit('Pending native helper: ' + ', '.join(pending))
    selected_batches = batches if args.batch == 'all' else {args.batch: batches[args.batch]}
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    modules = {module for selected, _ in batches.values() for module in selected}
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in modules} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-buffer-source.py'})
    for batch in selected_batches:
        for profile in profiles:
            output = ROOT / 'build/value-buffer-source' / batch / profile
            output.mkdir(parents=True, exist_ok=True)
            runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile, batch=batch))
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for batch, (selected, expected) in selected_batches.items():
        runner.MODULES = selected
        for profile in profiles:
            runner.verify_profile(profile, False, expected, inputs, 'native', f'build/value-buffer-source/{batch}')


if __name__ == '__main__':
    main()
