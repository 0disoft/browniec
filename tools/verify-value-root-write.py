"""Verify direct mutable root writes against the original owning-vector transfers."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-root-write'
bottom.EXTRA_INPUTS = {'tools/verify-value-root-write.py'}
bottom.MODULES = {
    'value_root_write': None,
    'value_buffer_roots': None,
    'value_root_resolution': ['checked_root_resolution_matches_original_for_every_row_and_combined_fault_priority'],
    'value_root_leases': ['exact_native_leases_block_mutation_and_prepaid_cleanup_orders_drain'],
    'value_buffer_frames': ['addressed_byte_operations_preserve_frame_words_and_initialization_order',
                            'fuel_authentication_and_combined_quotas_reject_before_mutation_and_abort_frees'],
}
if __name__ == '__main__':
    bottom.main()
