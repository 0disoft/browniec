"""Verify returned-view Fuel boundaries and affected ownership/CLI regressions."""
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
GROUPS = {
    'entry': {'slice_result_fuel': 6, 'slice_result_entry': 7},
    'regression': {'slice_result_execution': 9, 'slice_result_owned_execution': 7,
                   'slice_result_record_execution': 7},
    'runtime': {'slice_result_runtime': 12, 'slice_result_owned_runtime': 3,
                'slice_result_record_runtime': 3, 'slice_result_frames': 2},
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--batch', choices=['entry', 'regression', 'runtime', 'cli', 'all'], default='all')
    args = parser.parse_args()
    output = ROOT / 'build/m2-slice-result-fuel' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    commands = []

    def run(command, capture=None):
        command = list(map(str, command))
        commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                              encoding='utf-8', timeout=1800)
        if capture is not None:
            capture.write_text(done.stdout, encoding='utf-8')
        if done.returncode:
            raise RuntimeError(f'{command}\n{done.stdout}\n{done.stderr}')
        return done.stdout

    head = run(['git', 'rev-parse', 'HEAD']).strip()
    check = run([compiler, 'check', '--locked'])
    paths = run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '--',
                 'src', 'tests', 'tools', 'examples', 'fairy.toml', 'fairy.lock', 'toolchain.json']).splitlines()
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in sorted(set(paths))]
    compiler_hash = digest(compiler)
    version = run([compiler, '--version']).strip()
    manifest = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    key = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert compiler_hash == manifest['platforms'][key]['sha256']
    assert not os.environ.get('CL') and not os.environ.get('_CL_')

    def unchanged():
        assert digest(compiler) == compiler_hash
        assert all(digest(ROOT / p['path']) == p['sha256'] for p in inputs)

    def identities(groups):
        result = set()
        for module, count in groups.items():
            names = re.findall(r'@test\s+fn void (\w+)\(',
                               (ROOT / f'tests/m2/{module}.fy').read_text(encoding='utf-8'))
            assert len(names) == count
            result.update(f'tests::m2::{module}::{n}' for n in names)
        return result

    def validate(report, expected):
        assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
        assert report['profile'] == args.profile and report['lock'] == 'verified'
        assert report['status'] == 'ok' and report['failed'] == 0
        tests = report['tests']
        assert report['passed'] == len(tests) == len(expected)
        assert {t['identity'] for t in tests} == expected
        assert all(t['outcome'] == 'passed' and t['trapCategory'] is None and
                   not t['stdoutBase64'] and not t['stderrBase64'] for t in tests)

    selected = GROUPS if args.batch == 'all' else ({args.batch: GROUPS[args.batch]} if args.batch in GROUPS else {})
    for batch, groups in selected.items():
        receipt = output / f'{batch}-receipt.json'
        write(receipt, dict(status='incomplete', profile=args.profile, batch=batch))
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
        if args.profile == 'release':
            command.append('--release')
        for module in groups:
            command.extend(['--file', f'tests/m2/{module}.fy'])
        report_path = output / f'{batch}-native.json'
        report = json.loads(run(command, report_path))
        validate(report, identities(groups))
        unchanged()
        write(receipt, dict(status='passed', profile=args.profile, batch=batch,
              startingHead=head, recordedAt=datetime.now(timezone.utc).isoformat(),
              sourceSha256=inputs, compilerSha256=compiler_hash, compilerVersion=version,
              report=dict(path=report_path.relative_to(ROOT).as_posix(), sha256=digest(report_path)),
              nativeGroups=sum(groups.values()), commands=list(commands)))
        print(f'PASS: {args.profile}: {sum(groups.values())} native {batch} groups', flush=True)
    if args.batch in GROUPS:
        return

    receipt = output / 'receipt.json'
    write(receipt, dict(status='incomplete', profile=args.profile))
    batches = []
    for batch, groups in GROUPS.items():
        path = output / f'{batch}-receipt.json'
        saved = json.loads(path.read_text(encoding='utf-8'))
        assert saved['status'] == 'passed' and saved['profile'] == args.profile and saved['batch'] == batch
        assert saved['sourceSha256'] == inputs and saved['compilerSha256'] == compiler_hash
        assert saved['compilerVersion'] == version
        report_path = ROOT / saved['report']['path']
        assert digest(report_path) == saved['report']['sha256']
        validate(json.loads(report_path.read_text(encoding='utf-8')), identities(groups))
        batches.append(dict(batch=batch, nativeGroups=sum(groups.values()), startingHead=saved['startingHead'],
                       receipt=dict(path=path.relative_to(ROOT).as_posix(), sha256=digest(path)),
                       report=saved['report'], commands=saved['commands']))
    build = run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []))
    artifact = output / ('browniec.exe' if os.name == 'nt' else 'browniec')
    shutil.copyfile(ROOT / 'build' / artifact.name, artifact)
    cli = []
    for kind, count in [('slice-result-origins', 88), ('temporary-array-borrow-arguments', 120)]:
        print(run([sys.executable, '-B', ROOT / f'tools/check-m2-{kind}.py',
                   '--exe', artifact, '--profile', args.profile]).strip(), flush=True)
        path = ROOT / f'build/m2-{kind}' / args.profile / 'cli-receipt.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        assert data['status'] == 'passed' and data['count'] == count == len(data['cases'])
        assert data['exeSha256'] == digest(artifact)
        kept = output / f'{kind}-cli.json'
        shutil.copyfile(path, kept)
        cli.append(dict(matrix=kind, count=count, path=kept.relative_to(ROOT).as_posix(), sha256=digest(kept)))
    unchanged()
    write(receipt, dict(schema='browniec.slice-result-fuel-verification/v1', status='passed', profile=args.profile,
          recordedAt=datetime.now(timezone.utc).isoformat(), startingHead=head, os=platform.platform(),
          check=check, sourceSha256=inputs, compilerSha256=compiler_hash, compilerVersion=version,
          nativeBatches=batches, nativeGroups=56, nativeResultReuse=False,
          nativeNote='Fresh split batches; continuation requires identical inputs/compiler and validated report hashes.',
          cli=cli, cliCases=208, artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)),
          build=build, commands=commands,
          limitations=['Bounded returned-view metering; public result syntax and capabilities stay gated; CLI cap unchanged.',
                       'Full M1/other M2, Linux, isolation, ABI, packaging, allocator instrumentation and size/stack/timing not verified.']))
    print(f'PASS: {receipt.relative_to(ROOT).as_posix()}', flush=True)


if __name__ == '__main__':
    main()
