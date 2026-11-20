"""Exercise explicit Windows configuration file acquisition in both native profiles."""

from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import mkdtemp


ROOT = Path(__file__).resolve().parent.parent
COMPILER = ROOT / 'build/toolchain/fairyc.exe'
REFERENCE = ROOT / 'tools/runtime-policy/reference'
LIMIT = 65536


def verify(profile):
    project = Path(mkdtemp(prefix=f'cli-configuration-{profile}-', dir=ROOT / 'build'))
    for name in ('fairy.toml', 'fairy.windows.json'):
        shutil.copyfile(ROOT / name, project / name)
    for name in ('src', 'native'):
        shutil.copytree(ROOT / name, project / name)
    shutil.copyfile(ROOT / 'tools/cli-run-configuration/main.fy', project / 'src/main.fy')

    def run(label, argv, timeout=900):
        result = subprocess.run(argv, cwd=project, capture_output=True, timeout=timeout)
        (project / f'{label}.stdout').write_bytes(result.stdout)
        (project / f'{label}.stderr').write_bytes(result.stderr)
        assert result.returncode == 0 and not result.stderr, (
            profile, project, label, result.returncode, result.stderr[-3500:])
        return result.stdout

    policy = (REFERENCE / 'policy.pure.json').read_bytes()
    config = json.loads((REFERENCE / 'run-config.example.json').read_bytes())
    config['limits'] = json.loads(policy)['run']
    config['limits']['fuel'] = 10000000
    assert config['limits']['fuel'] <= json.loads(policy)['run']['fuel']
    allowed = json.dumps(config).encode('utf-8')
    config['grants'] = ['brownie.output.emit']
    data = {
        'policy.json': policy.ljust(LIMIT, b' '),
        'run.json': allowed.ljust(LIMIT, b' '),
        'too-large.json': policy.ljust(LIMIT + 1, b' '),
        'denied.json': json.dumps(config).encode('utf-8'),
        'malformed.json': b'{"schema":',
    }
    for name, raw in data.items():
        (project / name).write_bytes(raw)

    run('check', [COMPILER, 'check'])
    build = [COMPILER, 'build', '--locked']
    if profile == 'release':
        build.append('--release')
    run('build', build)
    assert not run('execute', [project / 'build/browniec.exe', *data, 'missing.json'], timeout=30)
    print(f'PASS {profile}: exact cap, over cap, authority, syntax, missing file ({project})', flush=True)


if __name__ == '__main__':
    assert __debug__ and os.name == 'nt'
    assert not {'CL', '_CL_', 'LINK'}.intersection(key.upper() for key in os.environ)
    pin = json.loads((ROOT / 'toolchain.json').read_bytes())['platforms']['windows/amd64']['sha256']
    assert hashlib.sha256(COMPILER.read_bytes()).hexdigest() == pin
    with ThreadPoolExecutor(max_workers=2) as executor:
        list(executor.map(verify, ('development', 'release')))
