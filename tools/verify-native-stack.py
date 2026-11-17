"""Run unchanged combined native stack regressions with the pinned toolchain."""
import argparse
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
CASES = {
    'quota': {
        'array_operand_cells': None,
        'public_program': ['image_quota_is_exact_and_independent_of_the_public_backing_limit'],
        'call_copy_plan_work': ['empty_copy_fast_path_matches_complete_plan_validation_without_mutation'],
        'static_image': ['admission_and_failed_interning_preserve_exact_limits_and_scratch',
                         'full_capacity_builder_matches_checked_constructor'],
        'array_expression_projections': ['combined_group_index_and_32_deep_captured_call_bounds_stay_original'],
    },
    'routing': {
        'public_program': ['source_routing_keeps_legacy_profiles_and_admits_the_extended_path',
                           'image_quota_is_exact_and_independent_of_the_public_backing_limit',
                           'private_api_gates_and_native_host_budgets_remain_unchanged'],
    },
    'annotation': {
        'value_signature_depth': None,
        'value_source_must_use_source': ['unused_results_parameters_overwrites_scope_exits_and_error_names_are_distinct'],
    },
}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=CASES, required=True)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='development')
    parser.add_argument('--discover', action='store_true')
    parser.add_argument('--regression-only', action='store_true')
    args = parser.parse_args()
    bottom.MODULES = CASES[args.case]
    if args.regression_only:
        identities = {
            'quota': ('public_program', 'image_quota_is_exact_and_independent_of_the_public_backing_limit'),
            'routing': ('public_program', 'source_routing_keeps_legacy_profiles_and_admits_the_extended_path'),
            'annotation': ('value_signature_depth', 'four_wrapper_local_annotations_with_32_controls_execute_and_33_reject'),
        }
        module, name = identities[args.case]
        bottom.MODULES = {module: [name]}
    bottom.DIRECTORY = 'build/native-stack/' + args.case
    if args.regression_only:
        bottom.DIRECTORY += '-original'
    bottom.EXTRA_INPUTS = {'tools/verify-native-stack.py'}
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    # One profile per runner invocation: never overlap MSVC builds or alter its
    # timeout, default native stack, selected fixtures or optimization flags.
    for profile in profiles:
        sys.argv = [__file__, '--profile', profile] + (['--discover'] if args.discover else [])
        bottom.main()
        if args.discover:
            break
