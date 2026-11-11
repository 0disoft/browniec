"""Verify staged canonical catalogs and typed/value source signatures."""
import importlib.util
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_signature_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/value-signature-work'
bottom.MODULES = {'value_properties_work': None, 'value_type_work': None, 'value_signature_work': None, 'value_function_work': None, 'value_catalog_work': None, 'value_signature_depth': None, 'value_source_control': ['mutable_buffers_wrappers_and_scalar_slots_replace_reinitialize_and_snapshot_rhs_values', 'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override']}
bottom.EXTRA_INPUTS = {'tools/verify-value-signature-work.py'}
if __name__ == '__main__':
    bottom.main()
