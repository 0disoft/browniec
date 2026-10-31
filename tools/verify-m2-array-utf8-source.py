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
    kind = ('array-slice-parameter-source' if args.slice_parameter_source else 'array-slice-borrow-ir' if args.slice_borrow_ir else 'array-slice-builders' if args.slice_builders else 'array-slice-parameters' if args.slice_parameters else 'array-slice-arguments' if args.slice_arguments else 'array-slice-alias' if args.slice_alias else 'array-slice-sub' if args.slice_sub else 'array-slice-index' if args.slice_index else 'array-slice-length' if args.slice_length else 'array-utf8-slices' if args.slices else 'array-utf8-temporary-computed-ranges' if args.temporary_computed_ranges else 'array-utf8-computed-ranges' if args.computed_ranges else 'array-utf8-temporary-dynamic-ranges' if args.temporary_dynamic_ranges else 'array-utf8-dynamic-ranges' if args.dynamic_ranges else 'array-utf8-open-ranges' if args.open_ranges else 'array-utf8-temporary-ranges' if args.temporary_ranges else 'array-utf8-ranges' if args.ranges else 'array-utf8-literals' if args.literals else
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
    paths.update(ROOT.glob('tests/**/*.fy'))
    paths.update(ROOT.glob('tools/*.py'))
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    groups = ({'slice_parameters_source': 5, 'slice_parameters': 4, 'slice_arguments': 4, 'array_signatures': 6}
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
    matrices_to_run = ({'array-slice-parameter-source': None, 'array-slice-alias': 120, 'array-slice-sub': 124}
                       if args.slice_parameter_source else {'array-slice-alias': 120, 'array-slice-sub': 124}
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
        report = ROOT / ('build/m2-' + selection) / args.profile / 'cli-receipt.json'
        cases = json.loads(report.read_text(encoding='utf-8'))
        require(cases['status'] == 'passed' and cases['exeSha256'] == exe_hash
                and cases['count'] == len(cases['cases'])
                and (count is None or count == cases['count']), 'CLI identity/count mismatch')
        matrices.append(dict(selection=selection, count=cases['count'], receiptSha256=digest(report)))
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
                  limitations=['Qualified text::valid_utf8 over named u8 arrays, direct u8-array call results and repeated-byte literals. Named-array and temporary literal ranges have focused selections. Lexical let ref u8[] bindings over named arrays support text::valid_utf8 and reverse-order cleanup through a focused slices selection. Borrowed roots reject writes; copies remain allowed. Slice length has a focused slice-length selection using opcode57 and a fresh usize value; reads revalidate active sessions and backing capacity before publishing. Slice indexing has a focused slice-index selection using opcode58, a once-only usize index and a fresh element value. Reads preserve loans and revalidate relative bounds. Lexical subslice declarations have a focused slice-sub selection using opcode59 and parent-relative bounds; children share the active root session without payload copies. Explicit ref-name slice aliases have a focused slice-alias selection that reuses whole-parent opcode59 lowering with independent tickets and identical Fuel. Private atomic slice-argument borrowing and batch cleanup have a focused slice-arguments selection; incoming tickets are validated against the original pool before staged publication. This is an unmetered native foundation with no CALL/signature integration. A focused slice-borrow-ir selection checks rootless formal/derived UTF8, length, read, close and same-origin subslice instruction builders while keeping owned-root open and the core execution gate unchanged. A focused slice-builders selection checks shared site reservation, formal and flattened derived declarations and checked argument encoding. It does not enable borrowed instructions or CALL execution. A focused slice-parameters selection checks private formal/derived borrow metadata, initial live masks and live u8 CALL sources; the core verifier explicitly rejects nonzero borrowed-parameter metadata until metered runtime support exists. A focused slice-parameter-source selection parses readonly ref u8[] signatures, explicit ref-name slice arguments and formal-derived bindings into prospective IR. Both CLI check and run remain verification errors for any borrowed signature until runtime integration. Slice results and borrowing temporaries remain unavailable, as do Buffer/text ownership and general slice expressions. Sixteen static slice sites and sixty-four lexical bindings remain bounded. Named and temporary computed usize endpoints have focused selections. Computed temporary endpoints use an anonymous lexical capture for cleanup; nested allocations require overlapping capacity. Focused native and CLI sentinels. Full suites, M0, Linux, '
                               'isolation, DLL, packaging, allocation instrumentation and performance not run.'])
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
