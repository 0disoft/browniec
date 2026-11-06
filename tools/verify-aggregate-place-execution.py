"""Verify aggregate places in both drivers, exact Fuel boundaries and retained guards."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
FILES = {'core': ['tests/m2/aggregate_place_execution.fy'],
         'regression': ['tests/m2/aggregate_place_ir.fy', 'tests/m2/record_place_execution.fy',
                        'tests/m2/slice_place_execution.fy', 'tests/m2/slice_result_call_ir.fy']}
EXACT = {
    'aggregate_place_ir': ['complete_admission_accepts_aggregates_while_legacy_only_adapters_keep_their_gates',
                           'exact_encoding_scalar_roles_nominals_and_builder_failures_are_checked_independently',
                           'available_destination_and_source_lifetimes_hold_across_loans_and_separate_call_frames'],
    'record_place_execution': ['ordinary_and_retained_record_compounds_match_independent_exact_fuel',
                               'retained_aggregate_guards_separate_record_nominals_from_protected_array_roots'],
    'slice_place_execution': ['ordinary_and_retained_slice_compounds_have_independent_exact_fuel'],
    'slice_result_call_ir': ['aggregate_fill_list_and_constructor_cannot_observe_opaque_call_identities'],
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
    out = ROOT / 'build/aggregate-place-execution' / args.profile
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
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-aggregate-place-execution.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    expected = set()
    for path in selected:
        names = set(re.findall(r'@test\s+fn void (\w+)\(', (ROOT / path).read_text()))
        choice = EXACT.get(Path(path).stem)
        if choice:
            assert set(choice) <= names
            names = set(choice)
        expected.update(path[:-3].replace('/', '::') + '::' + name for name in names)
    assert len(expected) == {'core': 5, 'regression': 7, 'all': 12}[args.batch]
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
    write(receipt, dict(status='passed', schema='browniec.aggregate-place-execution-verification/v1',
                        recordedAt=datetime.now(timezone.utc).isoformat(), profile=args.profile,
                        batch=args.batch, inputs=inputs, compilerSha256=digest(compiler), check=check,
                        commands=commands, report=report, nativeOverrides=False, historicalResultReuse=False))
    print(f'PASS {args.profile}: {len(expected)} native groups', flush=True)


if __name__ == '__main__':
    main()
