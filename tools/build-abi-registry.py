"""Build the internal Windows x64 Fairy registry coordinator and real C host.
No public DLL/VM lifecycle, test mutation hook, custom stack or root lock writes.
The complete private generated transport must match the reviewed hash exactly.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
COMPILER = '13f32b5ffc77b38b34d91eacee465e95dbfe569d9eff3344351d3148fd1e87ab'
REVISION = '801c5d8caa64d19aab8925763d6bf07f65f26418'
TRANSPORT = 'e08554d63d567e9100bc47d51594e3babcab01f65e6284b972239d1eed599ccb'
KERNEL = '8a27896a2597323a53fda255bc1c521101d929e416e83d6e3d005f7c8c3a5fbb'
RETENTION = '19e295a582ecaf048fe34c448247ab860c951a18b3d4ff157803160764ab1f54'
HELPER = '5c562f408deb71cc2a73aeab46ed1d5c137ba2ae5f894b0c3ae96feb65c3a488'
HELPER_HEADER = '982becbdcc9310ba557a6e8e52861ffd8e24de19a9ec8125786d4199fcb08e6a'
FEATURES = ['src/abi_handles.fy', 'native/abi_registry.c', 'native/abi_registry.h',
            'native/abi_thread_identity.c', 'native/abi_thread_identity.h',
            'tools/build-abi-registry.py', 'tools/abi-registry/main.fy',
            'tools/abi-registry/transport.json', 'tests/embed/abi_registry_host.c',
            'tests/embed/handle_registry.fy', 'toolchain.json']
MANIFEST = ('schema = "fairyc.manifest/v1"\n\n[package]\nuid = "browniec.abi-registry"\n'
            'name = "browniec-abi-registry"\nversion = "0.1.0"\n'
            'language = "fairyc-language/20"\nsource = "src"\n')


def need(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)


def pe(path):
    data = path.read_bytes()
    need(data[:2] == b'MZ', 'Expected DOS header')
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    need(data[offset:offset + 4] == b'PE\0\0' and
         struct.unpack_from('<H', data, offset + 4)[0] == 0x8664, 'Expected AMD64 PE')
    optional = offset + 24
    need(struct.unpack_from('<H', data, optional)[0] == 0x20b, 'Expected PE32+')
    stack = struct.unpack_from('<QQ', data, optional + 72)
    need(stack == (1048576, 4096), 'Unexpected stack reserve/commit')
    return dict(path=str(path), sha256=sha(data), bytes=len(data),
                stackReserve=stack[0], stackCommit=stack[1])


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain/fairyc.exe')
    parser.add_argument('--output', type=Path, help='New output directory only')
    parser.add_argument('--profile', choices=['development', 'optimized', 'all'], default='all')
    parser.add_argument('--kernel-receipt', type=Path, action='append', default=[],
                        help='Optional prior native kernel receipt; never reruns or mutates kernel tests')
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows x64 required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ),
         'Compiler/linker overrides must be absent, including empty values')
    output = (args.output or ROOT / 'build/abi-registry' /
              datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')).resolve()
    need(not output.exists(), 'Never overwrite previous evidence')
    output.mkdir(parents=True)
    compiler = args.compiler.resolve()
    receipt = dict(schema='browniec.abi-registry/v1', status='incomplete',
                   capturedAt=datetime.now(timezone.utc).isoformat(), commands=[],
                   scope='Internal 64-slot lazy module coordinator; not full E02/E01 or VM/native lifecycle')

    def run(command, cwd=output, env=None):
        command = list(map(str, command))
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=120)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index:02d}.stdout', f'logs/{index:02d}.stderr'
        write(output / stdout, result.stdout); write(output / stderr, result.stderr)
        receipt['commands'].append(dict(argv=command, cwd=str(cwd), exitCode=result.returncode,
                                       stdout=stdout, stderr=stderr,
                                       stdoutSha256=sha(result.stdout), stderrSha256=sha(result.stderr)))
        need(result.returncode == 0, f'Failed {command}; see {output / stderr}')
        return result.stdout

    try:
        need(sha(compiler.read_bytes()) == COMPILER, 'Pinned compiler mismatch')
        version = run([compiler, '--version']).decode('utf-8')
        need(REVISION in version and 'modified: true' in version and
             'fairyc-language/20' in version and '0.0.0-stage0.87' in version, 'Compiler identity mismatch')
        receipt['compiler'] = dict(sha256=COMPILER, revision=REVISION, version=version)
        inputs = {n: (ROOT / n).read_bytes() for n in FEATURES}
        need(all(b'\r' not in b for b in inputs.values()), 'All feature inputs must retain LF')
        need(sha(inputs['src/abi_handles.fy']) == KERNEL and
             sha(inputs['tools/abi-registry/main.fy']) == RETENTION, 'Reviewed kernel/retention mismatch')
        need(sha(inputs['native/abi_thread_identity.c']) == HELPER and
             sha(inputs['native/abi_thread_identity.h']) == HELPER_HEADER, 'Reviewed TLS-verifying successor required')
        contract = json.loads(inputs['tools/abi-registry/transport.json'])
        need(contract['schema'] == 'browniec.abi-registry-transport/v1' and
             contract['transportSha256'] == TRANSPORT and contract['kernelSha256'] == KERNEL and
             contract['compilerSha256'] == COMPILER and contract['retentionSha256'] == RETENTION,
             'Reviewed transport manifest mismatch')
        receipt['inputs'] = [dict(path=n, sha256=sha(b), bytes=len(b)) for n, b in inputs.items()]
        frozen = output / 'inputs'
        for name, data in inputs.items():
            write(frozen / name, data)
        provenance = []
        for index, path in enumerate(args.kernel_receipt):
            data = path.read_bytes(); prior = json.loads(data)
            need(prior['schema'] == 'browniec.abi-handles-verification/v1' and
                 prior['status'] == 'passed' and prior['nativeGroups'] == 10 and
                 prior['compilerSha256'] == COMPILER and prior['nativeReport']['passed'] == 10 and
                 prior['nativeReport']['failed'] == 0, 'Invalid prior native kernel receipt')
            hashes = {row['path']: row['sha256'] for row in prior['inputs']}
            need(hashes['src/abi_handles.fy'] == KERNEL and
                 hashes['tests/embed/handle_registry.fy'] == sha(inputs['tests/embed/handle_registry.fy']),
                 'Kernel evidence does not match current raw source/test')
            retained = f'kernel-evidence/{index}.json'; write(output / retained, data)
            provenance.append(dict(profile=prior['profile'], path=retained, sha256=sha(data),
                                   nativeGroups=10, sourceAndTestBytesMatch=True))
        receipt['priorKernelEvidence'] = provenance
        project = output / 'project'
        write(project / 'fairy.toml', MANIFEST)
        write(project / 'src/abi_handles.fy', inputs['src/abi_handles.fy'])
        write(project / 'src/main.fy', inputs['tools/abi-registry/main.fy'])
        run([compiler, 'check'], cwd=project)
        lock_bytes = (project / 'fairy.lock').read_bytes(); lock = json.loads(lock_bytes)
        need(lock['schema'] == 'fairyc.lock/v1' and len(lock['packages']) == 1 and
             lock['packages'][0]['packageUid'] == 'browniec.abi-registry' and lock['dependencies'] == [],
             'Expected isolated import-free kernel package')
        receipt['isolatedLockSha256'] = sha(lock_bytes)
        run([compiler, 'check', '--locked'], cwd=project)
        generated = run([compiler, 'experimental', 'emit-workspace-c', '--target',
                         'x86_64-windows-msvc', '--locked'], cwd=project)
        write(output / 'abi_registry_generated.c', generated)
        need(generated.startswith(b'/* fairyc constrained C transport: x86_64-windows-msvc, ISO C11 */\n') and
             sha(generated) == TRANSPORT, 'Full private generated transport mismatch')
        receipt['privateTransport'] = dict(sha256=TRANSPORT, bytes=len(generated), reviewedFunctions=23)
        pf = Path(os.environ['ProgramFiles(x86)'])
        vs = Path(run([pf / 'Microsoft Visual Studio/Installer/vswhere.exe', '-latest', '-products', '*',
                       '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
                       '-property', 'installationPath']).decode().strip())
        mv = (vs / 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt').read_text().strip()
        msvc = vs / 'VC/Tools/MSVC' / mv; cl = msvc / 'bin/Hostx64/x64/cl.exe'
        kits = pf / 'Windows Kits/10'
        versions = sorted(p.name for p in (kits / 'Include').iterdir() if p.name.startswith('10.') and
                          all((kits / a / p.name / b).is_dir() for a, b in
                              [('Include', 'ucrt'), ('Include', 'shared'), ('Include', 'um'),
                               ('Lib', 'ucrt/x64'), ('Lib', 'um/x64')]))
        need(bool(versions), 'Complete Windows SDK required'); sdk = versions[-1]
        env = dict(os.environ); env['PATH'] = str(cl.parent) + os.pathsep + env['PATH']
        env['INCLUDE'] = os.pathsep.join(map(str, [msvc / 'include'] +
                                       [kits / 'Include' / sdk / s for s in ['ucrt', 'shared', 'um']]))
        env['LIB'] = os.pathsep.join(map(str, [msvc / 'lib/x64'] +
                                   [kits / 'Lib' / sdk / s / 'x64' for s in ['ucrt', 'um']]))
        receipt['msvc'] = dict(version=mv, sdk=sdk, clSha256=sha(cl.read_bytes()),
                               standardEnvironment={k: env[k] for k in ['INCLUDE', 'LIB']},
                               compilerOverrides=False, stack='MSVC default, no /STACK')
        empty = output / 'empty-tools'; empty.mkdir()
        runtime = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
        runtime['PATH'] = str(empty)
        results = []
        for profile in (['development', 'optimized'] if args.profile == 'all' else [args.profile]):
            target = output / profile; target.mkdir()
            flags = ['/nologo', '/TC', '/std:c11', '/MT', '/W4', '/WX',
                     '/Od' if profile == 'development' else '/O2',
                     '/I' + str(frozen / 'native'), '/I' + str(output)]
            objects = []
            for source, name in [('native/abi_registry.c', 'registry'),
                                 ('native/abi_thread_identity.c', 'identity'),
                                 ('tests/embed/abi_registry_host.c', 'host')]:
                obj = target / (name + '.obj')
                run([cl, *flags, '/c', frozen / source, '/Fo' + str(obj)], env=env)
                objects.append(obj)
                symbols = run([cl.parent / 'dumpbin.exe', '/symbols', obj], env=env)
                need(b'bc_abi_test_' not in symbols, 'No test mutation controls in coordinator/identity/host')
            exe = target / 'abi-registry-host.exe'
            run([cl, '/nologo', *objects, '/Fe' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            cases = []
            for mode in ['basic', 'capacity', 'concurrent', 'lifetimes']:
                text = run([exe, mode], env=runtime).decode('utf-8').strip()
                need(text.startswith('PASS registry ' + mode + ':'), 'Unexpected host output: ' + text)
                cases.append(dict(mode=mode, result=text))
                print(profile + ': ' + text, flush=True)
            results.append(dict(profile=profile, cases=cases, host=pe(exe),
                                objects=[dict(path=str(p), sha256=sha(p.read_bytes())) for p in objects],
                                testControlsAbsent=True))
        need(all((ROOT / n).read_bytes() == b and (frozen / n).read_bytes() == b for n, b in inputs.items()),
             'Feature inputs changed during build')
        need(sha(compiler.read_bytes()) == COMPILER and (project / 'fairy.lock').read_bytes() == lock_bytes and
             sha((output / 'abi_registry_generated.c').read_bytes()) == TRANSPORT, 'Frozen build identity changed')
        receipt.update(status='passed', profiles=results, runtimeEnvironment='cleared; empty tool PATH',
                       kernelRerun=False, publicExports=False,
                       limitations=['64-slot module singleton, not accepted 65536-slot lazy paging',
                                    'no VM/native Engine lifecycle, Program pins, public E01 APIs or recovery',
                                    'generation exhaustion relies on matching prior kernel native evidence',
                                    'no allocator/TLS failure injection or process-wide coordination across DLL copies'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        write(output / 'receipt.json', json.dumps(receipt, indent=2) + '\n')
    print('Artifacts: ' + str(output), flush=True)


if __name__ == '__main__':
    main()
