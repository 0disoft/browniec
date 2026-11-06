"""Verify private value execution in fresh locked production/selected-test mirrors.

Both profiles run by default. --public-fuel-cli adds the existing 105 public
Fuel CLI cases, building inside each mirror and running with a tool-free PATH.
"""
import argparse
import ast
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
MODULES = {
    'value_program': None,
    'value_call_vm': None,
    'value_call_adapters': None,
    'value_execution': None,
    'value_frame_layout': [
        'independent_functions_align_slots_and_trailing_bytes_with_empty_functions_preserved'],
    'value_frame_meter': None,
    'value_frames': [
        'recursive_buffer_moves_preserve_owner_token_charge_data_and_reject_copy_overwrite_double_drop',
        'combined_frame_root_quotas_and_exact_fuel_boundaries_do_not_publish_rejected_work',
        'zero_fuel_leave_and_abort_release_native_roots_despite_corrupt_guest_bytes_and_live_masks'],
    'slice_reborrow_call_vm': [
        'mixed_shared_and_multiple_writer_calls_reuse_frames_without_leaking_handles',
        'recursive_formal_children_restore_through_call_and_lexical_receipts_in_lifo_order'],
    'slice_reborrow_array_results': [
        'owned_arguments_shared_readers_and_multiple_writers_return_arrays'],
    'slice_reborrow_record_results': [
        'nested_owned_shared_multiple_writer_and_child_results_execute'],
    'place_dispatch': [
        'legacy_programs_keep_all_three_formats_exact_setup_and_no_aggregate_allocation'],
    'place_cleanup': [
        'array_and_record_handoffs_end_pending_places_before_drops_and_promotion'],
}
CLI_INPUTS = ['examples/fuel-wide-call.brc', 'tests/m2/public_fuel.fy',
              'tests/m2/struct_parameters_source.fy', 'tools/verify-public-fuel.py']


def sha(data):
    return hashlib.sha256(data).hexdigest()


def digest(path):
    return sha(path.read_bytes())


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode('utf-8')


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def discover():
    expected = set()
    for module, selection in MODULES.items():
        path = ROOT / f'tests/m2/{module}.fy'
        source = path.read_text(encoding='utf-8')
        assert re.search(r'\bmodule\s+tests::m2::' + re.escape(module) + r'\s*;', source), path
        names = re.findall(r'@test\s+fn\s+void\s+(\w+)\s*\(', source)
        assert names and len(names) == len(set(names)), path
        if selection is not None:
            assert len(selection) == len(set(selection)) and set(selection) <= set(names), path
            names = selection
        identities = {f'tests::m2::{module}::{name}' for name in names}
        assert expected.isdisjoint(identities), path
        expected.update(identities)
    assert 0 < len(expected) <= 30, f'{len(expected)} groups exceeds the focused per-profile limit of 30'
    return expected


