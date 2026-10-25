"""Run the real Fairy C native planner tests; this is not a layout model."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
FILES = ['tests/m2/struct_layout.fy', 'tests/m2/array_layout.fy']


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def verify(compiler):
    output = ROOT / 'build/m2-struct-layout'
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    write(receipt, dict(status='incomplete', startedAt=datetime.now(timezone.utc).isoformat()))
    require(not os.environ.get('CL') and not os.environ.get('_CL_'), 'Unexpected CL/_CL_ override')
    compiler = compiler.resolve(strict=True)
    compiler_hash = digest(compiler)
    commands = []

    def run(arguments):
        commands.append([str(compiler), *arguments])
        result = subprocess.run([str(compiler), *arguments], cwd=ROOT,
                                capture_output=True, text=True, encoding='utf-8', timeout=600)
        require(result.returncode == 0,
                f'Compiler failed ({result.returncode}): {arguments}\n{result.stdout}\n{result.stderr}')
        require(not result.stderr, f'Unexpected compiler stderr: {result.stderr}')
        return result.stdout.strip()

    version = run(['--version'])
    check = run(['check', '--locked'])
    paths = {ROOT / p for p in ['fairy.toml', 'fairy.lock', 'toolchain.json',
                               'tools/verify-m2-struct-layout.py', *FILES]}
    paths.update((ROOT / 'src').glob('*.fy'))
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    results = []
    for profile in ['development', 'release']:
        arguments = ['test', '--native', '--capture-output', '--json', '--locked']
        if profile == 'release':
            arguments.append('--release')
        for path in FILES:
            arguments.extend(['--file', path])
        native = json.loads(run(arguments))
        write(output / (profile + '-native.json'), native)
        require(native['status'] == 'ok' and native['count'] == native['passed'] == 14
                and native['failed'] == 0, f'Unexpected native outcomes: {profile}')
        tests = native['tests']
        require(len(tests) == len({t['identity'] for t in tests}) == 14,
                f'Unexpected or duplicate native identities: {profile}')
        require(sum(t['identity'].startswith('tests::m2::struct_layout::') for t in tests) == 8
                and sum(t['identity'].startswith('tests::m2::array_layout::') for t in tests) == 6,
                f'Unexpected native selection: {profile}')
        require(all(t['outcome'] == 'passed' and t['trapCategory'] is None
                    and not t['stdoutBase64'] and not t['stderrBase64'] for t in tests),
                f'Native failure or unexpected process output: {profile}')
        results.append(dict(profile=profile, nativeGroups=14, newStructGroups=8,
                            arrayRegressionGroups=6, nativeTests=native))
        print(f'PASS: {profile}: 8 struct + 6 array layout native groups', flush=True)
    require({t['identity'] for t in results[0]['nativeTests']['tests']}
            == {t['identity'] for t in results[1]['nativeTests']['tests']}, 'Profile selections differ')
    require(digest(compiler) == compiler_hash, 'Compiler changed during verification')
    require(all(digest(ROOT / item['path']) == item['sha256'] for item in inputs),
            'Verification input changed during execution')
    lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    baseline = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    write(receipt, dict(schema='browniec.m2-struct-layout/v1', status='passed',
          recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
          compilerVersion=version, compilerSha256=compiler_hash,
          standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
          os=platform.platform(), pythonVersion=sys.version.split()[0], lockedCheck=check,
          commands=commands, sourceSha256=inputs, results=results,
          limits=dict(records=32, fieldsPerRecord=16, structuralDepth=16,
                      dependencyFieldChecksAtMost=16384, payloadLimit='caller supplied per record'),
          artifacts='Tool-managed native test images; no new guest struct CLI artifact.',
          limitations=[
              'Private layout planning only: all six scalar fields and acyclic nested records.',
              'Bounds are private planner limits, not a full source profile or native C ABI.',
              'No source struct syntax, field names, initialization, payload allocation, codec, ownership, IR, VM or Fuel integration.',
              'Tagged/array/borrow/Buffer fields and empty record definitions are not supported.',
              'CLI, full native suites, M0, Linux, isolation, DLL, clean-machine packaging, allocation instrumentation and performance not rerun.',
              'The harness uses Python standard-library APIs without shell execution; this invocation verifies Windows only.'
          ]))
    print('PASS: build/m2-struct-layout/receipt.json', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path,
                        default=ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc'))
    args = parser.parse_args()
    verify(args.compiler)
