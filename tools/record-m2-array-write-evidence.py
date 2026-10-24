"""Record focused array evidence; run or reuse matching scalar CLI regressions."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote

parser = argparse.ArgumentParser()
parser.add_argument('--slice', choices=['write','copy','length','scopes'], default='write')
regression = parser.add_mutually_exclusive_group()
regression.add_argument('--scalar-regression', action='store_true')
regression.add_argument('--reuse-scalar-regression', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
kind = 'copy-source' if args.slice == 'copy' else args.slice
native_count = 19 if args.slice == 'scopes' else 15 if args.slice == 'length' else 12 if args.slice == 'copy' else 9
copy_count = 58 if args.slice in ['copy', 'length', 'scopes'] else 0
date = '20261024' if args.slice == 'write' else '20261025'
evidence_path = f'docs/evidence/m2-array-{kind}-windows-{date}.json'
has_regression = args.scalar_regression or args.reuse_scalar_regression


def read(name):
    return json.loads((root / name).read_text(encoding='utf-8-sig'))


def digest(name):
    return hashlib.sha256((root / name).read_bytes()).hexdigest()


def unchanged(items):
    for item in items:
        assert digest(item['path']) == item['sha256'], item['path']


receipt = read(f'build/m2-array-{kind}/receipt.json')
assert receipt['schema'] == f'browniec.m2-array-{kind}/v1' and receipt['status'] == 'passed'
unchanged(receipt['sourceSha256'])
assert digest('build/toolchain/fairyc.exe') == receipt['compilerSha256']
assert [r['profile'] for r in receipt['results']] == ['development', 'release']
for result in receipt['results']:
    tests = result['nativeTests']
    assert tests['engine'] == 'native' and tests['profile'] == result['profile']
    assert tests['status'] == 'ok' and tests['count'] == tests['passed'] == native_count and tests['failed'] == 0
    assert len(tests['tests']) == native_count and all(t['outcome'] == 'passed' for t in tests['tests'])
    assert digest(result['artifact']) == result['sha256']
    checks = [('source', 67, 'cliCases'), ('write', 61, 'writeCliCases')]
    if args.slice in ['copy', 'length', 'scopes']: checks.append(('copy-source', copy_count, 'copyCliCases'))
    if args.slice in ['length', 'scopes']: checks.append(('length', 40, 'lengthCliCases'))
    if args.slice == 'scopes': checks.append(('scopes', 44, 'scopeCliCases'))
    for cli_kind, count, field in checks:
        path = f"build/m2-array-{cli_kind}/{result['profile']}/cli-receipt.json"
        cli = read(path)
        assert cli['schema'] == f'browniec.m2-array-{cli_kind}-cli/v1'
        assert cli['status'] == 'passed' and cli['profile'] == result['profile']
        assert cli['exeSha256'] == result['sha256']
        assert cli['count'] == result[field] == len(cli['cases']) == count
        for case in cli['cases']:
            if 'sourceSha256' in case:
                fixture = f"build/m2-array-{cli_kind}/{result['profile']}/{case['case']}.brc"
                assert digest(fixture) == case['sourceSha256'], fixture
        result[f'{cli_kind}CliReceiptSha256'] = digest(path)

m0 = read('docs/evidence/m0-windows-20261023.json')
unchanged(m0['sourceSha256'])
assert m0['compilerSha256'] == receipt['compilerSha256']
prior_path = 'docs/evidence/m2-array-write-windows-20261024.json' if args.slice == 'copy' else 'docs/evidence/m2-array-source-windows-20261024.json'
if args.slice == 'length': prior_path = 'docs/evidence/verifier-bitsets-windows-20261025.json'
if args.slice == 'scopes': prior_path = 'docs/evidence/m2-array-length-windows-20261025.json'
previous = read(prior_path)
changed = {'src/compiler.fy', 'src/array_source.fy', 'src/render.fy', 'src/main.fy'}
if args.slice == 'scopes': changed.add('src/loops.fy')
backend = [item for item in previous['sourceSha256']
           if (item['path'].startswith('src/') and item['path'] not in changed)
           or item['path'] in {'tests/m2/array_ir.fy', 'tests/m2/array_vm.fy', 'tests/m2/array_allocation.fy'}]
fixture_evidence = 'docs/evidence/m2-array-source-windows-20261024.json'
for item in read(fixture_evidence)['sourceSha256']:
    if item['path'] in {'tests/m2/array_ir.fy', 'tests/m2/array_vm.fy', 'tests/m2/array_allocation.fy'} and item['path'] not in {r['path'] for r in backend}:
        backend.append(item)
unchanged(backend)
assert {'src/vm.fy', 'src/verifier.fy', 'src/array_vm.fy', 'src/array_verifier.fy'} <= {item['path'] for item in backend}
assert previous['compilerSha256'] == receipt['compilerSha256']
receipt['foundationReuse'] = dict(m0Inputs=len(m0['sourceSha256']),
    unchangedBackendInputs=len(backend), compilerIdentity='unchanged',
    priorEvidence=prior_path, fixtureEvidence=fixture_evidence)
receipt['commands'] = [f'pwsh -NoProfile -File tools/verify-m2-arrays.ps1 -Slice {args.slice}']

if args.scalar_regression:
    scripts = [root / 'tools/check-m1-cli.py', *sorted((root / 'tools').glob('m1_*.py'))]
    identities = [dict(path=p.relative_to(root).as_posix(), sha256=digest(p)) for p in scripts]

    def scalar(result):
        command = [sys.executable, '-B', str(root / 'tools/check-m1-cli.py'),
                   '--exe', str(root / result['artifact']), '--profile', result['profile']]
        ran = subprocess.run(command, cwd=root, capture_output=True, text=True)
        assert ran.returncode == 0, (result['profile'], ran.stdout, ran.stderr)
        print(ran.stdout, end='', flush=True)
        path = f"build/m1/{result['profile']}/cli-receipt.json"
        cli = read(path)
        assert cli['schema'] == 'browniec.m1-cli-checks/v1' and cli['status'] == 'passed'
        assert cli['count'] == len(cli['cases']) == 1969 and cli['profile'] == result['profile']
        assert cli['exeSha256'] == result['sha256']
        return dict(profile=result['profile'], cliCases=1969,
                    artifact=result['artifact'], sha256=result['sha256'], cliReceiptSha256=digest(path))

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(scalar, receipt['results']))
    unchanged(identities)
    receipt['scalarRegression'] = dict(nativeRerun=False, results=results, sourceSha256=identities,
        recordedAt=datetime.now(timezone.utc).isoformat())
    assert all(digest(result['artifact']) == result['sha256'] for result in results)

if args.reuse_scalar_regression:
    saved = read(evidence_path)
    scalar_saved = saved['scalarRegression']
    unchanged(scalar_saved['sourceSha256'])
    assert saved['compilerSha256'] == receipt['compilerSha256']
    assert [(r['profile'],r['sha256']) for r in scalar_saved['results']] == [(r['profile'],r['sha256']) for r in receipt['results']]
    for result in scalar_saved['results']:
        path = f"build/m1/{result['profile']}/cli-receipt.json"
        cli = read(path)
        assert digest(result['artifact']) == result['sha256'] and digest(path) == result['cliReceiptSha256']
        assert cli['status'] == 'passed' and cli['count'] == result['cliCases'] == 1969
        assert cli['exeSha256'] == result['sha256'] and cli['profile'] == result['profile']
    receipt['scalarRegression'] = scalar_saved
    receipt['commands'] += [c for c in saved['commands'] if '--scalar-regression' in c]

unchanged(receipt['sourceSha256'])
assert digest('build/toolchain/fairyc.exe') == receipt['compilerSha256']
for result in receipt['results']:
    assert digest(result['artifact']) == result['sha256']
destination = root / evidence_path
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '--', '*.md'],
                                cwd=root, text=True).splitlines()
links = 0
for name in paths:
    doc = root / name
    text = doc.read_text(encoding='utf-8-sig')
    assert not re.search(r'[A-Za-z]:[\\/](?:Users|Program Files)', text), name
    for target in re.findall(r'(?<!!)\[[^\]]*\]\(([^)]+)\)', text):
        target = target.strip().strip('<>')
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target) or target.startswith('#'):
            continue
        target = unquote(target.split('#', 1)[0])
        if target:
            assert (doc.parent / target).resolve() == destination or (doc.parent / target).exists(), (name, target)
            links += 1
subprocess.run(['git', 'diff', '--check'], cwd=root, check=True)
receipt['documentationChecks'] = dict(files=len(paths), relativeLinks=links, diffCheck='passed')
receipt['baselineCommit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
receipt['evidenceRecorderSha256'] = digest(Path(__file__))
receipt['commands'].append('python -B tools/record-m2-array-write-evidence.py' +
                           (f' --slice {args.slice}' if args.slice != 'write' else '') +
                           (' --scalar-regression' if args.scalar_regression else ' --reuse-scalar-regression' if args.reuse_scalar_regression else ''))
receipt['commands'].append('git diff --check')
receipt['skipped'] = [
    dict(check='M0 and private array IR/VM native reruns', reason='Named compiler, backend and fixture inputs unchanged.'),
    dict(check='Full 84-group scalar native rerun' if args.slice in ['length', 'scopes'] else 'Full 81-group scalar native rerun', reason='Focused native parser/VM tests and scalar CLI regression used for this frontend increment.'
         if has_regression else 'Scalar CLI regression is pending; this receipt establishes focused verification only.'),
    dict(check='Instrumented allocator, Linux, isolation, DLL, performance', reason='Not executed in this frontend increment.'),
]
destination.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps(dict(status='passed', evidence=destination.relative_to(root).as_posix(),
    nativeGroups=native_count, readCliCases=67, writeCliCases=61, copyCliCases=copy_count,
    lengthCliCases=40 if args.slice in ['length', 'scopes'] else 0,
    scopeCliCases=44 if args.slice == 'scopes' else 0, scalarCliCases=1969 if has_regression else 0)))
