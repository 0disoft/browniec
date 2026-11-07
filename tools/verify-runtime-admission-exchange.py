"""Verify composed policy/run grants and real typed native host exchange."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('admission_exchange_suite', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/runtime-admission-exchange'
suite.EXTRA_INPUTS = {'tools/verify-runtime-admission-exchange.py'}
suite.MODULES = {
    'runtime_admission_exchange': None,
    'value_source_control': ['admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}

if __name__ == '__main__':
    suite.main()
