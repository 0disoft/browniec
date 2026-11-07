"""Focused native Buffer-view call handoff checks in locked mirrors; --discover only reads.

Native verification is explicit execution by the coordinating parent after its
production-source freeze. Production sources are hashed and copied byte-for-byte
into temporary mirrors; receipts live under build/value-view-calls.
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


def discover(batch):
    core = {'value_view_call_pool': None, 'value_view_call_runtime': None}
    regressions = {'value_view_copy_roots': None, 'value_view_copy_execution': None}
    runner.MODULES = core if batch == 'core' else regressions
    expected = runner.discover()
    assert len(expected) == 6
    if batch == 'core':
        assert sum('::value_view_call_pool::' in name for name in expected) == 3
        assert sum('::value_view_call_runtime::' in name for name in expected) == 3
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['core', 'regression'], default='core')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    expected = discover(args.batch)
    if args.discover:
        print(json.dumps(sorted(expected), indent=2))
        return
    directory = 'build/value-view-calls/' + args.batch
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    for profile in profiles:
        output = ROOT / directory / profile
        output.mkdir(parents=True, exist_ok=True)
        runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile))
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-view-calls.py'})
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for profile in profiles:
        runner.verify_profile(profile, False, expected, inputs, 'native', directory)


if __name__ == '__main__':
    main()
