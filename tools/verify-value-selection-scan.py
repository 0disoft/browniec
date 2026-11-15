"""Verify single-scan tag selection, error ordering and native ownership."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-selection-scan'
bottom.EXTRA_INPUTS = {'tools/verify-value-selection-scan.py'}
bottom.MODULES = {'value_codec': None, 'value_tag_test': None,
                  'value_frames': ['inactive_and_active_move_only_tags_refuse_copy_and_consume_matches_with_exact_payload_bindings',
                                   'maximum_array_and_four_wrappers_preserve_late_bytes_and_sole_active_root']}
if __name__ == '__main__':
    bottom.main()
