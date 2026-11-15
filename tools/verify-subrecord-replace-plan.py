"""Verify single-plan subrecord replacement, checked bounds and atomic publication."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/subrecord-replace-plan'
bottom.EXTRA_INPUTS = {'tools/verify-subrecord-replace-plan.py'}
bottom.MODULES = {'subrecord_replace_plan': None,
                  'aggregate_places': ['late_invalid_sources_and_scalar_staging_never_publish_a_prefix'],
                  'aggregate_place_vm': ['record_copy_and_constructor_keep_original_subtree_and_fixed_envelopes',
                                         'maximum_record_depth_128_registers_and_full_owner_capacity_preserve_prices']}
if __name__ == '__main__':
    bottom.main()
