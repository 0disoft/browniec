"""Verify prepaid native aggregate place snapshots, stores and legacy Fuel stability."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
FILES = {'core': ['tests/m2/aggregate_place_vm.fy'],
         'regression': ['tests/m2/fuel_schedule.fy', 'tests/m2/record_place_vm.fy',
                        'tests/m2/aggregate_place_ir.fy', 'tests/m2/array_list_execution.fy']}
EXACT = {
    'record_place_vm': ['six_scalar_domains_prepay_each_effect_at_independent_exact_prices'],
    'aggregate_place_ir': ['executable_image_reference_and_native_adapters_reject_before_fuel_or_backing_work'],
    'array_list_execution': ['six_scalar_domains_execute_at_independently_computed_exact_fuel'],
}



def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--batch', choices=['core', 'regression', 'all'], default='all')
    args = parser.parse_args()
    selected = FILES['core'] + FILES['regression'] if args.batch == 'all' else FILES[args.batch]
    out = ROOT / 'build/aggregate-place-vm' / args.profile
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / (args.batch + '-receipt.json')
    write(receipt, dict(status='incomplete'))
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    commands = []

    def run(command, capture):
        command = list(map(str, command)); commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=600)
        capture.write_bytes(done.stdout)
        capture.with_suffix('.stderr.txt').write_bytes(done.stderr)
        assert done.returncode == 0, (command, done.stdout[-6000:], done.stderr[-2000:])
        return done.stdout

    check = run([compiler, 'check', '--locked'], out / 'check.txt').decode()
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')] + selected +
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-aggregate-place-vm.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    expected = set()
    for path in selected:
        names = set(re.findall(r'@test\s+fn void (\w+)\(', (ROOT / path).read_text()))
        choice = EXACT.get(Path(path).stem)
        if choice:
            assert set(choice) <= names
            names = set(choice)
        expected.update(path[:-3].replace('/', '::') + '::' + name for name in names)
    assert len(expected) == {'core': 9, 'regression': 6, 'all': 15}[args.batch]
    command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        command.append('--release')
    for identity in sorted(expected):
        command.extend(['--exact', identity])
    report = json.loads(run(command, out / (args.batch + '.json')))
    assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
    assert report['profile'] == args.profile and report['lock'] == 'verified' and report['status'] == 'ok'
    assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
    assert {row['identity'] for row in report['tests']} == expected
    assert all(row['outcome'] == 'passed' and row['trapCategory'] is None and
               not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    write(receipt, dict(status='passed', schema='browniec.aggregate-place-vm-verification/v1',
                        recordedAt=datetime.now(timezone.utc).isoformat(), profile=args.profile,
                        batch=args.batch, inputs=inputs, compilerSha256=digest(compiler), check=check,
                        commands=commands, report=report, nativeOverrides=False, historicalResultReuse=False))
    print(f'PASS {args.profile}: {len(expected)} native groups', flush=True)


if __name__ == '__main__':
    main()
