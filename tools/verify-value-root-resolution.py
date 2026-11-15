"""Verify operation-local root resolution reuse against raw owner API oracles."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-root-resolution'
bottom.EXTRA_INPUTS = {'tools/verify-value-root-resolution.py'}
bottom.MODULES = {'value_root_resolution': None, 'value_root_authentication': None,
                  'value_root_leases': ['exact_native_leases_block_mutation_and_prepaid_cleanup_orders_drain'],
                  'value_buffer_roots': None}
if __name__ == '__main__':
    bottom.main()
