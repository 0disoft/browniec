"""Verify indexed view headers against the frozen pairwise oracle and real VM reads."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-view-header'
bottom.EXTRA_INPUTS = {'tools/verify-value-view-header.py'}
bottom.MODULES = {'value_view_lookup': None, 'value_buffer_views': None,
                  'value_view_execution': [
                      'real_bytes_nested_ranges_aliases_move_and_empty_windows_outlive_parent_close']}
if __name__ == '__main__':
    bottom.main()
