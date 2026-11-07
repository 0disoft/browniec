"""Verify evolving source-loop view origins and terminal expression composition."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_bottom_verifier', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/value-view-loop-origins'
suite.EXTRA_INPUTS = {'tools/verify-value-view-loop-origins.py'}
suite.MODULES = {
    'value_view_loop_origins_source': None,
    'value_view_loop_origins_bindings': None,
    'value_source_loops_source': None,
    'value_bottom_source': [
        'all_terminal_loop_value_arms_retain_break_continue_and_outer_mutations',
        'owned_and_view_return_contexts_preserve_real_terminal_cleanup',
        'short_circuit_bottom_keeps_skip_edge_and_never_replays_effects'],
    'value_view_conditional_source': [
        'loop_iterations_and_transfers_close_views_before_optional_owners'],
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}


if __name__ == '__main__':
    suite.main()
