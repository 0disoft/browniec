"""Verify bounded token-only literal scanning against the independent raw decoder."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('literal_scan_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/literal-scan-work'
bottom.MODULES = {'literal_scan_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-literal-scan-work.py'}

if __name__ == '__main__':
    bottom.main()
