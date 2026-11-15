"""Verify coordinate-only Static preflight against the original packing path."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/static-view-validation'
bottom.EXTRA_INPUTS = {'tools/verify-static-view-validation.py'}
bottom.MODULES = {
    'static_view_validation': None,
    'static_views': [
        'packed_ranges_round_trip_zero_empty_and_full_payload_edges',
        'forged_payloads_high_bits_and_host_sized_values_fail_before_arithmetic',
        'byte_windows_can_narrow_but_never_cross_the_proved_image_window',
        'text_words_preserve_exact_validated_ranges_and_cannot_coerce_bytes',
        'physical_frames_and_liveness_remain_separate_from_valid_range_words',
        'guest_crop_is_relative_and_reports_bounds_without_mutating_its_parent'],
    'static_ranges': [
        'shortage_and_bad_endpoints_preserve_destination_words_registers_and_source'],
    'static_call_execution': [
        'actual_byte_ranges_transfer_without_broadening_and_preflight_complete_call_price',
        'parameter_activation_and_static_return_check_exact_recipient_before_publication',
        'text_arguments_require_the_complete_validated_window'],
}
if __name__ == '__main__':
    bottom.main()
