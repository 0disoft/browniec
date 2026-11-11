"""Verify staged compiler source adapters against independent raw token/collection helpers."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('compiler_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/compiler-source-work'
bottom.MODULES = {'source_context_work': None, 'literal_source_work': None, 'literal_scan_work': None, 'lexer_work': None,
                  'source_context_check_work': None, 'source_name_work': None, 'type_parse_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-compiler-source-work.py'}

if __name__ == '__main__':
    bottom.main()
