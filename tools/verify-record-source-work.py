"""Verify integrated source struct/field/layout adapters and exact independent raw results."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('record_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-source-work'
bottom.MODULES = {'struct_scan_work': None, 'record_fields_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-record-source-work.py'}

if __name__ == '__main__':
    bottom.main()
