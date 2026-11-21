"""Verify lexer continuation parity and Fuel with the Windows clock companion."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parent.parent
COMPILER = ROOT / 'build/toolchain/fairyc.exe'
FIXTURE = ROOT / 'tests/m2/lexer_work.fy'
CLOCK = ROOT / 'native/runtime-engine/clock.inc'
MODULE = 'module tests::m2::lexer_work;'
TEST = re.compile(r'^@test fn void ([a-z_][a-z_0-9]*)\(\)', re.MULTILINE)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture_main():
    source = FIXTURE.read_text(encoding='utf-8')
    names = TEST.findall(source)
    if not source.startswith(MODULE + '\n') or not names or source.count('@test') != len(names):
        raise ValueError('Expected lexer test functions in the fixture')
    entry = '\nfn i32 main(){\n' + ''.join(f'    {name}();\n' for name in names)
    return TEST.sub(r'fn void \1()', source.replace(MODULE, 'module main;', 1)) + entry + '    return 0;\n}\n', names


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    source, names = fixture_main()
    if args.discover:
        print(json.dumps(sorted(f'tests::m2::lexer_work::{name}' for name in names), indent=2))
        return
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    inputs = [FIXTURE, CLOCK, COMPILER, Path(__file__).resolve(), ROOT / 'fairy.toml',
              *sorted((ROOT / 'src').rglob('*.fy'))]
    hashes = {path.relative_to(ROOT).as_posix(): digest(path) for path in inputs}
    # Native test mode cannot link the clock companion. Use the same build
    # entry point as the production executable in a disposable source mirror.
    with TemporaryDirectory(prefix='lexer-clock-', dir=ROOT / 'build') as scratch:
        mirror = Path(scratch)
        shutil.copytree(ROOT / 'src', mirror / 'src')
        shutil.copyfile(ROOT / 'fairy.toml', mirror / 'fairy.toml')
        shutil.copyfile(CLOCK, mirror / 'lexer-clock.c')
        (mirror / 'src/main.fy').write_bytes(source.encode('utf-8'))
        (mirror / 'fairy.windows.json').write_bytes(json.dumps({
            'schema': 'fairyc.windows-build/v1', 'subsystem': 'console',
            'sources': ['lexer-clock.c'],
        }).encode('utf-8') + b'\n')
        subprocess.run([COMPILER, 'check'], cwd=mirror, check=True, timeout=180)
        for profile in profiles:
            output = ROOT / 'build/lexer-work' / profile
            output.mkdir(parents=True, exist_ok=True)
            receipt = output / 'receipt.json'
            receipt.write_text(json.dumps({'status': 'incomplete', 'profile': profile}), encoding='utf-8')
            build = [str(COMPILER), 'build', '--locked']
            if profile == 'release':
                build.append('--release')
            subprocess.run(build, cwd=mirror, check=True, timeout=300)
            image = mirror / 'build/browniec.exe'
            result = subprocess.run([image], cwd=mirror, capture_output=True, timeout=30)
            if result.returncode != 0 or result.stdout or result.stderr:
                raise SystemExit(f'{profile} lexer fixture failed: {result.returncode}, '
                                 f'{result.stdout!r}, {result.stderr!r}')
            if hashes != {path.relative_to(ROOT).as_posix(): digest(path) for path in inputs}:
                raise SystemExit('Lexer fixture inputs changed during verification')
            receipt.write_text(json.dumps({
                'status': 'passed', 'profile': profile, 'inputs': hashes, 'tests': names,
                'build': build, 'imageSha256': digest(image), 'exit': result.returncode,
            }, indent=2) + '\n', encoding='utf-8')
            print(f'PASS {profile}: {len(names)} lexer groups', flush=True)


if __name__ == '__main__':
    main()
