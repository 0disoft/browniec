"""Verify staged CALL context prefixes and external Fuel ordering against raw begin."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('call_context_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/call-context-work'
bottom.MODULES = {'call_context_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-call-context-work.py'}

if __name__ == '__main__':
    bottom.main()
