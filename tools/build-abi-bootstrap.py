"""Build/verify ONLY the Windows x64 revision-2 ABI bootstrap, never the CLI.

Private emit-workspace-c transport is pinned byte-for-byte, not a stable C ABI.
No engine implementations, success stubs, custom stacks or availability claims.
Requires installed MSVC x64 + Windows SDK; uses their standard include/lib paths.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
COMPILER_SHA256 = '9651623adbb6e05e0f948b826431853df310050387c955aee77ac0b12a81ab7a'
COMPILER_REVISION = 'eb274643bfcfe746617121ddc6f130b018978b53'
TRANSPORT_SHA256 = '0b05383737badf57699028ef9040432df3ed3ef0a2432e6236223369987deef8'
ARCHIVE_SHA256 = '9786d2d2a0d0cd9048a47d17f6fd5c4574cdbcaeec00d17570602fa541b7dc5e'
HEADER_SHA256 = 'cfc230a0ac1483fb00338206f66fd62a06539c2128c5378ba9bdc647a5ff5e90'
LAYOUT_SHA256 = '3330f91917e8f449855030343eb004e5d9fc3f9392023c3ce167472b5b8a63ea'
FEATURE_FILES = ['include/brownie.h', 'src/abi_bootstrap.fy', 'native/abi_bootstrap.c',
                 'tools/build-abi-bootstrap.py', 'tools/abi-bootstrap/main.fy',
                 'tests/embed/abi_bootstrap_host.c', 'native/abi_bootstrap_layout.h',
                 'tools/abi-bootstrap/reference/host-abi.h',
                 'tools/abi-bootstrap/reference/abi-layout.json']


def need(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)


def pe_identity(path, is_dll):
    data = path.read_bytes()
    need(data[:2] == b'MZ', 'Missing PE DOS signature')
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    need(data[offset:offset + 4] == b'PE\0\0', 'Missing PE signature')
    need(struct.unpack_from('<H', data, offset + 4)[0] == 0x8664, 'Expected AMD64 PE')
    flags = struct.unpack_from('<H', data, offset + 22)[0]
    need(bool(flags & 0x2000) == is_dll, 'Unexpected DLL/image kind')
    optional = offset + 24
    need(struct.unpack_from('<H', data, optional)[0] == 0x20b, 'Expected PE32+')
    reserve, commit = struct.unpack_from('<QQ', data, optional + 72)
    need((reserve, commit) == (1048576, 4096), 'Unexpected MSVC default stack sizes')
    return dict(path=str(path), sha256=sha(data), machine='AMD64',
                stackReserve=reserve, stackCommit=commit)


def main():
    # Redirected Windows streams otherwise use an ACP that cannot represent paths.
    sys.stdout.reconfigure(encoding='utf-8', errors='backslashreplace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain/fairyc.exe')
    parser.add_argument('--design-archive', type=Path,
                        help='Optional provenance check against the original design ZIP; not a build dependency.')
    parser.add_argument('--output', type=Path,
                        help='New output directory; defaults to a unique build/abi-bootstrap run.')
    parser.add_argument('--profile', choices=['development', 'optimized', 'all'], default='all')
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows x64 only')
    need(all(key.upper() not in {'CL', '_CL_', 'LINK'} for key in os.environ),
         'CL/_CL_/LINK must be absent, including empty overrides')
    compiler = args.compiler.resolve()
    out = (args.output or ROOT / 'build/abi-bootstrap' /
           datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')).resolve()
    need(not out.exists(), 'Use a new output directory; never overwrite previous evidence')
    out.mkdir(parents=True)
    commands = []
    receipt = dict(schema='browniec.abi-bootstrap/v1', status='incomplete',
                   capturedAt=datetime.now(timezone.utc).isoformat(), commands=commands,
                   stacks='MSVC defaults; no /STACK or compiler/linker environment overrides',
                   scope='bootstrap only; E01 and embedding remain incomplete')

    def run(command, cwd=out, env=None):
        command = list(map(str, command))
        index = len(commands)
        log = out / 'logs' / f'{index:02d}'
        result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=180)
        write(log.with_suffix('.stdout'), result.stdout)
        write(log.with_suffix('.stderr'), result.stderr)
        commands.append(dict(command=command, cwd=str(cwd), exitCode=result.returncode,
                             stdout=str(log.with_suffix('.stdout').relative_to(out)),
                             stderr=str(log.with_suffix('.stderr').relative_to(out)),
                             stdoutSha256=sha(result.stdout), stderrSha256=sha(result.stderr)))
        need(result.returncode == 0, f'Command failed: {command}; see {log}')
        return result.stdout

    try:
        need(sha(compiler.read_bytes()) == COMPILER_SHA256, 'Compiler checksum mismatch')
        version = run([compiler, '--version']).decode('utf-8')
        need(COMPILER_REVISION in version and 'modified: false' in version
             and 'fairyc-language/20' in version and '0.0.0-stage0.87' in version,
             'Compiler/version schema mismatch')
        receipt['compiler'] = dict(path=str(compiler), sha256=COMPILER_SHA256, version=version)
        inputs = {name: (ROOT / name).read_bytes() for name in FEATURE_FILES}
        need(all(b'\r' not in blob for blob in inputs.values()), 'Feature inputs must be LF')
        receipt['inputs'] = [dict(path=n, sha256=sha(b)) for n, b in inputs.items()]
        frozen = out / 'inputs/feature'
        for name, data in inputs.items():
            write(frozen / name, data)
        canonical = inputs['tools/abi-bootstrap/reference/host-abi.h']
        layout = inputs['tools/abi-bootstrap/reference/abi-layout.json']
        archive = None
        archive_bytes = None
        doc = None
        if args.design_archive is not None:
            archive = args.design_archive.resolve()
            archive_bytes = archive.read_bytes()
            need(sha(archive_bytes) == ARCHIVE_SHA256, 'Design archive checksum mismatch')
            with zipfile.ZipFile(archive) as z:
                prefix = 'brownie-c-design-v0.3.0/'
                need(z.read(prefix + 'contracts/host-abi.h') == canonical and
                     z.read(prefix + 'contracts/abi-layout.json') == layout,
                     'Archive contracts differ from repository references')
                doc = z.read(prefix + 'docs/08-embedding-and-worker.md')
        need(sha(canonical) == HEADER_SHA256 and sha(layout) == LAYOUT_SHA256,
             'Canonical contract checksum mismatch')
        spec = json.loads(layout)
        need(spec['schema'] == 'brownie.abi-layout/1' and spec['abi_revision'] == 2
             and spec['target'] == 'windows-x64-natural' and spec['pointer_bits'] == 64,
             'Canonical layout schema mismatch')

        def declarations(blob):
            text = re.sub(r'/\*.*?\*/', '', blob.decode('utf-8'), flags=re.S)
            text = re.sub(r'^\s*#.*$', '', text, flags=re.M)
            return re.sub(r'\s+', '', text.replace('BC_BOOTSTRAP_QUERY_API', '').replace('BC_API', ''))

        need(declarations(canonical) == declarations(inputs['include/brownie.h']),
             'Header declarations differ from canonical contract')
        receipt['design'] = dict(source='repository ABI references',
                                 archiveVerified=archive is not None,
                                 archivePath=str(archive) if archive else None,
                                 archiveSha256=ARCHIVE_SHA256,
                                 headerSha256=HEADER_SHA256, layoutSha256=LAYOUT_SHA256,
                                 embeddingDocSha256=sha(doc) if doc is not None else None)
        for name, data in [('host-abi.h', canonical), ('abi-layout.json', layout)]:
            write(out / 'inputs' / name, data)
        if doc is not None:
            write(out / 'inputs/08-embedding-and-worker.md', doc)
        project = out / 'project'
        write(project / 'src/abi_bootstrap.fy', inputs['src/abi_bootstrap.fy'])
        write(project / 'src/main.fy', inputs['tools/abi-bootstrap/main.fy'])
        write(project / 'fairy.toml', 'schema = "fairyc.manifest/v1"\n\n[package]\n'
              'uid = "browniec.abi-bootstrap"\nname = "browniec-abi-bootstrap"\n'
              'version = "0.1.0"\nlanguage = "fairyc-language/20"\nsource = "src"\n')
        run([compiler, 'check'], cwd=project)  # Own lock only; never root workspace.
        lock_bytes = (project / 'fairy.lock').read_bytes()
        lock = json.loads(lock_bytes)
        need(lock['schema'] == 'fairyc.lock/v1' and lock['language'] == 'fairyc-language/20'
             and len(lock['packages']) == 1 and lock['packages'][0]['role'] == 'root'
             and lock['packages'][0]['packageUid'] == 'browniec.abi-bootstrap'
             and lock['dependencies'] == [], 'Isolated lock schema/package mismatch')
        receipt['isolatedLockSha256'] = sha(lock_bytes)
        run([compiler, 'check', '--locked'], cwd=project)
        generated = run([compiler, 'experimental', 'emit-workspace-c', '--target',
                         'x86_64-windows-msvc', '--locked'], cwd=project)
        write(out / 'abi_bootstrap_generated.c', generated)
        need(generated.startswith(b'/* fairyc constrained C transport: x86_64-windows-msvc, ISO C11 */\n')
             and sha(generated) == TRANSPORT_SHA256, 'Private transport/schema/symbol mismatch')
        receipt['privateTransportSha256'] = sha(generated)
        # Standard installed toolchain paths; no runtime/SDK source or fairyc edits.
        pf = Path(os.environ['ProgramFiles(x86)'])
        vs = Path(run([pf / 'Microsoft Visual Studio/Installer/vswhere.exe', '-latest',
                       '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
                       '-property', 'installationPath']).decode().strip())
        mv = (vs / 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt').read_text().strip()
        msvc = vs / 'VC/Tools/MSVC' / mv
        cl = msvc / 'bin/Hostx64/x64/cl.exe'
        dumpbin = cl.parent / 'dumpbin.exe'
        kits = pf / 'Windows Kits/10'
        versions = sorted(p.name for p in (kits / 'Include').iterdir() if p.name.startswith('10.')
                          and all((kits / a / p.name / b).is_dir() for a, b in
                                  [('Include', 'ucrt'), ('Include', 'um'), ('Include', 'shared'),
                                   ('Lib', 'ucrt/x64'), ('Lib', 'um/x64')]))
        need(bool(versions), 'Complete Windows SDK unavailable')
        sdk = versions[-1]
        env = dict(os.environ)
        env['PATH'] = str(cl.parent) + os.pathsep + os.environ['PATH']
        env['INCLUDE'] = os.pathsep.join(map(str, [msvc / 'include'] +
                                           [kits / 'Include' / sdk / s for s in ['ucrt', 'shared', 'um']]))
        env['LIB'] = os.pathsep.join(map(str, [msvc / 'lib/x64'] +
                                       [kits / 'Lib' / sdk / s / 'x64' for s in ['ucrt', 'um']]))
        receipt['msvc'] = dict(version=mv, sdk=sdk, cl=str(cl), clSha256=sha(cl.read_bytes()),
                               dumpbinSha256=sha(dumpbin.read_bytes()),
                               overrideEnvironment={key: key in os.environ for key in ['CL', '_CL_', 'LINK']},
                               standardEnvironment={key: env[key] for key in ['INCLUDE', 'LIB']})
        include = ['/I' + str(frozen / 'include'), '/I' + str(frozen / 'native'), '/I' + str(out)]
        host_source = frozen / 'tests/embed/abi_bootstrap_host.c'
        # C++ compile independently verifies public declarations and every layout assertion.
        run([cl, '/nologo', '/TP', '/std:c++17', '/W4', '/WX', *include, '/c', host_source,
             '/Fo' + str(out / 'layout-cxx.obj')], env=env)
        results = []
        for profile in (['development', 'optimized'] if args.profile == 'all' else [args.profile]):
            target = out / profile
            target.mkdir()
            dll = target / 'brownie-bootstrap.dll'
            host = target / 'abi-bootstrap-host.exe'
            flags = ['/nologo', '/TC', '/std:c11', '/MT', '/W4', '/WX',
                     '/Od' if profile == 'development' else '/O2', *include]
            run([cl, *flags, '/LD', frozen / 'native/abi_bootstrap.c',
                 '/Fo' + str(target / 'bootstrap.obj'), '/Fe' + str(dll), '/link',
                 '/INCREMENTAL:NO', '/Brepro', '/IMPLIB:' + str(target / 'bootstrap.lib')], env=env)
            exports = run([dumpbin, '/exports', dll], env=env).decode(errors='replace')
            names = re.findall(r'^\s*\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\S+)\s*$', exports, re.M)
            need(names == ['bc_get_abi_info_v2'], 'DLL must export exactly the unmangled bootstrap symbol')
            run([dumpbin, '/headers', dll], env=env)
            run([cl, *flags, host_source, '/Fo' + str(target / 'host.obj'), '/Fe' + str(host),
                 '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            imports = run([dumpbin, '/imports', host], env=env).decode(errors='replace')
            need('brownie-bootstrap' not in imports.lower(), 'Host must not link a Brownie import library')
            runtime_env = {key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ}
            empty = out / 'runtime-empty'
            empty.mkdir(exist_ok=True)
            need(not any(empty.iterdir()), 'Runtime tool directory must remain empty')
            runtime_env['PATH'] = str(empty)
            output = run([host, dll], env=runtime_env).decode('utf-8').strip()
            need(output.startswith('PASS abi-bootstrap: 53 DLL calls;'), 'Unexpected host result')
            results.append(dict(profile=profile, exports=names, result=output,
                                dll=pe_identity(dll, True), host=pe_identity(host, False)))
            print(profile + ': ' + output, flush=True)
        need(sha(compiler.read_bytes()) == COMPILER_SHA256, 'Compiler changed')
        if archive is not None:
            need(archive.read_bytes() == archive_bytes, 'Archive changed')
        need((project / 'fairy.lock').read_bytes() == lock_bytes, 'Isolated lock changed')
        need(all((ROOT / n).read_bytes() == b for n, b in inputs.items()), 'Feature inputs changed')
        need(all((frozen / n).read_bytes() == b for n, b in inputs.items()), 'Frozen inputs changed')
        need(sha((out / 'abi_bootstrap_generated.c').read_bytes()) == TRANSPORT_SHA256,
             'Retained private transport changed')
        receipt.update(status='passed', profiles=results,
                       runtimeEnvironment='cleared; empty tool PATH')
        print('Artifacts: ' + str(out), flush=True)
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        write(out / 'receipt.json', json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    main()
