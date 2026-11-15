"""Verify record validation against the original decoder and native frame boundaries."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-record-validation'
bottom.EXTRA_INPUTS = {'tools/verify-value-record-validation.py'}
bottom.MODULES = {
    'value_record_validation': None,
    'value_codec': ['records_validate_nested_scalars_and_all_padding_before_any_publication',
                    'maximum_arrays_records_and_independent_depth_are_bounded_and_layout_snapshots_are_immutable',
                    'active_tags_inactive_bytes_and_opaque_words_are_checked_without_owner_authority'],
    'value_frames': ['scalar_array_record_copies_validate_canonical_bytes_and_remain_independent'],
    'scalar_codec': None,
}
if __name__ == '__main__':
    bottom.main()
