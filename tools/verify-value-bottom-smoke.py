"""Optional bottom smoke: one fail-fast native image calls 10 reviewed checks.

Install as tools/verify-value-bottom-smoke.py. This adds a call frame, shares
process state and one 60-second timeout; it never replaces isolated depth,
process, IO or leak tests. Both native profiles run concurrently by default.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import stat
import subprocess
import sys
import tempfile
import time
from types import MappingProxyType

ROOT = Path(__file__).resolve().parent.parent
TOOL = 'tools/verify-value-bottom-smoke.py'
TEST = 'tests/m2/value_bottom_source.fy'
MODULE = 'tests::m2::value_bottom_source'
DRIVER = 'bottom_smoke_selected_checks'
IDENTITY = MODULE + '::' + DRIVER
# Explicit reviewed order. Never discover/enrol new tests automatically.
CHECKS = (
    'bottom_is_distinct_from_void_and_accepts_any_expected_domain',
    'both_return_if_and_switch_need_no_destination_or_outer_return',
    'nested_bottom_tails_and_else_if_suffixes_compose',
    'declarations_discard_and_assignments_do_not_capture_dead_results',
    'owned_and_view_return_contexts_preserve_real_terminal_cleanup',
    'operand_and_last_call_argument_bottom_skip_enclosing_work',
    'short_circuit_bottom_keeps_skip_edge_and_never_replays_effects',
    'all_terminal_loop_value_arms_retain_break_continue_and_outer_mutations',
    'void_and_malformed_or_unreachable_trailing_source_stay_errors',
    'independent_cfg_proof_still_rejects_tampered_returns',
)
LIMITS = ('Smoke only: extra call frame, shared process/allocator state, fail-fast; '
          'one default 60-second native timeout for all 10 checks. Never a substitute '
          'for isolated depth/process/IO/leak tests. No timing speedup claim.')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    """Atomic receipt replacement; each invocation owns a fresh directory."""
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')
    os.replace(temporary, path)


def source_paths():
    return sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy'))


def code_only(data):
    """Mask comments and quoted literals before inspecting declarations.

    Keep newlines and token boundaries; guest programs inside byte literals are
    not Fairy declarations. Reject unterminated literals/comments explicitly.
    """
    text = data.decode('utf-8')
    result = list(text)
    i = 0
    while i < len(text):
        start = i
        if text.startswith('//', i):
            end = text.find('\n', i)
            i = len(text) if end < 0 else end
        elif text.startswith('/*', i):
            i += 2
            depth = 1
            while depth and i < len(text):
                if text.startswith('/*', i):
                    depth += 1
                    i += 2
                elif text.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            require(depth == 0, 'Unterminated test comment')
        elif text[i] in ('"', "'"):
            quote = text[i]
            i += 1
            while i < len(text) and text[i] != quote:
                i += 2 if text[i] == '\\' else 1
            require(i < len(text), 'Unterminated test literal')
            i += 1
        else:
            i += 1
            continue
        result[start:i] = ['\n' if c == '\n' else ' ' for c in text[start:i]]
    return ''.join(result)


def append_driver(original):
    require(len(CHECKS) == 10 and len(set(CHECKS)) == 10, 'Missing/duplicate smoke selections')
    code = code_only(original)
    modules = re.findall(r'\bmodule\s+([\w:]+)\s*;', code)
    require(modules == [MODULE], 'Unexpected bottom module declaration')
    require(not re.search(r'@\s*effects\b', code), 'Effects annotations are not allowed in the smoke module')
    require(not re.search(r'\b' + re.escape(DRIVER) + r'\b', code), 'Smoke driver collision')
    declarations = re.findall(r'@\s*test\s+fn\s+void\s+([A-Za-z_]\w*)\s*\(\s*\)\s*\{', code)
    annotations = re.findall(r'@\s*test\b', code)
    require(len(declarations) == len(annotations), 'Unsupported @test declaration shape')
    require(len(declarations) == len(set(declarations)), 'Duplicate test declarations')
    require(set(declarations) == set(CHECKS), 'Missing or unreviewed bottom tests; update the explicit allowlist only after review')
    all_functions = re.findall(r'\bfn\s+(?:[\w:<>\[\],]+\s+)+([A-Za-z_]\w*)\s*\(', code)
    require(all(all_functions.count(name) == 1 for name in CHECKS), 'Missing/duplicate selected functions')
    driver = ('\n// Optional smoke only: one image, 10 checks, fail-fast.\n'
              '@test fn void ' + DRIVER + '(){\n' +
              ''.join('    ' + name + '();\n' for name in CHECKS) + '}\n').encode('utf-8')
    return original + driver, driver


def snapshot(run, env):
    require(not any(env.get(name) for name in ('CL', '_CL_', 'LINK')),
            'Remove CL/_CL_/LINK overrides; smoke uses default compiler/linker stacks')
    sources = source_paths()
    require(bool(sources), 'No production sources found')
    paths = sorted(sources + ['fairy.toml', 'fairy.lock', 'toolchain.json', TEST, TOOL])
    blobs = {name: (ROOT / name).read_bytes() for name in paths}
    require(source_paths() == sources and all((ROOT / name).read_bytes() == data for name, data in blobs.items()),
            'Inputs changed while freezing; no native work started')
    generated, driver = append_driver(blobs[TEST])
    machine = platform.machine().lower()
    require(machine in ('amd64', 'x86_64'), 'Only pinned amd64 native platforms are supported')
    if os.name == 'nt':
        target, native_target, executable = 'windows/amd64', 'x86_64-windows-msvc', 'fairyc.exe'
    else:
        require(sys.platform == 'linux', 'Only Windows/Linux native platforms are supported')
        target, native_target, executable = 'linux/amd64', 'x86_64-linux-gnu', 'fairyc'
    compiler = ROOT / 'build/toolchain' / executable
    pin = json.loads(blobs['toolchain.json'])
    compiler_sha = pin['platforms'][target]['sha256']
    require(sha(compiler.read_bytes()) == compiler_sha, 'Pinned compiler SHA-256 mismatch')
    rows = [dict(path=name, bytes=len(data), sha256=sha(data)) for name, data in blobs.items()]
    for name, data in blobs.items():
        path = run / 'snapshot' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        path.chmod(stat.S_IREAD | (stat.S_IRGRP | stat.S_IROTH if os.name != 'nt' else 0))
    write(run / 'inputs.json', dict(inputs=rows, sourceCount=len(sources),
                                   rootAtCompletionCompared=False))
    return dict(blobs=MappingProxyType(blobs), rows=rows, generated=generated,
                driver=driver, compiler=compiler, compilerSha=compiler_sha,
                compilerRevision=pin['compiler']['revision'], nativeTarget=native_target)


def verify_hashes(run, mirror, frozen):
    """Compare only frozen bytes, never the root's completion-time state."""
    expected_paths = {row['path'] for row in frozen['rows']}
    snapshot_paths = {p.relative_to(run / 'snapshot').as_posix()
                      for p in (run / 'snapshot').rglob('*') if p.is_file()}
    require(snapshot_paths == expected_paths, 'Frozen input inventory changed')
    for folder, expected in [('src', {name for name in expected_paths if name.startswith('src/')}),
                             ('tests', {TEST})]:
        actual_paths = {p.relative_to(mirror).as_posix() for p in (mirror / folder).rglob('*') if p.is_file()}
        require(actual_paths == expected, 'Mirror source/test inventory changed: ' + folder)
    for row in frozen['rows']:
        name = row['path']
        original = (run / 'snapshot' / name).read_bytes()
        require(len(original) == row['bytes'] and sha(original) == row['sha256'], 'Frozen input changed: ' + name)
        actual = (mirror / name).read_bytes()
        expected = frozen['generated'] if name == TEST else original
        require(sha(actual) == sha(expected), 'Final mirror input changed: ' + name)
        if name == TEST:
            require(actual[:len(original)] == original, 'Original test prefix changed')
    require(sha(frozen['compiler'].read_bytes()) == frozen['compilerSha'], 'Compiler changed during smoke')


