"""Verify integrated owning signature/declaration adapters against independent raw scans."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('function_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/function-source-work'
bottom.MODULES = {'function_scan_work': None, 'signature_parse_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-function-source-work.py'}

if __name__ == '__main__':
    bottom.main()
