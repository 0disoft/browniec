"""Verify single-pass shared array lease authentication and slice VM regressions."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/array-lease-authentication'
bottom.EXTRA_INPUTS = {'tools/verify-array-lease-authentication.py'}
bottom.MODULES = {'array_lease_authentication': None,
                  'array_read_leases': [
                      'active_session_blocks_writes_replacement_transfer_and_cleanup_atomically',
                      'old_or_copied_tickets_cannot_access_or_end_a_new_session'],
                  'slice_index_vm': ['checked_reads_prepay_fuel_and_preserve_output_and_loan_on_every_failure'],
                  'slice_vm': ['verified_slice_scan_runs_with_runtime_bounds_and_prepaid_fuel']}
if __name__ == '__main__':
    bottom.main()
