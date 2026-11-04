"""Verify immutable-image Static execution and affected Program/IR/return behavior."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
FILES = [f'tests/m2/{name}.fy' for name in
         ['static_execution', 'static_ir', 'program_image', 'slice_scalar_entry', 'slice_result_call_execution', 'slice_result_call_ir']] + ['tests/core.fy', 'tests/functions.fy']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--selection', choices=['all', 'statics', 'views', 'ranges', 'range-core', 'call-ir', 'call-proof'], default='all',
                        help='statics runs the changed image/proof/VM suites; all adds return and source regressions')
    args = parser.parse_args()
    profile = args.profile
    selections = {'all': FILES + ['tests/m2/static_views.fy', 'tests/m2/static_ranges.fy', 'tests/m2/static_call_ir.fy', 'tests/m2/static_call_admission.fy'],
                  'statics': FILES[:3], 'views': ['tests/m2/static_views.fy'],
                  'ranges': ['tests/m2/static_ranges.fy'] + FILES[:2],
                  'range-core': ['tests/m2/static_ranges.fy'],
                  'call-ir': ['tests/m2/static_call_ir.fy', FILES[2]],
                  'call-proof': ['tests/m2/static_call_admission.fy', 'tests/m2/static_ranges.fy', FILES[0], FILES[3]]}
    files = selections[args.selection]
    out = ROOT / 'build/static-execution' / profile / args.selection
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / 'receipt.json'
    write(receipt, {'status': 'incomplete'})
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_hash = digest(compiler)
    assert compiler_hash == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    production = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy'))
    assert all(b'\r' not in (ROOT / p).read_bytes() for p in production)
    paths = sorted(production + files + ['fairy.toml', 'fairy.lock', 'toolchain.json',
                                       'tools/verify-static-execution.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]

    def discovery():
        tree = [(p.relative_to(ROOT).as_posix(), digest(p)) for p in sorted((ROOT / 'tests').rglob('*.fy'))]
        value = hashlib.sha256(''.join(p + ' ' + h + '\n' for p, h in tree).encode()).hexdigest()
        return dict(count=len(tree), sha256=value)

    tree = discovery()
    captured = datetime.now(timezone.utc).isoformat()

    def run(command, cwd=ROOT):
        result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True,
                                text=True, encoding='utf-8', timeout=1200)
        if result.returncode:
            raise RuntimeError(f'{command}\n{result.stdout[-8000:]}\n{result.stderr[-3000:]}')
        return result

    mirror = out / 'lf-workspace'
    for path in production + ['fairy.toml', 'fairy.lock']:
        destination = mirror / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes((ROOT / path).read_bytes())
    checked = run([compiler, 'check', '--locked'], mirror).stdout.strip()
    command = [compiler.relative_to(ROOT).as_posix(), 'test', '--native',
               '--capture-output', '--json', '--locked']
    if profile == 'release':
        command.append('--release')
    expected = set()
    for path in files:
        command.extend(['--file', path])
        source = (ROOT / path).read_text(encoding='utf-8')
        names = re.findall(r'@test\s+fn void (\w+)\(', source)
        module = re.search(r'\bmodule\s+([\w:]+);', source).group(1)
        expected.update(module + '::' + name for name in names)
    result = run(command)
    (out / 'native.json').write_text(result.stdout, encoding='utf-8', newline='\n')
    (out / 'native-stderr.txt').write_text(result.stderr, encoding='utf-8', newline='\n')
    report = json.loads(result.stdout)
    assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
    assert report['status'] == 'ok' and report['profile'] == profile and report['lock'] == 'verified'
    assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
    assert {t['identity'] for t in report['tests']} == expected
    assert all(t['outcome'] == 'passed' and t['trapCategory'] is None and
               not t['stdoutBase64'] and not t['stderrBase64'] for t in report['tests'])
    assert all(digest(ROOT / i['path']) == i['sha256'] for i in inputs)
    assert discovery() == tree and digest(compiler) == compiler_hash
    write(receipt, dict(schema='browniec.static-execution-verification/v1', status='passed',
                       profile=profile, selection=args.selection, startingHead=run(['git', 'rev-parse', 'HEAD']).stdout.strip(),
                       platform=platform.platform(), compilerSha256=compiler_hash,
                       compilerVersion=run([compiler, '--version']).stdout.strip(),
                       inputSnapshotCapturedAt=captured, inputs=inputs, testDiscovery=tree,
                       lfMirror=dict(command=['build/toolchain/fairyc.exe' if os.name == 'nt' else 'build/toolchain/fairyc', 'check', '--locked'],
                                     workingDirectory=mirror.relative_to(ROOT).as_posix(),
                                     productionFiles=len(production), result=checked),
                       command=command, nativeGroups=len(expected), report=report,
                       nativeReportSha256=digest(out / 'native.json'),
                       nativeOverrides=False, historicalResultReuse=False))
    print(f'PASS {profile}: {len(expected)} native groups; {len(inputs)} matching inputs', flush=True)


if __name__ == '__main__':
    main()
