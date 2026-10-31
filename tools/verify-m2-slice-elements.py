"""Verify private typed slice IR while retaining public readonly u8 execution."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'slice_elements': 4, 'slice_parameters': 4, 'slice_builders': 5,
          'slice_borrow_ir': 4, 'slice_borrow_flow': 5, 'slice_lifecycle_vm': 6}
MATRICES = {'array-slice-parameters': 64, 'array-slice-parameter-source': 74,
            'array-slice-alias': 120, 'array-slice-sub': 124}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    args = parser.parse_args()
    output = ROOT / 'build/m2-slice-elements' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    pinned = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    compiler_hash = digest(compiler)
    require(compiler_hash == pinned['platforms']['windows/amd64' if os.name == 'nt' else 'linux/amd64']['sha256'], 'Compiler checksum')
    require(not os.environ.get('CL') and not os.environ.get('_CL_'), 'CL/_CL_ override')
    commands = []

    def run(command):
        command = list(map(str, command))
        commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                              encoding='utf-8', timeout=600,
                              env={**os.environ, 'PYTHONUTF8': '1'})
        require(done.returncode == 0 and not done.stderr,
                f'{command}: {done.returncode}\n{done.stdout}\n{done.stderr}')
        return done.stdout.strip()

    baseline = run(['git', 'rev-parse', 'HEAD'])
    version = run([compiler, '--version'])
    require(pinned['compiler']['revision'] in version and pinned['sdk']['version'] in version, 'Compiler/SDK version')
    check = run([compiler, 'check', '--locked'])
    paths = set(ROOT.glob('src/*.fy')) | set(ROOT.glob('tests/**/*.fy')) | set(ROOT.glob('tools/*.py'))
    paths.update(ROOT / name for name in ['fairy.toml', 'fairy.lock', 'toolchain.json'])
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    flags = ['--release'] if args.profile == 'release' else []
    native = []
    for name, count in GROUPS.items():
        report = json.loads(run([compiler, 'test', '--native', '--capture-output', '--json',
                                 '--locked', *flags, '--file', f'tests/m2/{name}.fy']))
        require(report['status'] == 'ok' and report['count'] == report['passed'] == count
                and report['failed'] == 0 and report['engine'] == 'native'
                and report['profile'] == args.profile, name)
        tests = report['tests']
        require(len(tests) == len({t['identity'] for t in tests}) == count
                and all(t['identity'].startswith(f'tests::m2::{name}::')
                        and t['outcome'] == 'passed' and t['trapCategory'] is None
                        and not t['stdoutBase64'] and not t['stderrBase64'] for t in tests), name)
        native.append(report)
        (output / f'{name}.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(f'PASS: {args.profile}: {name}: {count} native groups', flush=True)
    build = run([compiler, 'build', '--locked', *flags])
    exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
    retained = output / exe.name
    shutil.copyfile(exe, retained)
    exe_hash = digest(retained)
    matrices = []
    for name, count in MATRICES.items():
        run([sys.executable, '-B', ROOT / f'tools/check-m2-{name}.py',
             '--exe', retained, '--profile', args.profile])
        directory = 'array-slice-parameters-public' if name == 'array-slice-parameters' else name
        path = ROOT / f'build/m2-{directory}' / args.profile / 'cli-receipt.json'
        report = json.loads(path.read_text(encoding='utf-8'))
        require(report['status'] == 'passed' and report['count'] == count
                and report['exeSha256'] == exe_hash, name)
        shutil.copyfile(path, output / f'{name}-cli.json')
        matrices.append(dict(selection=name, count=count, receiptSha256=digest(path)))
        print(f'PASS: {args.profile}: {name}: {count} CLI cases', flush=True)
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    boundaries = []
    for tag in ['i32', 'bool', 'i64', 'u32', 'usize']:
        for declaration in [f'fn i32 f(ref {tag}[] p){{return 42;}}fn i32 main(){{return 42;}}',
                            f'fn i32 main(){{let {tag}[1] a=[{"true" if tag == "bool" else "42"};1];let ref {tag}[] p=ref a;return 42;}}']:
            path = output / f'boundary-{len(boundaries)}.brc'
            path.write_text('module main;' + declaration, encoding='utf-8')
            for mode in ['check', 'run']:
                command = [str(retained), mode, str(path), '--json']
                commands.append(command)
                done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
                result = json.loads(done.stdout)
                require(done.returncode == 3 and not done.stderr and result['status'] == 'error'
                        and result['command'] == mode and result['schema'] == 'browniec.result/v1'
                        and result['return_i32'] is None and result['error']['kind'] in ['syntax', 'type'], str(result))
                boundaries.append(dict(command=command, sourceSha256=digest(path), exit=done.returncode, result=result))
    require(all(digest(ROOT / row['path']) == row['sha256'] for row in inputs), 'Inputs changed')
    require(digest(compiler) == compiler_hash and digest(retained) == exe_hash, 'Artifact changed')
    report = dict(schema='browniec.slice-elements/v1', status='passed', profile=args.profile,
                  recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
                  compilerVersion=version, compilerSha256=compiler_hash, lockedCheck=check,
                  sourceSha256=inputs, commands=commands, native=native, build=build,
                  retainedArtifact=dict(path=retained.relative_to(ROOT).as_posix(), sha256=exe_hash, bytes=retained.stat().st_size),
                  matrices=matrices, boundaries=boundaries, nativeGroups=sum(GROUPS.values()),
                  cliCases=sum(MATRICES.values()) + len(boundaries),
                  limitations=['Private typed IR inspection only; public source/VM remain readonly u8-only.',
                               'No full native/M1/other M2, Linux, M0, packaging, isolation or performance rerun.'])
    receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {args.profile}: {report["nativeGroups"]} native groups; {report["cliCases"]} CLI cases', flush=True)


if __name__ == '__main__':
    main()
