"""Verify single-plan owner-bound record access, metadata errors and VM execution."""
import importlib.util
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/record-access-plan'
bottom.EXTRA_INPUTS = {'tools/verify-record-access-plan.py'}
bottom.MODULES = {'record_access_plan': None,
                  'struct_owners': ['one_owner_holds_maximum_leaves_or_maximum_depth'],
                  'struct_nested_storage': ['paths_require_the_whole_root_and_scalar_endpoint_before_writes'],
                  'struct_vm': ['every_opcode_prepays_before_tokens_bytes_registers_or_metadata_change',
                                'iterative_leaf_paths_cover_depth_sixteen_and_all_128_leaves']}
if __name__ == '__main__':
    bottom.main()
