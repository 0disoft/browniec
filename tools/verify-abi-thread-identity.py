"""Verify the internal Windows registry guard and nonreused TLS lifetimes."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
FEATURES = ['native/abi_thread_identity.c', 'native/abi_thread_identity.h',
            'tests/embed/abi_thread_identity_host.c', 'tools/verify-abi-thread-identity.py',
            'tools/build-abi-bootstrap.py']
spec = importlib.util.spec_from_file_location('bootstrap', ROOT / 'tools/build-abi-bootstrap.py')
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)
need = bootstrap.need
sha = lambda b: hashlib.sha256(b).hexdigest()


def main():
    need(os.name == 'nt', 'Windows x64 required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ), 'Compiler overrides must be absent')
    output = ROOT / 'build/abi-thread-identity' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output.mkdir(parents=True)
    frozen = output / 'inputs'
    inputs = {name: (ROOT / name).read_bytes() for name in FEATURES}
    for name, data in inputs.items():
        need(b'\r' not in data, f'LF input required: {name}')
        path = frozen / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    receipt = dict(schema='browniec.abi-thread-identity/v1', status='incomplete',
                   recordedAt=datetime.now(timezone.utc).isoformat(),
                   inputs=[dict(path=n, sha256=sha(b)) for n, b in inputs.items()], commands=[])

    def run(command, env=None):
        command = list(map(str, command))
        result = subprocess.run(command, cwd=output, env=env, capture_output=True, timeout=90)
        index = len(receipt['commands'])
        stdout, stderr = f'{index:02}.stdout', f'{index:02}.stderr'
        (output / stdout).write_bytes(result.stdout)
        (output / stderr).write_bytes(result.stderr)
        receipt['commands'].append(dict(argv=command, exit=result.returncode,
                                       stdout=stdout, stderr=stderr,
                                       stdoutSha256=sha(result.stdout), stderrSha256=sha(result.stderr)))
        need(result.returncode == 0, f'Failed command: {command}; see {output / stderr}')
        return result.stdout

    try:
        pf = Path(os.environ['ProgramFiles(x86)'])
        vs = Path(run([pf / 'Microsoft Visual Studio/Installer/vswhere.exe', '-latest', '-products', '*',
                       '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
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
                                       [kits / 'Include' / sdk / n for n in ['ucrt', 'shared', 'um']]))
        env['LIB'] = os.pathsep.join(map(str, [msvc / 'lib/x64'] +
                                   [kits / 'Lib' / sdk / n / 'x64' for n in ['ucrt', 'um']]))
        receipt['toolchain'] = dict(msvc=version, sdk=sdk, compilerSha256=sha(cl.read_bytes()),
                                    nativeOverrides=False, stack='MSVC default')
        results = []
        for profile in ['development', 'optimized']:
            target = output / profile
            target.mkdir()
            flags = ['/nologo', '/TC', '/std:c11', '/MT', '/W4', '/WX',
                     '/Od' if profile == 'development' else '/O2', '/I' + str(frozen / 'native')]
            source = frozen / 'native/abi_thread_identity.c'
            production = target / 'production.obj'
            run([cl, *flags, '/c', source, '/Fo' + str(production)], env)
            symbols = run([cl.parent / 'dumpbin.exe', '/symbols', production], env).decode(errors='replace')
            need('bc_abi_test_' not in symbols, 'Production must omit test-only state controls')
            test_object = target / 'identity.obj'
            run([cl, *flags, '/DBC_ABI_IDENTITY_TEST', '/c', source, '/Fo' + str(test_object)], env)
            exe = target / 'identity-host.exe'
            run([cl, *flags, '/DBC_ABI_IDENTITY_TEST', frozen / 'tests/embed/abi_thread_identity_host.c',
                 '/Fo' + str(target / 'host.obj'), '/Fe' + str(exe), '/link', test_object,
                 '/INCREMENTAL:NO', '/Brepro'], env)
            empty = output / 'empty-tools'
            empty.mkdir(exist_ok=True)
            runtime = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
            runtime['PATH'] = str(empty)
            report = run([exe], runtime).decode('utf-8').strip()
            need(report == 'PASS thread-identity: 8 concurrent threads, 1024 guarded updates, 32 sequential lifetimes, nonwrapping exhaustion',
                 'Unexpected host result')
            results.append(dict(profile=profile, result=report, productionSha256=sha(production.read_bytes()),
                                testControlAbsentFromProduction=True, host=bootstrap.pe_identity(exe, False)))
            print(f'{profile}: {report}', flush=True)
        need(all((ROOT / n).read_bytes() == b and (frozen / n).read_bytes() == b for n, b in inputs.items()),
             'Feature inputs changed')
        receipt.update(status='passed', profiles=results, runtimeEnvironment='cleared; empty tool PATH',
                       scope='OS primitive only: not wired to process-wide Fairy registry or public ABI')
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('Artifacts: ' + str(output))


if __name__ == '__main__':
    main()
