"""Verify structural value properties and native ownership handoff, without guest promotion."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
MODULES = {'value_properties': 4, 'buffer_transfer': 4}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    args = parser.parse_args()
    output = ROOT / 'build/value-ownership' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'

    def write(data):
        receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')

    write(dict(status='incomplete'))
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    assert not any(os.environ.get(k) for k in ['CL', '_CL_', 'LINK'])
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')] +
                   [f'tests/m2/{name}.fy' for name in MODULES] +
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-ownership.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    commands = []

    def run(command, name):
        command = list(map(str, command)); commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=900)
        (output / name).write_bytes(done.stdout)
        (output / (name + '.stderr.txt')).write_bytes(done.stderr)
        assert done.returncode == 0, (command, done.stdout[-4000:], done.stderr[-2500:])
        return done.stdout

    check = run([compiler, 'check', '--locked'], 'check.txt').decode()
    expected = set()
    for module, count in MODULES.items():
        names = re.findall(r'@test\s+fn void (\w+)\(', (ROOT / f'tests/m2/{module}.fy').read_text())
        assert len(names) == len(set(names)) == count
        expected.update('tests::m2::' + module + '::' + n for n in names)
    command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        command.append('--release')
    for identity in sorted(expected):
        command.extend(['--exact', identity])
    report = json.loads(run(command, 'native.json'))
    assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
    assert report['profile'] == args.profile and report['lock'] == 'verified' and report['status'] == 'ok'
    assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
    assert {row['identity'] for row in report['tests']} == expected
    assert all(row['trapCategory'] is None and row['outcome'] == 'passed' and
               not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    write(dict(schema='browniec.value-ownership-verification/v1', status='passed',
               recordedAt=datetime.now(timezone.utc).isoformat(), profile=args.profile,
               compilerSha256=digest(compiler), inputs=inputs, check=check, commands=commands,
               nativeOverrides=False, historicalResultReuse=False, nativeGroups=len(expected), nativeReport=report))
    print(f'PASS {args.profile}: {len(expected)} native ownership groups', flush=True)


if __name__ == '__main__':
    main()
