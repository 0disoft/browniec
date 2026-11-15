"""Verify shared subrecord owner-table preflight and staged assignment."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/subrecord-assign-preflight'
bottom.EXTRA_INPUTS = {'tools/verify-subrecord-assign-preflight.py'}
bottom.MODULES = {'subrecord_assign_plan': None,
                  'struct_subassign_owners': None,
                  'struct_atomic_source': ['full_fuel_is_prepaid_and_one_less_preserves_bytes_and_owners']}
if __name__ == '__main__':
    bottom.main()
