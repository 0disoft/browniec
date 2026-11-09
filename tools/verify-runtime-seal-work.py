"""Verify admitted output sealing against independent raw seal_metered."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('seal_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/runtime-seal-work'
bottom.MODULES = {'runtime_seal_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-runtime-seal-work.py'}

if __name__ == '__main__':
    bottom.main()
