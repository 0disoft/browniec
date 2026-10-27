"""Check nominal signatures under the current executable source contract."""
from pathlib import Path
import runpy
import sys

sys.argv.extend(['--selection', 'signatures'])
runpy.run_path(str(Path(__file__).with_name('check-m2-struct-parameters-source.py')), run_name='__main__')
