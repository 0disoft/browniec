"""Verify selected binary input execution and unchanged scalar/depth boundaries."""
import importlib.util
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
if any(key.upper() in {'CL', '_CL_', 'LINK'} for key in os.environ):
    raise SystemExit('CL/_CL_/LINK overrides must be absent, including empty values')
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('input_execution_suite', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/module-input-execution'
suite.EXTRA_INPUTS = {'tools/verify-module-input-execution.py'}
suite.MODULES = {
    'module_input_execution': None,
    'module_program': ['selected_nonfirst_entry_and_private_helpers_execute_with_exact_scalar_fuel',
                       'shared_byte_returns_literals_ranges_and_text_cross_real_module_calls'],
    'reference_return_execution': ['the_same_returned_signature_reads_distinct_image_and_runtime_values_at_exact_fuel',
        'caller_alias_and_range_survive_parent_and_original_loan_close_until_last_alias',
        'complete_return_fuel_is_checked_before_invalid_native_formal_authentication'],
    'captured_call_stack': ['retained_captured_calls_keep_the_32_deep_limit_and_reject_33'],
}

if __name__ == '__main__':
    suite.main()
