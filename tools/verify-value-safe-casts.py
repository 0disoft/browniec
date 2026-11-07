"""Verify private widening casts and ownership/terminal/depth composition."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_bottom_verifier', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/value-safe-casts'
suite.EXTRA_INPUTS = {'tools/verify-value-safe-casts.py'}
suite.MODULES = {
    'value_safe_casts_source': None,
    'value_loop_header_owners_source': None,
    'value_source_joins_source': None,
    'value_bottom_source': [
        'all_terminal_loop_value_arms_retain_break_continue_and_outer_mutations',
        'both_return_if_and_switch_need_no_destination_or_outer_return'],
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}


if __name__ == '__main__':
    suite.main()
