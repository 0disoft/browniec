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
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--replace-values', action='store_true', help='Verify private scalar-value root replacement and storage/owner regressions.')
    selection.add_argument('--child-path', action='store_true', help='Verify constructor child paths and related source regressions.')
    selection.add_argument('--atomic', action='store_true', help='Verify prepaid atomic subrecord assignment and backend regressions.')
    selection.add_argument('--subassign', action='store_true', help='Verify subrecord assignment with extraction/write/scalar regressions.')
    selection.add_argument('--extract', action='store_true', help='Verify independent subrecord extraction and child/nested/scalar regressions.')
    selection.add_argument('--child', action='store_true', help='Verify bare-name child snapshots plus nested/scalar source regressions.')
    selection.add_argument('--nested', action='store_true', help='Verify bounded nested constructors, scalar paths and root copies.')
    selection.add_argument('--copy', action='store_true', help='Verify source record copies/assignment plus struct and scalar regressions.')
    selection.add_argument('--write', action='store_true', help='Verify field writes plus constructor, VM and switch-arm regressions.')
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
    if args.copy:
        kind = 'struct-source-copy'
        files = ['tests/m2/struct_source_copy.fy', 'tests/m2/struct_write.fy',
                 'tests/m2/struct_values.fy', 'tests/m2/struct_vm.fy',
                 'tests/m2/struct_ir.fy', 'tests/switch_arm_statements.fy']
        groups = {'tests::m2::struct_source_copy::': 6, 'tests::m2::struct_write::': 5,
                  'tests::m2::struct_values::': 5, 'tests::m2::struct_vm::': 8,
                  'tests::m2::struct_ir::': 9, 'tests::switch_arm_statements::': 6}
    if args.nested:
        kind = 'struct-source-nested'
        files = ['tests/m2/struct_source_nested.fy', 'tests/m2/struct_source_copy.fy',
                 'tests/m2/struct_write.fy', 'tests/m2/struct_values.fy',
                 'tests/m2/struct_vm.fy', 'tests/switch_arm_statements.fy']
        groups = {'tests::m2::struct_source_nested::': 6, 'tests::m2::struct_source_copy::': 6,
                  'tests::m2::struct_write::': 5, 'tests::m2::struct_values::': 5,
                  'tests::m2::struct_vm::': 8, 'tests::switch_arm_statements::': 6}
    if args.child or args.extract or args.subassign or args.atomic:
        kind = 'struct-child'
        files = ['tests/m2/struct_child_source.fy', 'tests/m2/struct_source_nested.fy',
                 'tests/m2/struct_values.fy', 'tests/m2/struct_write.fy']
        groups = {'tests::m2::struct_child_source::': 5, 'tests::m2::struct_source_nested::': 6,
                  'tests::m2::struct_values::': 5, 'tests::m2::struct_write::': 5}
    if args.extract or args.subassign or args.atomic:
        kind = 'struct-extract'
        files = ['tests/m2/struct_extract_source.fy', *files]
        groups = {'tests::m2::struct_extract_source::': 5, **groups}
    if args.subassign or args.atomic:
        kind = 'struct-subassign'
        files = ['tests/m2/struct_subassign_source.fy', 'tests/m2/struct_extract_source.fy', 'tests/m2/struct_write.fy']
        groups = {'tests::m2::struct_subassign_source::': 5, 'tests::m2::struct_extract_source::': 5, 'tests::m2::struct_write::': 5}
    if args.atomic:
        kind = 'struct-subassign-atomic'
        files = ['tests/m2/struct_atomic_source.fy', 'tests/m2/struct_subassign_source.fy', 'tests/m2/struct_vm.fy', 'tests/m2/struct_ir.fy']
        groups = {'tests::m2::struct_atomic_source::': 4, 'tests::m2::struct_subassign_source::': 5, 'tests::m2::struct_vm::': 8, 'tests::m2::struct_ir::': 9}
    if args.child_path:
        kind = 'struct-child-path'
        files = ['tests/m2/struct_child_path_source.fy', 'tests/m2/struct_child_source.fy',
                 'tests/m2/struct_extract_source.fy', 'tests/m2/struct_atomic_source.fy']
        groups = {'tests::m2::struct_child_path_source::': 5, 'tests::m2::struct_child_source::': 5,
                  'tests::m2::struct_extract_source::': 5, 'tests::m2::struct_atomic_source::': 4}
    if args.replace_values:
        kind = 'struct-replace-values'
        files = ['tests/m2/struct_replace_values.fy', 'tests/m2/struct_nested_storage.fy',
                 'tests/m2/struct_owner_copy.fy', 'tests/m2/struct_subassign_owners.fy']
        groups = {'tests::m2::struct_replace_values::': 6, 'tests::m2::struct_nested_storage::': 6,
                  'tests::m2::struct_owner_copy::': 6, 'tests::m2::struct_subassign_owners::': 3}
    expected = sum(groups.values())
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
    # CLI scripts also generate cases from these fixtures, independently of native selection.
    paths.update(ROOT / ('tests/m2/' + name + '.fy') for name in ['struct_values', 'struct_write', 'struct_source_copy', 'struct_source_nested', 'struct_child_source', 'struct_child_path_source', 'struct_extract_source', 'struct_subassign_source'])
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
        if args.write or args.copy or args.nested or args.child or args.extract or args.subassign or args.atomic:
            selections.insert(0, ('check-m2-struct-write.py', 'm2-struct-write'))
        if args.copy or args.nested or args.child or args.extract or args.subassign or args.atomic:
            selections.insert(0, ('check-m2-struct-source-copy.py', 'm2-struct-source-copy'))
        if args.nested or args.child or args.extract or args.subassign or args.atomic:
            selections.insert(0, ('check-m2-struct-source-nested.py', 'm2-struct-source-nested'))
        if args.child or args.extract or args.subassign or args.atomic:
            selections.insert(0, ('check-m2-struct-child.py', 'm2-struct-child'))
        if args.extract or args.subassign or args.atomic:
            selections.insert(0, ('check-m2-struct-extract.py', 'm2-struct-extract'))
        if args.subassign or args.atomic:
            selections.insert(0, ('check-m2-struct-subassign.py', 'm2-struct-subassign'))
        if args.child_path:
            selections = [('check-m2-struct-child-path.py', 'm2-struct-child-path'),
                          ('check-m2-struct-child.py', 'm2-struct-child'),
                          ('check-m2-struct-extract.py', 'm2-struct-extract'),
                          ('check-m2-struct-subassign.py', 'm2-struct-subassign')]
        if args.replace_values:
            selections = [('check-m2-struct-child-path.py', 'm2-struct-child-path'),
                          ('check-m2-struct-subassign.py', 'm2-struct-subassign')]
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
        limitations=['Source records remain entry-only: inline/binding/path child initializers and scalar paths have sixteen-leaf staging, depth 16 and root cap 128 bytes. Subrecord declaration extraction and assignment are supported; constructor RHS assignment, struct parameters/results and borrows remain unavailable.',
                     *(['The child-path selection runs only child-path, whole-child, extraction and subrecord-assignment CLI matrices; scalar, array and other struct CLI matrices are not rerun.'] if args.child_path else []),
                     *(['Private scalar-value root replacement only; no source syntax, opcode, verifier, VM dispatch or Fuel change. Only child-path and subrecord-assignment CLI matrices are rerun.'] if args.replace_values else []),
                     'Full native suites, full array CLI matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.']))
    print('PASS: '+str(receipt.relative_to(ROOT)), flush=True)


if __name__ == '__main__':
    main()
