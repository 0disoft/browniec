"""Verify one-pass root table authentication, metering and Buffer VM integration."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-root-authentication'
bottom.EXTRA_INPUTS = {'tools/verify-value-root-authentication.py'}
bottom.MODULES = {'value_root_authentication': None, 'value_roots': [
                      'middle_removal_preserves_all_other_actual_allocations_and_bindings',
                      'fuel_boundaries_precede_invalid_handles_and_never_mutate_roots',
                      'corrupt_native_metadata_is_rejected_before_data_or_ownership_changes'],
                  'value_buffer_execution': [
                      'all_six_buffer_opcodes_preserve_owners_copy_results_and_extract_usize_payload']}
if __name__ == '__main__':
    bottom.main()