def verify_profile(profile, run, frozen, env):
    started = time.perf_counter()
    output = run / profile
    receipt_path = output / 'receipt.json'
    receipt = json.loads(receipt_path.read_bytes())
    mirror = output / 'project'
    ready = False
    try:
        receipt.update(inputs=frozen['rows'], compiler=str(frozen['compiler']),
                       compilerSha256=frozen['compilerSha'], selectedChecks=list(CHECKS),
                       driverIdentity=IDENTITY, driverSha256=sha(frozen['driver']),
                       originalTestSha256=sha(frozen['blobs'][TEST]),
                       originalTestBytes=len(frozen['blobs'][TEST]),
                       generatedModuleSha256=sha(frozen['generated']))
        write(receipt_path, receipt)
        mirror.mkdir()
        for name, original in frozen['blobs'].items():
            destination = mirror / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(frozen['generated'] if name == TEST else original)
            destination.chmod(stat.S_IREAD | (stat.S_IRGRP | stat.S_IROTH if os.name != 'nt' else 0))
        (output / 'driver.fy').write_bytes(frozen['driver'])
        ready = True
        verify_hashes(run, mirror, frozen)

        def command(args, name):
            require(sha(frozen['compiler'].read_bytes()) == frozen['compilerSha'], 'Compiler changed before command')
            argv = [str(frozen['compiler']), *args]
            record = dict(argv=argv, cwd=str(mirror), timeoutSeconds=900, expectedExit=0)
            receipt['commands'].append(record)
            write(receipt_path, receipt)
            begin = time.perf_counter()
            try:
                done = subprocess.run(argv, cwd=mirror, env=env, stdin=subprocess.DEVNULL,
                                      capture_output=True, timeout=900)
                stdout, stderr, code = done.stdout, done.stderr, done.returncode
            except subprocess.TimeoutExpired as error:
                stdout, stderr, code = error.stdout or b'', error.stderr or b'', None
                record['error'] = 'Compiler command exceeded 900 seconds; native execution has its own default 60-second timeout'
            (output / (name + '.stdout')).write_bytes(stdout)
            (output / (name + '.stderr')).write_bytes(stderr)
            record.update(exit=code, elapsedSeconds=round(time.perf_counter()-begin, 3),
                          stdout=name + '.stdout', stderr=name + '.stderr',
                          stdoutSha256=sha(stdout), stderrSha256=sha(stderr))
            write(receipt_path, receipt)
            require(code is not None, record.get('error', 'Command did not finish'))
            return code, stdout, stderr

        code, version, errors = command(['--version'], 'compiler-version')
        require(code == 0 and not errors, 'Compiler version command failed; see retained logs')
        receipt['compilerVersion'] = version.decode('utf-8')
        require('revision: ' + frozen['compilerRevision'] in receipt['compilerVersion'].splitlines(), 'Compiler revision mismatch')
        code, _, errors = command(['check', '--locked'], 'check')
        require(code == 0 and not errors, 'Locked check failed; see retained logs')
        args = ['test', '--native', '--capture-output', '--json', '--locked', '--exact', IDENTITY]
        if profile == 'release':
            args.append('--release')
        receipt['nativeCommandAttempted'] = True
        code, raw, errors = command(args, 'native')
        (output / 'native.json').write_bytes(raw)
        report = json.loads(raw)
        receipt.update(nativeReport=report, nativeReportSha256=sha(raw))
        require(report['schemaVersion'] == 'fairyc.test-report/v4' and report['engine'] == 'native', 'Unexpected report schema/engine')
        require(report['target'] == frozen['nativeTarget'] and report['profile'] == profile and report['lock'] == 'verified', 'Unexpected report target/profile/lock')
        require(type(report['count']) is int and report['count'] == 1 and len(report['tests']) == 1, 'Smoke requires exactly one reported native group')
        row = report['tests'][0]
        require(row['identity'] == IDENTITY, 'Unexpected native driver identity')
        require(type(report['passed']) is int and type(report['failed']) is int and
                report['passed'] + report['failed'] == 1, 'Invalid native report totals')
        receipt['nativeImagesReported'] = 1
        require(code == 0 and not errors and report['status'] == 'ok' and
                report['passed'] == 1 and report['failed'] == 0 and row['outcome'] == 'passed', 'Smoke failed; see native report and logs')
        require(row['trapCategory'] is None and row['stdoutBase64'] == '' and row['stderrBase64'] == '', 'Smoke produced a trap or process output')
        receipt.update(status='pass', checksCompleted=10)
    except Exception as error:
        receipt.update(status='error', error=str(error))
    finally:
        if ready:
            try:
                verify_hashes(run, mirror, frozen)
                receipt['originalAndFinalHashesVerified'] = True
            except Exception as error:
                receipt.update(status='error', checksCompleted=None, integrityError=str(error))
        receipt['elapsedSeconds'] = round(time.perf_counter()-started, 3)
        write(receipt_path, receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    args = parser.parse_args()
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    base = ROOT / 'build/value-bottom-smoke'
    base.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-'), dir=base))
    started = time.perf_counter()
    result = dict(schema='browniec.value-bottom-smoke/v1', status='incomplete',
                  recordedAt=datetime.now(timezone.utc).isoformat(), runDirectory=str(run),
                  profiles=profiles, limits=LIMITS, smokeOnly=True, nativeOverrides=False,
                  stack='toolchain default; CL/_CL_/LINK overrides rejected',
                  nativeTimeoutSeconds=60, plannedImagesPerProfile=1, checksPerImage=10,
                  accounting='1 native image / 10 ordered checks per profile; fail-fast, not 10 native groups')
    for profile in profiles:
        output = run / profile
        output.mkdir()
        write(output / 'receipt.json', dict(result, profile=profile, commands=[],
              nativeCommandAttempted=False, nativeImagesReported=None, checksCompleted=None))
    write(run / 'receipt.json', result)
    print('SMOKE evidence: ' + str(run), flush=True)
    try:
        env = dict(os.environ)
        frozen = snapshot(run, env)
        result.update(inputs=frozen['rows'], compilerSha256=frozen['compilerSha'],
                      driverSha256=sha(frozen['driver']))
        write(run / 'receipt.json', result)
        with ThreadPoolExecutor(max_workers=len(profiles)) as pool:
            futures = {profile: pool.submit(verify_profile, profile, run, frozen, env) for profile in profiles}
            reports = {profile: future.result() for profile, future in futures.items()}
        result['results'] = {profile: dict(status=r['status'], nativeImagesReported=r['nativeImagesReported'],
                             checksCompleted=r['checksCompleted'], elapsedSeconds=r['elapsedSeconds'])
                             for profile, r in reports.items()}
        result['status'] = 'pass' if all(r['status'] == 'pass' for r in reports.values()) else 'error'
    except Exception as error:
        result.update(status='error', error=str(error))
        for profile in profiles:
            path = run / profile / 'receipt.json'
            receipt = json.loads(path.read_bytes())
            if receipt['status'] == 'incomplete':
                receipt.update(status='error', error=str(error))
                write(path, receipt)
    finally:
        result['elapsedSeconds'] = round(time.perf_counter()-started, 3)
        write(run / 'receipt.json', result)
    for profile in profiles:
        receipt = json.loads((run / profile / 'receipt.json').read_bytes())
        detail = '1 native image / 10 checks; fail-fast' if receipt['status'] == 'pass' else 'see receipt; completed checks unknown'
        print(f'SMOKE {profile}: {receipt["status"]}; {detail}', flush=True)
    return 0 if result['status'] == 'pass' else 1


if __name__ == '__main__':
    sys.exit(main())
