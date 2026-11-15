"""Verify authenticated root copy-out against raw owner, range and lease oracles."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-root-copy-out'
bottom.EXTRA_INPUTS = {'tools/verify-value-root-copy-out.py'}
bottom.MODULES = {
    'value_root_resolution': None,
    'value_root_authentication': None,
    'value_root_leases': ['exact_native_leases_block_mutation_and_prepaid_cleanup_orders_drain'],
    'value_buffer_roots': None,
    'value_buffer_views': None,
    'value_view_call_pool': ['eight_aliases_fill_last_rows_preserve_source_windows_and_shared_leases'],
}
if __name__ == '__main__':
    bottom.main()
