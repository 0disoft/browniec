"""Verify staged CALL publication and Fuel against the independent legacy path."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('call_metadata_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/call-metadata-execution'
bottom.MODULES = {'call_metadata_execution': None}
bottom.EXTRA_INPUTS = {'tools/verify-call-metadata-execution.py'}
if __name__ == '__main__':
    bottom.main()
