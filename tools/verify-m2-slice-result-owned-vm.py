"""Verify private returned-view VM owned temporaries and ordinary CALL integration."""
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


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    args = parser.parse_args()
    output = ROOT / 'build/m2-slice-result-owned-vm' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    commands = []

    def run(command):
        command = list(map(str, command))
        commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                              encoding='utf-8', timeout=1800)
        if done.returncode:
            raise RuntimeError(f'{command}\n{done.stdout}\n{done.stderr}')
        return done.stdout

    commit = run(['git', 'rev-parse', 'HEAD']).strip()
    check = run([compiler, 'check', '--locked'])
    paths = run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '--',
                 'src', 'tests', 'tools', 'examples', 'fairy.toml', 'fairy.lock', 'toolchain.json']).splitlines()
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in sorted(set(paths))]
    compiler_hash = digest(compiler)
    version = run([compiler, '--version']).strip()
    assert not os.environ.get('CL') and not os.environ.get('_CL_'), 'Unexpected native compiler overrides'
    manifest = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    key = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert compiler_hash == manifest['platforms'][key]['sha256']
    modules = {'slice_result_runtime': 12, 'slice_result_owned_runtime': 3, 'slice_result_frames': 2, 'slice_result_execution': 9, 'slice_result_owned_execution': 7}
    identities = set()
    for module, count in modules.items():
        names = re.findall(r'@test\s+fn void (\w+)\(',
                           (ROOT / f'tests/m2/{module}.fy').read_text(encoding='utf-8'))
        assert len(names) == count
        identities.update(f'tests::m2::{module}::{name}' for name in names)
    native_command = [str(compiler), 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        native_command.append('--release')
    for module in modules:
        native_command.extend(['--file', f'tests/m2/{module}.fy'])
    batches = [dict(report=json.loads(run(native_command)), command=native_command)]
    seen = set()
    for index, batch in enumerate(batches):
        native = batch['report']
        tests = native['tests']
        assert native['schemaVersion'] == 'fairyc.test-report/v4' and native['engine'] == 'native'
        assert native['profile'] == args.profile and native['lock'] == 'verified'
        assert native['status'] == 'ok' and native['passed'] == len(tests) and native['failed'] == 0
        current = {t['identity'] for t in tests}
        assert not (seen & current) and len(current) == len(tests)
        seen |= current
        assert all(t['outcome'] == 'passed' and t['trapCategory'] is None and
                   not t['stdoutBase64'] and not t['stderrBase64'] for t in tests)
        report = output / f'native-batch-{index}.json'
        report.write_text(json.dumps(native, indent=2) + '\n', encoding='utf-8')
        batch['path'] = report.relative_to(ROOT).as_posix()
        batch['sha256'] = digest(report)
    assert seen == identities
    print(f'PASS: {args.profile}: 33 native groups in {len(batches)} recorded batch(es)', flush=True)
    build = run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []))
    artifact = output / ('browniec.exe' if os.name == 'nt' else 'browniec')
    shutil.copyfile(ROOT / 'build' / artifact.name, artifact)
    cli = []
    for kind, count in [('slice-result-origins', 88), ('temporary-array-borrow-arguments', 120), ('m1', 2007)]:
        checker = 'check-m1-cli.py' if kind == 'm1' else f'check-m2-{kind}.py'
        print(run([sys.executable, '-B', ROOT / 'tools' / checker,
                   '--exe', artifact, '--profile', args.profile]).strip(), flush=True)
        path = ROOT / ('build/m1' if kind == 'm1' else f'build/m2-{kind}') / args.profile / 'cli-receipt.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        assert data['status'] == 'passed' and data['count'] == count == len(data['cases'])
        assert data['exeSha256'] == digest(artifact)
        kept = output / f'{kind}-cli.json'
        shutil.copyfile(path, kept)
        cli.append(dict(matrix=kind, count=count, path=kept.relative_to(ROOT).as_posix(), sha256=digest(kept)))
    assert all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Input changed during verification'
    assert digest(compiler) == compiler_hash, 'Compiler changed during verification'
    data = dict(schema='browniec.slice-result-owned-vm-verification/v1', status='passed', profile=args.profile,
                recordedAt=datetime.now(timezone.utc).isoformat(), startingHead=commit,
                compilerSha256=compiler_hash, compilerVersion=version, os=platform.platform(), check=check,
                sourceSha256=inputs, nativeBatches=batches, nativeGroups=33,
                nativeResultReuse=False,
                nativeReuseNote=None,
                cli=cli, cliCases=sum(c['count'] for c in cli),
                artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)),
                build=build, commands=commands,
                limitations=['Native vm::run_slice_result executes owned arrays, temporary borrowed arguments, ordinary scalar/array CALLs and private 63/64/65 returned views. Records, native owned entry inputs and public result admission remain gated.',
                             'Public compile/VM admission, Program layout, prices and capability flags remain unchanged.',
                             'Full native M1 and other M2 suites, Linux, isolation, ABI, packaging, allocator instrumentation and native size/stack/timing not verified. M1 CLI is checked.'])
    receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {receipt.relative_to(ROOT).as_posix()}', flush=True)


if __name__ == '__main__':
    main()
