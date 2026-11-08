"""Verify staged RET publication and Fuel against the independent legacy path."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('return_metadata_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/return-metadata-execution'
bottom.MODULES = {'return_metadata_execution': None}
bottom.EXTRA_INPUTS = {'tools/verify-return-metadata-execution.py'}
if __name__ == '__main__':
    bottom.main()
