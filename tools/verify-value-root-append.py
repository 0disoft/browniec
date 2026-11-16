"""Verify shared append preflight, exact operand authentication and rejection atomicity."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-root-append'
bottom.EXTRA_INPUTS = {'tools/verify-value-root-append.py'}
bottom.MODULES = {
    'value_root_append': None,
    'value_root_leases': ['exact_native_leases_block_mutation_and_prepaid_cleanup_orders_drain'],
    'value_view_copy_roots': None,
    'value_buffer_roots': ['byte_operations_preserve_serial_binding_and_refresh_only_structural_tokens'],
    'value_root_resolution': ['checked_root_resolution_matches_original_for_every_row_and_combined_fault_priority'],
}
if __name__ == '__main__':
    bottom.main()
