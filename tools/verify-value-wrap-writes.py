"""Verify padding-only wrapper initialization, byte parity and native ownership."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-wrap-writes'
bottom.EXTRA_INPUTS = {'tools/verify-value-wrap-writes.py'}
bottom.MODULES = {'value_wrap_writes': None,
                  'value_codec': ['tag_layout_uses_design_bytes_and_locates_only_the_single_active_buffer',
                                  'records_validate_nested_scalars_and_all_padding_before_any_publication',
                                  'one_backing_copies_support_both_alias_directions_and_reject_unsafe_tag_overlap_atomically',
                                  'active_tags_inactive_bytes_and_opaque_words_are_checked_without_owner_authority'],
                  'value_frames': ['dirty_tag_scratch_preserves_full_small_and_absent_payloads_at_exact_fuel',
                                   'inactive_and_active_move_only_tags_refuse_copy_and_consume_matches_with_exact_payload_bindings',
                                   'maximum_array_and_four_wrappers_preserve_late_bytes_and_sole_active_root'],
                  'value_tag_test': ['repeated_predicates_preserve_plain_nested_and_active_inactive_buffer_wrappers_in_vm']}
if __name__ == '__main__':
    bottom.main()
