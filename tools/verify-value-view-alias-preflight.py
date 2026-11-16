"""Verify one registry header preflight per atomic view CALL alias batch."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-view-alias-preflight'
bottom.EXTRA_INPUTS = {'tools/verify-value-view-alias-preflight.py'}
bottom.MODULES = {
    'value_view_call_pool': None,
    'value_view_lookup': ['original_lookup_matches_all_pool_sizes_metadata_faults_and_error_priorities'],
    'value_buffer_views': None,
    'value_view_call_runtime': ['arguments_alias_eight_actuals_and_selected_range_returns_without_copy_or_early_unpin'],
}
if __name__ == '__main__':
    bottom.main()
