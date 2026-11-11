"""Verify staged source-context lexer setup, raw failures and builtin shadowing."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('source_state_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/source-state-work'
bottom.MODULES = {'source_state_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-source-state-work.py'}

if __name__ == '__main__':
    bottom.main()
