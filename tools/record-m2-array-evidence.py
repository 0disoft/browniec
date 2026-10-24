"""Validate executed Windows receipts and record the source-array increment."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote


root = Path(__file__).resolve().parent.parent


def read(name):
    return json.loads((root / name).read_text(encoding='utf-8-sig'))


def digest(name):
    return hashlib.sha256((root / name).read_bytes()).hexdigest()


def native(result, count):
    tests = result['nativeTests']
    assert tests['status'] == 'ok' and tests['count'] == count
    assert tests['passed'] == count and tests['failed'] == 0
    assert tests['profile'] == result['profile'] and tests['engine'] == 'native'
    assert len(tests['tests']) == count
    assert all(t['outcome'] == 'passed' for t in tests['tests'])


def inputs(receipt):
    assert receipt['status'] == 'passed'
    assert [r['profile'] for r in receipt['results']] == ['development', 'release']
    for item in receipt['sourceSha256']:
        assert digest(item['path']) == item['sha256'], item['path']
    assert digest('build/toolchain/fairyc.exe') == receipt['compilerSha256']


receipt = read('build/m2-array-source/receipt.json')
assert receipt['schema'] == 'browniec.m2-array-source/v1'
inputs(receipt)
assert receipt['allocatorTests'] == []
for result in receipt['results']:
    native(result, 18)
    assert digest(result['artifact']) == result['sha256']
    name = f"build/m2-array-source/{result['profile']}/cli-receipt.json"
    cli = read(name)
    assert cli['schema'] == 'browniec.m2-array-source-cli/v1'
    assert cli['status'] == 'passed' and cli['count'] == result['cliCases'] == 67
    assert cli['profile'] == result['profile'] and cli['exeSha256'] == result['sha256']
    assert len(cli['cases']) == 67
    for case in cli['cases']:
        if 'sourceSha256' in case:
            fixture = f"build/m2-array-source/{result['profile']}/{case['case']}.brc"
            assert digest(fixture) == case['sourceSha256'], fixture
    result['cliReceiptSha256'] = digest(name)

scalar = read('build/m1/receipt.json')
assert scalar['schema'] == 'browniec.m1-scalar/v1'
inputs(scalar)
assert scalar['compilerSha256'] == receipt['compilerSha256']
assert scalar['recordedAt'] >= receipt['recordedAt'], 'Scalar regression must follow the source slice'
for result in scalar['results']:
    native(result, 81)
    assert result['cliCases'] == 1969
    assert digest(result['artifact']) == result['sha256']
    name = f"build/m1/{result['profile']}/cli-receipt.json"
    cli = read(name)
    assert cli['schema'] == 'browniec.m1-cli-checks/v1'
    assert cli['status'] == 'passed' and cli['count'] == result['cliCases']
    assert cli['profile'] == result['profile'] and cli['exeSha256'] == result['sha256']
    assert len(cli['cases']) == 1969
    result['cliReceiptSha256'] = digest(name)
receipt['scalarRegression'] = scalar

m0 = read('docs/evidence/m0-windows-20261023.json')
for item in m0['sourceSha256']:
    assert digest(item['path']) == item['sha256'], item['path']
assert m0['compilerSha256'] == receipt['compilerSha256']

paths = subprocess.check_output(
    ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '--', '*.md'],
    cwd=root, text=True).splitlines()
links = 0
destination = root / 'docs/evidence/m2-array-source-windows-20261024.json'
for name in paths:
    doc = root / name
    content = doc.read_text(encoding='utf-8-sig')
    assert not re.search(r'[A-Za-z]:[\\/](?:Users|Program Files)', content), name
    for target in re.findall(r'(?<!!)\[[^\]]*\]\(([^)]+)\)', content):
        target = target.strip().strip('<>')
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
            continue
        target = unquote(target.split('#', 1)[0])
        if target:
            resolved = (doc.parent / target).resolve()
            assert resolved == destination or resolved.exists(), (name, target)
            links += 1
subprocess.run(['git', 'diff', '--check'], cwd=root, check=True)
receipt['baselineCommit'] = subprocess.check_output(
    ['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
receipt['sourceIdentity'] = 'Exact worktree input hashes, rechecked after both profiles and scalar regression.'
receipt['commands'] = [
    'pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice source',
    'pwsh -NoProfile -File tools/verify-m1.ps1',
    'python -B tools/record-m2-array-evidence.py',
    'git diff --check',
]
receipt['documentationChecks'] = dict(files=len(paths), relativeLinks=links,
    noLocalAbsolutePaths='passed', diffCheck='passed')
receipt['m0Reuse'] = dict(inputs=len(m0['sourceSha256']),
    compilerIdentity='unchanged', inputIdentity='unchanged')
receipt['skipped'] = [
    dict(check='M0 rerun', reason='All recorded inputs and compiler unchanged.'),
    dict(check='Instrumented allocator normal/OOM runs',
         reason='Not repeated in the source slice; the earlier array-VM receipt records those runs.'),
    dict(check='Array writes/copies/borrows, full frame integration, Windows isolation, DLL and packaging',
         reason='Outside this bounded source-read slice.'),
    dict(check='Linux execution and performance budgets', reason='Not measured.'),
]
receipt['evidenceRecorderSha256'] = digest('tools/record-m2-array-evidence.py')
destination.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps(dict(status='passed', evidence=destination.relative_to(root).as_posix(),
    nativeGroups=18, cliCases=67, scalarNativeGroups=81, scalarCliCases=1969,
    files=len(paths), relativeLinks=links)))
