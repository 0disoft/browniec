"""Verify single-plan record chunk validation and fresh metadata admission."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-work-plan'
bottom.EXTRA_INPUTS = {'tools/verify-record-work-plan.py'}
bottom.MODULES = {'record_work_plan': None,
    'return_record_work': ['selected_nested_measure_and_mask_match_independent_storage',
                         'shared_leaf_expansion_reaches_exact_128_byte_limit'],
    'struct_atomic_source': ['full_fuel_is_prepaid_and_one_less_preserves_bytes_and_owners',
                             'invalid_bool_ranges_frame_and_authority_fail_before_commit']}
if __name__ == '__main__':
    bottom.main()
