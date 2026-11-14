"""Verify single-preflight shared argument batches and actual CALL regressions."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/slice-argument-preflight'
bottom.EXTRA_INPUTS = {'tools/verify-slice-argument-preflight.py'}
bottom.MODULES = {'slice_argument_preflight': None,
                  'slice_arguments': [
                      'late_invalid_future_or_excess_arguments_and_partial_capacity_never_publish_children',
                      'eight_arguments_full_pool_scalar_types_maximum_ranges_and_empty_batches_stay_bounded'],
                  'slice_exclusive_pool': ['shared_exclusive_conflicts_and_borrow_batches_preserve_both_modes_atomically'],
                  'slice_call_vm': ['mixed_formal_ordinals_duplicate_ranges_exact_fuel_and_frame_reuse_preserve_caller_storage']}
if __name__ == '__main__':
    bottom.main()
