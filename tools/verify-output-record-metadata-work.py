"""Verify staged output record binding flattening against raw struct metadata."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('record_metadata_work_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/output-record-metadata-work'
bottom.MODULES = {'output_record_metadata_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-output-record-metadata-work.py'}

if __name__ == '__main__':
    bottom.main()
