"""Verify bounded staged output-return signature analysis against the raw oracle."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('return_signature_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/output-return-signature-work'
bottom.MODULES = {'output_return_signature_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-output-return-signature-work.py'}

if __name__ == '__main__':
    bottom.main()
