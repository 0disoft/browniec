"""Verify shared value/record inspection and retained native layouts."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-retain-plan'
bottom.EXTRA_INPUTS = {'tools/verify-value-retain-plan.py'}
bottom.MODULES = {'value_retain_plan': None, 'value_properties': None,
                  'value_codec': None, 'value_frame_layout': None,
                  'value_frames': ['scalar_array_record_copies_validate_canonical_bytes_and_remain_independent',
                                   'maximum_array_and_four_wrappers_preserve_late_bytes_and_sole_active_root']}
if __name__ == '__main__':
    bottom.main()
