"""Verify terminal value expressions and their ownership/control regressions."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
DESCRIPTION = __doc__
DIRECTORY = 'build/value-bottom'
EXTRA_INPUTS = set()
MODULES = {
    'value_bottom_source': None,
    'value_view_join_source': None,
    'value_source_joins_source': None,
    'value_source_must_use_source': None,
    'value_source_loops_source': None,
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}


def main():
    parser = argparse.ArgumentParser(description=DESCRIPTION)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    runner.MODULES = MODULES
    expected = runner.discover()
    if args.discover:
        print(json.dumps(sorted(expected), indent=2))
        return
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    directory = DIRECTORY
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-bottom.py'} | EXTRA_INPUTS)
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for profile in profiles:
        output = ROOT / directory / profile
        output.mkdir(parents=True, exist_ok=True)
        runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile))

    def verify(profile):
        runner.verify_profile(profile, False, expected, inputs, 'native', directory)

    with ThreadPoolExecutor(max_workers=len(profiles)) as pool:
        list(pool.map(verify, profiles))


if __name__ == '__main__':
    main()
