"""Verify the public Fuel ceiling, exact costs and tool-free CLI boundaries."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
MODULES = ['public_fuel', 'slice_public_canonical', 'slice_mutable_execution',
           'slice_result_fuel', 'slice_result_call_execution', 'reference_return_execution']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--phase', choices=['native', 'cli', 'all'], default='all')
    args = parser.parse_args()
    out = ROOT / 'build/public-fuel' / args.profile
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / (args.phase + '-receipt.json')
    write(receipt, {'status': 'incomplete'})
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    assert not any(os.environ.get(k) for k in ['CL', '_CL_', 'LINK'])
    key = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][key]['sha256']
    commands = []

    def run(command, capture=None):
        command = list(map(str, command)); commands.append(command)
        ran = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=1200)
        if capture:
            capture.write_text(ran.stdout, encoding='utf-8')
            capture.with_suffix('.stderr.txt').write_text(ran.stderr, encoding='utf-8')
        if ran.returncode:
            raise RuntimeError(f'{command}\n{ran.stdout[-6000:]}\n{ran.stderr[-3000:]}')
        return ran.stdout

    head = run(['git', 'rev-parse', 'HEAD']).strip()
    version = run([compiler, '--version']).strip()
    check = run([compiler, 'check', '--locked'])
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy')] +
                   [f'tests/m2/{name}.fy' for name in MODULES] +
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-public-fuel.py',
                    'tools/check-m1-cli.py', 'examples/fuel-wide-call.brc',
                    'tests/m2/struct_parameters_source.fy'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    tree = [(p.relative_to(ROOT).as_posix(), digest(p)) for p in sorted((ROOT / 'tests').rglob('*.fy'))]
    tree_digest = hashlib.sha256(''.join(p + ' ' + h + '\n' for p, h in tree).encode()).hexdigest()
    result = dict(schema='browniec.public-fuel-verification/v1', status='incomplete', profile=args.profile,
                  phase=args.phase, startingHead=head, recordedAt=datetime.now(timezone.utc).isoformat(),
                  platform=platform.platform(), inputs=inputs, testDiscovery=dict(count=len(tree), sha256=tree_digest),
                  compilerSha256=digest(compiler), compilerVersion=version, check=check,
                  nativeOverrides=False, historicalResultReuse=False, commands=commands)
    if args.phase in ['native', 'all']:
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
        if args.profile == 'release':
            command.append('--release')
        expected = set()
        for name in MODULES:
            command.extend(['--file', f'tests/m2/{name}.fy'])
            names = re.findall(r'@test\s+fn void (\w+)\(', (ROOT / f'tests/m2/{name}.fy').read_text())
            expected.update(f'tests::m2::{name}::{n}' for n in names)
        report = json.loads(run(command, out / 'native.json'))
        assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
        assert report['status'] == 'ok' and report['profile'] == args.profile and report['lock'] == 'verified'
        assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
        assert {t['identity'] for t in report['tests']} == expected
        assert all(t['outcome'] == 'passed' and t['trapCategory'] is None and
                   not t['stdoutBase64'] and not t['stderrBase64'] for t in report['tests'])
        result.update(nativeGroups=len(expected), nativeReport=report)
        print(f'PASS {args.profile}: {len(expected)} native groups', flush=True)
    if args.phase in ['cli', 'all']:
        command = [compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else [])
        result['build'] = run(command, out / 'build.txt')
        artifact = out / ('browniec.exe' if os.name == 'nt' else 'browniec')
        shutil.copyfile(ROOT / 'build' / artifact.name, artifact)
        empty = out / 'no-runtime-tools'; empty.mkdir(exist_ok=True)
        env = {k: str(empty) for k in ['PATH', 'TEMP', 'TMP']}
        env.update({k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ})
        rows = []

        def invoke(source, extra=(), error=None, mode='run'):
            path = out / f'case-{len(rows):03}.brc'; path.write_bytes(source.encode())
            command = [str(artifact), mode, str(path), '--json', *map(str, extra)]
            done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=30)
            data = json.loads(done.stdout)
            code = 2 if error == 'usage' else 5 if error else 0
            assert done.returncode == code and not done.stderr, (command, done)
            assert data['schema'] == 'browniec.result/v1' and data['command'] == mode
            assert data['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), data
            assert data['return_i32'] == (None if error or mode == 'check' else 42), data
            assert data['error']['kind'] == error if error else data['error'] is None, data
            rows.append(dict(command=command, sourceSha256=hashlib.sha256(source.encode()).hexdigest(),
                             exit=done.returncode, result=data))

        scalar = 'module main;fn i32 main(){return 42;}'
        invoke(scalar)
        for budget in [0, 1, 2, 256, 1000000, 1000001, 16000000]:
            invoke(scalar, ['--fuel', budget], 'fuel' if budget < 2 else None)
        for raw in ['-1', '16000001', '9223372036854775807', '9223372036854775808',
                    '18446744073709551615', '184467440737095516150', '', '1.5', 'nope']:
            invoke(scalar, ['--fuel', raw], 'usage')
        for extra, mode in [(['--fuel'], 'run'), (['--fuel', 1, '--fuel', 2], 'run'),
                            (['--json'], 'run'), (['--fuel', 2], 'check')]:
            invoke(scalar, extra, 'usage', mode)
        wide = (ROOT / 'examples/fuel-wide-call.brc').read_text().strip()
        invoke(wide, mode='check')
        invoke(wide, ['--fuel', 1000000], 'fuel')
        invoke(wide, ['--fuel', 16000000])
        # Existing aggregate workloads previously needed native-only budgets.
        fixtures = re.findall(r'value\(b"([^"\n]+)",\d+\);',
                              (ROOT / 'tests/m2/struct_parameters_source.fy').read_text())
        costly = [s for s in fixtures if 'while(i<42)' in s or 'fn i32 sum(P a,P b,P c,P d,P e,P f,P g,P h)' in s]
        assert len(costly) == 4
        for source in costly:
            invoke(source, ['--fuel', 1000000], 'fuel')
            invoke(source, ['--fuel', 16000000])
        # Independent numeric oracles for current source features. Exercise the
        # actual public route (not a forced private entry) at all three boundaries.
        precise = [
            ('module main;fn i32 main(){let a=[20,22];return a[0]+a[1];}', 66017),
            ('module main;fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){return take([20,22]);}', 66340),
            ('module main;fn i32[2] make(){return [20,22];}fn i32 main(){let a=make();return a[0]+a[1];}', 66083),
            ('module main;fn i32 main(){var a=[0;2];a=[20,22];return a[0]+a[1];}', 66083),
            ('module main;fn i32 main(){return [20,42][1];}', 65978),
            ('module main;fn i32 main(){return [42;2][1];}', 65698),
            ('module main;fn i32 main(){let ref u8[] marker=b"*";return [20,42][1];}', 410063),
            ('module main;fn i32 main(){let ref u8[] marker=b"*";return [42;2][1];}', 409783),
        ]
        for source, price in precise:
            invoke(source, ['--fuel', price - 1], 'fuel')
            invoke(source, ['--fuel', price])
            invoke(source, ['--fuel', price + 1])
        version_run = subprocess.run([str(artifact), '--version', '--json'], cwd=empty, env=env,
                                     capture_output=True, timeout=15)
        metadata = json.loads(version_run.stdout)
        assert version_run.returncode == 0 and not version_run.stderr
        assert metadata['fuel_default'] == 256 and metadata['fuel_limit'] == 16000000
        assert not metadata.get('array_slice_results', False) and not metadata['restricted'] and not metadata['embed']
        result.update(cliCases=len(rows) + 1, cli=rows, version=metadata,
                      artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)),
                      runtimeEnvironment='cleared; tool-free PATH')
        print(f'PASS {args.profile}: {len(rows) + 1} CLI cases', flush=True)
    assert all(digest(ROOT / i['path']) == i['sha256'] for i in inputs)
    current = [(p.relative_to(ROOT).as_posix(), digest(p)) for p in sorted((ROOT / 'tests').rglob('*.fy'))]
    assert current == tree
    result['status'] = 'passed'
    write(receipt, result)
    print(f'PASS {receipt.relative_to(ROOT).as_posix()}', flush=True)


if __name__ == '__main__':
    main()
