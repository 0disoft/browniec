"""Run Fairy C native struct layout, storage, and record-copy tests."""
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
FILES = ['tests/m2/struct_layout.fy', 'tests/m2/array_layout.fy']


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def verify(compiler, storage=False, copy_records=False, nested=False, nested_copy=False):
    require(sum([storage, copy_records, nested, nested_copy]) <= 1, 'Choose only one verification selection')
    if nested_copy:
        kind = 'nested-copy'
        files = ['tests/m2/struct_nested_copy.fy', 'tests/m2/struct_nested_storage.fy',
                 'tests/m2/struct_layout.fy', 'tests/m2/scalar_codec.fy']
        groups = {'struct_nested_copy': 6, 'struct_nested_storage': 6, 'struct_layout': 8, 'scalar_codec': 4}
        expected = 24
    elif nested:
        kind = 'nested-storage'
        files = ['tests/m2/struct_nested_storage.fy', 'tests/m2/struct_layout.fy', 'tests/m2/scalar_codec.fy']
        groups = {'struct_nested_storage': 6, 'struct_layout': 8, 'scalar_codec': 4}
        expected = 18
    elif copy_records:
        kind = 'copy'
        files = ['tests/m2/struct_copy.fy', 'tests/m2/struct_storage.fy',
                 'tests/m2/struct_layout.fy', 'tests/m2/scalar_codec.fy']
        groups = {'struct_copy': 8, 'struct_storage': 8, 'struct_layout': 8, 'scalar_codec': 4}
        expected = 28
    elif storage:
        kind = 'storage'
        files = ['tests/m2/struct_storage.fy', 'tests/m2/struct_layout.fy', 'tests/m2/scalar_codec.fy']
        groups = {'struct_storage': 8, 'struct_layout': 8, 'scalar_codec': 4}
        expected = 20
    else:
        kind = 'layout'
        files = FILES
        groups = {'struct_layout': 8, 'array_layout': 6}
        expected = 14
    output = ROOT / ('build/m2-struct-' + kind)
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    write(receipt, dict(status='incomplete', startedAt=datetime.now(timezone.utc).isoformat()))
    require(not os.environ.get('CL') and not os.environ.get('_CL_'), 'Unexpected CL/_CL_ override')
    compiler = compiler.resolve(strict=True)
    compiler_hash = digest(compiler)
    commands = []

    def run(arguments):
        commands.append([str(compiler), *arguments])
        result = subprocess.run([str(compiler), *arguments], cwd=ROOT,
                                capture_output=True, text=True, encoding='utf-8', timeout=600)
        require(result.returncode == 0,
                f'Compiler failed ({result.returncode}): {arguments}\n{result.stdout}\n{result.stderr}')
        require(not result.stderr, f'Unexpected compiler stderr: {result.stderr}')
        return result.stdout.strip()

    version = run(['--version'])
    check = run(['check', '--locked'])
    paths = {ROOT / p for p in ['fairy.toml', 'fairy.lock', 'toolchain.json',
                               'tools/verify-m2-struct-layout.py', *files]}
    paths.update((ROOT / 'src').glob('*.fy'))
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    results = []
    for profile in ['development', 'release']:
        arguments = ['test', '--native', '--capture-output', '--json', '--locked']
        if profile == 'release':
            arguments.append('--release')
        for path in files:
            arguments.extend(['--file', path])
        native = json.loads(run(arguments))
        write(output / (profile + '-native.json'), native)
        require(native['status'] == 'ok' and native['count'] == native['passed'] == expected
                and native['failed'] == 0, f'Unexpected native outcomes: {profile}')
        tests = native['tests']
        require(len(tests) == len({t['identity'] for t in tests}) == expected,
                f'Unexpected or duplicate native identities: {profile}')
        require(all(sum(t['identity'].startswith('tests::m2::' + name + '::') for t in tests) == count
                    for name, count in groups.items()),
                f'Unexpected native selection: {profile}')
        require(all(t['outcome'] == 'passed' and t['trapCategory'] is None
                    and not t['stdoutBase64'] and not t['stderrBase64'] for t in tests),
                f'Native failure or unexpected process output: {profile}')
        result = dict(profile=profile, nativeGroups=expected, nativeTests=native)
        if nested_copy:
            result.update(newNestedCopyGroups=6, nestedStorageRegressionGroups=6,
                          structLayoutRegressionGroups=8, codecRegressionGroups=4)
        elif nested:
            result.update(newNestedStorageGroups=6, structLayoutRegressionGroups=8, codecRegressionGroups=4)
        elif copy_records:
            result.update(newCopyGroups=8, storageRegressionGroups=8,
                          structLayoutRegressionGroups=8, codecRegressionGroups=4)
        else:
            result.update(dict(newStorageGroups=8, structLayoutRegressionGroups=8, codecRegressionGroups=4)
                          if storage else dict(newStructGroups=8, arrayRegressionGroups=6))
        results.append(result)
        print(f'PASS: {profile}: {expected} native {kind} groups {groups}', flush=True)
    require({t['identity'] for t in results[0]['nativeTests']['tests']}
            == {t['identity'] for t in results[1]['nativeTests']['tests']}, 'Profile selections differ')
    require(digest(compiler) == compiler_hash, 'Compiler changed during verification')
    require(all(digest(ROOT / item['path']) == item['sha256'] for item in inputs),
            'Verification input changed during execution')
    lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    baseline = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    limits = (dict(fieldsPerRecord=16, recordBytes=128, encodedScratchBytes=128,
                   initializationBackingWritesAtMost=135) if storage or copy_records or nested or nested_copy else
              dict(records=32, fieldsPerRecord=16, structuralDepth=16,
                   dependencyFieldChecksAtMost=16384, payloadLimit='caller supplied per record'))
    if nested or nested_copy:
        limits.update(scalarLeaves=128, structuralDepth=16, fieldPathLength=16,
                      traversalFieldVisitsAtMost=2048)
    if copy_records or nested_copy:
        limits.update(copyBackingWritesAtMost=135, assignmentBackingWritesAtMost=128,
                      assignmentAdditionalExtents=0)
    limitations = ([
        'Private nested-record value copies and assignment only; no owner tokens, source structs, IR/VM or Fuel integration.',
        'The full catalog is replanned once per operation. Both complete root extents, metadata, arena state and alignment are validated before snapshotting.',
        'A private iterative cursor copies only scalar bytes into caller-local zeroed 128-byte scratch. Padding is normalized, integer bits preserved, and all bools checked before any backing mutation.',
        'Copy charges existing plus new bytes and alignment padding, publishing the cursor last. Assignment uses existing storage with zero additional extents and no cursor change, including self and bidirectional overlap.',
        'A single record describes both byte ranges; offsets do not prove nominal type, ownership, lifetime, borrow or write authority. Work and staging bounds are algorithmic, not instrumentation or performance measurements.',
        'Scalar-storage/copy sources and fixtures are unchanged and their native suites were not rerun.'
    ] if nested_copy else [
        'Private nested-record initialization and scalar field-path reads/writes only; no nested record copies, ownership, source struct grammar, IR/VM or Fuel integration.',
        'Full catalogs are replanned at every public boundary; selected roots are capped at 128 bytes, while valid unselected records may be larger.',
        'Depth-first scalar initialization uses a private sixteen-frame iterative cursor and caller-owned zeroed 128-byte scratch; every fallible check precedes backing/cursor publication.',
        'Field paths must end at scalars; arena state, alignment and the complete published root extent are rechecked before access.',
        'Base offsets and field paths do not prove object identity, ownership, lifetime or write authority. Bounds are algorithmic, not native stack or throughput measurements.',
        'Existing scalar-storage/copy source and fixtures are unchanged and their native suites were not rerun.'
    ] if nested else [
        'Private scalar-record by-value copy initialization and assignment only; no source structs, nested record storage, owner tokens, IR/VM or Fuel integration.',
        'Both operations revalidate metadata, state and complete published extents and preflight every bool before any backing mutation.',
        'Field bytes are snapshotted into a zeroed 128-byte payload; padding is normalized and integer bits are preserved. Self-assignment and both overlap directions use the snapshot.',
        'Copy appends one extent and charges the old plus new peak including padding. Assignment writes existing storage without advancing the cursor or reserving an extent.',
        'Base offsets and matching Shapes do not prove record identity, lifetime, ownership or write authority. Overlap handling is a primitive property, not guest aliasing permission.',
        'Staging and byte-write limits are algorithmic bounds, not native stack, allocation instrumentation or throughput measurements.'
    ] if copy_records else [
        'Private scalar-only record preparation, complete initialization and indexed field reads/writes in the shared caller-backed array arena.',
        'Nested layouts remain supported; materializing a selected nested record is rejected. Whole-record copies, ownership, source grammar, IR/VM and Fuel remain unimplemented.',
        'Every operation recomputes bounded canonical Shape metadata; base offsets do not prove object identity, ownership or lifetime.',
        'Encoded initialization scratch is 128 bytes; all fallible checks precede backing-byte and cursor mutation. These are algorithmic bounds, not allocator or stack measurements.',
        'No allocator API is invoked or new guest CLI artifact produced.'
    ] if storage else [
        'Private layout planning only: all six scalar fields and acyclic nested records.',
        'Bounds are private planner limits, not a full source profile or native C ABI.',
        'No source struct syntax, field names, initialization, payload allocation, codec, ownership, IR, VM or Fuel integration.',
        'Tagged/array/borrow/Buffer fields and empty record definitions are not supported.'
    ])
    limitations.extend([
        'CLI, full native suites, M0, Linux, isolation, DLL, clean-machine packaging, allocation instrumentation and performance not rerun.',
        'The harness uses Python standard-library APIs without shell execution; this invocation verifies Windows only.'
    ])
    write(receipt, dict(schema='browniec.m2-struct-' + kind + '/v1', status='passed',
          recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
          compilerVersion=version, compilerSha256=compiler_hash,
          standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
          os=platform.platform(), pythonVersion=sys.version.split()[0], lockedCheck=check,
          commands=commands, sourceSha256=inputs, results=results,
          limits=limits,
          artifacts='Tool-managed native test images; no new guest struct CLI artifact.',
          limitations=limitations))
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path,
                        default=ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc'))
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--storage', action='store_true', help='Verify scalar record storage and its layout/codec dependencies.')
    selection.add_argument('--copy', dest='copy_records', action='store_true', help='Verify scalar record copies and assignments with storage/layout/codec regressions.')
    selection.add_argument('--nested', action='store_true', help='Verify nested record storage and its layout/codec dependencies.')
    selection.add_argument('--nested-copy', action='store_true', help='Verify nested record copies with nested storage/layout/codec regressions.')
    args = parser.parse_args()
    verify(args.compiler, args.storage, args.copy_records, args.nested, args.nested_copy)
