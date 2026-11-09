"""Verify staged zero-Fuel cleanup against the independent atomic abort."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('cleanup_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/runtime-cleanup-work'
bottom.MODULES = {'runtime_cleanup_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-runtime-cleanup-work.py'}
if __name__ == '__main__':
    bottom.main()
