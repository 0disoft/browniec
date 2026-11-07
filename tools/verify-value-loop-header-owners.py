"""Verify deferred anonymous loop-header owners and actual terminal cleanup."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_bottom_verifier', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/value-loop-header-owners'
suite.EXTRA_INPUTS = {'tools/verify-value-loop-header-owners.py'}
suite.MODULES = {
    'value_loop_header_owners_source': None,
    'value_loop_header_owners_bindings': None,
    'value_view_loop_origins_source': None,
    'value_view_conditional_source': [
        'loop_iterations_and_transfers_close_views_before_optional_owners'],
    'value_bottom_source': [
        'all_terminal_loop_value_arms_retain_break_continue_and_outer_mutations'],
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}


if __name__ == '__main__':
    suite.main()
