"""Focused source Buffer view checks in locked mirrors; --discover only reads.

Native verification is explicit execution by the coordinating parent after its
production-source freeze. Production sources are hashed and copied byte-for-byte
into temporary mirrors; receipts live under build/value-view-source.
"""
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


def discover():
    runner.MODULES = {
        'value_view_source': None,
        'value_buffer_copy': None,
        'value_buffer_source': None,
        'value_view_execution': None,
        'value_source_control': [
            'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
    }
    expected = runner.discover()
    assert sum('::value_view_source::' in name for name in expected) == 8
    assert sum('::value_buffer_copy::' in name for name in expected) == 3
    assert sum('::value_buffer_source::' in name for name in expected) == 3
    assert sum('::value_view_execution::' in name for name in expected) == 8
    assert len(expected) == 23
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    expected = discover()
    if args.discover:
        print(json.dumps(sorted(expected), indent=2))
        return
    directory = 'build/value-view-source'
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    for profile in profiles:
        output = ROOT / directory / profile
        output.mkdir(parents=True, exist_ok=True)
        runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile))
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-view-source.py'})
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for profile in profiles:
        runner.verify_profile(profile, False, expected, inputs, 'native', directory)


if __name__ == '__main__':
    main()
