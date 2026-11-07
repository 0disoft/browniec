"""Actual OS project -> existing Fairy project admission/compile/run, Windows x64."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
NEW = ['native/project-source-loader/loader.fy', 'tools/project-source-loader/main.fy',
       'tools/project-source-loader/support.c', 'tools/project-source-loader/heap-observer.h',
       'tools/verify-project-source-loader.py', 'docs/engineering/project-source-loader.md']
PREREQUISITES = ['native/anchored-source-loader/loader.fy', 'native/anchored-source-loader/bridge.c',
                 'native/anchored-source-loader/bridge.h', 'native/anchored_sources.c', 'native/anchored_sources.h',
                 'tools/verify-runtime-store-probe.py', 'toolchain.json', 'fairy.toml', 'fairy.lock']


def sha(b):
    return hashlib.sha256(b).hexdigest()


def need(value, message):
    if not value:
        raise RuntimeError(message)


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)


def fixtures():
    app = b'module app;import lib as m;pub fn i32 start(){return m::answer();}pub fn i32 other(){return 99;}'
    trap = b'module app;pub fn i32 start(){let i32 zero=0;return 42/zero;}'
    lib = b'module lib;pub fn i32 answer(){return 42;}'
    base = dict(schema='brownie.project/0.3', name='fixture', entry=dict(module='app', function='start'),
                sources=[dict(module='app', path='src/main.fy'), dict(module='lib', path='src/math.fy')], requires=[])
    cases = []

    def add(label, mode, main=app, library=lib, change=None):
        metadata = json.loads(json.dumps(base))
        if change:
            change(metadata)
        cases.append(dict(label=label, mode=mode, metadata=metadata,
                          files={'src/main.fy': main, 'src/math.fy': library}))

    add('named-entry-42-and-reuse-after-source-rewrite', '0')
    add('requirements-before-zero-fuel-and-divide-by-zero', '1', main=trap, change=lambda m: m['requires'].append('fs.read'))
    add('actual-runtime-divide-by-zero', '2', main=trap)
    add('different-explicit-entry-99', '3', change=lambda m: m['entry'].update(function='other'))
    add('swapped-map-headers', '4', change=lambda m: [s.update(module='lib' if s['module'] == 'app' else 'app') for s in m['sources']])
    add('wrong-source-header', '4', library=b'module wrong;pub fn i32 answer(){return 42;}')
    add('missing-entry', '4', change=lambda m: m['entry'].update(function='missing'))
    add('private-entry', '4', main=b'module app;fn i32 start(){return 42;}')
    add('input-entry-not-supported-here', '4', main=b'module app;pub fn i32 start(ref u8[] x){return 42;}')
    add('missing-member-path', '5', change=lambda m: m['sources'][1].update(path='src/missing.fy'))
    add('invalid-source-utf8', '5', library=b'\xff')
    add('source-byte-ceiling', '5', library=b'a' * 4097)
    add('actual-body-type-error', '6', library=b'module lib;pub fn i32 answer(){return true;}')
    add('current-source-byte-limit', '7')
    add('17-admitted-metadata-files-current-limit', '7', change=lambda m: m['sources'].extend(
        dict(module=f'm{i}', path=f'src/m{i}.fy') for i in range(15)))
    for mode, label in [('8', 'bridge-allocation'), ('9', 'anchor-allocation'), ('A', 'native-snapshot-allocation')]:
        add(label + '-failure-cleanup', mode)
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core-root', type=Path, default=ROOT, help='Read-only core source input; default is this checkout.')
    args = parser.parse_args()
    core = args.core_root.resolve(strict=True)
    need(os.name == 'nt', 'Actual Windows required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ), 'CL/_CL_/LINK prohibited')
    out = ROOT / 'build/project-source-loader' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    receipt = dict(schema='browniec.project-source-loader/v1', status='incomplete', coreRoot=str(core), commands=[], profiles=[])

    def run(command, cwd=out, env=None):
        command = list(map(str, command))
        need(not any('/STACK' in s.upper() for s in command), 'Stack override prohibited')
        done = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=300)
        n = len(receipt['commands'])
        write(out / f'logs/{n}.stdout', done.stdout)
        write(out / f'logs/{n}.stderr', done.stderr)
        receipt['commands'].append(dict(argv=command, exit=done.returncode, stdout=f'logs/{n}.stdout', stderr=f'logs/{n}.stderr',
            stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr)))
        need(done.returncode == 0, f'Failed: {command}: {done.stdout[-1500:]!r} {done.stderr[-2500:]!r}')
        return done.stdout

    try:
        local = {p: (ROOT / p).read_bytes() for p in NEW + PREREQUISITES}
        inputs = {}
        pending = ['project_manifest', 'project_sources', 'project_program']
        while pending:
            name = pending.pop()
            path = 'src/' + name.replace('::', '/') + '.fy'
            if path in inputs:
                continue
            body = (core / path).read_bytes()
            inputs[path] = body
            pending.extend(n.decode() for n in re.findall(rb'import\s+([A-Za-z_][A-Za-z_0-9:]*)\s+as', body)
                           if not n.startswith(b'std::'))
        need(all(b'\r' not in b for b in [*local.values(), *inputs.values()]), 'LF required')
        receipt['inputs'] = [dict(origin='checkout', path=p, sha256=sha(b), bytes=len(b)) for p, b in local.items()]
        receipt['inputs'] += [dict(origin='core', path=p, sha256=sha(b), bytes=len(b)) for p, b in sorted(inputs.items())]
        write(out / 'inputs.json', json.dumps(receipt['inputs'], indent=2) + '\n')
        tc = json.loads(local['toolchain.json'])
        need((core / 'toolchain.json').read_bytes() == local['toolchain.json'], 'Core toolchain mismatch')
        compiler = ROOT / 'build/toolchain/fairyc.exe'
        if not compiler.exists():
            compiler = ROOT.parents[1] / 'build/toolchain/fairyc.exe'
        need(sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256'], 'Pinned compiler mismatch')
        receipt['compiler'] = dict(sha256=sha(compiler.read_bytes()), version=run([compiler, '--version']).decode())
        project = out / 'project'
        write(project / 'fairy.toml', local['fairy.toml'])
        for path, body in inputs.items():
            write(project / path, body)
        for path, target in [('native/project-source-loader/loader.fy', 'project_source_loader.fy'),
                             ('native/anchored-source-loader/loader.fy', 'anchored_source_loader.fy'),
                             ('tools/project-source-loader/main.fy', 'main.fy')]:
            write(project / 'src' / target, local[path])
        run([compiler, 'check'], cwd=project)
        lock = (project / 'fairy.lock').read_bytes()
        sdk = [p for p in json.loads(lock)['packages'] if p['role'] != 'root']
        need(len(sdk) == 1 and sdk[0]['sdkIdentity'] == tc['sdk']['identity'] and sdk[0]['version'] == tc['sdk']['version']
             and sdk[0]['runtimeAbi'] == tc['runtimeAbi'] and sdk[0]['sourceDigest'] ==
             'fysrc1-sha256-e256aabfe2a16a603f947d4ef5b55b5a4ae80915fdd855e18c6016910fbcc597',
             'Pinned isolated bytes/text/vec SDK closure mismatch')
        receipt['sdk'] = sdk
        receipt['isolatedLockSha256'] = sha(lock)
        emitted = run([compiler, 'experimental', 'emit-workspace-c', '--target', 'x86_64-windows-msvc', '--locked'], cwd=project)
        write(out / 'generated.c', emitted)
        receipt['transportSha256'] = sha(emitted)
        repository = (ROOT / tc['source']['localRepository']).resolve()
        if not (repository / '.git').exists():
            repository = ROOT.parents[1].parent / 'fairyc'
        runtime = [local['tools/project-source-loader/heap-observer.h'].decode()]
        receipt['runtimeInputs'] = []
        for path in ['internal/cstdlib/' + n for n in ['stage0_system_heap.c', 'stage0_buffer.c', 'stage0_vector_storage.c',
                      'stage0_windows_console.c', 'stage0_windows_process_args.c', 'stage0_text_view.c']] + ['internal/cruntime/stage0_scalar.c']:
            raw = run(['git', '-C', repository, 'show', tc['compiler']['revision'] + ':' + path])
            receipt['runtimeInputs'].append(dict(path=path, revision=tc['compiler']['revision'], sha256=sha(raw)))
            write(out / 'runtime-inputs' / Path(path).name, raw)
            body = raw.decode()
            if path.endswith('stage0_scalar.c'):
                for token, value in [('@TRAP_RECEIPT_INCLUDE@', ''), ('@TRAP_RECEIPT_WRITE@', ''), ('@TRAP_EXIT_BASE@', '128')]:
                    need(body.count(token) == 1, 'Scalar template changed')
                    body = body.replace(token, value)
            runtime.append(body)
        write(out / 'runtime.c', '\n'.join(runtime))
        receipt['runtimeSha256'] = sha((out / 'runtime.c').read_bytes())
        spec = importlib.util.spec_from_file_location('native_helper', ROOT / 'tools/verify-runtime-store-probe.py')
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        cl, env, receipt['msvc'] = helper.native_environment(run)
        empty = out / 'empty-tools'
        empty.mkdir()
        execution = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
        execution['PATH'] = str(empty)
        for profile in ['development', 'release']:
            folder = out / profile
            folder.mkdir()
            objects = []
            for name, path in [('generated', out / 'generated.c'), ('runtime', out / 'runtime.c'),
                               ('collector', ROOT / 'native/anchored_sources.c'), ('bridge', ROOT / 'native/anchored-source-loader/bridge.c'),
                               ('support', ROOT / 'tools/project-source-loader/support.c')]:
                obj = folder / (name + '.obj')
                run([cl, '/nologo', '/TC', '/std:c11', '/MT', '/W4', '/WX', '/Od' if profile == 'development' else '/O2',
                     '/DBC_ASL_TEST', '/DBC_ANCHORED_SOURCES_TEST', '/c', path, '/Fo' + str(obj)], env=env)
                objects.append(obj)
            exe = folder / 'project-loader.exe'
            run([cl, '/nologo', *objects, 'ntdll.lib', '/Fe' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            results = []
            for case in fixtures():
                base = folder / 'fixtures' / case['label']
                root = base / 'root-\uD55C\uAE00'
                for path, body in case['files'].items():
                    write(root / path, body)
                metadata = json.dumps(case['metadata'], separators=(',', ':'))
                stdout = run([exe, root, metadata, case['mode']], env=execution)
                need(stdout == b'' and receipt['commands'][-1]['stderrSha256'] == sha(b''), 'Expected silent native assertions')
                need(base.resolve().parent == (folder / 'fixtures').resolve() and not base.is_symlink(), 'Unsafe cleanup target')
                shutil.rmtree(base)
                need(not base.exists(), 'Fixture cleanup failed')
                results.append(dict(label=case['label'], mode=case['mode'], metadataSha256=sha(metadata.encode()),
                    files=[dict(path=p, sha256=sha(b), bytes=len(b)) for p, b in case['files'].items()],
                    exit=0, nativeAllocations=0, fairyHeapAllocations=0, handlesUnchanged=True, fixtureCleanup=True))
            receipt['profiles'].append(dict(profile=profile, host=helper.image(exe), cases=results,
                objects=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p.read_bytes())) for p in objects]))
            print(f'PASS {profile}: {len(results)} actual OS/project/compile/run cases, heap/handles clean', flush=True)
        need(all((ROOT / p).read_bytes() == b for p, b in local.items()), 'Frozen/local input changed')
        need(all((core / p).read_bytes() == b for p, b in inputs.items()), 'Core input changed')
        need(sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256'], 'Compiler changed')
        receipt.update(status='passed', defaultStacks=True, compilerOverrides=False, frozenPrerequisitesUnchanged=True,
            sourceFiles=16, sourceBytes=4096, executableZeroArgumentProject=True,
            limitations=['Private synchronous zero-argument i32 project path; no Engine/InputEntry/CLI binding.',
                         'Requirements denied by existing project_program::run; no grants.',
                         'Owned bounded copied bytes, no writable-mapping point-in-time consistency or R03 guarantee.'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        write(out / 'receipt.json', json.dumps(receipt, indent=2) + '\n')
        print('Receipt: ' + str(out / 'receipt.json'), flush=True)


if __name__ == '__main__':
    main()
