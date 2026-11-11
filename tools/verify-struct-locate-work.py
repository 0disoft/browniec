"""Verify resumable single-source nominal discovery against the raw declaration walk."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('struct_locate_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/struct-locate-work'
bottom.MODULES = {'struct_locate_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-struct-locate-work.py'}

if __name__ == '__main__':
    bottom.main()
