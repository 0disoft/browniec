"""Verify single-plan aggregate record selection and saved-place/store boundaries."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/aggregate-record-select-plan'
bottom.EXTRA_INPUTS = {'tools/verify-aggregate-record-select-plan.py'}
bottom.MODULES = {'aggregate_record_select_plan': None,
                  'aggregate_places': ['record_generation_expiry_invalid_nominal_and_bad_catalog_reject_before_publication',
                                       'malformed_snapshot_fields_domains_and_owner_ledgers_cannot_redirect_writes'],
                  'aggregate_place_vm': ['record_copy_and_constructor_keep_original_subtree_and_fixed_envelopes',
                                         'maximum_record_depth_128_registers_and_full_owner_capacity_preserve_prices']}
if __name__ == '__main__':
    bottom.main()
