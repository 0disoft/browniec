"""Verify Buffer copy source and direct tag destinations in isolated native batches."""
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
    'source': {
        'value_buffer_copy': None,
        'value_buffer_source': None,
        'value_source_boolean': None,
        'value_source_control': [
            'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
    },
    'native': {'value_tag_destination': None, 'value_buffer_source_ops': None},
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['source', 'native', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    batches = BATCHES if args.batch == 'all' else {args.batch: BATCHES[args.batch]}
    selections = {}
    for batch, modules in batches.items():
        runner.MODULES = modules
        tests = runner.discover()
        assert len(tests) == (9 if batch == 'source' else 4)
        selections[batch] = tests
    if len(selections) == 2:
        assert selections['source'].isdisjoint(selections['native'])
    if args.discover:
        print(json.dumps(dict(groupsPerProfile=sum(map(len,selections.values())), batches={
            batch: sorted(tests) for batch, tests in selections.items()}), indent=2))
        return
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    for batch in batches:
        for profile in profiles:
            output = ROOT / 'build/value-buffer-copy' / batch / profile
            output.mkdir(parents=True, exist_ok=True)
            runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile, batch=batch))
    for batch, selected in batches.items():
        runner.MODULES = selected
        paths = sorted({p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy')} |
                       {f'tests/m2/{name}.fy' for name in selected} |
                       {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                        'tools/verify-value-buffer-copy.py'})
        inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
        for profile in profiles:
            runner.verify_profile(profile, False, selections[batch], inputs, 'native', f'build/value-buffer-copy/{batch}')


if __name__ == '__main__':
    main()
