"""Verify staged scoped name lookup and visibility against the raw source binder."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('source_name_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/source-name-work'
bottom.MODULES = {'source_name_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-source-name-work.py'}

if __name__ == '__main__':
    bottom.main()
