"""Verify private resumable body control and exact compiler lowering outcomes."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('body_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/body-source-work'
bottom.MODULES = {'body_source_work': None, 'body_lowering': None}
bottom.EXTRA_INPUTS = {'tools/verify-body-source-work.py'}
if __name__ == '__main__':
    bottom.main()
