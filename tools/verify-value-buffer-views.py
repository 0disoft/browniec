"""Verify Native Buffer views, read leases and existing root/VM ownership in isolated native batches."""
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
    'views': {'value_buffer_views': None, 'value_root_leases': None, 'value_roots': None},
    'vm': {'value_buffer_roots': None, 'value_buffer_frames': None, 'value_buffer_copy': None},
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['views', 'vm', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    batches = BATCHES if args.batch == 'all' else {args.batch: BATCHES[args.batch]}
    selections = {}
    for batch, modules in batches.items():
        runner.MODULES = modules
        tests = runner.discover()
        assert len(tests) == (10 if batch == 'views' else 9)
        selections[batch] = tests
    if len(selections) == 2:
        assert selections['views'].isdisjoint(selections['vm'])
    if args.discover:
        print(json.dumps(dict(groupsPerProfile=sum(map(len,selections.values())), batches={
            batch: sorted(tests) for batch, tests in selections.items()}), indent=2))
        return
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    for batch in batches:
        for profile in profiles:
            output = ROOT / 'build/value-buffer-views' / batch / profile
            output.mkdir(parents=True, exist_ok=True)
            runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile, batch=batch))
    for batch, selected in batches.items():
        runner.MODULES = selected
        paths = sorted({p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy')} |
                       {f'tests/m2/{name}.fy' for name in selected} |
                       {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                        'tools/verify-value-buffer-views.py'})
        inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
        for profile in profiles:
            runner.verify_profile(profile, False, selections[batch], inputs, 'native', f'build/value-buffer-views/{batch}')


if __name__ == '__main__':
    main()
