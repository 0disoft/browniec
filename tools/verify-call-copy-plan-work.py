"""Verify bounded CALL copy preparation and prepared payload against raw oracles."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('call_plan_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/call-copy-plan-work'
bottom.MODULES = {'call_copy_plan_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-call-copy-plan-work.py'}
if __name__ == '__main__':
    bottom.main()
