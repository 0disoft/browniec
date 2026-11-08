"""Verify private staged CALL/RET metadata against independent atomic kernels."""
import argparse
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('metadata_bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.EXTRA_INPUTS = {'tools/verify-runtime-metadata-work.py'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--slice', choices=['kernels', 'runtime', 'shared'], required=True)
    selection, remaining = parser.parse_known_args()
    sys.argv = [sys.argv[0]] + remaining
    bottom.DIRECTORY = 'build/runtime-metadata-work/' + selection.slice
    names = ['metadata_budget', 'slice_handoff_work', 'slice_handoff', 'array_owners'] if selection.slice == 'kernels' else [
        'runtime_metadata_work', 'slice_result_runtime', 'slice_authority']
    if selection.slice == 'shared':
        names = ['runtime_metadata_shared_work']
    bottom.MODULES = {name: None for name in names}
    if selection.slice == 'runtime':
        bottom.MODULES['slice_authority'] = ['thirty_one_mixed_restores_fit_and_the_next_call_or_child_is_atomic',
                                           'empty_calls_consume_depth_and_corrupt_ownership_is_rejected_then_abortable']
    bottom.main()
