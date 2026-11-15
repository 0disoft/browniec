"""Verify single-plan whole-record replacement and checked publication boundaries."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-replace-plan'
bottom.EXTRA_INPUTS = {'tools/verify-record-replace-plan.py'}
bottom.MODULES = {'record_replace_plan': None,
                  'struct_replace_values': ['mixed_values_replace_nested_root_and_normalize_only_its_padding',
                                            'full_owner_table_and_full_arena_replace_all_128_leaves_in_place',
                                            'storage_checks_layout_extents_alignment_state_and_exact_field_count'],
                  'struct_replace_vm': ['fuel_is_prepaid_and_failed_values_authority_and_metadata_preserve_state']}
if __name__ == '__main__':
    bottom.main()
