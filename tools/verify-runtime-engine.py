"""Execute the private owning Engine/Program/Instance lifecycle on native Windows."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'native/runtime-engine'
spec = importlib.util.spec_from_file_location('store_probe', ROOT / 'tools/verify-runtime-store-probe.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
need, sha, write, record = probe.need, probe.sha, probe.write, probe.record


def closure():
    files = {p.stem: p for p in (ROOT / 'src').glob('*.fy')}
    files.update(runtime_engine=NATIVE / 'runtime_engine.fy', main=ROOT / 'tools/runtime-engine/main.fy')
    seen, todo = {}, ['main']
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        need(name in files, f'Missing source module: {name}')
        path = files[name]
        seen[name] = path
        todo.extend(re.findall(r'^import ([A-Za-z_][A-Za-z0-9_]*)(?: as [A-Za-z_][A-Za-z0-9_]*)?;',
                               path.read_text(encoding='utf-8'), re.M))
    return sorted(seen.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--fairyc-repository', type=Path)
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows native execution required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ),
         'CL/_CL_/LINK overrides must be absent, including empty values')
    output = ROOT / 'build/runtime-engine' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output.mkdir(parents=True, exist_ok=False)
    receipt_path = output / 'receipt.json'
    receipt = dict(schema='browniec.private-runtime-engine-verification/v1', status='incomplete',
                   recordedAt=datetime.now(timezone.utc).isoformat(), commands=[], profiles=[], runtimeInputs=[])
    root_lock = (ROOT / 'fairy.lock').read_bytes()

    def run(command, cwd=output, env=None):
        command = list(map(str, command))
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=180)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index:02d}.stdout', f'logs/{index:02d}.stderr'
        write(output / stdout, result.stdout)
        write(output / stderr, result.stderr)
        receipt['commands'].append(dict(argv=command, cwd=str(cwd), exit=result.returncode,
                                       stdout=stdout, stderr=stderr,
                                       stdoutSha256=sha(result.stdout), stderrSha256=sha(result.stderr)))
        record(receipt_path, receipt)
        need(result.returncode == 0, f'Command failed: {command}; see {output / stderr}')
        return result.stdout

    try:
        contract = json.loads((NATIVE / 'transport.json').read_bytes())
        toolchain = json.loads((ROOT / 'toolchain.json').read_bytes())
        revision = contract['compilerRevision']
        need(toolchain['compiler']['revision'] == revision and
             toolchain['platforms']['windows/amd64']['sha256'] == contract['compilerSha256'],
             'Reviewed compiler identity changed')
        compiler = ROOT / 'build/toolchain/fairyc.exe'
        need(sha(compiler.read_bytes()) == contract['compilerSha256'], 'Compiler binary changed')
        receipt['compiler'] = dict(revision=revision, sha256=contract['compilerSha256'],
                                   version=run([compiler, '--version']).decode().strip())
        sources = closure()
        expected = {row['path']: row['sha256'] for row in contract['sourceInputs']}
        need({p.relative_to(ROOT).as_posix() for p in sources} == set(expected), 'Reviewed closure changed')
        for path in sources:
            need(sha(path.read_bytes()) == expected[path.relative_to(ROOT).as_posix()], f'Source changed: {path}')
        extras = ['fairy.toml', 'toolchain.json', 'tools/verify-runtime-engine.py',
                  'tools/verify-runtime-store-probe.py', 'tools/runtime-engine/test-host.inc',
                  'native/runtime-engine/bridge.inc', 'native/runtime-engine/transport.json',
                  'native/abi_thread_identity.c', 'native/abi_thread_identity.h',
                  'probes/runtime-store/heap-observer.c']
        inputs = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in sources}
        inputs.update({name: (ROOT / name).read_bytes() for name in extras})
        need(all(b'\r' not in raw for name, raw in inputs.items()
                 if name.endswith(('.fy', '.c', '.h', '.inc', '.py'))), 'Source must retain LF')
        receipt['inputs'] = [dict(path=name, sha256=sha(raw), bytes=len(raw)) for name, raw in sorted(inputs.items())]
        project = output / 'project'
        write(project / 'fairy.toml', inputs['fairy.toml'])
        for path in sources:
            write(project / 'src' / path.name, path.read_bytes())
        run([compiler, 'check'], cwd=project)
        lock = (project / 'fairy.lock').read_bytes()
        run([compiler, 'check', '--locked'], cwd=project)
        generated = run([compiler, 'experimental', 'emit-workspace-c', '--target',
                         'x86_64-windows-msvc', '--locked'], cwd=project)
        need(sha(generated) == contract['transportSha256'], 'Emitted transport changed; review every private binding')
        write(output / 'generated.c', generated)
        bindings = f'typedef {contract["engineType"]} bc_engine;\ntypedef {contract["incomingType"]} bc_engine_input;\n'
        bindings += '\n'.join(f'#define B{key} {value}' for key, value in contract['bindings'].items()) + '\n'
        write(output / 'bindings.h', bindings)
        for name in ['abi_thread_identity.c', 'abi_thread_identity.h']:
            write(output / name, inputs['native/' + name])
        write(output / 'bridge.inc', inputs['native/runtime-engine/bridge.inc'])
        write(output / 'test-host.inc', inputs['tools/runtime-engine/test-host.inc'])
        write(output / 'transport.c', '#define main generated_main\n#include "generated.c"\n#undef main\n'
              '#include "abi_thread_identity.h"\n#include "bindings.h"\n'
              '#include "bridge.inc"\n#include "test-host.inc"\n')
        repository = (args.fairyc_repository or ROOT / toolchain['source']['localRepository']).resolve()
        runtime = [inputs['probes/runtime-store/heap-observer.c'].decode('utf-8')]
        for row in contract['runtimeInputs']:
            need(row['revision'] == revision, 'Runtime revision mismatch')
            raw = run(['git', 'show', revision + ':' + row['path']], cwd=repository)
            need(sha(raw) == row['sha256'], f'Pinned runtime Git object changed: {row["path"]}')
            write(output / 'runtime-inputs' / Path(row['path']).name, raw)
            receipt['runtimeInputs'].append(row)
            text = raw.decode('utf-8')
            if row['path'].endswith('stage0_scalar.c'):
                for key, value in [('@TRAP_EXIT_BASE@', '192'), ('@TRAP_RECEIPT_INCLUDE@', ''),
                                   ('@TRAP_RECEIPT_WRITE@', '')]:
                    need(text.count(key) == 1, f'Unexpected runtime placeholder: {key}')
                    text = text.replace(key, value)
            runtime.append(text)
        composed = '\n'.join(runtime)
        write(output / 'runtime.c', composed)
        receipt.update(transportSha256=sha(generated), runtimeSha256=sha(composed.encode()),
                       isolatedLockSha256=sha(lock), sourceClosure=len(sources))
        cl, env, receipt['msvc'] = probe.native_environment(run)
        empty = output / 'empty-tools'
        empty.mkdir()
        runtime_env = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
        runtime_env['PATH'] = str(empty)
        for profile in (['development', 'release'] if args.profile == 'all' else [args.profile]):
            folder = output / profile
            folder.mkdir()
            objects = []
            for name in ['transport', 'runtime', 'abi_thread_identity']:
                obj = folder / (name + '.obj')
                run([cl, '/nologo', '/TC', '/std:c11', '/MT', '/W3',
                     '/Od' if profile == 'development' else '/O2', '/c', output / (name + '.c'),
                     '/Fo' + str(obj)], env=env)
                objects.append(obj)
            exe = folder / 'runtime-engine.exe'
            run([cl, '/nologo', *objects, '/Fe' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            need(run([exe], env=runtime_env) == b'' and
                 receipt['commands'][-1]['stderrSha256'] == sha(b''), 'Expected silent native success')
            receipt['profiles'].append(dict(profile=profile, artifact=probe.image(exe), exit=0,
                liveHeapAllocationsAtExit=0, assertions='native Fairy and C, no parsed trace',
                objects=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p.read_bytes())) for p in objects]))
            print(f'PASS {profile}: real compile/reuse, pins, fresh VM, terminal/cancel, OS guards, exhaustion; heap 0', flush=True)
        need(all((ROOT / name).read_bytes() == raw for name, raw in inputs.items()), 'Input changed during verification')
        need((ROOT / 'fairy.lock').read_bytes() == root_lock and (project / 'fairy.lock').read_bytes() == lock,
             'Root or isolated lock changed')
        need(sha(compiler.read_bytes()) == contract['compilerSha256'], 'Compiler changed during verification')
        receipt.update(status='passed', rootLockUnchanged=True, compilerOverrides=False,
                       runtimeEnvironment='cleared; empty tool PATH', limitations=[
                           'Private synchronous typed transport, not public C handles or CLI lifecycle APIs',
                           'Complete Engine accounting/preallocation, OOM injection and poison containment remain',
                           'No bounded step quanta, in-flight cancellation, host/input/output dispatch or OS deadline'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        record(receipt_path, receipt)
        print('Receipt: ' + str(receipt_path), flush=True)


if __name__ == '__main__':
    main()
