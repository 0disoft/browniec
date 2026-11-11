"""Verify resumable primitive/wrapper type parsing and exact raw diagnostics."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('type_parse_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/type-parse-work'
bottom.MODULES = {'type_parse_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-type-parse-work.py'}

if __name__ == '__main__':
    bottom.main()
