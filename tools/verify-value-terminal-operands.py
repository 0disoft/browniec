"""Verify terminal byte/view operands, existing loan semantics and depth.

--regressions-only selects seven existing checks; use after or alongside the
new development groups on byte-identical independent worker inputs.
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
suite.DIRECTORY = 'build/value-terminal-operands'
suite.EXTRA_INPUTS = {'tools/verify-value-terminal-operands.py'}
suite.MODULES = {
    'value_terminal_operands_source': None,
    'value_buffer_source': None,
    'value_view_source': [
        'unrelated_calls_and_ordered_endpoint_effects_preserve_caller_views',
        'return_and_result_propagation_close_views_before_capturing_or_dropping_owners'],
    'value_loop_header_owners_source': [
        'return_propagation_and_runtime_failures_close_deferred_seed_roots'],
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}


if __name__ == '__main__':
    selector = argparse.ArgumentParser(add_help=False)
    selector.add_argument('--regressions-only', action='store_true')
    selection, remaining = selector.parse_known_args()
    sys.argv[1:] = remaining
    if selection.regressions_only:
        del suite.MODULES['value_terminal_operands_source']
    suite.main()