def public_cli(mirror, output, compiler, profile, run):
    build = [compiler, 'build', '--locked'] + (['--release'] if profile == 'release' else [])
    run(build, 'cli-build.txt')
    artifact = output / ('browniec.exe' if os.name == 'nt' else 'browniec')
    shutil.copyfile(mirror / 'build' / artifact.name, artifact)
    if os.name != 'nt':
        artifact.chmod(artifact.stat().st_mode | 0o111)
    empty = mirror / 'no-runtime-tools'
    empty.mkdir()
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    rows = []

    def invoke(source, extra=(), error=None, mode='run'):
        path = output / f'case-{len(rows):03}.brc'
        path.write_bytes(source.encode('utf-8'))
        command = [artifact, mode, path, '--json', *map(str, extra)]
        code = 2 if error == 'usage' else 5 if error else 0
        raw = run(command, f'cli-{len(rows):03}.json', cwd=empty, env=env,
                  expected_exit=code, timeout=30)
        data = json.loads(raw)
        assert data['schema'] == 'browniec.result/v1' and data['command'] == mode, data
        assert data['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), data
        assert data['return_i32'] == (None if error or mode == 'check' else 42), data
        assert (data['error']['kind'] == error) if error else (data['error'] is None), data
        rows.append(dict(command=list(map(str, command)), sourceSha256=digest(path),
                         exit=code, resultSha256=sha(encoded(data)), result=data))

    scalar = 'module main;fn i32 main(){return 42;}'
    invoke(scalar)
    for budget in [0, 1, 2, 256, 1000000, 1000001, 16000000]:
        invoke(scalar, ['--fuel', budget], 'fuel' if budget < 2 else None)
    for raw in ['-1', '16000001', '9223372036854775807', '9223372036854775808',
                '18446744073709551615', '184467440737095516150', '', '1.5', 'nope']:
        invoke(scalar, ['--fuel', raw], 'usage')
    for extra, mode in [(['--fuel'], 'run'), (['--fuel', 1, '--fuel', 2], 'run'),
                        (['--json'], 'run'), (['--fuel', 2], 'check')]:
        invoke(scalar, extra, 'usage', mode)
    wide = (ROOT / 'examples/fuel-wide-call.brc').read_text(encoding='utf-8').strip()
    invoke(wide, mode='check')
    invoke(wide, ['--fuel', 1000000], 'fuel')
    invoke(wide, ['--fuel', 16000000])
    fixtures = re.findall(r'value\(b"([^"\n]+)",\d+\);',
                          (ROOT / 'tests/m2/struct_parameters_source.fy').read_text(encoding='utf-8'))
    costly = [source for source in fixtures if 'while(i<42)' in source or
              'fn i32 sum(P a,P b,P c,P d,P e,P f,P g,P h)' in source]
    assert len(costly) == 4
    for source in costly:
        invoke(source, ['--fuel', 1000000], 'fuel')
        invoke(source, ['--fuel', 16000000])
    precise = [(ast.literal_eval(source).decode('utf-8'), int(price))
               for source, price in re.findall(
                   r'public_exact\((b"(?:\\.|[^"\\])*")\s*,(\d+),(?:true|false)\);',
                   (ROOT / 'tests/m2/public_fuel.fy').read_text(encoding='utf-8'))]
    assert len(precise) == len({source for source, _ in precise}) == 24
    for source, price in precise:
        invoke(source, ['--fuel', price - 1], 'fuel')
        invoke(source, ['--fuel', price])
        invoke(source, ['--fuel', price + 1])
    version_raw = run([artifact, '--version', '--json'], 'cli-version.json', cwd=empty, env=env, timeout=15)
    metadata = json.loads(version_raw)
    assert metadata['fuel_default'] == 256 and metadata['fuel_limit'] == 16000000
    assert not metadata.get('array_slice_results', False) and not metadata['restricted'] and not metadata['embed']
    assert len(rows) + 1 == 105
    return dict(cliCases=105, cli=rows, version=metadata, versionSha256=sha(encoded(metadata)),
                artifact=dict(path=artifact.relative_to(ROOT).as_posix(), sha256=digest(artifact)),
                runtimeEnvironment='cleared; tool-free PATH')


def verify_profile(profile, cli, expected, inputs):
    started = time.perf_counter()
    output = ROOT / 'build/value-execution' / profile
    receipt = output / 'receipt.json'
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_sha = digest(compiler)
    assert compiler_sha == json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))['platforms'][target]['sha256']
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    commands = []
    result = dict(schema='browniec.value-execution-verification/v1', status='incomplete',
                  recordedAt=datetime.now(timezone.utc).isoformat(), profile=profile,
                  compilerSha256=compiler_sha, inputs=inputs, commands=commands,
                  selectedTests=sorted(expected), nativeGroups=len(expected),
                  nativeWorkspace='byte-identical-production-selected-tests',
                  nativeOverrides=False, historicalResultReuse=False)
    write(receipt, result)
    mirror_inputs = [row for row in inputs if row['path'].startswith('src/') or
                     row['path'] in ['fairy.toml', 'fairy.lock'] or
                     row['path'] in {f'tests/m2/{name}.fy' for name in MODULES}]
    with tempfile.TemporaryDirectory(dir=output, prefix='native-') as temporary:
        mirror = Path(temporary)
        for row in mirror_inputs:
            destination = mirror / row['path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / row['path'], destination)
        assert all(digest(mirror / row['path']) == row['sha256'] for row in mirror_inputs)
        assert {path.relative_to(mirror).as_posix() for path in mirror.rglob('*') if path.is_file()} == {
            row['path'] for row in mirror_inputs}

        def run(command, name, cwd=mirror, env=None, expected_exit=0, timeout=900):
            command = list(map(str, command))
            invocation = dict(argv=command, cwd='native-project' if cwd == mirror else 'no-runtime-tools',
                              temporarySelectedTestMirror=cwd == mirror,
                              toolFreeRuntime=env is not None, expectedExit=expected_exit)
            invocation['commandSha256'] = sha(encoded(dict(
                argv=command, cwd=invocation['cwd'], expectedExit=expected_exit)))
            commands.append(invocation)
            write(receipt, result)
            command_started = time.perf_counter()
            done = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=timeout)
            (output / name).write_bytes(done.stdout)
            stderr_name = name + '.stderr.txt'
            (output / stderr_name).write_bytes(done.stderr)
            invocation.update(elapsedSeconds=round(time.perf_counter() - command_started, 3),
                              exit=done.returncode, stdout=name, stderr=stderr_name,
                              stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr))
            write(receipt, result)
            assert done.returncode == expected_exit and not done.stderr, (
                command, done.returncode, done.stdout[-4000:], done.stderr[-2500:])
            return done.stdout

        result['compilerVersion'] = run([compiler, '--version'], 'compiler-version.txt').decode('utf-8').strip()
        result['check'] = run([compiler, 'check', '--locked'], 'check.txt').decode('utf-8')
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
        if profile == 'release':
            command.append('--release')
        for identity in sorted(expected):
            command.extend(['--exact', identity])
        report = json.loads(run(command, 'native.json'))
        assert report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native'
        assert report['profile'] == profile and report['lock'] == 'verified' and report['status'] == 'ok'
        assert report['count'] == report['passed'] == len(expected) == len(report['tests']) and report['failed'] == 0
        assert {row['identity'] for row in report['tests']} == expected
        assert all(row['trapCategory'] is None and row['outcome'] == 'passed' and
                   not row['stdoutBase64'] and not row['stderrBase64'] for row in report['tests'])
        result.update(nativeReport=report, nativeReportSha256=sha(encoded(report)))
        if cli:
            result.update(public_cli(mirror, output, compiler, profile, run))
        assert all(digest(mirror / row['path']) == row['sha256'] for row in mirror_inputs)
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    assert sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')) == [
        row['path'] for row in inputs if row['path'].startswith('src/')]
    assert digest(compiler) == compiler_sha
    result.update(status='passed', nativeInputMirrorVerified=True,
                  elapsedSeconds=round(time.perf_counter() - started, 3))
    if not cli:
        result['cliSkipped'] = 'Optional public Fuel CLI suite was not requested.'
    write(receipt, result)
    print(f'PASS {profile}: {len(expected)} native groups' + ('; 105 public Fuel CLI cases' if cli else ''), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--public-fuel-cli', action='store_true', help='Build/run 105 existing public Fuel CLI cases in each mirror.')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    # Invalidate earlier receipts even if discovery fails while a new test is pending.
    for profile in profiles:
        output = ROOT / 'build/value-execution' / profile
        output.mkdir(parents=True, exist_ok=True)
        write(output / 'receipt.json', dict(status='incomplete', profile=profile))
    expected = discover()
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-execution.py'} |
                   (set(CLI_INPUTS) if args.public_fuel_cli else set()))
    inputs = [dict(path=path, sha256=digest(ROOT / path)) for path in paths]
    for profile in profiles:
        verify_profile(profile, args.public_fuel_cli, expected, inputs)


if __name__ == '__main__':
    main()
