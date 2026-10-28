"""Verify private Buffer owner descriptors, storage and growth reservations with focused native and tool-free CLI checks."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'buffer_owners': 8, 'buffer_storage': 7, 'buffer_growth': 8}
CLI = {}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain' /
                        ('fairyc.exe' if os.name == 'nt' else 'fairyc'))
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = ROOT / 'build/m2-buffer-owners' / args.profile
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
                                   'tools/verify-m2-buffer-owners.py'])
    paths.update(ROOT.glob('tests/**/*.fy'))
    paths.update(ROOT.glob('tools/*.py'))
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    groups = GROUPS
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
    print(f'PASS: {args.profile}: {expected} native groups', flush=True)
    build = None
    exe_hash = None
    cli = []
    build = run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []))
    exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
    exe_hash = digest(exe)
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    sentinels = [
        ('module main;fn i32 main(){return 42;}', None),
        ('module main;fn i32 main(){let i32[2] a=[21;2];return a[0]+a[1];}', None),
        ('module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return p.x;}', None),
        ('module main;fn i32 main(){let Buffer b=Buffer{};return 42;}', 'type'),
    ]
    for i, (source, error) in enumerate(sentinels):
        path = output / f'sentinel-{i}.brc'
        path.write_text(source, encoding='utf-8')
        for mode in ['check', 'run']:
            cmd = [str(exe), mode, str(path), '--json']
            if mode == 'run':
                cmd += ['--fuel', '1000000']
            commands.append(cmd)
            done = subprocess.run(cmd, cwd=empty, env=env, capture_output=True, timeout=15)
            require(done.returncode == (3 if error else 0) and not done.stderr, str(done))
            result = json.loads(done.stdout)
            require(result['schema'] == 'browniec.result/v1' and result['command'] == mode, 'CLI schema')
            require(result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), 'CLI status')
            require(result['return_i32'] == (42 if not error and mode == 'run' else None), 'CLI value')
            require((result['error']['kind'] == error) if error else result['error'] is None, 'CLI error')
            cli.append(dict(command=cmd, sourceSha256=hashlib.sha256(source.encode()).hexdigest(),
                            exit=done.returncode, result=result))
    print(f'PASS: {args.profile}: {len(cli)} CLI sentinels; Buffer syntax remains rejected', flush=True)
    require(all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Inputs changed')
    require(digest(compiler) == compiler_hash, 'Compiler changed')
    lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    result = dict(schema='browniec.buffer-owners/v1', status='passed',
                  recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
                  profile=args.profile, compilerVersion=version,
                  compilerSha256=compiler_hash, lockedCheck=check, commands=commands,
                  standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
                  sourceSha256=inputs, native=native, build=build, exeSha256=exe_hash, cli=cli,
                  limitations=['Private table-local Buffer descriptors over trusted caller-bound native roots; no guest syntax, root ownership enforcement, dynamic descriptor quota or VM integration. Allocator failure injection and allocation instrumentation not run. Focused Windows native/CLI checks only. Full suites, M0, Linux, '
                               'isolation, DLL, packaging, allocation instrumentation and performance not run.'])
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
