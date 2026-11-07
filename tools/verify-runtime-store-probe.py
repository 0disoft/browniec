"""Build the pinned opaque owning Store probe; R01 prerequisite, not Engine lifecycle."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PROBE = ROOT / 'probes/runtime-store'
COMPILER_SHA256 = '9651623adbb6e05e0f948b826431853df310050387c955aee77ac0b12a81ab7a'
REVISION = 'eb274643bfcfe746617121ddc6f130b018978b53'
TRANSPORT_SHA256 = '0bd1ddef0850813b03bfb81c9bd11abd760525706c5fbcb2605aaff30c43ccec'
RUNTIME_SHA256 = '86476d852a19e01ceffeb90916168a37b028dcffd1a61d682e149767c5e5baf3'


def need(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)


def record(path, value):
    write(path, json.dumps(value, indent=2) + '\n')


def native_environment(run):
    pf = Path(os.environ['ProgramFiles(x86)'])
    vs = Path(run([pf / 'Microsoft Visual Studio/Installer/vswhere.exe', '-latest',
                   '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
                   '-property', 'installationPath']).decode().strip())
    version = (vs / 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt').read_text().strip()
    msvc = vs / 'VC/Tools/MSVC' / version
    cl = msvc / 'bin/Hostx64/x64/cl.exe'
    kits = pf / 'Windows Kits/10'
    versions = sorted(p.name for p in (kits / 'Include').iterdir() if p.name.startswith('10.') and
                      all((kits / a / p.name / b).is_dir() for a, b in
                          [('Include', 'ucrt'), ('Include', 'shared'), ('Include', 'um'),
                           ('Lib', 'ucrt/x64'), ('Lib', 'um/x64')]))
    need(bool(versions), 'Complete Windows SDK required')
    sdk = versions[-1]
    env = dict(os.environ)
    env['PATH'] = str(cl.parent) + os.pathsep + env['PATH']
    env['INCLUDE'] = os.pathsep.join(map(str, [msvc / 'include'] +
                                   [kits / 'Include' / sdk / s for s in ['ucrt', 'shared', 'um']]))
    env['LIB'] = os.pathsep.join(map(str, [msvc / 'lib/x64'] +
                               [kits / 'Lib' / sdk / s / 'x64' for s in ['ucrt', 'um']]))
    return cl, env, dict(version=version, sdk=sdk, compilerSha256=sha(cl.read_bytes()),
                        overrides=False)


def image(path):
    data = path.read_bytes()
    need(data[:2] == b'MZ', 'Expected native PE image')
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    need(data[offset:offset + 4] == b'PE\0\0' and
         struct.unpack_from('<H', data, offset + 4)[0] == 0x8664, 'Expected AMD64 PE')
    optional = offset + 24
    need(struct.unpack_from('<H', data, optional)[0] == 0x20b, 'Expected PE32+')
    stack = struct.unpack_from('<QQ', data, optional + 72)
    need(stack == (1048576, 4096), 'Unexpected stack reserve/commit')
    return dict(path=path.relative_to(ROOT).as_posix(), sha256=sha(data), bytes=len(data),
                stackReserve=stack[0], stackCommit=stack[1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fairyc-repository', type=Path,
                        help='Git repository containing the pinned runtime objects; default: toolchain source.localRepository')
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows AMD64 native probe required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ),
         'CL/_CL_/LINK overrides must be absent, including empty values')
    output = ROOT / 'build/runtime-store-probe' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output.mkdir(parents=True, exist_ok=False)
    receipt_path = output / 'receipt.json'
    receipt = dict(schema='browniec.runtime-store-probe-verification/v1', status='incomplete',
                   recordedAt=datetime.now(timezone.utc).isoformat(), commands=[], runtimeInputs=[], profiles=[],
                   scope='R01 owning-store prerequisite evidence; not Engine lifecycle completion')
    initial_lock = (ROOT / 'fairy.lock').read_bytes() if (ROOT / 'fairy.lock').exists() else None

    def run(command, cwd=output, env=None):
        command = list(map(str, command))
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=120)
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
        contract = json.loads((PROBE / 'transport.json').read_bytes())
        need(contract['compilerRevision'] == REVISION and contract['compilerSha256'] == COMPILER_SHA256 and
             contract['transportSha256'] == TRANSPORT_SHA256 and contract['runtimeSha256'] == RUNTIME_SHA256,
             'Reviewed transport contract changed')
        toolchain = json.loads((ROOT / 'toolchain.json').read_bytes())
        need(toolchain['platforms']['windows/amd64']['sha256'] == COMPILER_SHA256 and
             toolchain['compiler']['revision'] == REVISION, 'Root pinned toolchain contract changed')
        compiler = ROOT / 'build/toolchain/fairyc.exe'
        need(sha(compiler.read_bytes()) == COMPILER_SHA256, 'Pinned compiler mismatch')
        receipt['compiler'] = dict(sha256=COMPILER_SHA256, revision=REVISION,
                                   version=run([compiler, '--version']).decode().strip())
        repository = (args.fairyc_repository or
                      ROOT / toolchain['source']['localRepository']).resolve()
        inputs = {p.relative_to(ROOT).as_posix(): p.read_bytes() for p in PROBE.rglob('*') if p.is_file()}
        inputs.update({p: (ROOT / p).read_bytes() for p in
                       ['tools/verify-runtime-store-probe.py', 'docs/engineering/runtime-store-probe.md', 'toolchain.json']})
        need(all(b'\r' not in b for n, b in inputs.items() if n != 'toolchain.json'), 'Probe files must retain LF')
        receipt['inputs'] = [dict(path=n, sha256=sha(b), bytes=len(b)) for n, b in sorted(inputs.items())]
        need(set(p.relative_to(PROBE).as_posix() for p in PROBE.rglob('*') if p.is_file()) ==
             {'transport.json', *(row['path'] for row in contract['sourceInputs'])}, 'Unexpected probe source file')
        for row in contract['sourceInputs']:
            need(sha((PROBE / row['path']).read_bytes()) == row['sha256'], f'Reviewed source changed: {row["path"]}')
        project = output / 'project'
        for name in ['fairy.toml', 'src/store.fy', 'src/main.fy']:
            write(project / name, (PROBE / name).read_bytes())
        run([compiler, 'check'], cwd=project)
        lock = (project / 'fairy.lock').read_bytes()
        receipt['isolatedLockSha256'] = sha(lock)
        run([compiler, 'check', '--locked'], cwd=project)
        generated = run([compiler, 'experimental', 'emit-workspace-c', '--target',
                         'x86_64-windows-msvc', '--locked'], cwd=project)
        need(sha(generated) == TRANSPORT_SHA256, 'Emitted transport changed: re-review every private binding')
        need(b'fy_resource_2 f_0;\n} fy_resource_3;' in generated and
             b'fy_resource_0 f_0;\n    uintptr_t f_1;\n} fy_resource_1;' in generated,
             'Expected reviewed owning fields')
        write(output / 'generated.c', generated)
        write(output / 'bridge.c', (PROBE / 'bridge.c').read_bytes())
        runtime = []
        for row in contract['runtimeInputs']:
            need(row['revision'] == REVISION, 'Runtime revision mismatch')
            raw = run(['git', 'show', REVISION + ':' + row['path']], cwd=repository)
            need(sha(raw) == row['sha256'], f'Pinned Git object mismatch: {row["path"]}')
            write(output / 'runtime-inputs' / Path(row['path']).name, raw)
            receipt['runtimeInputs'].append(dict(row))
            text = raw.decode('utf-8')
            if row['path'].endswith('stage0_scalar.c'):
                for key, value in [('@TRAP_EXIT_BASE@', '192'), ('@TRAP_RECEIPT_INCLUDE@', ''),
                                   ('@TRAP_RECEIPT_WRITE@', '')]:
                    need(text.count(key) == 1, f'Runtime placeholder mismatch: {key}')
                    text = text.replace(key, value)
            runtime.append(text)
        composed = (PROBE / 'heap-observer.c').read_text(encoding='utf-8') + '\n'.join(runtime)
        need(sha(composed.encode()) == RUNTIME_SHA256, 'Composed pinned runtime changed')
        write(output / 'runtime.c', composed)
        receipt['transportSha256'] = TRANSPORT_SHA256
        receipt['runtimeSha256'] = RUNTIME_SHA256
        cl, env, receipt['msvc'] = native_environment(run)
        empty = output / 'empty-tools'
        empty.mkdir()
        runtime_env = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
        runtime_env['PATH'] = str(empty)
        for profile in (['development', 'release'] if args.profile == 'all' else [args.profile]):
            folder = output / profile
            folder.mkdir()
            objects = []
            for name in ['bridge', 'runtime']:
                obj = folder / (name + '.obj')
                run([cl, '/nologo', '/TC', '/std:c11', '/MT', '/W4',
                     '/Od' if profile == 'development' else '/O2', '/c', output / (name + '.c'),
                     '/Fo' + str(obj)], env=env)
                objects.append(obj)
            exe = folder / 'store-probe.exe'
            run([cl, '/nologo', *objects, '/Fe' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            stdout = run([exe], env=runtime_env)
            need(stdout == b'' and receipt['commands'][-1]['stderrSha256'] == sha(b''), 'Expected silent native success')
            receipt['profiles'].append(dict(profile=profile, artifact=image(exe), exit=0,
                cleanup=dict(postResetDropTrace=[22, 11, 33], liveHeapAllocationsAtExit=0,
                             evidence='Native Fairy assertions and guarded C process exit; no parsed trace log'),
                objects=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p.read_bytes())) for p in objects]))
            print(f'PASS {profile}: Store/Vec/Buffer push, mutate, pop, move, drop; trace [22,11,33]; live heap 0', flush=True)
        need(all((ROOT / n).read_bytes() == b for n, b in inputs.items()), 'Source input changed during verification')
        need((project / 'fairy.lock').read_bytes() == lock and sha(compiler.read_bytes()) == COMPILER_SHA256,
             'Isolated lock/compiler changed')
        need((ROOT / 'fairy.lock').read_bytes() == initial_lock if initial_lock is not None else
             not (ROOT / 'fairy.lock').exists(), 'Root lock changed')
        receipt.update(status='passed', rootLockUnchanged=True, compilerOverrides=False,
                       runtimeEnvironment='cleared; empty tool PATH', productionEdits=False,
                       limitations=['Trusted synchronous C projection shim; no general safe resource-field projection',
                                    'No Engine lifecycle, public ABI, concurrency, OOM rollback or recovery proof'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        record(receipt_path, receipt)
        print('Receipt: ' + str(receipt_path), flush=True)


if __name__ == '__main__':
    main()
