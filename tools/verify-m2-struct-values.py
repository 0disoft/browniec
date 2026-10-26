"""Build and verify the source scalar-field struct value slice; standard library only."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'tests::m2::struct_values::': 5, 'tests::m2::struct_source::': 5,
          'tests::m2::struct_vm::': 8, 'tests::functions::': 4, 'tests::loops::': 6}
FILES = ['tests/m2/struct_values.fy', 'tests/m2/struct_source.fy',
         'tests/m2/struct_vm.fy', 'tests/functions.fy', 'tests/loops.fy']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc'))
    parser.add_argument('--write', action='store_true', help='Verify field writes plus constructor, VM and switch-arm regressions.')
    args = parser.parse_args()
    files = FILES
    groups = GROUPS
    kind = 'struct-values'
    if args.write:
        kind = 'struct-write'
        files = ['tests/m2/struct_write.fy', 'tests/m2/struct_values.fy',
                 'tests/m2/struct_vm.fy', 'tests/switch_arm_statements.fy']
        groups = {'tests::m2::struct_write::': 5, 'tests::m2::struct_values::': 5,
                  'tests::m2::struct_vm::': 8, 'tests::switch_arm_statements::': 6}
    expected = 24 if args.write else 28
    compiler = args.compiler.resolve(strict=True)
    output = ROOT / ('build/m2-' + kind)
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    write(receipt, dict(status='incomplete'))
    commands = []

    def run(command):
        commands.append(list(map(str, command)))
        ran = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=600,
                             env={**os.environ, 'PYTHONUTF8': '1'})
        if ran.returncode or ran.stderr:
            raise RuntimeError(f'{command}: {ran.returncode}\n{ran.stdout}\n{ran.stderr}')
        return ran.stdout.strip()

    version = run([compiler, '--version'])
    check = run([compiler, 'check', '--locked'])
    paths = set(ROOT.glob('src/*.fy')) | set(ROOT.glob('tools/*.py'))
    paths.update(ROOT / p for p in ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tests/m2/array_literal_assignment.fy', 'examples/loops.brc', *files])
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    compiler_hash = digest(compiler)
    results = []
    for profile in ['development', 'release']:
        flags = ['--release'] if profile == 'release' else []
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked', *flags]
        for file in files:
            command += ['--file', file]
        native = json.loads(run(command))
        write(output / (profile+'-native.json'), native)
        assert native['status'] == 'ok' and native['count'] == native['passed'] == expected and native['failed'] == 0, native
        tests = native['tests']
        assert len({t['identity'] for t in tests}) == expected
        assert all(sum(t['identity'].startswith(prefix) for t in tests) == count for prefix, count in groups.items())
        assert all(t['outcome'] == 'passed' and t['trapCategory'] is None and not t['stdoutBase64'] and not t['stderrBase64'] for t in tests)
        build = run([compiler, 'build', '--locked', *flags])
        exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
        checks = []
        selections = [('check-m2-struct-values.py', 'm2-struct-values'),
                                 ('check-m2-struct-source.py', 'm2-struct-source'),
                                 ('check-m2-array-literal-assignment.py', 'm2-array-literal-assignment'),
                                 ('check-m1-cli.py', 'm1')]
        if args.write:
            selections.insert(0, ('check-m2-struct-write.py', 'm2-struct-write'))
        for script, relative in selections:
            message = run([sys.executable, '-B', ROOT / 'tools' / script, '--exe', exe, '--profile', profile])
            cli = json.loads((ROOT / 'build' / relative / profile / 'cli-receipt.json').read_text())
            assert cli['status'] == 'passed' and cli['exeSha256'] == digest(exe)
            checks.append(cli)
            print(message, flush=True)
        results.append(dict(profile=profile, native=native, build=build, cli=checks))
        print(f'PASS: {profile}: {expected} native groups', flush=True)
    assert {t['identity'] for t in results[0]['native']['tests']} == {t['identity'] for t in results[1]['native']['tests']}
    assert digest(compiler) == compiler_hash
    assert all(digest(ROOT / item['path']) == item['sha256'] for item in inputs)
    lock = json.loads((ROOT / 'fairy.lock').read_text())
    write(receipt, dict(schema='browniec.m2-' + kind + '/v1', status='passed',
        recordedAt=datetime.now(timezone.utc).isoformat(),
        baselineCommit=subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
        compilerVersion=version, compilerSha256=compiler_hash, os=platform.platform(),
        standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
        lockedCheck=check, commands=commands, sourceSha256=inputs, results=results,
        limitations=['Entry-owned scalar-field construction/read lowering, plus field writes only when --write is selected. Nested object construction, record copies/assignment, struct parameters/results and borrows remain unavailable.',
                     'Full native suites, full array CLI matrices, Linux, isolation, DLL, packaging and performance were not run.']))
    print('PASS: '+str(receipt.relative_to(ROOT)), flush=True)


if __name__ == '__main__':
    main()
