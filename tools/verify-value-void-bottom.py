"""Verify terminal operands of private void returns and retained cleanup.

--regressions-only selects the four existing composition/depth checks when the
new groups already passed on byte-identical development mirror inputs.
"""
import argparse
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_bottom_verifier', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/value-void-bottom'
suite.EXTRA_INPUTS = {'tools/verify-value-void-bottom.py'}
suite.MODULES = {
    'value_void_bottom_source': None,
    'value_bottom_source': [
        'void_and_malformed_or_unreachable_trailing_source_stay_errors',
        'all_terminal_loop_value_arms_retain_break_continue_and_outer_mutations'],
    'value_safe_casts_source': [
        'bottom_validates_targets_without_reads_captures_or_widening'],
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}


if __name__ == '__main__':
    selector = argparse.ArgumentParser(add_help=False)
    selector.add_argument('--regressions-only', action='store_true')
    selection, remaining = selector.parse_known_args()
    sys.argv[1:] = remaining
    if selection.regressions_only:
        del suite.MODULES['value_void_bottom_source']
    suite.main()
