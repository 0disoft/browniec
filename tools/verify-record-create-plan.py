"""Verify single-plan record creation, checked receipts, and unchanged VM Fuel."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-create-plan'
bottom.EXTRA_INPUTS = {'tools/verify-record-create-plan.py'}
bottom.MODULES = {'record_create_plan': None,
                  'struct_owners': ['invalid_values_quota_and_shared_sixteen_owner_pressure_roll_back',
                                    'generation_retirement_and_clear_apply_to_both_owner_kinds'],
                  'struct_nested_storage': ['repeated_nested_records_preserve_scalar_bits_and_all_padding'],
                  'struct_vm': ['every_opcode_prepays_before_tokens_bytes_registers_or_metadata_change']}
if __name__ == '__main__':
    bottom.main()
