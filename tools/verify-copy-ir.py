"""Verify independently derived IR copy strategies, ownership lifetimes and public costs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SELECTED = {
    'copy_ir': None,
    'aggregate_copy': None,
    'array_ir': None,
    'struct_ir': None,
    'struct_parameters_ir': [
        'call_arguments_require_live_immutable_caller_owned_exact_nominal_records',
        'returns_joins_and_backedges_preserve_parameter_lifetimes',
        'mixed_array_scalar_record_calls_array_results_and_recursion_verify',
    ],
    'struct_function_ir': [
        'every_record_opcode_is_verified_in_its_declared_function',
        'destination_and_source_ownership_are_independent_of_layout_and_liveness',
    ],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--phase', choices=['native', 'cli', 'all'], default='all')
    parser.add_argument('--batch', choices=['all', 'core', 'regression'], default='all')
    args = parser.parse_args()
    selected = {k: v for k, v in SELECTED.items() if args.batch == 'all' or (k == 'copy_ir') == (args.batch == 'core')}
    out = ROOT / 'build/copy-ir' / args.profile
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / (args.phase + '-' + args.batch + '-receipt.json')
    write(receipt, {'status': 'incomplete'})
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    platform = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][platform]['sha256']
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    commands = []

    def run(command, capture=None):
        command = list(map(str, command)); commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=900)
        if capture:
            capture.write_text(done.stdout, encoding='utf-8', newline='\n')
            capture.with_suffix('.stderr.txt').write_text(done.stderr, encoding='utf-8', newline='\n')
        assert done.returncode == 0, (command, done.stdout[-6000:], done.stderr[-2000:])
        return done.stdout

    check = run([compiler, 'check', '--locked'])
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')] +
                   [f'tests/m2/{name}.fy' for name in selected] +
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-copy-ir.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    result = dict(status='incomplete', schema='browniec.copy-ir-verification/v1',
                  recordedAt=datetime.now(timezone.utc).isoformat(), profile=args.profile, phase=args.phase, batch=args.batch,
                  inputs=inputs, check=check, compilerSha256=digest(compiler),
                  nativeOverrides=False, historicalResultReuse=False, commands=commands)
    if args.phase in ['native', 'all']:
        expected = set()
        for module, selection in selected.items():
            names = set(re.findall(r'@test\s+fn void (\w+)\(', (ROOT / f'tests/m2/{module}.fy').read_text()))
            if selection is not None:
                assert set(selection) <= names
                names = set(selection)
            expected.update(f'tests::m2::{module}::{name}' for name in names)
        assert len(expected) == {'all': 30, 'core': 8, 'regression': 22}[args.batch]
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
        if args.profile == 'release':
            command.append('--release')
        for identity in sorted(expected):
            command.extend(['--exact', identity])
        report = json.loads(run(command, out / ('native-' + args.batch + '.json')))
        assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
        assert report['profile'] == args.profile and report['lock'] == 'verified' and report['status'] == 'ok'
        assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
        assert {row['identity'] for row in report['tests']} == expected
        assert all(row['trapCategory'] is None and not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
        result.update(nativeGroups=len(expected), nativeReport=report)
        print(f'PASS {args.profile}: {len(expected)} native groups', flush=True)
    if args.phase in ['cli', 'all']:
        run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []), out / 'build.txt')
        artifact = out / ('browniec.exe' if os.name == 'nt' else 'browniec')
        shutil.copyfile(ROOT / 'build' / artifact.name, artifact)
        empty = out / 'no-runtime-tools'; empty.mkdir(exist_ok=True)
        env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
        env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
        rows = []

        def invoke(source, budget, failure=False):
            path = out / f'case-{len(rows):03}.brc'; path.write_bytes(source.encode())
            done = subprocess.run([str(artifact), 'run', str(path), '--json', '--fuel', str(budget)],
                                  cwd=empty, env=env, capture_output=True, timeout=30)
            data = json.loads(done.stdout)
            assert done.returncode == (5 if failure else 0) and not done.stderr, data
            assert data['status'] == ('error' if failure else 'completed')
            assert data['error']['kind'] == 'fuel' if failure else data['error'] is None
            assert data['return_i32'] == (None if failure else 42), data
            rows.append(dict(sourceSha256=hashlib.sha256(source.encode()).hexdigest(), budget=budget, result=data))

        array = 'module main;fn i32 main(){var a=[42;1];a=a;return a[0];}'
        record = 'module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=42};p=p;return p.x;}'
        # Independent pre-existing opcode prices: array self assignment costs85;
        # record self assignment retains snapshot60545, including normalization.
        for source, ordinary, retained in [(array, 65779, 409865), (record, 213577, 557663)]:
            marker = source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1)
            for text, price in [(source, ordinary), (marker, retained)]:
                for budget in [0, price - 1, price, price + 1]:
                    invoke(text, budget, budget < price)
        for source in [
            'module main;fn i32 main(){var a=[true;1];a=a;if(a[0]){return 42;}return 0;}',
            'module main;struct P{i32 x;}fn i32 take(i32[1] a,P p){return a[0]+p.x;}fn i32 main(){let a=[20;1];let P p=P{.x=22};return take(a,p);}',
        ]:
            invoke(source, 16000000)
            invoke(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1), 16000000)
        for source in [
            'module main;fn i32 main(){var a=[20;2];let b=a;a=b;a=a;return a[0]+22;}',
            'module main;struct P{i32 x;bool b;}fn i32 main(){var P p=P{.x=20,.b=true};let P q=p;p=q;p=p;return p.x+22;}',
            'module main;struct I{i32 x;}struct O{I a;I b;}fn i32 main(){var O p=O{.a=I{.x=20},.b=I{.x=42}};p.a=p.b;p.b=p.a;p.a=p.a;return p.a.x;}',
            'module main;struct P{i32 x;}fn i32 use(i32[1] a,P p,i32[1] b,P q){return a[0]+p.x+b[0]+q.x;}fn i32 main(){let a=[10;1];let P p=P{.x=11};return use(a,p,a,p);}',
        ]:
            invoke(source, 16000000)
            invoke(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1), 16000000)
        result.update(cliCases=len(rows), cli=rows, artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)))
        print(f'PASS {args.profile}: {len(rows)} tool-free CLI cases', flush=True)
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    result['status'] = 'passed'
    write(receipt, result)


if __name__ == '__main__':
    main()
