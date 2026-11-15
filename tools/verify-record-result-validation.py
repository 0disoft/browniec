"""Verify validation-only record results, forged metadata and direct RET boundaries."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-result-validation'
bottom.EXTRA_INPUTS = {'tools/verify-record-result-validation.py'}
bottom.MODULES = {'record_result_validation': None,
                  'struct_result_vm': ['failed_transfer_preserves_every_token_owner_field_and_payload_byte',
                                       'full_owner_table_and_payload_return_without_copy_or_generation_change',
                                       'nominal_mismatch_and_array_tokens_cannot_be_returned_as_records'],
                  'record_access_plan': ['checked_storage_binding_rejects_forged_shape_before_path_or_payload_access']}
if __name__ == '__main__':
    bottom.main()
