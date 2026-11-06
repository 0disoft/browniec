"""Verify typed value IR, Dead-state CFG and canonical owner/loan composition."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
MODULES = {
    'value_ir': None,
    'copy_ir': ['recursive_calls_never_treat_equal_static_ids_as_same_frame_identity',
                'both_drivers_execute_existing_copy_forms_and_mixed_repeated_arguments'],
    'slice_reborrow_calls': ['forests_joins_and_backedges_still_require_exact_lifo_restoration'],
    'reference_call_source': ['shared_formals_coexist_with_mutable_owned_and_record_arguments'],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--batch', choices=['core', 'regression', 'all'], default='all')
    args = parser.parse_args()
    modules = {k: v for k, v in MODULES.items() if args.batch == 'all' or (k == 'value_ir') == (args.batch == 'core')}
    output = ROOT / 'build/value-ir' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / (args.batch + '-receipt.json')

    def write(data):
        receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')

    write(dict(status='incomplete'))
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    assert not any(os.environ.get(k) for k in ['CL', '_CL_', 'LINK'])
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')] +
                   [f'tests/m2/{name}.fy' for name in modules] +
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-ir.py'])
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
    for module, selection in modules.items():
        names = re.findall(r'@test\s+fn void (\w+)\(', (ROOT / f'tests/m2/{module}.fy').read_text())
        assert len(names) == len(set(names))
        if selection is not None:
            assert set(selection) <= set(names)
            names = selection
        else:
            assert len(names) == 8
        expected.update('tests::m2::' + module + '::' + n for n in names)
    assert len(expected) == {'all': 12, 'core': 8, 'regression': 4}[args.batch]
    command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        command.append('--release')
    for identity in sorted(expected):
        command.extend(['--exact', identity])
    report = json.loads(run(command, args.batch + '-native.json'))
    assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
    assert report['profile'] == args.profile and report['lock'] == 'verified' and report['status'] == 'ok'
    assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
    assert {row['identity'] for row in report['tests']} == expected
    assert all(row['trapCategory'] is None and row['outcome'] == 'passed' and
               not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    write(dict(schema='browniec.value-ir-verification/v1', status='passed',
               recordedAt=datetime.now(timezone.utc).isoformat(), profile=args.profile, batch=args.batch,
               compilerSha256=digest(compiler), inputs=inputs, check=check, commands=commands,
               nativeOverrides=False, historicalResultReuse=False, nativeGroups=len(expected), nativeReport=report))
    print(f'PASS {args.profile}: {len(expected)} typed value and canonical regression groups', flush=True)


if __name__ == '__main__':
    main()
