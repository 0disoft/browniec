"""Verify exact-nominal subrecord return paths with focused native and tool-free CLI checks."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'core': {'struct_return_paths': 6},
          'regressions': {'struct_extract_source': 5, 'struct_result_source': 8,
                          'struct_call_assignment': 6}}
CLI = {'struct-return-paths': 148, 'struct-extract': 117,
       'struct-result-source': 166, 'struct-call-assignment': 148}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=GROUPS, required=True)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain' /
                        ('fairyc.exe' if os.name == 'nt' else 'fairyc'))
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = ROOT / 'build/m2-struct-return-paths' / args.phase / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    require(not os.environ.get('CL') and not os.environ.get('_CL_'), 'CL/_CL_ override')
    commands = []

    def run(command):
        command = list(map(str, command))
        commands.append(command)
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding='utf-8', timeout=600,
                                env={**os.environ, 'PYTHONUTF8': '1'})
        require(result.returncode == 0 and not result.stderr,
                f'{command}: {result.returncode}\n{result.stdout}\n{result.stderr}')
        return result.stdout.strip()

    baseline = run(['git', 'rev-parse', 'HEAD'])
    compiler_hash = digest(compiler)
    version = run([compiler, '--version'])
    check = run([compiler, 'check', '--locked'])
    paths = set(ROOT.glob('src/*.fy'))
    paths.update(ROOT / p for p in ['fairy.toml', 'fairy.lock', 'toolchain.json',
                                   'tools/verify-m2-struct-return-paths.py'])
    paths.update(ROOT.glob('tests/**/*.fy'))
    paths.update(ROOT.glob('tools/*.py'))
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    groups = GROUPS[args.phase]
    command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        command.append('--release')
    for name in groups:
        command.extend(['--file', 'tests/m2/' + name + '.fy'])
    native = json.loads(run(command))
    expected = sum(groups.values())
    require(native['status'] == 'ok' and native['count'] == native['passed'] == expected
            and native['failed'] == 0 and native['engine'] == 'native'
            and native['profile'] == args.profile, 'Native outcomes/profile mismatch')
    tests = native['tests']
    require(len(tests) == len({t['identity'] for t in tests}) == expected, 'Duplicate/missing tests')
    require(all(sum(t['identity'].startswith('tests::m2::' + name + '::') for t in tests)
                == count for name, count in groups.items()), 'Native selection mismatch')
    require(all(t['outcome'] == 'passed' and t['trapCategory'] is None
                and not t['stdoutBase64'] and not t['stderrBase64'] for t in tests), 'Native failure/output')
    print(f'PASS: {args.phase} {args.profile}: {expected} native groups', flush=True)
    build = None
    exe_hash = None
    cli = []
    if args.phase == 'regressions':
        build = run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []))
        exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
        exe_hash = digest(exe)
        for selection, count in CLI.items():
            print(run([os.sys.executable, '-B', ROOT / ('tools/check-m2-' + selection + '.py'),
                       '--exe', exe, '--profile', args.profile]), flush=True)
            report = ROOT / ('build/m2-' + selection) / args.profile / 'cli-receipt.json'
            cases = json.loads(report.read_text(encoding='utf-8'))
            require(cases['status'] == 'passed' and cases['exeSha256'] == exe_hash
                    and cases['count'] == len(cases['cases']) == count, 'CLI identity/count mismatch')
            cli.append(dict(selection=selection, count=count, receiptSha256=digest(report)))
    require(all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Inputs changed')
    require(digest(compiler) == compiler_hash, 'Compiler changed')
    lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    result = dict(schema='browniec.struct-return-paths/v1', status='passed',
                  recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
                  phase=args.phase, profile=args.profile, compilerVersion=version,
                  compilerSha256=compiler_hash, lockedCheck=check, commands=commands,
                  standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
                  sourceSha256=inputs, native=native, build=build, exeSha256=exe_hash, cli=cli,
                  limitations=['Focused Windows native/CLI checks only. Full suites, M0, Linux, '
                               'isolation, DLL, packaging, allocation instrumentation and performance not run.'])
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
