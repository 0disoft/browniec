"""Verify the source-level u8-array UTF-8 predicate with focused native and CLI checks."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'array_utf8_source': 5, 'array_utf8': 6, 'array_length': 3, 'array_call_reads': 4}
CLI = {'array-utf8-source': 142, 'array-call-reads': 106}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain' /
                        ('fairyc.exe' if os.name == 'nt' else 'fairyc'))
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--slice-parameters-public', action='store_true', help='Verify public borrowed slice VM and CLI admission with unchanged metering')
    selection.add_argument('--slice-lifecycle-vm', action='store_true', help='Verify shared VM slice dispatch and normal/abort frame cleanup behind the public gate')
    selection.add_argument('--call-frame-vm', action='store_true', help='Verify VM CALL scalar/control publication after mixed admission')
    selection.add_argument('--slice-frame-vm', action='store_true', help='Verify private dynamic-root borrowed slice instruction dispatch')
    selection.add_argument('--mixed-call-vm', action='store_true', help='Verify private atomic owned and borrowed CALL admission')
    selection.add_argument('--slice-call-vm', action='store_true', help='Verify private metered borrowed frame retain and cleanup adapters')
    selection.add_argument('--slice-borrow-flow', action='store_true', help='Verify independent borrowed slice control-flow inspection behind the execution gate')
    selection.add_argument('--slice-parameter-source', action='store_true', help='Verify gated source borrowed signatures and ref-name arguments')
    selection.add_argument('--slice-borrow-ir', action='store_true', help='Verify private rootless borrowed slice instruction builders')
    selection.add_argument('--slice-builders', action='store_true', help='Verify borrow-aware private IR declaration and argument builders')
    selection.add_argument('--slice-parameters', action='store_true', help='Verify private borrowed parameter origins and call argument checks')
    selection.add_argument('--slice-arguments', action='store_true', help='Verify private atomic slice argument borrowing and cleanup')
    selection.add_argument('--slice-alias', action='store_true', help='Verify checked read-only slice alias bindings')
    selection.add_argument('--slice-sub', action='store_true', help='Verify checked read-only subslice bindings')
    selection.add_argument('--slice-index', action='store_true', help='Verify checked slice indexing')
    selection.add_argument('--slice-length', action='store_true', help='Verify checked slice length values')
    selection.add_argument('--slices', action='store_true', help='Verify lexical read-only u8 slice bindings')
    selection.add_argument('--call-results', action='store_true', help='Verify direct UTF-8 array-result calls')
    selection.add_argument('--literals', action='store_true', help='Verify repeated-byte UTF-8 literals')
    selection.add_argument('--ranges', action='store_true', help='Verify named-array literal UTF-8 ranges')
    selection.add_argument('--temporary-ranges', action='store_true', help='Verify literal ranges on temporary calls and literals')
    selection.add_argument('--open-ranges', action='store_true', help='Verify omitted static UTF-8 range endpoints')
    selection.add_argument('--dynamic-ranges', action='store_true', help='Verify named-array ranges with usize local endpoints')
    selection.add_argument('--temporary-dynamic-ranges', action='store_true', help='Verify usize endpoints on temporary arrays')
    selection.add_argument('--computed-ranges', action='store_true', help='Verify computed usize bounds on named arrays')
    selection.add_argument('--temporary-computed-ranges', action='store_true', help='Verify computed usize bounds on temporary arrays')
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    kind = ('array-slice-parameters-public' if args.slice_parameters_public else 'array-slice-lifecycle-vm' if args.slice_lifecycle_vm else 'array-call-frame-vm' if args.call_frame_vm else 'array-slice-frame-vm' if args.slice_frame_vm else 'array-mixed-call-vm' if args.mixed_call_vm else 'array-slice-call-vm' if args.slice_call_vm else 'array-slice-borrow-flow' if args.slice_borrow_flow else 'array-slice-parameter-source' if args.slice_parameter_source else 'array-slice-borrow-ir' if args.slice_borrow_ir else 'array-slice-builders' if args.slice_builders else 'array-slice-parameters' if args.slice_parameters else 'array-slice-arguments' if args.slice_arguments else 'array-slice-alias' if args.slice_alias else 'array-slice-sub' if args.slice_sub else 'array-slice-index' if args.slice_index else 'array-slice-length' if args.slice_length else 'array-utf8-slices' if args.slices else 'array-utf8-temporary-computed-ranges' if args.temporary_computed_ranges else 'array-utf8-computed-ranges' if args.computed_ranges else 'array-utf8-temporary-dynamic-ranges' if args.temporary_dynamic_ranges else 'array-utf8-dynamic-ranges' if args.dynamic_ranges else 'array-utf8-open-ranges' if args.open_ranges else 'array-utf8-temporary-ranges' if args.temporary_ranges else 'array-utf8-ranges' if args.ranges else 'array-utf8-literals' if args.literals else
            'array-utf8-calls' if args.call_results else 'array-utf8-source')
    output = ROOT / ('build/m2-' + kind) / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    require(not os.environ.get('CL') and not os.environ.get('_CL_'), 'CL/_CL_ override')
    commands = []

    def run(command):
        command = list(map(str, command))
        commands.append(command)
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding='utf-8', timeout=600,
                                env={**os.environ, 'PYTHONUTF8': '1'})
        require(result.returncode == 0 and not result.stderr,
                f'{command}: {result.returncode}\n{result.stdout}\n{result.stderr}')
        return result.stdout.strip()

    baseline = run(['git', 'rev-parse', 'HEAD'])
    compiler_hash = digest(compiler)
    pinned = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    platform_key = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    require(compiler_hash == pinned['platforms'][platform_key]['sha256'], 'Compiler checksum mismatch')
    version = run([compiler, '--version'])
    require(pinned['compiler']['revision'] in version and pinned['sdk']['version'] in version, 'Compiler/SDK mismatch')
    check = run([compiler, 'check', '--locked'])
    paths = set(ROOT.glob('src/*.fy'))
    paths.update(ROOT / p for p in ['fairy.toml', 'fairy.lock', 'toolchain.json',
                                   'tools/verify-m2-array-utf8-source.py'])
    if args.call_frame_vm or args.slice_lifecycle_vm or args.slice_parameters_public:
        paths.update(ROOT.glob('examples/*.brc'))
    paths.update(ROOT.glob('tests/**/*.fy'))
    paths.update(ROOT.glob('tools/*.py'))
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    groups = ({'slice_lifecycle_vm': 6, 'slice_borrow_flow': 5} if args.slice_parameters_public else {'slice_lifecycle_vm': 6} if args.slice_lifecycle_vm else {'call_frame_vm': 4} if args.call_frame_vm else {'slice_frame_vm': 4, 'slice_sub_vm': 3}
              if args.slice_frame_vm else {'mixed_call_vm': 5, 'slice_call_vm': 4, 'struct_call_vm': 8, 'slice_arguments': 4}
              if args.mixed_call_vm else {'slice_call_vm': 4, 'slice_arguments': 4, 'slice_borrow_flow': 5, 'slice_sub_vm': 3}
              if args.slice_call_vm else {'slice_borrow_flow': 5, 'slice_parameters_source': 5, 'slice_sub_vm': 3, 'slice_index_vm': 3}
              if args.slice_borrow_flow else {'slice_parameters_source': 5, 'slice_parameters': 4, 'slice_arguments': 4, 'array_signatures': 6}
              if args.slice_parameter_source else {'slice_borrow_ir': 4, 'slice_builders': 5, 'slice_parameters': 4, 'slice_sub_vm': 3, 'slice_index_vm': 3}
              if args.slice_borrow_ir else {'slice_builders': 5, 'slice_parameters': 4, 'slice_sub_vm': 3, 'array_slice_alias': 3}
              if args.slice_builders else {'slice_parameters': 4, 'array_calls': 9, 'struct_parameters_ir': 7}
              if args.slice_parameters else {'slice_arguments': 4, 'array_slices': 7, 'slice_sub_vm': 3}
              if args.slice_arguments else {'array_slice_alias': 3, 'slice_sub_vm': 3, 'array_slice_sub': 3, 'array_utf8_slices': 6}
              if args.slice_alias else {'slice_sub_vm': 3, 'array_slice_sub': 3, 'array_slice_index': 3, 'array_slice_length': 4, 'array_utf8_slices': 6}
              if args.slice_sub else {'slice_index_vm': 3, 'array_slice_index': 3, 'array_slice_length': 4, 'slice_vm': 8, 'array_utf8_slices': 6, 'array_length': 3}
              if args.slice_index else {'array_slice_length': 4, 'slice_vm': 8, 'array_utf8_slices': 6, 'array_length': 3}
              if args.slice_length else {'array_utf8_slices': 6, 'slice_vm': 8, 'array_utf8_temporary_computed_ranges': 5, 'array_utf8_computed_ranges': 5, 'array_utf8_source': 5}
              if args.slices else {'array_utf8_temporary_computed_ranges': 5, 'array_utf8_computed_ranges': 5, 'array_utf8_temporary_dynamic_ranges': 5, 'array_utf8_temporary_ranges': 4, 'array_utf8_open_ranges': 4}
              if args.temporary_computed_ranges else {'array_utf8_computed_ranges': 5, 'array_utf8_dynamic_ranges': 5, 'array_utf8_temporary_dynamic_ranges': 5, 'array_utf8_ranges': 4, 'array_utf8_open_ranges': 4}
              if args.computed_ranges else {'array_utf8_temporary_dynamic_ranges': 5, 'array_utf8_dynamic_ranges': 5, 'array_utf8_temporary_ranges': 4, 'array_utf8_open_ranges': 4, 'array_dynamic_utf8': 5}
              if args.temporary_dynamic_ranges else {'array_utf8_dynamic_ranges': 5, 'array_dynamic_utf8': 5, 'array_range_utf8': 6, 'array_utf8_ranges': 4, 'array_utf8_open_ranges': 4}
              if args.dynamic_ranges else {'array_utf8_open_ranges': 4, 'array_utf8_temporary_ranges': 4, 'array_utf8_ranges': 4}
              if args.open_ranges else {'array_utf8_temporary_ranges': 4, 'array_utf8_ranges': 4, 'array_utf8_calls': 4, 'array_utf8_literals': 4}
              if args.temporary_ranges else {'array_utf8_ranges': 4, 'array_utf8_source': 5, 'array_range_utf8': 6}
              if args.ranges else {'array_utf8_literals': 4, 'array_utf8_source': 5, 'array_utf8_calls': 4}
              if args.literals else
              {'array_utf8_calls': 4, 'array_utf8_source': 5, 'array_call_reads': 4}
              if args.call_results else GROUPS)
    command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
    if args.profile == 'release':
        command.append('--release')
    if args.slice_parameters_public:
        # Bound individual native compilations; retain each real compiler report.
        reports = []
        for name in groups:
            part = json.loads(run([*command, '--file', 'tests/m2/' + name + '.fy']))
            require(part['status'] == 'ok' and part['passed'] == groups[name]
                    and part['failed'] == 0 and part['count'] == groups[name], name)
            reports.append(part)
            print(f'PASS: {args.profile}: {name} native groups', flush=True)
        native = dict(schema='browniec.native-selection/v1', engine='native',
                      target=reports[0]['target'], profile=args.profile, status='ok',
                      count=sum(p['count'] for p in reports), passed=sum(p['passed'] for p in reports),
                      failed=0, tests=[t for p in reports for t in p['tests']], reports=reports)
    else:
        for name in groups:
            command.extend(['--file', 'tests/m2/' + name + '.fy'])
        native = json.loads(run(command))
    (output / 'native-report.json').write_text(json.dumps(native, indent=2) + '\n', encoding='utf-8')
    expected = sum(groups.values())
    require(native['status'] == 'ok' and native['count'] == native['passed'] == expected
            and native['failed'] == 0 and native['engine'] == 'native'
            and native['profile'] == args.profile,
            f"Native outcomes/profile mismatch: expected={expected}, count={native.get('count')}, passed={native.get('passed')}, failed={native.get('failed')}")
    tests = native['tests']
    require(len(tests) == len({t['identity'] for t in tests}) == expected, 'Duplicate/missing tests')
    require(all(sum(t['identity'].startswith('tests::m2::' + name + '::') for t in tests)
                == count for name, count in groups.items()), 'Native selection mismatch')
    require(all(t['outcome'] == 'passed' and t['trapCategory'] is None
                and not t['stdoutBase64'] and not t['stderrBase64'] for t in tests), 'Native failure/output')
    print(f'PASS: {args.profile}: {expected} native groups', flush=True)
    build = None
    exe_hash = None
    cli = []
    build = run([compiler, 'build', '--locked'] + (['--release'] if args.profile == 'release' else []))
    exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
    exe_hash = digest(exe)
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    sentinels = [
        ('module main;fn i32 main(){return 42;}', None),
        ('module main;fn i32 main(){let i32[2] a=[21;2];return a[0]+a[1];}', None),
        ('module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return p.x;}', None),
        ('module main;fn i32 main(){let Buffer b=Buffer{};return 42;}', 'type'),
    ]
    for i, (source, error) in enumerate(sentinels):
        path = output / f'sentinel-{i}.brc'
        path.write_text(source, encoding='utf-8')
        for mode in ['check', 'run']:
            cmd = [str(exe), mode, str(path), '--json']
            if mode == 'run':
                cmd += ['--fuel', '1000000']
            commands.append(cmd)
            done = subprocess.run(cmd, cwd=empty, env=env, capture_output=True, timeout=15)
            require(done.returncode == (3 if error else 0) and not done.stderr, str(done))
            result = json.loads(done.stdout)
            require(result['schema'] == 'browniec.result/v1' and result['command'] == mode, 'CLI schema')
            require(result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), 'CLI status')
            require(result['return_i32'] == (42 if not error and mode == 'run' else None), 'CLI value')
            require((result['error']['kind'] == error) if error else result['error'] is None, 'CLI error')
            cli.append(dict(command=cmd, sourceSha256=hashlib.sha256(source.encode()).hexdigest(),
                            exit=done.returncode, result=result))
    print(f'PASS: {args.profile}: {len(cli)} CLI sentinels; Buffer syntax remains rejected', flush=True)
    matrices = []
    matrices_to_run = ({'array-slice-parameters': 64, 'array-call-reads': 106, 'struct-call-reads': 102, 'array-slice-parameter-source': 74, 'array-slice-alias': 120, 'array-slice-sub': 124}
                       if args.slice_parameters_public else {'array-call-reads': 106, 'struct-call-reads': 102, 'array-slice-parameter-source': 74, 'array-slice-alias': 120, 'array-slice-sub': 124}
                       if args.slice_lifecycle_vm else {'array-call-reads': 106, 'struct-call-reads': 102, 'array-slice-parameter-source': 74}
                       if args.call_frame_vm else {'array-slice-parameter-source': None, 'array-slice-alias': 120, 'array-slice-sub': 124}
                       if args.slice_frame_vm or args.mixed_call_vm or args.slice_parameter_source or args.slice_borrow_flow or args.slice_call_vm else {'array-slice-alias': 120, 'array-slice-sub': 124}
                       if args.slice_parameters or args.slice_builders or args.slice_borrow_ir else {'array-slice-alias': 120, 'array-slice-sub': 124}
                       if args.slice_arguments else {'array-slice-alias': 120, 'array-slice-sub': 124, 'array-utf8-slices': 248}
                       if args.slice_alias else {'array-slice-sub': 124, 'array-slice-index': 186, 'array-slice-length': 104, 'array-utf8-slices': 248}
                       if args.slice_sub else {'array-slice-index': 186, 'array-slice-length': 104, 'array-utf8-slices': 248}
                       if args.slice_index else {'array-slice-length': 104, 'array-utf8-slices': 248}
                       if args.slice_length else {'array-utf8-slices': 248, 'array-utf8-temporary-computed-ranges': 310, 'array-utf8-computed-ranges': 196}
                       if args.slices else {'array-utf8-temporary-computed-ranges': 310, 'array-utf8-computed-ranges': 196, 'array-utf8-temporary-dynamic-ranges': 484, 'array-utf8-temporary-ranges': 250, 'array-utf8-open-ranges': 270}
                       if args.temporary_computed_ranges else {'array-utf8-computed-ranges': 196, 'array-utf8-dynamic-ranges': 634, 'array-utf8-temporary-dynamic-ranges': 484, 'array-utf8-ranges': 202, 'array-utf8-open-ranges': 270}
                       if args.computed_ranges else {'array-utf8-temporary-dynamic-ranges': 484, 'array-utf8-dynamic-ranges': 634, 'array-utf8-temporary-ranges': 250, 'array-utf8-open-ranges': 270}
                       if args.temporary_dynamic_ranges else {'array-utf8-dynamic-ranges': 634, 'array-utf8-open-ranges': 270, 'array-utf8-ranges': 202}
                       if args.dynamic_ranges else {'array-utf8-open-ranges': 270, 'array-utf8-temporary-ranges': 250, 'array-utf8-ranges': 202, 'array-utf8-source': 142, 'array-utf8-calls': 100, 'array-utf8-literals': 130}
                       if args.open_ranges else {'array-utf8-temporary-ranges': 250, 'array-utf8-ranges': 202, 'array-utf8-source': 142, 'array-utf8-calls': 100, 'array-utf8-literals': 130}
                       if args.temporary_ranges else {'array-utf8-ranges': 202, 'array-utf8-source': 142, 'array-utf8-calls': 100, 'array-utf8-literals': 130}
                       if args.ranges else {'array-utf8-literals': 130, 'array-utf8-source': 142, 'array-utf8-calls': 100}
                       if args.literals else {'array-utf8-calls': 100, **CLI} if args.call_results else CLI)
    for selection, count in matrices_to_run.items():
        print(run([os.sys.executable, '-B', ROOT / ('tools/check-m2-' + selection + '.py'),
                   '--exe', exe, '--profile', args.profile]), flush=True)
        report = ROOT / ('build/m2-' + ('array-slice-parameters-public' if selection == 'array-slice-parameters' else selection)) / args.profile / 'cli-receipt.json'
        cases = json.loads(report.read_text(encoding='utf-8'))
        require(cases['status'] == 'passed' and cases['exeSha256'] == exe_hash
                and cases['count'] == len(cases['cases'])
                and (count is None or count == cases['count']), 'CLI identity/count mismatch')
        matrices.append(dict(selection=selection, count=cases['count'], receiptSha256=digest(report)))
    m1 = None
    if args.call_frame_vm or args.slice_lifecycle_vm or args.slice_parameters_public:
        print(run([os.sys.executable, '-B', ROOT / 'tools/check-m1-cli.py',
                   '--exe', exe, '--profile', args.profile]), flush=True)
        m1_path = ROOT / 'build/m1' / args.profile / 'cli-receipt.json'
        m1_report = json.loads(m1_path.read_text(encoding='utf-8'))
        require(m1_report['status'] == 'passed' and m1_report['count'] == 2007
                and m1_report['exeSha256'] == exe_hash, 'M1 count/image mismatch')
        import shutil
        shutil.copyfile(m1_path, output / 'm1-cli-receipt.json')
        m1 = dict(count=m1_report['count'], receiptSha256=digest(m1_path))
    retained = output / exe.name
    import shutil
    shutil.copyfile(exe, retained)
    require(digest(retained) == exe_hash, 'Retained CLI mismatch')
    require(all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Inputs changed')
    require(digest(compiler) == compiler_hash, 'Compiler changed')
    lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    result = dict(schema='browniec.' + kind + '/v1', status='passed',
                  recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
                  profile=args.profile, compilerVersion=version,
                  compilerSha256=compiler_hash, lockedCheck=check, commands=commands,
                  standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
                  sourceSha256=inputs, native=native, build=build, exeSha256=exe_hash, cli=cli, matrices=matrices,
                  limitations=['Focused native and CLI selection only. Public readonly u8 slice parameters use full origin/type/flow verification, metered CALL, dynamic roots and normal/error cleanup. Buffer/text ownership, slice results, mutable/non-u8 slices, temporary-root arguments, isolation and embedding remain unavailable. Full native suites, other matrices, Linux, M0, packaging and performance were not rerun.'])
    if args.call_frame_vm or args.slice_lifecycle_vm or args.slice_parameters_public:
        result['m1'] = m1
        result['limitations'] = ['CALL publication uses the shared public VM path. This selection covers the four CALL adapter groups and its recorded CLI matrices only; full native suites, other matrices, Linux, M0, isolation, packaging and timing were not rerun.']
    if args.slice_lifecycle_vm:
        result['limitations'] = ['The shared internal core and public VM wrapper are exercised with borrowed source Programs. Six focused lifecycle native groups and recorded CLI matrices only. Full native suites, other matrices, Linux, M0, isolation, packaging and performance were not rerun.']
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
