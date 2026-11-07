"""Verify private reference-valued joins and origin inference in locked native mirrors."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

BATCHES = {
    'core': {'value_view_join_source': None, 'value_view_join_bindings': None},
    'proof': {'value_view_join_ir': None, 'value_view_join_origins': None},
    'regression': {'value_view_call_source': None, 'value_view_call_bindings': None,
                   'value_view_source': None, 'value_source_joins_source': None,
                   'value_source_joins': None, 'result_handling_source': None,
                   'value_source_control': ['admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override']},
    'origins': {'slice_result_source_origins': None, 'slice_result_call_source': None,
                'reference_return_source': None},
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=sorted(BATCHES), default='core')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    directory = 'build/value-view-joins/' + args.batch
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    if not args.discover:
        for profile in profiles:
            output = ROOT / directory / profile
            output.mkdir(parents=True, exist_ok=True)
            runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile))
    runner.MODULES = BATCHES[args.batch]
    expected = runner.discover()
    if args.discover:
        print(json.dumps(sorted(expected), indent=2))
        return
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-view-joins.py'})
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for profile in profiles:
        runner.verify_profile(profile, False, expected, inputs, 'native', directory)


if __name__ == '__main__':
    main()
