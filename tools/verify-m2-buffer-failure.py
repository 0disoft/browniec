"""Windows Buffer lifecycle, append, target-allocator failure and cleanup probe."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
MODULES = ['buffer_growth.fy', 'buffer_storage.fy', 'buffer_owners.fy', 'buffer_replacement.fy', 'buffer_append.fy', 'buffer_close.fy', 'buffer_truncate.fy', 'buffer_resize.fy', 'buffer_create.fy']
FIXTURES = ['main.fy', 'grow_resize.fy', 'create.fy', 'copy_out.fy']
MODES = [('normal-min', None), ('normal-preferred', None), ('abandon', None),
         ('oom-min', 320), ('oom-preferred', 384), ('append-success', None),
         ('append-capacity', None), ('append-identity', None), ('append-state', None),
         ('close-success', None), ('close-preflight', None), ('close-snapshot', None), ('close-generation', None),
         ('grow-append-preferred', None), ('grow-append-min', None),
         ('grow-append-oom-min', 320), ('grow-append-oom-preferred', 384),
         ('grow-append-abandon', None), ('grow-append-self', None), ('grow-append-preflight', None),
         ('truncate-success', None), ('truncate-bounds', None),
         ('truncate-generation', None), ('truncate-state', None),
         ('resize-success', None), ('resize-capacity', None),
         ('resize-generation', None), ('resize-state', None),
         ('grow-resize-preferred', None), ('grow-resize-min', None),
         ('grow-resize-oom-min', 320), ('grow-resize-oom-preferred', 384),
         ('grow-resize-abandon', None), ('grow-resize-truncated', None), ('grow-resize-preflight', None),
         ('create-success', None), ('create-preflight', None), ('create-state', None), ('create-slots', None),
         ('copy-out-success', None), ('copy-out-bounds', None), ('copy-out-identity', None), ('copy-out-pending', None)]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain/fairyc.exe')
    args = parser.parse_args()
    need(os.name == 'nt', 'This probe uses the Windows MSVC forced-include allocator seam')
    need(not os.environ.get('CL') and not os.environ.get('_CL_'), 'Ambient CL/_CL_ override')
    compiler = args.compiler.resolve(strict=True)
    fixture = ROOT / 'probes/m2-buffer-failure'
    output = ROOT / 'build/m2-buffer-failure'
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / ('receipt.json' if args.profile == 'all' else args.profile + '-receipt.json')
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    commands = []

    def run(command, cwd=ROOT, env=None, timeout=600):
        command = list(map(str, command))
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                                text=True, encoding='utf-8', timeout=timeout)
        row = dict(command=command, cwd=str(cwd), exit=result.returncode,
                   stdout=result.stdout, stderr=result.stderr)
        commands.append(row)
        need(result.returncode == 0 and not result.stderr, str(row))
        return result.stdout.strip()

    baseline = run(['git', 'rev-parse', 'HEAD'])
    tc = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    compiler_hash = sha(compiler)
    need(compiler_hash == tc['platforms']['windows/amd64']['sha256'], 'Compiler checksum')
    version = run([compiler, '--version'])
    need(tc['compiler']['revision'] in version and tc['sdk']['version'] in version, 'Compiler/SDK identity')
    locked = run([compiler, 'check', '--locked'])
    root_lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    sdk = [p for p in root_lock['packages'] if p['role'] != 'root']
    paths = [ROOT / 'src' / name for name in MODULES]
    paths += [fixture / 'src' / name for name in FIXTURES]
    paths += [fixture / 'fairy.toml', fixture / 'allocator_probe.h',
              ROOT / 'tools/verify-m2-buffer-failure.py', ROOT / 'fairy.toml',
              ROOT / 'fairy.lock', ROOT / 'toolchain.json']
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p)) for p in sorted(paths)]
    project = output / 'project'
    source = project / 'src'
    source.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(fixture / 'fairy.toml', project / 'fairy.toml')
    for name in FIXTURES:
        shutil.copyfile(fixture / 'src' / name, source / name)
    for name in MODULES:
        shutil.copyfile(ROOT / 'src' / name, source / name)
    need(all(sha(source / name) == sha(ROOT / 'src' / name) for name in MODULES),
         'Generated modules differ from production sources')
    need(all(sha(source / name) == sha(fixture / 'src' / name) for name in FIXTURES)
         and sha(project / 'fairy.toml') == sha(fixture / 'fairy.toml'), 'Generated fixture differs')
    need({p.name for p in source.rglob('*.fy')} == set(MODULES + FIXTURES)
         and len(list(source.rglob('*.fy'))) == len(MODULES) + len(FIXTURES), 'Unexpected generated source')
    generated = [dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p))
                 for p in sorted(source.glob('*.fy'))]
    run([compiler, 'check'], cwd=project)
    generated_lock = project / 'fairy.lock'
    lock_hash = sha(generated_lock)
    project_lock = json.loads(generated_lock.read_text(encoding='utf-8'))
    need([p for p in project_lock['packages'] if p['role'] != 'root'] == sdk, 'Generated SDK differs')
    header = fixture / 'allocator_probe.h'
    build_env = {**os.environ, 'CL': '/FI"' + str(header) + '"', 'PYTHONUTF8': '1'}
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    runtime_env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    runtime_env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    outcomes = []
    for profile in profiles:
        build = run([compiler, 'build', '--locked'] + (['--release'] if profile == 'release' else []),
                    cwd=project, env=build_env)
        exe = output / ('buffer-failure-' + profile + '.exe')
        shutil.copyfile(project / 'build/brownie-buffer-failure.exe', exe)
        binary_hash = sha(exe)
        cases = []
        for mode, target in MODES:
            env = dict(runtime_env)
            if target:
                env['BROWNIE_BUFFER_FAIL_BYTES'] = str(target)
            lines = run([exe, mode], cwd=empty, env=env, timeout=30).splitlines()
            need(len(lines) == 2 and lines[0] == 'buffer-failure: passed', 'Probe output')
            counters = json.loads(lines[1])
            single = (mode.startswith(('append-', 'close-', 'truncate-', 'resize-', 'create-', 'copy-out-'))
                      or mode in ('grow-append-preflight', 'grow-resize-preflight')) and mode != 'copy-out-pending'
            expected = dict(schema='browniec.buffer-allocator/v2', live=0, target=target or 0,
                            targetAttempts=2 if target else 0, failures=1 if target else 0,
                            attempts=3 if target else 1 if single else 2,
                            frees=1 if single else 2)
            need(counters == expected, 'Allocator counters: ' + str(counters))
            cases.append(dict(mode=mode, allocator=counters))
        need(sha(exe) == binary_hash, 'Executable changed')
        outcomes.append(dict(profile=profile, build=build, executable=exe.relative_to(ROOT).as_posix(),
                             exeSha256=binary_hash, cases=cases))
        print(f'PASS: {profile}: {len(MODES)} native lifecycle/allocator scenarios; exit live count zero', flush=True)
    need(all(sha(ROOT / p['path']) == p['sha256'] for p in inputs + generated), 'Inputs changed')
    need(sha(compiler) == compiler_hash and sha(generated_lock) == lock_hash, 'Toolchain/lock changed')
    result = dict(schema='browniec.buffer-failure/v1', status='passed',
                  recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
                  os=platform.platform(), profiles=profiles, compilerVersion=version,
                  compilerSha256=compiler_hash, lockedCheck=locked, standardLibraryLockIdentity=sdk,
                  sourceSha256=inputs, generatedSourceSha256=generated,
                  generatedLockSha256=lock_hash, forcedInclude=str(header), commands=commands,
                  profileReceipts=outcomes,
                  limitations=['Windows native probe with byte-identical copies of nine production modules. '
                               'Only FY system-heap allocations are counted, not all process memory. '
                               'Provider inconsistency injection, full suites, M0, Linux, isolation, DLL, '
                               'packaging and elapsed-time performance were not run. Guest Buffer is not implemented.'])
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
