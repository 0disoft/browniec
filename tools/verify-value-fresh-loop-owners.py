"""Verify fresh retained anonymous loop owners in native locked mirrors."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_bottom_verifier', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/value-fresh-loop-owners'
suite.EXTRA_INPUTS = {'tools/verify-value-fresh-loop-owners.py'}
suite.MODULES = {
    'value_fresh_loop_owners_source': None,
    'value_fresh_loop_owners_runtime': None,
    'value_loop_header_owners_source': [
        'last_seed_alias_rebinding_repeats_through_while_for_and_nested_edges',
        'deferral_does_not_admit_named_owner_loss_pins_or_pending_results'],
    'value_view_loop_origins_source': [
        'while_ranges_conditions_continue_and_nested_origin_changes_execute'],
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}
if __name__ == '__main__':
    suite.main()
