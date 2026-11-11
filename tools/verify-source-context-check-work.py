"""Verify resumable compiler context authentication against raw validity."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('source_context_check_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/source-context-check-work'
bottom.MODULES = {'source_context_check_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-source-context-check-work.py'}

if __name__ == '__main__':
    bottom.main()
