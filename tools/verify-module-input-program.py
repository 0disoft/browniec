"""Verify complete selected input compilation/IR proof and unchanged execution gates."""
import importlib.util
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
if any(key.upper() in {'CL', '_CL_', 'LINK'} for key in os.environ):
    raise SystemExit('CL/_CL_/LINK overrides must be absent, including empty values')
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('input_program_suite', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/module-input-program'
suite.EXTRA_INPUTS = {'tools/verify-module-input-program.py'}
suite.MODULES = {
    'module_input_program': None,
    'module_program': ['selected_nonfirst_entry_and_private_helpers_execute_with_exact_scalar_fuel'],
    'captured_call_stack': ['retained_captured_calls_keep_the_32_deep_limit_and_reject_33'],
}

if __name__ == '__main__':
    suite.main()
