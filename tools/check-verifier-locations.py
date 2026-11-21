"""Run the single internal verifier output fixture in an isolated Windows release build."""

import json
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parent.parent
COMPILER = ROOT / 'build/toolchain/fairyc.exe'


def fixture_main():
    fixture = (ROOT / 'tests/m2/cli_locations.fy').read_text(encoding='utf-8')
    module = 'module tests::m2::cli_locations;'
    entry = '@test\nfn void renders_verifier_instruction_index()'
    if not fixture.startswith(module + '\n') or fixture.count(entry) != 1 or fixture.count('@test\n') != 1:
        raise ValueError('Expected the single verifier location fixture')
    return (
        fixture.replace(module, 'module main;', 1).replace(entry, entry.removeprefix('@test\n'), 1)
        + '\n@effects(console)\nfn i32 main(){renders_verifier_instruction_index();return 0;}\n'
    )


def verify_output(result):
    expected = []
    for index in (0, 1):
        for version, location in (
            (1, {'byte_offset': index}),
            (2, {'location': {'kind': 'instruction_index', 'offset': index}}),
        ):
            expected.append(json.dumps({
                'schema': f'browniec.result/v{version}',
                'profile': 'brownie.m1-scalar/1',
                'command': 'check',
                'status': 'error',
                'return_i32': None,
                'error': {'kind': 'verification', **location},
            }, separators=(',', ':')))
    stdout = ('\n'.join(expected) + '\n').encode('ascii')
    stderr = b'browniec: verification at instruction 0\nbrowniec: verification at instruction 1\n'
    if result.returncode != 0 or result.stdout != stdout or result.stderr != stderr:
        raise SystemExit(
            f'Verifier fixture exited {result.returncode}. '
            f'Expected exact stdout and stderr. Got {result.stdout!r} and {result.stderr!r}.'
        )


def main():
    # Native test in the pinned compiler cannot link project companions.
    # Use the release build path with only the verifier's clock companion.
    with TemporaryDirectory(prefix='verifier-locations-', dir=ROOT / 'build') as scratch:
        project = Path(scratch)
        shutil.copytree(ROOT / 'src', project / 'src')
        shutil.copyfile(ROOT / 'fairy.toml', project / 'fairy.toml')
        shutil.copyfile(ROOT / 'native/runtime-engine/clock.inc', project / 'verifier-clock.c')
        (project / 'src/main.fy').write_text(fixture_main(), encoding='utf-8', newline='\n')
        (project / 'fairy.windows.json').write_text(json.dumps({
            'schema': 'fairyc.windows-build/v1',
            'subsystem': 'console',
            'sources': ['verifier-clock.c'],
        }) + '\n', encoding='utf-8', newline='\n')
        subprocess.run([COMPILER, 'check'], cwd=project, check=True)
        subprocess.run([COMPILER, 'build', '--release', '--locked'], cwd=project, check=True)
        result = subprocess.run([project / 'build/browniec.exe'], cwd=project, capture_output=True, timeout=30)
        verify_output(result)
    print('PASS: one native release fixture checked instructions 0 and 1 in text, JSON v1 and JSON v2')


if __name__ == '__main__':
    main()
