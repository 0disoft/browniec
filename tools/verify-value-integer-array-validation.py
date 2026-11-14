"""Verify integer-array validation elision with bool/padding/frame regressions."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-integer-array-validation'
bottom.EXTRA_INPUTS = {'tools/verify-value-integer-array-validation.py'}
bottom.MODULES = {'value_integer_array_validation': None,
                  'value_codec': ['records_validate_nested_scalars_and_all_padding_before_any_publication',
                                  'active_tags_inactive_bytes_and_opaque_words_are_checked_without_owner_authority'],
                  'value_frames': ['scalar_array_record_copies_validate_canonical_bytes_and_remain_independent',
                                   'maximum_array_and_four_wrappers_preserve_late_bytes_and_sole_active_root']}
if __name__ == '__main__':
    bottom.main()
