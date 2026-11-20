"""Execute the private anchored collector -> Fairy source Snapshot adapter."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
NEW = ['src/anchored_source_loader.fy', 'native/anchored-source-loader/bridge.c',
       'native/anchored-source-loader/bridge.h', 'tools/anchored-source-loader/main.fy',
       'tools/anchored-source-loader/support.c', 'tools/verify-anchored-source-loader.py',
       'docs/engineering/anchored-source-loader.md']
FROZEN = ['native/anchored_sources.c', 'native/anchored_sources.h',
          'tests/native/anchored_sources_host.c', 'tools/verify-anchored-sources.py',
          'docs/engineering/anchored-sources.md']


def sha(data):
    return hashlib.sha256(data).hexdigest()


def need(value, message):
    if not value:
        raise RuntimeError(message)


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)


def main():
    need(os.name == 'nt', 'Actual Windows required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ), 'CL/_CL_/LINK prohibited')
    out = ROOT / 'build/anchored-source-loader' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True)
    receipt = dict(schema='browniec.anchored-source-loader/v1', status='incomplete', commands=[], profiles=[])

    def run(command, cwd=out, env=None):
        command = list(map(str, command))
        need(not any('/STACK' in s.upper() for s in command), 'Stack override prohibited')
        done = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=120)
        n = len(receipt['commands'])
        write(out / f'logs/{n}.stdout', done.stdout)
        write(out / f'logs/{n}.stderr', done.stderr)
        receipt['commands'].append(dict(argv=command, exit=done.returncode,
            stdout=f'logs/{n}.stdout', stderr=f'logs/{n}.stderr',
            stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr)))
        need(done.returncode == 0, f'Command failed: {command}: {done.stdout[-1500:]!r} {done.stderr[-2500:]!r}')
        return done.stdout

    try:
        files = NEW + FROZEN + ['src/source_snapshot.fy', 'fairy.toml', 'fairy.lock', 'toolchain.json',
                                'tools/verify-runtime-store-probe.py']
        inputs = {p: (ROOT / p).read_bytes() for p in files}
        need(all(b'\r' not in b for p, b in inputs.items() if p.endswith(('.fy', '.py', '.c', '.h', '.md'))), 'LF required')
        receipt['inputs'] = [dict(path=p, sha256=sha(b), bytes=len(b)) for p, b in inputs.items()]
        write(out / 'inputs.json', json.dumps(receipt['inputs'], indent=2) + '\n')
        tc = json.loads(inputs['toolchain.json'])
        compiler = ROOT / 'build/toolchain/fairyc.exe'
        if not compiler.exists():
            compiler = ROOT.parents[1] / 'build/toolchain/fairyc.exe'
        need(sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256'], 'Pinned compiler mismatch')
        receipt['compiler'] = dict(path=str(compiler), sha256=sha(compiler.read_bytes()), version=run([compiler, '--version']).decode())
        project = out / 'project'
        for src, dst in [('src/source_snapshot.fy', 'src/source_snapshot.fy'),
                         ('src/anchored_source_loader.fy', 'src/anchored_source_loader.fy'),
                         ('tools/anchored-source-loader/main.fy', 'src/main.fy'), ('fairy.toml', 'fairy.toml')]:
            write(project / dst, inputs[src])
        run([compiler, 'check'], cwd=project)
        lock = (project / 'fairy.lock').read_bytes()
        sdk = [p for p in json.loads(lock)['packages'] if p['role'] != 'root']
        # This isolated source closure imports fewer SDK modules than the root CLI.
        need(len(sdk) == 1 and sdk[0]['sdkIdentity'] == tc['sdk']['identity']
             and sdk[0]['version'] == tc['sdk']['version'] and sdk[0]['runtimeAbi'] == tc['runtimeAbi']
             and sdk[0]['sourceDigest'] == 'fysrc1-sha256-c531e88e52b684a34cf9688eda19e5cafcc5788e7a4bbf7e5121e86874a7246a',
             'Isolated anchored-loader SDK mismatch')
        receipt['isolatedLockSha256'] = sha(lock)
        emitted = run([compiler, 'experimental', 'emit-workspace-c', '--target', 'x86_64-windows-msvc', '--locked'], cwd=project)
        write(out / 'generated.c', emitted)
        receipt['transportSha256'] = sha(emitted)
        # No emitted type is inspected or projected by the bridge: scalar/pointer
        # prototypes only. Exact actual generated C is compiled without rewriting.
        repository = (ROOT / tc['source']['localRepository']).resolve()
        if not (repository / '.git').exists():
            repository = ROOT.parents[1].parent / 'fairyc'
        runtime = ['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)\n']
        receipt['runtimeInputs'] = []
        for path in ['internal/cstdlib/' + n for n in ['stage0_system_heap.c', 'stage0_buffer.c',
                      'stage0_windows_console.c', 'stage0_windows_process_args.c', 'stage0_text_view.c']] + ['internal/cruntime/stage0_scalar.c']:
            raw = run(['git', '-C', repository, 'show', tc['compiler']['revision'] + ':' + path])
            receipt['runtimeInputs'].append(dict(path=path, revision=tc['compiler']['revision'], sha256=sha(raw)))
            body = raw.decode()
            if path.endswith('stage0_scalar.c'):
                for token, value in [('@TRAP_RECEIPT_INCLUDE@', ''), ('@TRAP_RECEIPT_WRITE@', ''), ('@TRAP_EXIT_BASE@', '128')]:
                    need(body.count(token) == 1, 'Scalar template changed')
                    body = body.replace(token, value)
            runtime.append(body)
        write(out / 'runtime.c', '\n'.join(runtime))
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
            flags = ['/nologo', '/TC', '/std:c11', '/MT', '/W4', '/WX', '/Od' if profile == 'development' else '/O2']
            production = folder / 'bridge-production.obj'
            run([cl, *flags, '/c', ROOT / 'native/anchored-source-loader/bridge.c', '/Fo' + str(production)], env=env)
            symbols = run([cl.parent / 'dumpbin.exe', '/symbols', production], env=env)
            need(b'bc_asl_test_' not in symbols, 'Test hooks in production')
            objects = []
            for name, source in [('generated', out / 'generated.c'), ('runtime', out / 'runtime.c'),
                                 ('collector', ROOT / 'native/anchored_sources.c'),
                                 ('bridge', ROOT / 'native/anchored-source-loader/bridge.c'),
                                 ('support', ROOT / 'tools/anchored-source-loader/support.c')]:
                obj = folder / (name + '.obj')
                run([cl, *flags, '/DBC_ASL_TEST', '/DBC_ANCHORED_SOURCES_TEST', '/c', source, '/Fo' + str(obj)], env=env)
                objects.append(obj)
            exe = folder / 'loader.exe'
            run([cl, '/nologo', *objects, 'ntdll.lib', '/Fe' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            fixtures = folder / 'fixtures'
            root = fixtures / 'root-\uD55C\uAE00'
            (root / 'sub').mkdir(parents=True)
            fixture_inputs = {'sub/a.fy': b'module a;\r\n// \xc3\xa9\x00', 'empty.brc': b'', 'invalid.fy': b'\xff',
                              'bound.fy': b'a' * 4096, 'large.fy': b'a' * 4097,
                              **{f'f{i:02}.fy': b'' for i in range(16)}}
            for p, data in fixture_inputs.items():
                write(root / p, data)
            write(fixtures / 'outside.fy', b'outside')
            os.link(fixtures / 'outside.fy', root / 'alias.fy')
            stdout = run([exe, root], env=execution)
            need(stdout == b'' and receipt['commands'][-1]['stderrSha256'] == sha(b''), 'Unexpected native output')
            need(fixtures.resolve().parent == folder.resolve() and not fixtures.is_symlink(), 'Unsafe cleanup target')
            shutil.rmtree(fixtures)
            need(not fixtures.exists(), 'Fixture cleanup failed')
            receipt['profiles'].append(dict(profile=profile, passed=True, fixtureCleanup=True,
                host=helper.image(exe), productionTestHooksAbsent=True, productionSha256=sha(production.read_bytes()),
                fixtures=[dict(path=p, bytes=len(b), sha256=sha(b)) for p, b in fixture_inputs.items()],
                objects=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p.read_bytes())) for p in objects]))
            print('PASS ' + profile + ': actual OS -> owning Fairy Snapshot, UTF8/admission/limits/OOM/cleanup', flush=True)
        need(all((ROOT / p).read_bytes() == b for p, b in inputs.items()), 'Input changed')
        need(sha(compiler.read_bytes()) == tc['platforms']['windows/amd64']['sha256'], 'Compiler changed')
        receipt.update(status='passed', frozenCollectorUnchanged=True, rootLockUnchanged=True,
            sourceFiles=16, sourceBytes=4096, defaultStacks=True,
            limitations=['Private native adapter only; project/Engine/CLI binding open.',
                         'Owned copied bytes; no point-in-time consistency against preexisting writable mappings.'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        write(out / 'receipt.json', json.dumps(receipt, indent=2) + '\n')
        print('Receipt: ' + str(out / 'receipt.json'), flush=True)


if __name__ == '__main__':
    main()
