"""Verify private returned-view ownership transactions and unchanged public CLI admission."""
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
    output = ROOT / 'build/m2-slice-result-runtime' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    commands = []

    def run(command):
        command = list(map(str, command))
        commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                              encoding='utf-8', timeout=600)
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
    names = re.findall(r'@test\s+fn void (\w+)\(',
                       (ROOT / 'tests/m2/slice_result_runtime.fy').read_text(encoding='utf-8'))
    assert len(names) == 12
    identities = {'tests::m2::slice_result_runtime::' + n for n in names}
    native_command = [str(compiler), 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        native_command.append('--release')
    for name in names:
        native_command.extend(['--exact', 'tests::m2::slice_result_runtime::' + name])
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
    print(f'PASS: {args.profile}: 12 native groups in {len(batches)} recorded batch(es)', flush=True)
    build = run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []))
    artifact = output / ('browniec.exe' if os.name == 'nt' else 'browniec')
    shutil.copyfile(ROOT / 'build' / artifact.name, artifact)
    cli = []
    for kind, count in [('slice-result-origins', 88), ('temporary-array-borrow-arguments', 120)]:
        print(run([sys.executable, '-B', ROOT / 'tools' / f'check-m2-{kind}.py',
                   '--exe', artifact, '--profile', args.profile]).strip(), flush=True)
        path = ROOT / f'build/m2-{kind}' / args.profile / 'cli-receipt.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        assert data['status'] == 'passed' and data['count'] == count == len(data['cases'])
        assert data['exeSha256'] == digest(artifact)
        kept = output / f'{kind}-cli.json'
        shutil.copyfile(path, kept)
        cli.append(dict(matrix=kind, count=count, path=kept.relative_to(ROOT).as_posix(), sha256=digest(kept)))
    assert all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Input changed during verification'
    assert digest(compiler) == compiler_hash, 'Compiler changed during verification'
    data = dict(schema='browniec.slice-result-runtime-verification/v1', status='passed', profile=args.profile,
                recordedAt=datetime.now(timezone.utc).isoformat(), implementationCommit=commit,
                compilerSha256=compiler_hash, compilerVersion=version, os=platform.platform(), check=check,
                sourceSha256=inputs, nativeBatches=batches, nativeGroups=12,
                nativeResultReuse=False,
                nativeReuseNote=None,
                cli=cli, cliCases=sum(c['count'] for c in cli),
                artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)),
                build=build, commands=commands,
                limitations=['Real native CALL handoff, selected capture/owner lifetime and parent suspension; guest returned-view opcode dispatch remains unavailable.',
                             'Public compile/VM admission, Program layout, prices and capability flags remain unchanged.',
                             'Full native/M1/other M2, Linux, isolation, ABI, packaging, allocator instrumentation and native size/stack/timing not verified.'])
    receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {receipt.relative_to(ROOT).as_posix()}', flush=True)


if __name__ == '__main__':
    main()
