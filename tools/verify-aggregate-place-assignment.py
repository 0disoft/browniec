"""Verify aggregate source lowering, exact Fuel, nonlocal cleanup and CLI regression."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--phase', choices=['native', 'cli', 'all'], default='all')
    args = parser.parse_args()
    output = ROOT / 'build/aggregate-place-assignment' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / (args.phase + '-receipt.json')
    write(receipt, dict(status='incomplete'))
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))['platforms'][target]['sha256']
    assert not any(os.environ.get(k) for k in ['CL', '_CL_', 'LINK'])
    commands = []

    def run(command, path):
        command = list(map(str, command)); commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=600)
        path.write_bytes(done.stdout)
        path.with_suffix('.stderr.txt').write_bytes(done.stderr)
        assert done.returncode == 0, (command, done.stdout[-4000:], done.stderr[-2500:])
        return done.stdout

    check = run([compiler, 'check', '--locked'], output / 'check.txt').decode()
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')] +
                   ['tests/m2/aggregate_place_assignment.fy', 'tests/m2/public_fuel.fy',
                    'fairy.toml', 'fairy.lock', 'toolchain.json',
                    'tools/verify-aggregate-place-assignment.py', 'tools/check-aggregate-place-assignment.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    result = dict(schema='browniec.aggregate-place-assignment-verification/v1', status='incomplete',
                  profile=args.profile, phase=args.phase, recordedAt=datetime.now(timezone.utc).isoformat(),
                  compilerSha256=digest(compiler), inputs=inputs, check=check, commands=commands,
                  nativeOverrides=False, historicalResultReuse=False)
    if args.phase in ['native', 'all']:
        path = 'tests/m2/aggregate_place_assignment.fy'
        names = re.findall(r'@test\s+fn void (\w+)\(', (ROOT / path).read_text(encoding='utf-8'))
        expected = {'tests::m2::aggregate_place_assignment::' + n for n in names}
        assert len(expected) == 4
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked', '--file', path]
        if args.profile == 'release':
            command.append('--release')
        report = json.loads(run(command, output / 'native.json'))
        assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
        assert report['profile'] == args.profile and report['lock'] == 'verified' and report['status'] == 'ok'
        assert report['passed'] == len(report['tests']) == 4 and report['failed'] == 0
        assert {row['identity'] for row in report['tests']} == expected
        assert all(row['trapCategory'] is None and row['outcome'] == 'passed' and
                   not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
        result.update(nativeGroups=4, nativeReport=report)
        print(f'PASS {args.profile}: 4 aggregate source native groups', flush=True)
    if args.phase in ['cli', 'all']:
        run([sys.executable, '-B', 'tools/verify-public-fuel.py', '--profile', args.profile, '--phase', 'cli'], output / 'public-fuel.txt')
        public = json.loads((ROOT / 'build/public-fuel' / args.profile / 'cli-receipt.json').read_text(encoding='utf-8'))
        assert public['status'] == 'passed' and public['cliCases'] == 105
        run([sys.executable, '-B', 'tools/check-aggregate-place-assignment.py', '--profile', args.profile,
             '--exe', ROOT / public['artifact']['path']], output / 'cli.txt')
        feature = json.loads((output / 'cli-receipt.json').read_text(encoding='utf-8'))
        assert feature['status'] == 'passed' and feature['cliCases'] == 169
        result.update(cliCases=274, publicFuelReceipt='build/public-fuel/' + args.profile + '/cli-receipt.json',
                      aggregateCliReceipt=feature, artifact=public['artifact'])
        print(f'PASS {args.profile}: 274 CLI cases', flush=True)
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    result['status'] = 'passed'
    write(receipt, result)


if __name__ == '__main__':
    main()
