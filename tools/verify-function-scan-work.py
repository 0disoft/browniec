"""Verify staged complete untyped function scanning for single and immutable module input."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('function_scan_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/function-scan-work'
bottom.MODULES = {'function_scan_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-function-scan-work.py'}

if __name__ == '__main__':
    bottom.main()
