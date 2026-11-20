"""Verify sealed VM output framing in isolated, locked Windows builds."""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import mkdtemp
import base64
import hashlib
import json
import os
import shutil
import subprocess


ROOT = Path(__file__).resolve().parent.parent
COMPILER = ROOT / 'build/toolchain/fairyc.exe'
FIXTURE = ROOT / 'tools/cli-published-output/main.fy'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(profile):
    project = Path(mkdtemp(prefix=f'published-output-{profile}-', dir=ROOT / 'build'))
    for name in ('fairy.toml', 'fairy.windows.json'):
        shutil.copyfile(ROOT / name, project / name)
    for name in ('src', 'native'):
        shutil.copytree(ROOT / name, project / name)
    shutil.copyfile(FIXTURE, project / 'src/main.fy')

    def run(label, argv, timeout=900):
        done = subprocess.run(argv, cwd=project, capture_output=True, timeout=timeout)
        (project / f'{label}.stdout').write_bytes(done.stdout)
        (project / f'{label}.stderr').write_bytes(done.stderr)
        assert done.returncode == 0 and not done.stderr, (
            profile, project, label, done.returncode, done.stderr[-3500:])
        return done.stdout

    run('check', [COMPILER, 'check'])
    build = [COMPILER, 'build', '--locked']
    if profile == 'release':
        build.append('--release')
    run('build', build)
    artifact = project / 'build/browniec.exe'
    raw = run('execute', [artifact], timeout=30)
    assert raw.endswith(b'\n') and len(raw.splitlines()) == 8, (profile, project)
    results = [json.loads(line) for line in raw.splitlines()]

    def success(index, data, version):
        row = results[index]
        expected = {
            'schema': f'browniec.result/v{version}', 'profile': 'brownie.m2-reference/1',
            'command': 'run', 'status': 'completed', 'return_i32': 77, 'error': None,
            'output_b64': base64.b64encode(data).decode('ascii'),
        }
        assert row == expected, (profile, index, str(row)[:250])

    for index, data in enumerate((b'', b'\xff', b'\x00\xff', b'\x00\xff\xfe')):
        success(index, data, 1 if index == 0 else 2)
    for row, kind in zip(results[4:7], ('output_limit', 'output_denied', 'zero_divisor'), strict=True):
        assert row['error']['kind'] == kind, row
        assert row['status'] == 'error' and row['return_i32'] is None, row
        assert 'output_b64' not in row, row
    success(7, bytes(1048575) + b'\xff', 2)
    print(f'PASS {profile}: 8 exact frames, {sha(artifact)}, {project}', flush=True)


if __name__ == '__main__':
    assert __debug__ and os.name == 'nt'
    assert not {'CL', '_CL_', 'LINK'}.intersection(key.upper() for key in os.environ)
    pin = json.loads((ROOT / 'toolchain.json').read_bytes())['platforms']['windows/amd64']['sha256']
    assert sha(COMPILER) == pin
    with ThreadPoolExecutor(max_workers=2) as executor:
        list(executor.map(verify, ('development', 'release')))
