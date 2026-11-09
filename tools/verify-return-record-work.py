"""Verify staged RET catalog proof, selected measurement and scalar masks."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('return_record_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/return-record-work'
bottom.MODULES = {'return_record_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-return-record-work.py'}
if __name__ == '__main__':
    bottom.main()
