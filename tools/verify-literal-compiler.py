"""Verify source literal compilation, retained-image execution and public CLI gates."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
FILES = ['tests/m2/literal_compiler.fy', 'tests/m2/static_execution.fy',
         'tests/core.fy', 'tests/functions.fy']
BINDING_FILES = ['tests/m2/static_bindings_source.fy', 'tests/m2/literal_compiler.fy',
                 'tests/m2/image_text_dispatch.fy']
EQUALITY_FILES = ['tests/m2/static_equality_source.fy'] + BINDING_FILES
RANGE_FILES = ['tests/m2/static_ranges_source.fy'] + EQUALITY_FILES


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--phase', choices=['native', 'cli', 'all'], default='all')
    parser.add_argument('--selection', choices=['all', 'bindings', 'equality', 'ranges', 'range-core'], default='all')
    args = parser.parse_args()
    profile = args.profile
    selections = {'all': list(dict.fromkeys(FILES + RANGE_FILES)), 'bindings': BINDING_FILES,
                  'equality': EQUALITY_FILES, 'ranges': RANGE_FILES, 'range-core': RANGE_FILES[:1]}
    files = selections[args.selection]
    output = {'all': 'build/literal-compiler', 'bindings': 'build/static-bindings', 'equality': 'build/static-equality-source',
              'ranges': 'build/static-ranges-source', 'range-core': 'build/static-ranges-source-core'}
    out = ROOT / output[args.selection] / profile
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / (args.phase + '-receipt.json')
    write(receipt, {'status': 'incomplete'})
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_hash = digest(compiler)
    assert compiler_hash == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    production = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy'))
    assert all(b'\r' not in (ROOT / p).read_bytes() for p in production)
    paths = sorted(production + list(dict.fromkeys(FILES + RANGE_FILES)) + ['fairy.toml', 'fairy.lock', 'toolchain.json',
                                       'tools/verify-literal-compiler.py', 'tools/check-literal-source.py',
                                       'tools/check-lexical-compatibility.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]

    def discovery():
        tree = [(p.relative_to(ROOT).as_posix(), digest(p)) for p in sorted((ROOT / 'tests').rglob('*.fy'))]
        value = hashlib.sha256(''.join(p + ' ' + h + '\n' for p, h in tree).encode()).hexdigest()
        return dict(count=len(tree), sha256=value)

    tree = discovery()
    captured = datetime.now(timezone.utc).isoformat()

    def run(command, cwd=ROOT):
        result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True,
                                text=True, encoding='utf-8', timeout=1200)
        if result.returncode:
            raise RuntimeError(f'{command}\n{result.stdout[-8000:]}\n{result.stderr[-3000:]}')
        return result

    head = run(['git', 'rev-parse', 'HEAD']).stdout.strip()
    mirror = out / 'lf-workspace'
    for path in production + ['fairy.toml', 'fairy.lock']:
        destination = mirror / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes((ROOT / path).read_bytes())
    checked = run([compiler, 'check', '--locked'], mirror).stdout.strip()
    expected = set(); command = None; report = None
    if args.phase in ['native', 'all']:
        command = [compiler.relative_to(ROOT).as_posix(), 'test', '--native',
                   '--capture-output', '--json', '--locked']
        if profile == 'release':
            command.append('--release')
        expected = set()
        for path in files:
            command.extend(['--file', path])
            source = (ROOT / path).read_text(encoding='utf-8')
            names = re.findall(r'@test\s+fn void (\w+)\(', source)
            module = re.search(r'\bmodule\s+([\w:]+);', source).group(1)
            expected.update(module + '::' + name for name in names)
        result = run(command)
        (out / 'native.json').write_text(result.stdout, encoding='utf-8', newline='\n')
        (out / 'native-stderr.txt').write_text(result.stderr, encoding='utf-8', newline='\n')
        report = json.loads(result.stdout)
        assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
        assert report['status'] == 'ok' and report['profile'] == profile and report['lock'] == 'verified'
        assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
        assert {t['identity'] for t in report['tests']} == expected
        assert all(t['outcome'] == 'passed' and t['trapCategory'] is None and
                   not t['stdoutBase64'] and not t['stderrBase64'] for t in report['tests'])
    if args.phase in ['cli', 'all']:
        build_command = [compiler, 'build', '--locked'] + (['--release'] if profile == 'release' else [])
        built = run(build_command).stdout.strip()
        artifact = out / ('browniec.exe' if os.name == 'nt' else 'browniec')
        shutil.copyfile(ROOT / 'build' / artifact.name, artifact)
        literal_command = [sys.executable, '-B', ROOT / 'tools/check-literal-source.py',
                           '--exe', artifact, '--output', out / 'literal-cli']
        lexical_command = [sys.executable, '-B', ROOT / 'tools/check-lexical-compatibility.py',
                           '--exe', artifact, '--output', out / 'lexical-cli']
        run(literal_command)
        run(lexical_command)
        literal_cli = json.loads((out / 'literal-cli/receipt.json').read_text(encoding='utf-8'))
        lexical_cli = json.loads((out / 'lexical-cli/cli.json').read_text(encoding='utf-8'))
        assert literal_cli['status'] == lexical_cli['status'] == 'passed'
        assert literal_cli['count'] == 52 and lexical_cli['count'] == 36
        assert literal_cli['exeSha256'] == lexical_cli['exeSha256'] == digest(artifact)
    assert all(digest(ROOT / i['path']) == i['sha256'] for i in inputs)
    assert discovery() == tree and digest(compiler) == compiler_hash
    assert sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy')) == production
    write(receipt, dict(schema='browniec.literal-compiler-verification/v1', status='passed',
                       profile=profile, phase=args.phase, selection=args.selection, startingHead=head,
                       platform=platform.platform(), compilerSha256=compiler_hash,
                       compilerVersion=run([compiler, '--version']).stdout.strip(),
                       inputSnapshotCapturedAt=captured, inputs=inputs, testDiscovery=tree,
                       lfMirror=dict(command=['build/toolchain/fairyc.exe' if os.name == 'nt' else 'build/toolchain/fairyc', 'check', '--locked'],
                                     workingDirectory=mirror.relative_to(ROOT).as_posix(),
                                     productionFiles=len(production), result=checked),
                       command=command, nativeGroups=len(expected), report=report,
                       build=dict(command=[str(c) for c in build_command], result=built) if args.phase in ['cli','all'] else None,
                       artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)) if args.phase in ['cli','all'] else None,
                       literalCli=literal_cli if args.phase in ['cli','all'] else None,
                       lexicalCli=lexical_cli if args.phase in ['cli','all'] else None,
                       nativeReportSha256=digest(out / 'native.json') if args.phase in ['native','all'] else None,
                       nativeOverrides=False, historicalResultReuse=False))
    print(f'PASS {profile} {args.phase}: {len(expected)} native groups; {88 if args.phase in ["cli","all"] else 0} CLI cases; {len(inputs)} matching inputs', flush=True)


if __name__ == '__main__':
    main()
