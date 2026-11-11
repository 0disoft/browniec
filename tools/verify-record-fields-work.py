"""Verify staged record-field types, duplicates and partial catalog parity."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('record_fields_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-fields-work'
bottom.MODULES = {'record_fields_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-record-fields-work.py'}

if __name__ == '__main__':
    bottom.main()
