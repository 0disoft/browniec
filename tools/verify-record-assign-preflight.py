"""Verify shared whole-record assignment preflight and independent checked storage."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-assign-preflight'
bottom.EXTRA_INPUTS = {'tools/verify-record-assign-preflight.py'}
bottom.MODULES = {'record_assign_preflight': None,
                  'struct_owner_copy': ['matching_layouts_with_distinct_record_ids_and_array_tokens_are_rejected',
                                        'full_capacity_assignment_and_self_assignment_keep_owner_metadata'],
                  'struct_vm': ['every_opcode_prepays_before_tokens_bytes_registers_or_metadata_change',
                                'full_record_table_assignment_and_deferred_holes_preserve_shared_limits']}
if __name__ == '__main__':
    bottom.main()
