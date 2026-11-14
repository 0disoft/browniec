"""Verify stable typed loop snapshot compaction and nested exit regressions."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-loop-compaction'
bottom.EXTRA_INPUTS = {'tools/verify-value-loop-compaction.py'}
bottom.MODULES = {'value_loop_compaction': None, 'value_source_loops_source': None,
                  'value_source_control': ['admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override']}
if __name__ == '__main__':
    bottom.main()
