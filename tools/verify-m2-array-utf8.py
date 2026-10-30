"""Verify the private metered u8-array UTF-8 predicate in IR and native VM."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'array_utf8': 6, 'array_ir': 5, 'array_vm': 6, 'struct_vm': 8}
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
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--views', action='store_true', help='Verify private array range descriptors')
    selection.add_argument('--read-leases', action='store_true', help='Verify explicit array read sessions')
    selection.add_argument('--slice-vm', action='store_true', help='Verify private metered slice instructions and abort cleanup')
    selection.add_argument('--slices', action='store_true', help='Verify private shared read-only slice handles')
    selection.add_argument('--range-vm', action='store_true', help='Verify the private metered UTF-8 range instruction')
    selection.add_argument('--dynamic-vm', action='store_true', help='Verify private register-bounded UTF-8 ranges')
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    kind = 'array-slice-vm' if args.slice_vm else 'array-slices' if args.slices else 'array-dynamic-utf8' if args.dynamic_vm else 'array-range-utf8' if args.range_vm else 'array-read-leases' if args.read_leases else 'array-views' if args.views else 'array-utf8'
    output = ROOT / ('build/m2-' + kind) / args.profile
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
    pinned = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    platform_key = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    require(compiler_hash == pinned['platforms'][platform_key]['sha256'], 'Compiler checksum mismatch')
    version = run([compiler, '--version'])
    require(pinned['compiler']['revision'] in version and pinned['sdk']['version'] in version, 'Compiler/SDK mismatch')
    check = run([compiler, 'check', '--locked'])
    paths = set(ROOT.glob('src/*.fy'))
    paths.update(ROOT / p for p in ['fairy.toml', 'fairy.lock', 'toolchain.json',
                                   'tools/verify-m2-array-utf8.py'])
    paths.update(ROOT.glob('tests/**/*.fy'))
    paths.update(ROOT.glob('tools/*.py'))
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    groups = ({'slice_vm': 8, 'array_slices': 7, 'array_read_leases': 5, 'array_dynamic_utf8': 5, 'array_result_vm': 6, 'struct_vm': 8}
              if args.slice_vm else {'array_slices': 7, 'array_read_leases': 5, 'array_views': 5, 'array_owners': 5, 'array_result_vm': 6}
              if args.slices else {'array_dynamic_utf8': 5, 'array_range_utf8': 6, 'array_utf8': 6, 'array_ir': 5, 'struct_vm': 8}
              if args.dynamic_vm else {'array_range_utf8': 6, 'array_utf8': 6, 'array_ir': 5, 'array_vm': 6,
               'struct_vm': 8, 'array_read_leases': 5, 'array_views': 5}
              if args.range_vm else {'array_read_leases': 5, 'array_views': 5, 'array_owners': 5,
               'array_result_vm': 6, 'array_fill': 4, 'call_argument_copies': 9}
              if args.read_leases else {'array_views': 5, 'array_owners': 5, 'array_utf8': 6}
              if args.views else GROUPS)
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
    (output / 'native-report.json').write_text(json.dumps(native, indent=2) + '\n', encoding='utf-8')
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
    if args.views or args.read_leases or args.slices or args.slice_vm or args.range_vm or args.dynamic_vm:
        sentinels.extend([
            ('module main;fn i32 main(){let u8[1] a=[65;1];if(text::valid_utf8(a)){return 42;}return 0;}', None),
            ('module main;fn u8[1] make(){return [65;1];}fn i32 main(){if(text::valid_utf8(make()) && text::valid_utf8([0;1])){return 42;}return 0;}', None),
            ('module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] v=ref a;let usize n=v.capacity;return 42;}', 'type'),
        ])
    if args.dynamic_vm:
        sentinels.extend([
            ('module main;fn i32 main(){let u8[2] a=[65;2];if(text::valid_utf8(a[..])){return 42;}return 0;}', None),
            ('module main;fn i32 main(){let u32 lo=0;let u8[1] a=[65;1];let bool b=text::valid_utf8(a[lo..1]);return 42;}', 'type'),
        ])
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
    import shutil
    retained = output / exe.name
    shutil.copyfile(exe, retained)
    require(digest(retained) == exe_hash, 'Retained CLI mismatch')
    require(all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Inputs changed')
    require(digest(compiler) == compiler_hash, 'Compiler changed')
    lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    result = dict(schema='browniec.' + kind + '/v1', status='passed',
                  recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
                  profile=args.profile, compilerVersion=version,
                  compilerSha256=compiler_hash, lockedCheck=check, commands=commands,
                  standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
                  sourceSha256=inputs, native=native, build=build, exeSha256=exe_hash, cli=cli,
                  limitations=['Private array descriptors and UTF-8 backend selection; slice-vm selects private opcodes54/55/56, independently verified function-local origins and live masks, shared sessions, prepaid65537 open/4097+4*N scan/4097 close, and whole-invocation cleanup on success or VM error. No source borrow syntax or capability is added. slices selects sixteen independently retired read-only handles sharing one explicit session per root. No guest integration, automatic lexical cleanup, metering or capability is added. Slice pools and tickets remain table-local and require native caller ownership; raw session manipulation can invalidate them. range-vm selects opcode52 with literal endpoints and 65+4*K Fuel; dynamic-vm selects opcode53 with usize register bounds and worst-case65+4*N Fuel before endpoint reads, with named usize source endpoints exposed by the separate source selection. The scan is synchronous; this backend probe adds no guest syntax or capabilities. Bare descriptors do not pin roots; explicit per-root read sessions guard writes, transfer and cleanup. Guest borrow enforcement and origin table/backing association remain caller obligations. Focused native and CLI sentinels. Full suites, M0, Linux, '
                               'isolation, DLL, packaging, allocation instrumentation and performance not run.'])
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
