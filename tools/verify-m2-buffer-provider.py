"""Inject four safe provider inconsistencies into the pinned Windows native runtime."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
MODES = ['capacity', 'copy', 'append', 'resize']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def inject(source):
    # Anchor complete native function tails, never Fairy product logic. A compiler
    # layout change must fail closed instead of silently omitting an injection.
    edits = [
        ('    output->length = 0;\n    return FY_STD_ALLOC_OK_V0;',
         '    if (capacity == 384 && brownie_provider_fault("capacity")) output->block.size = 320;\n'),
        ('    buffer->length = new_length;\n    return FY_STD_ALLOC_OK_V0;\n}\n\nuint32_t fy_std_buffer_resize_zeroed_v0',
         '    if (buffer->block.size == 384 && count == 4 && brownie_provider_fault("copy")) buffer->length--;\n'
         '    if (buffer->block.size == 384 && count == 253 && brownie_provider_fault("append")) return FY_STD_ALLOC_INVALID_ARGUMENT_V0;\n'),
        ('    buffer->length = new_length;\n    return FY_STD_ALLOC_OK_V0;\n}\n\nuint32_t fy_std_buffer_truncate_v0',
         '    if (buffer->block.size == 384 && new_length == 257 && brownie_provider_fault("resize")) buffer->length--;\n'),
    ]
    for anchor, hook in edits:
        need(source.count(anchor) == 1, 'Provider injection anchor changed: ' + anchor)
        source = source.replace(anchor, anchor.replace('    return FY_STD_ALLOC_OK_V0;', hook + '    return FY_STD_ALLOC_OK_V0;', 1), 1)
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows MSVC provider probe')
    need(not os.environ.get('CL') and not os.environ.get('_CL_'), 'Ambient CL/_CL_ override')
    out = ROOT / 'build/m2-buffer-provider'
    source_dir = out / 'project/src'
    source_dir.mkdir(parents=True, exist_ok=True)
    receipt = out / ('receipt.json' if args.profile == 'all' else args.profile + '-receipt.json')
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    commands = []

    def run(command, cwd=ROOT, env=None, emit=False, timeout=180):
        command = list(map(str, command))
        p = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, encoding='utf-8', timeout=timeout)
        commands.append(dict(command=command, cwd=str(cwd), exit=p.returncode,
                             stdoutSha256=hashlib.sha256(p.stdout.encode()).hexdigest() if emit else None,
                             stdout='<emitted C retained separately>' if emit else p.stdout, stderr=p.stderr))
        need(p.returncode == 0 and not p.stderr, str(commands[-1]))
        return p.stdout

    tc = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    compiler = ROOT / 'build/toolchain/fairyc.exe'
    need(sha(compiler) == tc['platforms']['windows/amd64']['sha256'], 'Compiler checksum')
    version = run([compiler, '--version'])
    need(tc['compiler']['revision'] in version and tc['sdk']['version'] in version, 'Compiler/SDK identity')
    locked = run([compiler, 'check', '--locked'])
    baseline = run(['git', 'rev-parse', 'HEAD']).strip()
    spec = importlib.util.spec_from_file_location('lifecycle', ROOT / 'tools/verify-m2-buffer-failure.py')
    shared = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(shared)
    fixture = ROOT / 'probes/m2-buffer-provider'
    inputs = [ROOT / 'src' / name for name in shared.MODULES]
    inputs += [fixture / 'src/main.fy', fixture / 'fairy.toml', fixture / 'provider_probe.h',
               ROOT / 'probes/m2-buffer-failure/allocator_probe.h', Path(__file__),
               ROOT / 'tools/verify-m2-buffer-failure.py', ROOT / 'toolchain.json', ROOT / 'fairy.toml', ROOT / 'fairy.lock']
    hashes = [dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p)) for p in sorted(inputs)]
    for name in shared.MODULES:
        shutil.copyfile(ROOT / 'src' / name, source_dir / name)
    shutil.copyfile(fixture / 'src/main.fy', source_dir / 'main.fy')
    shutil.copyfile(fixture / 'fairy.toml', source_dir.parent / 'fairy.toml')
    need({p.name for p in source_dir.rglob('*.fy')} == set(shared.MODULES + ['main.fy']), 'Unexpected generated sources')
    generated = [dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p)) for p in sorted(source_dir.glob('*.fy'))]
    run([compiler, 'check'], cwd=source_dir.parent)
    lock = source_dir.parent / 'fairy.lock'
    sdk = [p for p in json.loads((ROOT / 'fairy.lock').read_text())['packages'] if p['role'] != 'root']
    need([p for p in json.loads(lock.read_text())['packages'] if p['role'] != 'root'] == sdk, 'Generated SDK differs')
    lock_hash = sha(lock)
    emitted = run([compiler, 'experimental', 'emit-workspace-c', '--target', 'x86_64-windows-msvc', '--locked'], cwd=source_dir.parent, emit=True)
    original = out / 'original.c'
    original.write_text(emitted, encoding='utf-8', newline='\n')
    # emit-workspace-c contains product code and ABI declarations, not native
    # providers. Read exact runtime Git objects at the compiler revision, without
    # modifying or trusting the current Fairy checkout's working tree.
    fairy_repo = (ROOT / tc['source']['localRepository']).resolve()
    runtime_inputs = []
    runtime_parts = ['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)\n']
    for git_path in ['internal/cstdlib/' + name for name in ['stage0_system_heap.c', 'stage0_buffer.c', 'stage0_windows_console.c', 'stage0_windows_process_args.c']] + ['internal/cruntime/stage0_scalar.c']:
        data = run(['git', '-C', fairy_repo, 'show', tc['compiler']['revision'] + ':' + git_path], emit=True)
        runtime_inputs.append(dict(revision=tc['compiler']['revision'], path=git_path, sha256=hashlib.sha256(data.encode()).hexdigest()))
        if git_path == 'internal/cruntime/stage0_scalar.c':
            # Standalone trap exits are fatal to the probe; no receipt transport.
            for token, replacement in [('@TRAP_RECEIPT_INCLUDE@', ''), ('@TRAP_RECEIPT_WRITE@', ''), ('@TRAP_EXIT_BASE@', '128')]:
                need(data.count(token) == 1, 'Scalar trap template changed: ' + token)
                data = data.replace(token, replacement)
        runtime_parts.append(data)
    native_original = out / 'runtime-original.c'
    native_original.write_text('\n'.join(runtime_parts), encoding='utf-8', newline='\n')
    patched = out / 'provider.c'
    patched.write_text(inject(native_original.read_text(encoding='utf-8')), encoding='utf-8', newline='\n')

    # Resolve the installed x64 MSVC and complete Windows SDK without a shell.
    program_files = Path(os.environ['ProgramFiles(x86)'])
    vswhere = program_files / 'Microsoft Visual Studio/Installer/vswhere.exe'
    vs = Path(run([vswhere, '-latest', '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath']).strip())
    msvc_version = (vs / 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt').read_text().strip()
    msvc = vs / 'VC/Tools/MSVC' / msvc_version
    cl = msvc / 'bin/Hostx64/x64/cl.exe'
    kits = program_files / 'Windows Kits/10'
    sdks = sorted(p.name for p in (kits / 'Include').iterdir() if p.is_dir() and p.name.startswith('10.')
                  and all((kits / q / p.name / sub).is_dir() for q, sub in [('Include', 'ucrt'), ('Include', 'um'), ('Include', 'shared'), ('Lib', 'ucrt/x64'), ('Lib', 'um/x64')]))
    need(bool(sdks), 'Complete Windows SDK unavailable')
    sdk_version = sdks[-1]
    native_env = {**os.environ, 'PATH': str(cl.parent) + os.pathsep + os.environ['PATH'],
                  'INCLUDE': os.pathsep.join(map(str, [msvc / 'include'] + [kits / 'Include' / sdk_version / s for s in ['ucrt', 'shared', 'um']])),
                  'LIB': os.pathsep.join(map(str, [msvc / 'lib/x64'] + [kits / 'Lib' / sdk_version / s / 'x64' for s in ['ucrt', 'um']]))}
    empty = out / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    runtime_env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    runtime_env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    artifacts = [dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p)) for p in [original, native_original, patched, lock]]
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    results = []
    for profile in profiles:
        exe = out / ('provider-' + profile + '.exe')
        objects = []
        for label, source_file in [('product', original), ('runtime', patched)]:
            obj = out / (label + '-' + profile + '.obj')
            flags = ['/FI' + str(fixture / 'provider_probe.h')] if label == 'runtime' else []
            run([cl, '/nologo', '/std:c11', '/TC', '/MT', '/W4', '/WX', '/Od' if profile == 'development' else '/O2',
                 *flags, '/c', source_file, '/Fo:' + str(obj)], cwd=out, env=native_env)
            objects.append(obj)
        run([cl, '/nologo', '/MT', *objects, '/Fe:' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], cwd=out, env=native_env)
        binary_hash = sha(exe)
        cases = []
        for mode in MODES:
            for injected in [False, True]:
                env = dict(runtime_env)
                if injected:
                    env['BROWNIE_BUFFER_PROVIDER_FAULT'] = mode
                lines = run([exe, mode] + ([] if injected else ['control']), cwd=empty, env=env, timeout=30).splitlines()
                need(len(lines) == (3 if injected else 2) and lines[0] == 'buffer-provider: passed', 'Probe output')
                reports = {v['schema']: v for v in map(json.loads, lines[1:])}
                expected = dict(schema='browniec.buffer-allocator/v2', live=0, target=0, targetAttempts=0, failures=0,
                                attempts=3 if injected else 2, frees=3 if injected else 2)
                need(reports.get('browniec.buffer-allocator/v2') == expected, 'Exact allocator counters')
                if injected:
                    need(reports.get('browniec.buffer-provider/v1') == dict(schema='browniec.buffer-provider/v1', hits=1), 'Exactly one provider fault required')
                cases.append(dict(mode=mode, injected=injected, reports=reports))
        need(sha(exe) == binary_hash, 'Binary changed')
        artifacts.append(dict(path=exe.relative_to(ROOT).as_posix(), sha256=binary_hash))
        results.append(dict(profile=profile, cases=cases))
        print('PASS: ' + profile + ': 4 injected provider faults + 4 controls; live=0', flush=True)
    for entry in hashes + generated + artifacts:
        need(sha(ROOT / entry['path']) == entry['sha256'], 'Input/artifact changed: ' + entry['path'])
    for name in shared.MODULES:
        need((ROOT / 'src' / name).read_bytes() == (source_dir / name).read_bytes(), 'Product copy differs: ' + name)
    need((fixture / 'src/main.fy').read_bytes() == (source_dir / 'main.fy').read_bytes()
         and (fixture / 'fairy.toml').read_bytes() == (source_dir.parent / 'fairy.toml').read_bytes(), 'Fixture copy differs')
    need(sha(lock) == lock_hash and sha(compiler) == tc['platforms']['windows/amd64']['sha256'], 'Lock/compiler changed')
    result = dict(schema='browniec.buffer-provider-windows/v1', status='passed', recordedAt=datetime.now(timezone.utc).isoformat(),
                  baselineCommit=baseline, os=platform.platform(), profiles=profiles, compilerVersion=version.strip(),
                  compilerSha256=sha(compiler), pinnedRuntimeSources=runtime_inputs, lockedCheck=locked.strip(), sourceSha256=hashes, generatedSourceSha256=generated,
                  artifacts=artifacts, standardLibraryLockIdentity=sdk, generatedLockSha256=lock_hash,
                  nativeToolchain=dict(compiler=str(cl), sha256=sha(cl), msvcVersion=msvc_version, windowsSdk=sdk_version),
                  commands=commands, profileReceipts=results,
                  limitations=['Test-only pinned native provider injections linked to emitted product C, not production binaries. Fifteen Fairy product modules are byte-identical copies.',
                               'Metadata shortening and post-write error injection only; no out-of-bounds pointers, arbitrary corruption, all-provider-failure or process-RSS guarantee.',
                               'Full lifecycle/native/CLI suites, M0, Linux, DLL, packaging, isolation, performance and automatic Instance teardown were not run.'])
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
