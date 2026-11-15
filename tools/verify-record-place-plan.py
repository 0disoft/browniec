"""Verify single-plan scalar places, binding errors and exact VM prices."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-place-plan'
bottom.EXTRA_INPUTS = {'tools/verify-record-place-plan.py'}
bottom.MODULES = {'record_place_plan': None,
                  'record_places': ['selection_does_not_read_bool_payload_and_failed_encoding_is_atomic'],
                  'record_place_vm': ['six_scalar_domains_prepay_each_effect_at_independent_exact_prices',
                                      'maximum_depth_leaves_and_full_owner_backing_capacity_keep_constant_prices']}
if __name__ == '__main__':
    bottom.main()
