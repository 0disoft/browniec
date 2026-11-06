"""Verify private non-consuming source predicates and typed TAG_TEST execution.

Use fresh locked byte-identical mirrors and hash receipts in both profiles.
The public compiler and CLI suites are outside this private-source selection.
"""
import argparse
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
runner.MODULES = {
    'value_source_predicates': None,
    'value_tag_test': None,
    'value_source_control': [
        'conditional_moves_emit_real_cleanup_on_the_other_path_without_owner_revival',
        'exhaustive_switches_extract_nested_wide_and_buffer_payloads_and_merge_surviving_paths',
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
    'value_source_mutation': [
        'mutable_buffer_replaces_reinitializes_and_keeps_fixed_name_slot',
        'copyable_reads_copy_but_assignment_consumes_rhs_and_immutable_names_stay_immutable'],
    'value_source': [
        'empty_buffer_and_nested_tags_run_through_forward_mixed_calls_and_real_cleanup',
        'whole_type_move_rules_and_unsupported_source_forms_fail_before_vm_admission'],
    'value_source_bindings': [
        'whole_types_select_copy_or_move_including_inactive_buffer_and_verify_actual_ir'],
    'value_source_ops': [
        'buffer_tags_copy_plain_children_and_move_whole_types_with_inactive_buffer_alternatives'],
    'value_execution': [
        'active_inactive_and_mismatched_buffer_tags_clean_up_and_scalar_payloads_roundtrip',
        'typed_calls_return_into_consumed_actuals_and_allow_repeated_copyable_arguments'],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['all', 'source', 'native'], default='all')
    args = parser.parse_args()
    if args.batch == 'source':
        runner.MODULES.pop('value_tag_test')
    elif args.batch == 'native':
        runner.MODULES = {'value_tag_test': None}
    directory = 'build/value-predicates' + ('' if args.batch == 'all' else '/' + args.batch)
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    for profile in profiles:
        output = ROOT / directory / profile
        output.mkdir(parents=True, exist_ok=True)
        runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile))
    expected = runner.discover()
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-predicates.py'})
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for profile in profiles:
        runner.verify_profile(profile, False, expected, inputs, 'native', directory)


if __name__ == '__main__':
    main()
