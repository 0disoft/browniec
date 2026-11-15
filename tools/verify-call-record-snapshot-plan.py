"""Verify single-plan bound record snapshots and atomic mixed CALL copies."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/call-record-snapshot-plan'
bottom.EXTRA_INPUTS = {'tools/verify-call-record-snapshot-plan.py'}
bottom.MODULES = {'call_record_snapshot_plan': None,
    'call_argument_copies': [
        'mixed_nested_records_normalize_padding_and_keep_copies_independent',
        'late_record_and_array_bool_errors_never_publish_a_prefix',
        'late_identity_token_descriptor_catalog_and_shape_errors_are_atomic',
        'combined_quota_alignment_and_array_shape_failures_leave_bytes_untouched',
        'owner_pressure_retirement_and_deferred_holes_are_preflighted',
        'zero_eight_nine_arguments_and_full_128_byte_roots_are_bounded'],
    'mixed_call_vm': ['exact_combined_fuel_duplicate_empty_ranges_and_owned_copies_publish_together']}
if __name__ == '__main__':
    bottom.main()
