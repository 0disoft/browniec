"""Build and execute the real Engine through the standard Windows build path."""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from tempfile import mkdtemp

ROOT = Path(__file__).resolve().parent.parent
COMPILER = ROOT / 'build/toolchain/fairyc.exe'
NATIVE = ROOT / 'native/runtime-engine'


def verify():
    assert __debug__ and os.name == 'nt'
    assert not {'CL', '_CL_', 'LINK'}.intersection(key.upper() for key in os.environ)
    pin = json.loads((ROOT / 'toolchain.json').read_bytes())['platforms']['windows/amd64']['sha256']
    assert hashlib.sha256(COMPILER.read_bytes()).hexdigest() == pin
    project = Path(mkdtemp(prefix='windows-engine-build-', dir=ROOT / 'build'))
    for folder in ('src', 'native'):
        shutil.copytree(ROOT / folder, project / folder)
    shutil.copyfile(ROOT / 'fairy.toml', project / 'fairy.toml')
    shutil.copyfile(ROOT / 'tools/windows-engine-build/main.fy', project / 'src/main.fy')
    for module in ('runtime_engine', 'runtime_pending_output', 'windows_engine_bindings'):
        shutil.copyfile(NATIVE / f'{module}.fy', project / 'src' / f'{module}.fy')

    def write(name, value):
        (project / name).write_text(json.dumps(value) + '\n', encoding='utf-8', newline='\n')

    source = 'native/windows-runtime-engine.c'
    bindings = re.findall(r'^#define B\d+ fy_private_fn_([0-9a-f]+) /\* (\S+) \*/$',
                          (ROOT / source).read_text(encoding='utf-8'), re.MULTILINE)
    assert len(bindings) == len({name for _, name in bindings}) == 35
    assert all(bytes.fromhex(encoded).decode('utf-8') == name for encoded, name in bindings)
    manifest = json.loads((ROOT / 'fairy.windows.json').read_bytes())
    manifest['sources'].append(source)
    manifest['privateFunctions'] = [name for _, name in bindings] + ['windows_engine_bindings::incoming']
    write('fairy.windows.json', manifest)

    policy = json.loads((ROOT / 'tools/runtime-policy/reference/policy.output.json').read_bytes())
    capabilities = ['brownie.output.emit']
    entry = {'module': 'app', 'function': 'chosen'}
    write('policy.json', policy)
    write('run.json', {
        'schema': 'brownie.run/0.3', 'entry': entry, 'requires': capabilities,
        'grants': capabilities, 'limits': policy['run'],
    })
    write('project.json', {
        'schema': 'brownie.project/0.3', 'name': 'fixture', 'entry': entry,
        'sources': [{'module': 'app', 'path': 'output.brc'}], 'requires': capabilities,
    })
    (project / 'output.brc').write_bytes(
        b'module app; pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 77;}')

    def run(label, *args, timeout=900):
        result = subprocess.run(args, cwd=project, capture_output=True, timeout=timeout)
        (project / f'{label}.stdout').write_bytes(result.stdout)
        (project / f'{label}.stderr').write_bytes(result.stderr)
        assert result.returncode == 0 and not result.stderr, (args, project, result)

    run('check', COMPILER, 'check')
    for profile, flags in [('development', []), ('release', ['--release'])]:
        run(f'{profile}-build', COMPILER, 'build', '--locked', *flags)
        exe = project / 'build/browniec.exe'
        run(f'{profile}-run', exe, 'policy.json', 'run.json', 'project.json', timeout=30)
        print(f'PASS {profile}: Engine return 77 and sealed bytes A\\0 ({project})', flush=True)


if __name__ == '__main__':
    verify()
