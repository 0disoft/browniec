"""Verify ordinary grouped and CALL operand continuations."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('semantic_source_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/operand-source-work'
bottom.MODULES = {'expression_lowering': None, 'body_lowering': ['grouped_operands_match_raw_ir_and_preserve_postfix_cast_context']}
bottom.EXTRA_INPUTS = {'tools/verify-operand-source-work.py'}
if __name__ == '__main__':
    bottom.main()
