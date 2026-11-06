"""Verify private native value-frame layout, metering, ownership and cleanup."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
MODULES = ('value_frame_layout', 'value_frame_meter', 'value_frames')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    started = time.perf_counter()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    args = parser.parse_args()
    output = ROOT / 'build/value-frames' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'

    def write(data):
        receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')

    write(dict(status='incomplete'))
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_sha = digest(compiler)
    assert compiler_sha == json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))['platforms'][target]['sha256']
    assert not any(os.environ.get(k) for k in ['CL', '_CL_', 'LINK'])
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')] +
                   [f'tests/m2/{name}.fy' for name in MODULES] +
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-frames.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    commands = []

    def run(command, name, cwd=ROOT):
        command = list(map(str, command))
        command_started = time.perf_counter()
        commands.append(dict(argv=command, cwd='.' if cwd == ROOT else 'native-project',
                             temporarySelectedTestMirror=cwd != ROOT))
        done = subprocess.run(command, cwd=cwd, capture_output=True, timeout=900)
        commands[-1]['elapsedSeconds'] = round(time.perf_counter() - command_started, 3)
        (output / name).write_bytes(done.stdout)
        (output / (name + '.stderr.txt')).write_bytes(done.stderr)
        assert done.returncode == 0, (command, done.stdout[-4000:], done.stderr[-2500:])
        return done.stdout

    check = run([compiler, 'check', '--locked'], 'check.txt').decode('utf-8')
    expected = set()
    for module in MODULES:
        source = (ROOT / f'tests/m2/{module}.fy').read_text(encoding='utf-8')
        names = re.findall(r'@test\s+fn\s+void\s+(\w+)\s*\(', source)
        assert names and len(names) == len(set(names)), module
        identities = {'tests::m2::' + module + '::' + name for name in names}
        assert expected.isdisjoint(identities), module
        expected.update(identities)
    command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        command.append('--release')
    for identity in sorted(expected):
        command.extend(['--exact', identity])
    mirror_inputs = [row for row in inputs if row['path'].startswith(('src/', 'tests/m2/')) or
                     row['path'] in ('fairy.toml', 'fairy.lock')]
    # The compiler checks every test in its workspace before applying --exact.
    # Keep production/lock bytes unchanged, but include only this suite's tests.
    with tempfile.TemporaryDirectory(dir=output, prefix='native-') as temporary:
        mirror = Path(temporary)
        for row in mirror_inputs:
            destination = mirror / row['path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / row['path'], destination)
        assert all(digest(mirror / row['path']) == row['sha256'] for row in mirror_inputs)
        assert {path.relative_to(mirror).as_posix() for path in mirror.rglob('*') if path.is_file()} == {
            row['path'] for row in mirror_inputs}
        report = json.loads(run(command, 'native.json', cwd=mirror).decode('utf-8'))
        assert all(digest(mirror / row['path']) == row['sha256'] for row in mirror_inputs)
    assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
    assert report['profile'] == args.profile and report['lock'] == 'verified' and report['status'] == 'ok'
    assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
    assert {row['identity'] for row in report['tests']} == expected
    assert all(row['trapCategory'] is None and row['outcome'] == 'passed' and
               not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    assert digest(compiler) == compiler_sha
    write(dict(schema='browniec.value-frames-verification/v1', status='passed',
               recordedAt=datetime.now(timezone.utc).isoformat(), profile=args.profile,
               compilerSha256=compiler_sha, inputs=inputs, check=check, commands=commands,
               nativeWorkspace='byte-identical-production-selected-tests', nativeInputMirrorVerified=True,
               elapsedSeconds=round(time.perf_counter() - started, 3),
               nativeOverrides=False, historicalResultReuse=False, nativeGroups=len(expected), nativeReport=report))
    print(f'PASS {args.profile}: {len(expected)} native value frame groups', flush=True)


if __name__ == '__main__':
    main()
