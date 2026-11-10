"""Verify staged output borrowed origins against the raw origin oracle."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    'borrowed_origins_work_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/output-borrowed-origins-work'
bottom.MODULES = {'output_borrowed_origins_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-output-borrowed-origins-work.py'}

if __name__ == '__main__':
    bottom.main()
