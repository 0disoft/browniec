"""Verify RETURN view handoff reuses header and authenticated source proofs."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-view-handoff'
bottom.EXTRA_INPUTS = {'tools/verify-value-view-handoff.py'}
bottom.MODULES = {
    'value_view_lookup': ['handoff_matches_original_for_all_pool_sizes_faults_and_error_priorities'],
    'value_view_call_pool': [
        'contained_ranges_and_empty_boundaries_retain_exact_lease_after_caller_close',
        'rejected_handoffs_and_exhausted_aliases_preserve_every_metadata_field_and_bytes'],
    'value_buffer_views': None,
    'value_view_call_runtime': None,
}
if __name__ == '__main__':
    bottom.main()
