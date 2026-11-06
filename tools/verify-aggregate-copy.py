"""Verify native copy-window proofs and unchanged public aggregate copy costs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SELECTED = {
    'aggregate_copy': None,
    'array_assign_storage': None,
    'array_copy': ['all_scalar_copies_are_typed_independent_values',
                   'noncanonical_bool_stale_source_and_owner_pressure_do_not_publish',
                   'full_width_array_copy_fits_exact_peak_and_survives_source_release'],
    'struct_copy': ['both_partial_overlap_directions_use_the_original_source_snapshot',
                    'invalid_final_bool_preserves_every_byte_and_the_arena',
                    'self_assignment_at_full_capacity_preserves_values_and_normalizes_tail_padding'],
    'struct_nested_copy': ['both_overlap_directions_and_self_assignment_use_prewrite_values',
                           'corrupt_last_nested_bool_rejects_copy_assign_and_self_atomically',
                           'maximum_leaves_and_depth_copy_and_assign_at_full_capacity'],
    'array_argument_copies': ['all_elements_and_repeated_sources_produce_independent_copies',
                              'late_shape_token_and_bool_errors_leave_all_state_untouched',
                              'maximum_payload_reservations_use_old_plus_new_peak'],
    'call_argument_copies': ['mixed_nested_records_normalize_padding_and_keep_copies_independent',
                             'late_record_and_array_bool_errors_never_publish_a_prefix',
                             'zero_eight_nine_arguments_and_full_128_byte_roots_are_bounded'],
    'struct_owner_copy': ['full_capacity_assignment_and_self_assignment_keep_owner_metadata'],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--phase', choices=['native', 'cli', 'all'], default='all')
    args = parser.parse_args()
    out = ROOT / 'build/aggregate-copy' / args.profile
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / (args.phase + '-receipt.json')
    write(receipt, {'status': 'incomplete'})
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    platform = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    assert digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][platform]['sha256']
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    commands = []

    def run(command, capture=None):
        command = list(map(str, command)); commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', timeout=900)
        if capture:
            capture.write_text(done.stdout, encoding='utf-8', newline='\n')
            capture.with_suffix('.stderr.txt').write_text(done.stderr, encoding='utf-8', newline='\n')
        assert done.returncode == 0, (command, done.stdout[-6000:], done.stderr[-2000:])
        return done.stdout

    check = run([compiler, 'check', '--locked'])
    paths = sorted([p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')] +
                   [f'tests/m2/{name}.fy' for name in SELECTED] +
                   ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-aggregate-copy.py'])
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    result = dict(status='incomplete', schema='browniec.aggregate-copy-verification/v1',
                  recordedAt=datetime.now(timezone.utc).isoformat(), profile=args.profile, phase=args.phase,
                  inputs=inputs, check=check, compilerSha256=digest(compiler),
                  nativeOverrides=False, historicalResultReuse=False, commands=commands)
    if args.phase in ['native', 'all']:
        expected = set()
        for module, selection in SELECTED.items():
            names = set(re.findall(r'@test\s+fn void (\w+)\(', (ROOT / f'tests/m2/{module}.fy').read_text()))
            if selection is not None:
                assert set(selection) <= names
                names = set(selection)
            expected.update(f'tests::m2::{module}::{name}' for name in names)
        assert len(expected) == 22
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
        if args.profile == 'release':
            command.append('--release')
        for identity in sorted(expected):
            command.extend(['--exact', identity])
        report = json.loads(run(command, out / 'native.json'))
        assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
        assert report['profile'] == args.profile and report['lock'] == 'verified' and report['status'] == 'ok'
        assert report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
        assert {row['identity'] for row in report['tests']} == expected
        assert all(row['trapCategory'] is None and not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
        result.update(nativeGroups=len(expected), nativeReport=report)
        print(f'PASS {args.profile}: {len(expected)} native groups', flush=True)
    if args.phase in ['cli', 'all']:
        run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []), out / 'build.txt')
        artifact = out / ('browniec.exe' if os.name == 'nt' else 'browniec')
        shutil.copyfile(ROOT / 'build' / artifact.name, artifact)
        empty = out / 'no-runtime-tools'; empty.mkdir(exist_ok=True)
        env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
        env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
        rows = []

        def invoke(source, budget, failure=False):
            path = out / f'case-{len(rows):03}.brc'; path.write_bytes(source.encode())
            done = subprocess.run([str(artifact), 'run', str(path), '--json', '--fuel', str(budget)],
                                  cwd=empty, env=env, capture_output=True, timeout=30)
            data = json.loads(done.stdout)
            assert done.returncode == (5 if failure else 0) and not done.stderr, data
            assert data['status'] == ('error' if failure else 'completed')
            assert data['error']['kind'] == 'fuel' if failure else data['error'] is None
            assert data['return_i32'] == (None if failure else 42), data
            rows.append(dict(sourceSha256=hashlib.sha256(source.encode()).hexdigest(), budget=budget, result=data))

        array = 'module main;fn i32 main(){var a=[42;1];a=a;return a[0];}'
        record = 'module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=42};p=p;return p.x;}'
        # Independent pre-existing opcode prices: array self assignment costs85;
        # record self assignment retains snapshot60545, including normalization.
        for source, ordinary, retained in [(array, 65779, 409865), (record, 213577, 557663)]:
            marker = source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1)
            for text, price in [(source, ordinary), (marker, retained)]:
                for budget in [0, price - 1, price, price + 1]:
                    invoke(text, budget, budget < price)
        for source in [
            'module main;fn i32 main(){var a=[true;1];a=a;if(a[0]){return 42;}return 0;}',
            'module main;struct P{i32 x;}fn i32 take(i32[1] a,P p){return a[0]+p.x;}fn i32 main(){let a=[20;1];let P p=P{.x=22};return take(a,p);}',
        ]:
            invoke(source, 16000000)
            invoke(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1), 16000000)
        result.update(cliCases=len(rows), cli=rows, artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)))
        print(f'PASS {args.profile}: {len(rows)} tool-free CLI cases', flush=True)
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    result['status'] = 'passed'
    write(receipt, result)


if __name__ == '__main__':
    main()
