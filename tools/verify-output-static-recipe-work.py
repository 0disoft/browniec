"""Verify bounded staged static output recipe analysis against the raw oracle."""
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('static_recipe_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/output-static-recipe-work'
bottom.MODULES = {'output_static_recipe_work': None}
bottom.EXTRA_INPUTS = {'tools/verify-output-static-recipe-work.py'}

if __name__ == '__main__':
    bottom.main()
