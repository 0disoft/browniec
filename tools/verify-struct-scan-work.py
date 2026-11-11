"""Verify staged struct declarations, type resolution and exact layout diagnostics."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('struct_scan_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/struct-scan-work'
bottom.MODULES = {'struct_scan_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-struct-scan-work.py'}

if __name__ == '__main__':
    bottom.main()
