"""Build the Windows x64 trusted scalar preview DLL with the pinned Fairy compiler."""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from tempfile import mkdtemp

from runtime_engine_transport import bindings_header, project_layouts

ROOT = Path(__file__).resolve().parents[1]
TARGET = ['experimental', 'emit-workspace-c', '--target', 'x86_64-windows-msvc', '--locked']


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def emit(compiler, project, destination):
    subprocess.run([compiler, 'check'], cwd=project, check=True)
    with destination.open('wb') as stream:
        subprocess.run([compiler, *TARGET], cwd=project, stdout=stream, check=True)
    return destination.read_text(encoding='utf-8')


def preview_bindings(source):
    markers = re.findall(r'bc_embed_binding\(UINT32_C\((\d+)\)\);\s+'
                         r'goto (fy_b_\d+);\s*\2:\n(?:    [^\n]+\n)*?    [^\n]*\b(fy_fn_\d+)\(', source)
    if [int(number) for number, _, _ in markers] != list(range(1, 21)):
        raise RuntimeError('Unrecognized scalar preview transport')
    return ''.join(f'#define P{number} {symbol}\n' for number, _, symbol in markers)


def write(path, content):
    path.write_text(content, encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'optimized', 'all'], default='all')
    args = parser.parse_args()
    if os.name != 'nt' or {key.upper() for key in os.environ} & {'CL', '_CL_', 'LINK'}:
        raise RuntimeError('Windows x64 and the default MSVC compiler/linker environment are required')
    compiler = ROOT / 'build/toolchain/fairyc.exe'
    contract = json.loads((ROOT / 'native/runtime-engine/transport.json').read_bytes())
    toolchain = json.loads((ROOT / 'toolchain.json').read_bytes())
    digest = hashlib.sha256(compiler.read_bytes()).hexdigest()
    if digest != contract['compilerSha256'] or digest != toolchain['platforms']['windows/amd64']['sha256']:
        raise RuntimeError('Pinned Fairy compiler differs from the Engine transport contract')
    out = Path(mkdtemp(prefix='embed-preview-', dir=ROOT / 'build'))
    print(f'Artifacts: {out}', flush=True)

    engine = out / 'engine'
    shutil.copytree(ROOT / 'src', engine / 'src')
    shutil.copyfile(ROOT / 'tools/embed-preview/main.fy', engine / 'src/main.fy')
    shutil.copyfile(ROOT / 'fairy.toml', engine / 'fairy.toml')
    source = emit(compiler, engine, out / 'generated.c')
    project_layouts(source, contract)
    write(out / 'bindings.h', bindings_header(contract) + preview_bindings(source))
    write(out / 'preview.c', '#define main bc_preview_unused_main\n#include "generated.c"\n#undef main\n'
          '#include "abi_thread_identity.h"\n#include "bindings.h"\n'
          '#include "bridge.inc"\n#include "preview.inc"\n')

    registry = out / 'registry'
    (registry / 'src').mkdir(parents=True)
    registry_tool = load_tool('build-abi-registry')
    write(registry / 'fairy.toml', registry_tool.MANIFEST)
    shutil.copyfile(ROOT / 'src/abi_handles.fy', registry / 'src/abi_handles.fy')
    shutil.copyfile(ROOT / 'tools/abi-registry/main.fy', registry / 'src/main.fy')
    emit(compiler, registry, out / 'abi_registry_generated.c')
    if hashlib.sha256((out / 'abi_registry_generated.c').read_bytes()).hexdigest() != registry_tool.TRANSPORT:
        raise RuntimeError('Review the Fairy registry transport before using it in the preview')

    sdk = (ROOT / toolchain['source']['localRepository']).resolve()
    # Fairy C's Windows x64 runtime uses MSVC's 16-byte malloc alignment.
    runtime = ['#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)']
    for row in contract['runtimeInputs']:
        data = subprocess.check_output(['git', 'show', f"{row['revision']}:{row['path']}"], cwd=sdk)
        if hashlib.sha256(data).hexdigest() != row['sha256']:
            raise RuntimeError(f"Pinned runtime changed: {row['path']}")
        text = data.decode('utf-8')
        runtime.append(text.replace('@TRAP_EXIT_BASE@', '192').replace('@TRAP_RECEIPT_INCLUDE@', '')
                       .replace('@TRAP_RECEIPT_WRITE@', ''))
    write(out / 'runtime.c', '\n'.join(runtime))

    probe = load_tool('verify-runtime-store-probe')
    cl, env, _ = probe.native_environment(subprocess.check_output)
    includes = ['/I' + str(path) for path in (ROOT, ROOT/'native', ROOT/'include',
                                             ROOT/'native/runtime-engine', out)]
    sources = [('preview', out/'preview.c', []), ('runtime', out/'runtime.c', []),
               ('registry', ROOT/'native/abi_registry.c', ['/Dfy_runtime_trap=bc_registry_trap',
                                                          '/Dfy_runtime_trap_at_v0=bc_registry_trap_at']),
               ('thread', ROOT/'native/abi_thread_identity.c', ['/DBC_ABI_WAIT_FOR_METADATA']),
               ('project', ROOT/'native/windows-project-cli.c', []),
               ('input', ROOT/'native/runtime_input_reader.c', []),
               ('adapter', ROOT/'native/host_adapter_process.c', [])]
    profiles = ['development', 'optimized'] if args.profile == 'all' else [args.profile]
    results = {}
    for profile in profiles:
        folder = out / profile
        folder.mkdir()
        flags = ['/nologo', '/std:c11', '/MT', '/Gy', '/Od' if profile == 'development' else '/O2', *includes]

        def native(*argv):
            subprocess.run([cl, *argv], cwd=folder, env=env, check=True, timeout=900)

        objects = []
        for name, path, extra in sources:
            obj = folder / (name + '.obj')
            native(*flags, *extra, '/c', path, '/Fo' + str(obj))
            objects.append(obj)
        dll = folder / 'brownie-preview.dll'
        native('/nologo', *objects, '/LD', '/Fe' + str(dll), '/link', '/OPT:REF', 'bcrypt.lib', 'ntdll.lib')
        host = folder / 'preview-host.exe'
        native(*flags, '/W4', '/WX', ROOT/'tests/embed/preview_host.c', '/Fe' + str(host),
               '/link', folder/'brownie-preview.lib')
        shutil.copyfile(ROOT/'tools/runtime-policy/reference/policy.pure.json', folder/'policy.json')
        shutil.copyfile(ROOT/'tools/runtime-policy/reference/run-base.json', folder/'run.json')
        shutil.copyfile(ROOT/'tools/runtime-policy/reference/policy.output.json', folder/'policy-output.json')
        output_run = json.loads((folder/'run.json').read_bytes())
        output_run['requires'] = output_run['grants'] = ['brownie.output.emit']
        output_run['limits']['output_bytes'] = 2
        write(folder/'run-output.json', json.dumps(output_run, separators=(',', ':')))
        host_policy = json.loads((folder/'policy.json').read_bytes())
        host_policy['capabilities'] = ['host.example.check']
        write(folder/'policy-host.json', json.dumps(host_policy, separators=(',', ':')))
        host_run = json.loads((folder/'run.json').read_bytes())
        host_run['requires'] = host_run['grants'] = host_policy['capabilities']
        write(folder/'run-host.json', json.dumps(host_run, separators=(',', ':')))
        subprocess.run([host], cwd=folder, check=True, timeout=30)
        results[profile] = hashlib.sha256(dll.read_bytes()).hexdigest()
    write(out / 'receipt.json', json.dumps({'compilerSha256': digest, 'dllSha256': results}, indent=2) + '\n')


if __name__ == '__main__':
    main()
