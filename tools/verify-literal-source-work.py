"""Verify staged literal interning and source collection against independent raw owners."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('literal_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/literal-source-work'
bottom.MODULES = {'literal_intern_work': None, 'literal_collection_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-literal-source-work.py'}

if __name__ == '__main__':
    bottom.main()
