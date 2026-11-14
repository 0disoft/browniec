"""Verify ascending sparse view-CFG scheduling against the original verifier."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-flow-pending'
bottom.EXTRA_INPUTS = {'tools/verify-value-flow-pending.py'}
bottom.MODULES = {'value_flow_pending': None, 'value_view_flow_reference': None,
                  'value_view_origin_sets_ir': [
                      'loop_widening_rechecks_earlier_writes_and_already_processed_exit_successors',
                      'repeated_loop_origin_widening_reaches_a_finite_fixed_point'],
                  'value_view_join_source': [
                      'terminal_arms_and_loop_transfers_clean_views_before_roots']}
if __name__ == '__main__':
    bottom.main()
