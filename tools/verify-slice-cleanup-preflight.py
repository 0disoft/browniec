"""Verify one-preflight slice cleanup with mutation/epoch/rollback and VM cases."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/slice-cleanup-preflight'
bottom.EXTRA_INPUTS = {'tools/verify-slice-cleanup-preflight.py'}
bottom.MODULES = {'slice_cleanup_preflight': None,
                  'slice_arguments': ['batch_exit_is_atomic_consumes_only_its_handles_and_rejects_stale_or_duplicate_copies'],
                  'array_slices': ['full_owner_table_and_external_sessions_remain_independent'],
                  'slice_exclusive_pool': ['both_modes_share_sixteen_slots_and_pool_and_owner_epochs_never_wrap'],
                  'slice_call_vm': ['late_cleanup_failures_preserve_all_tables_and_eight_empty_arguments_remain_bounded']}
if __name__ == '__main__':
    bottom.main()
