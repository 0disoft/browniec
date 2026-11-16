"""Verify one header preflight across view shutdown and exact partial cleanup."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-view-shutdown'
bottom.EXTRA_INPUTS = {'tools/verify-value-view-shutdown.py'}
bottom.MODULES = {
    'value_view_lookup': ['shutdown_matches_original_for_all_pool_sizes_faults_partial_progress_and_retirement'],
    'value_buffer_views': None,
    'value_view_call_runtime': ['arguments_alias_eight_actuals_and_selected_range_returns_without_copy_or_early_unpin'],
}
if __name__ == '__main__':
    bottom.main()
