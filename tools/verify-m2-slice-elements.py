"""Verify scalar slice IR, VM integration and public source admission."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'slice_elements': 4, 'slice_parameters': 4, 'slice_builders': 5,
          'slice_borrow_ir': 4, 'slice_borrow_flow': 5, 'slice_lifecycle_vm': 6}
MATRICES = {'array-slice-parameters': 64, 'array-slice-parameter-source': 74,
            'array-slice-alias': 120, 'array-slice-sub': 124}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--parameter-source', action='store_true', help='Verify scalar slice parameter source lowering and M1 parser regression')
    selection.add_argument('--element-vm', action='store_true', help='Verify private typed borrowed CALL, dynamic reads and normal/error cleanup')
    selection.add_argument('--public-elements', action='store_true', help='Verify public scalar slice roots, CALLs, full admission and M1 parser regression')
    selection.add_argument('--exclusive-ir', action='store_true', help='Verify private owned exclusive metadata/flow, public scalar slices and M1 regression')
    selection.add_argument('--slice-write-ir', action='store_true', help='Verify typed slice-write construction/flow and existing public behavior')
    selection.add_argument('--exclusive-pool', action='store_true', help='Verify shared/exclusive runtime tickets, native writes, drain and readonly regressions')
    selection.add_argument('--exclusive-vm', action='store_true', help='Verify private metered exclusive execution, failure containment and readonly regressions')
    selection.add_argument('--exclusive-source', action='store_true', help='Verify mutable slice source lowering, checked execution and parser regression')
    selection.add_argument('--public-exclusive', action='store_true', help='Verify public mutable scalar slices, full admission, checked execution and M1 regression')
    selection.add_argument('--mutable-parameters-ir', action='store_true', help='Verify private mutable formal metadata/body proof and unchanged public execution')
    args = parser.parse_args()
    kind = 'slice-mutable-parameters-ir' if args.mutable_parameters_ir else 'slice-exclusive-public' if args.public_exclusive else 'slice-exclusive-source' if args.exclusive_source else 'slice-exclusive-vm' if args.exclusive_vm else 'slice-exclusive-pool' if args.exclusive_pool else 'slice-write-ir' if args.slice_write_ir else 'slice-exclusive-ir' if args.exclusive_ir else 'slice-element-public' if args.public_elements else 'slice-element-vm' if args.element_vm else 'slice-element-source' if args.parameter_source else 'slice-elements'
    groups = ({'slice_element_public': 3, 'slice_element_vm': 5, 'slice_element_source': 5, 'slice_elements': 4, 'slice_borrow_flow': 5}
              if args.public_elements else {'slice_element_vm': 5, 'slice_call_vm': 4, 'slice_frame_vm': 4, 'slice_lifecycle_vm': 6}
              if args.element_vm else {'slice_element_source': 5, 'slice_parameters_source': 5, 'slice_elements': 4}
              if args.parameter_source else GROUPS)
    matrices_to_run = ({'slice-element-public': 192, 'slice-element-source': 252, **MATRICES} if args.public_elements
                       else {'slice-element-source': 252, **MATRICES} if args.parameter_source or args.element_vm else MATRICES)
    if args.exclusive_ir:
        groups = {'slice_exclusive_ir': 6, 'slice_borrow_flow': 5, 'slice_element_public': 3}
        matrices_to_run = {'slice-element-public': 192}
    if args.slice_write_ir:
        groups = {'slice_write_ir': 5, 'slice_exclusive_ir': 6, 'slice_element_public': 3}
        matrices_to_run = {'slice-element-public': 192}
    if args.exclusive_pool:
        groups = {'slice_exclusive_pool': 6, 'array_slices': 7, 'slice_arguments': 4, 'slice_element_vm': 5}
        matrices_to_run = {'slice-element-public': 192}
    if args.exclusive_vm:
        groups = {'slice_exclusive_vm': 6, 'slice_exclusive_pool': 6, 'slice_write_ir': 5,
                  'slice_element_vm': 5, 'slice_lifecycle_vm': 6}
        matrices_to_run = {'slice-element-public': 192}
    if args.exclusive_source:
        groups = {'slice_exclusive_source': 6, 'slice_exclusive_vm': 6, 'slice_element_source': 5}
        matrices_to_run = {'slice-exclusive-source': 222, 'slice-element-public': 192}
    if args.public_exclusive:
        groups = {'slice_exclusive_source': 6, 'slice_exclusive_vm': 6, 'slice_exclusive_ir': 6,
                  'slice_write_ir': 5, 'slice_element_public': 3}
        matrices_to_run = {'slice-exclusive-source': 222, 'slice-element-public': 192}
    if args.mutable_parameters_ir:
        groups = {'slice_mutable_parameters': 6, 'slice_parameters': 4, 'slice_builders': 5,
                  'slice_exclusive_ir': 6, 'slice_borrow_flow': 5}
        matrices_to_run = {'slice-exclusive-source': 222, 'slice-element-public': 192}
    output = ROOT / ('build/m2-' + kind) / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    pinned = json.loads((ROOT / 'toolchain.json').read_text(encoding='utf-8'))
    compiler_hash = digest(compiler)
    require(compiler_hash == pinned['platforms']['windows/amd64' if os.name == 'nt' else 'linux/amd64']['sha256'], 'Compiler checksum')
    require(not os.environ.get('CL') and not os.environ.get('_CL_'), 'CL/_CL_ override')
    commands = []

    def run(command):
        command = list(map(str, command))
        commands.append(command)
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                              encoding='utf-8', timeout=600,
                              env={**os.environ, 'PYTHONUTF8': '1'})
        require(done.returncode == 0 and not done.stderr,
                f'{command}: {done.returncode}\n{done.stdout}\n{done.stderr}')
        return done.stdout.strip()

    baseline = run(['git', 'rev-parse', 'HEAD'])
    version = run([compiler, '--version'])
    require(pinned['compiler']['revision'] in version and pinned['sdk']['version'] in version, 'Compiler/SDK version')
    check = run([compiler, 'check', '--locked'])
    paths = set(ROOT.glob('src/*.fy')) | set(ROOT.glob('tests/**/*.fy')) | set(ROOT.glob('tools/*.py'))
    paths.update(ROOT / name for name in ['fairy.toml', 'fairy.lock', 'toolchain.json'])
    paths.add(ROOT / 'examples/slice-elements.brc')
    paths.add(ROOT / 'examples/mutable-slices.brc')
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    flags = ['--release'] if args.profile == 'release' else []
    native = []
    for name, count in groups.items():
        report = json.loads(run([compiler, 'test', '--native', '--capture-output', '--json',
                                 '--locked', *flags, '--file', f'tests/m2/{name}.fy']))
        require(report['status'] == 'ok' and report['count'] == report['passed'] == count
                and report['failed'] == 0 and report['engine'] == 'native'
                and report['profile'] == args.profile, name)
        tests = report['tests']
        require(len(tests) == len({t['identity'] for t in tests}) == count
                and all(t['identity'].startswith(f'tests::m2::{name}::')
                        and t['outcome'] == 'passed' and t['trapCategory'] is None
                        and not t['stdoutBase64'] and not t['stderrBase64'] for t in tests), name)
        native.append(report)
        (output / f'{name}.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(f'PASS: {args.profile}: {name}: {count} native groups', flush=True)
    build = run([compiler, 'build', '--locked', *flags])
    exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
    retained = output / exe.name
    shutil.copyfile(exe, retained)
    exe_hash = digest(retained)
    matrices = []
    for name, count in matrices_to_run.items():
        run([sys.executable, '-B', ROOT / f'tools/check-m2-{name}.py',
             '--exe', retained, '--profile', args.profile])
        directory = 'array-slice-parameters-public' if name == 'array-slice-parameters' else name
        path = ROOT / f'build/m2-{directory}' / args.profile / 'cli-receipt.json'
        report = json.loads(path.read_text(encoding='utf-8'))
        require(report['status'] == 'passed' and report['count'] == count
                and report['exeSha256'] == exe_hash, name)
        shutil.copyfile(path, output / f'{name}-cli.json')
        matrices.append(dict(selection=name, count=count, receiptSha256=digest(path)))
        print(f'PASS: {args.profile}: {name}: {count} CLI cases', flush=True)
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    boundaries = []
    for tag in ([] if args.mutable_parameters_ir or args.public_exclusive or args.exclusive_source or args.exclusive_vm or args.exclusive_pool or args.slice_write_ir or args.exclusive_ir or args.parameter_source or args.element_vm or args.public_elements else ['i32', 'bool', 'i64', 'u32', 'usize']):
        for index, declaration in enumerate([f'fn i32 f(ref {tag}[] p){{return 42;}}fn i32 main(){{return 42;}}',
                            f'fn i32 main(){{let {tag}[1] a=[{"true" if tag == "bool" else "42"};1];let ref {tag}[] p=ref a;return 42;}}']):
            path = output / f'boundary-{len(boundaries)}.brc'
            path.write_text('module main;' + declaration, encoding='utf-8')
            for mode in ['check', 'run']:
                command = [str(retained), mode, str(path), '--json']
                if mode == 'run':
                    command += ['--fuel', '1000000']
                commands.append(command)
                done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
                result = json.loads(done.stdout)
                require(done.returncode == 0 and not done.stderr and result['status'] == ('checked' if mode == 'check' else 'completed')
                        and result['command'] == mode and result['schema'] == 'browniec.result/v1'
                        and result['return_i32'] == (None if mode == 'check' else 42) and result['error'] is None, str(result))
                boundaries.append(dict(command=command, sourceSha256=digest(path), exit=done.returncode, result=result))
    m1 = None
    if (args.mutable_parameters_ir or args.public_exclusive or args.exclusive_source or args.exclusive_vm or args.exclusive_pool or args.slice_write_ir or args.exclusive_ir or args.parameter_source or args.public_elements) and os.name == 'nt':
        run([sys.executable, '-B', ROOT / 'tools/check-m1-cli.py', '--exe', retained, '--profile', args.profile])
        path = ROOT / 'build/m1' / args.profile / 'cli-receipt.json'
        report = json.loads(path.read_text(encoding='utf-8'))
        require(report['status'] == 'passed' and report['count'] == 2007 and report['exeSha256'] == exe_hash, 'M1 CLI regression')
        shutil.copyfile(path, output / 'm1-cli.json')
        m1 = dict(count=report['count'], receiptSha256=digest(path))
        print(f'PASS: {args.profile}: M1: {m1["count"]} CLI cases', flush=True)
    require(all(digest(ROOT / row['path']) == row['sha256'] for row in inputs), 'Inputs changed')
    require(digest(compiler) == compiler_hash and digest(retained) == exe_hash, 'Artifact changed')
    report = dict(schema='browniec.' + kind + '/v1', status='passed', profile=args.profile,
                  recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
                  compilerVersion=version, compilerSha256=compiler_hash, lockedCheck=check,
                  sourceSha256=inputs, commands=commands, native=native, build=build,
                  retainedArtifact=dict(path=retained.relative_to(ROOT).as_posix(), sha256=exe_hash, bytes=retained.stat().st_size),
                  matrices=matrices, boundaries=boundaries, m1=m1, nativeGroups=sum(groups.values()),
                  cliCases=sum(matrices_to_run.values()) + len(boundaries) + (m1['count'] if m1 else 0),
                  limitations=['Readonly i32/bool/i64/u8/u32/usize slices use complete public metadata/type/flow validation and shared metered VM execution. Non-scalar slices, mutable formals, slice results, temporary roots and escaping references remain unavailable.',
                               'Focused native and CLI selection only; no full native/other M2, Linux, M0, packaging, isolation or performance rerun.',
                               'The parameter-source and public-elements selections run full M1 CLI on Windows only; other selections do not rerun M1.'])
    if args.exclusive_ir:
        report['limitations'] = ['Private owned exclusive slice metadata and complete independent flow inspection only. Public verify/VM rejects exclusive metadata before backing, Fuel or dispatch. No guest syntax, mutable parameters, subslices/reborrows, write instruction, metering, VM integration or capability change.',
                                 'Selected native and public scalar-slice CLI regression plus full M1 CLI on Windows. Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks were not rerun.']
    if args.slice_write_ir:
        report['limitations'] = ['Private opcode60 slice-write construction and independent verification only. Exact live owned exclusive site, ordinary defined same-function usize index and exact scalar value are required; no scalar or loan definition is published. Public verification/VM admission remains gated before backing/Fuel/dispatch.',
                                'No mutable guest syntax, write execution, opcode60 Fuel price, exclusive runtime integration, automatic cleanup, mutable parameters, subloans or capability change.',
                                'Selected native and public scalar-slice CLI regression plus full M1 CLI on Windows. Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks were not rerun.']
    if args.exclusive_pool:
        report['limitations'] = ['Private unified sixteen-ticket shared/exclusive runtime pool only. Native tests perform actual scalar writes, selected u8 UTF-8 scans, atomic mixed-mode cleanup and existing VM drain. Readonly adapters and CALL batches reject exclusive tickets.',
                                'Public exclusive admission remains gated. No exclusive VM instruction dispatch, new Fuel price, mutable guest syntax, mutable parameters, subloans or public capability is enabled.',
                                'Selected native and public scalar-slice CLI regression plus full M1 CLI on Windows. Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks were not rerun.']
    if args.exclusive_vm:
        report['limitations'] = ['Private owned exclusive instruction execution only, through immutable independently inspected IR and the shared execution loop. Exact Fuel and one-short failures cover open/read/write/length/u8 UTF-8/close; existing invocation cleanup drains writers after errors.',
                                'Public verification still rejects marker128 before backing/Fuel/dispatch. No mutable guest syntax, public admission, mutable parameters, subloans or capability change.',
                                'Selected native and public scalar-slice CLI regression plus full M1 CLI on Windows. Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks were not rerun.']
    if args.exclusive_source:
        report['limitations'] = ['Private source lowering for let ref mut Tag[] bound to ref mut of a same-function mutable owned scalar array, and checked element stores. Native tests independently inspect and execute actual source through the shared internal VM and invocation cleanup.',
                                'Public verify and CLI still reject exclusive sites before backing/Fuel/dispatch. No public mutable-slice capability, mutable parameters, aliases/subloans, CALL coercion or returned borrow is enabled. Program fields and Fuel prices are unchanged.',
                                'Selected native, private source-gate and public readonly scalar CLI regression plus full M1 CLI on Windows. Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks were not rerun.']
    # Earlier selection names remain available against current admission. Dated
    # committed receipts retain the private/gated behavior at their own hashes.
    if args.public_exclusive or args.exclusive_source or args.exclusive_vm or args.exclusive_pool or args.slice_write_ir or args.exclusive_ir:
        report['limitations'] = ['Public verify and CLI admit independently proved same-function owned mutable scalar slices over i32/bool/i64/u8/u32/usize roots. All existing metadata/type/flow/lifetime checks and metered exclusive execution/cleanup remain required. Version JSON adds array_slice_mutable.',
                                'Mutable formals, aliases/subloans, CALL coercions, returned borrows, temporary roots and non-scalar slices remain unsupported. Program fields, profiles and Fuel prices are unchanged.',
                                'Only the selected native groups and CLI matrices plus full M1 on Windows were rerun. Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks were not rerun.']
    if args.mutable_parameters_ir:
        report['limitations'] = ['Private rootless mutable formal descriptors use bit128 plus an exact scalar tag without growing Program. Native tests construct all six tags and independently inspect read/write/length/u8 UTF-8/close bodies and exact lifetimes. Public verify rejects these descriptors after complete proof and before allocation/Fuel/dispatch.',
                                'Mutable CALL argument handoff/restore, source formals, runtime formal execution, aliases/subloans and returned borrows remain unavailable. Readonly argument coercion and direct shared/exclusive VM adapters reject mutable formals. Existing owned mutable and readonly source execution stays public. No opcode, Fuel, profile or capability change.',
                                'Selected native groups, public mutable/readonly CLI matrices and full M1 on Windows only. Full native, other M2, Linux, M0, isolation, packaging, allocator and timing checks were not rerun.']
    receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {args.profile}: {report["nativeGroups"]} native groups; {report["cliCases"]} CLI cases', flush=True)


if __name__ == '__main__':
    main()
