"""Verify private record CALL execution in bounded core/regression phases."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {
    'core': {'struct_call_vm': 8, 'struct_parameters_ir': 7,
             'struct_parameter_signatures': 6},
    'regressions': {'array_calls': 9, 'array_result_vm': 6,
                    'struct_function_vm': 7, 'functions': 4},
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=GROUPS, required=True)
    parser.add_argument('--compiler', type=Path, default=ROOT / 'build/toolchain' /
                        ('fairyc.exe' if os.name == 'nt' else 'fairyc'))
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    phase = args.phase
    output = ROOT / ('build/m2-struct-call-vm-' + phase)
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'receipt.json'
    write(receipt, dict(status='incomplete', startedAt=datetime.now(timezone.utc).isoformat()))
    require(not os.environ.get('CL') and not os.environ.get('_CL_'), 'Unexpected CL/_CL_ override')
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
    version = run([compiler, '--version'])
    compiler_hash = digest(compiler)
    check = run([compiler, 'check', '--locked'])
    lock = json.loads((ROOT / 'fairy.lock').read_text(encoding='utf-8'))
    paths = set((ROOT / 'src').glob('*.fy'))
    paths.update(ROOT / p for p in ['fairy.toml', 'fairy.lock', 'toolchain.json',
                                   'tools/verify-m2-struct-call-vm.py'])
    # Hash both phase selections so later stepwise evidence can prove identical
    # runtime, fixture, harness and SDK inputs across the implementation commit.
    paths.update(ROOT / ('tests/' + ('' if name == 'functions' else 'm2/') + name + '.fy')
                 for groups in GROUPS.values() for name in groups)
    inputs = [dict(path=p.relative_to(ROOT).as_posix(), sha256=digest(p)) for p in sorted(paths)]
    groups = GROUPS[phase]
    expected = sum(groups.values())
    results = []
    for profile in ['development', 'release']:
        command = [compiler, 'test', '--native', '--capture-output', '--json', '--locked']
        if profile == 'release':
            command.append('--release')
        for name in groups:
            command.extend(['--file', 'tests/' + ('' if name == 'functions' else 'm2/') + name + '.fy'])
        native = json.loads(run(command))
        write(output / (profile + '-native.json'), native)
        require(native['status'] == 'ok' and native['count'] == native['passed'] == expected
                and native['failed'] == 0, f'Unexpected native outcomes: {profile}')
        tests = native['tests']
        require(len(tests) == len({t['identity'] for t in tests}) == expected, 'Duplicate/missing native identities')
        require(all(sum(t['identity'].startswith(('tests::' if name == 'functions' else 'tests::m2::') +
                                                name + '::') for t in tests) == count
                    for name, count in groups.items()), 'Unexpected native selection')
        require(all(t['outcome'] == 'passed' and t['trapCategory'] is None and
                    not t['stdoutBase64'] and not t['stderrBase64'] for t in tests), 'Native failure/output')
        results.append(dict(profile=profile, native=native))
        print(f'PASS: {phase} {profile}: {expected} native groups', flush=True)
    require({t['identity'] for t in results[0]['native']['tests']} ==
            {t['identity'] for t in results[1]['native']['tests']}, 'Profile identities differ')
    require(all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Input changed during verification')
    require(digest(compiler) == compiler_hash, 'Compiler changed during verification')
    write(receipt, dict(schema='browniec.m2-struct-call-vm/v1', status='passed', phase=phase,
          recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
          compilerVersion=version, compilerSha256=compiler_hash,
          standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
          os=platform.platform(), lockedCheck=check, commands=commands, sourceSha256=inputs,
          results=results, limits=dict(frames=32, sharedOwners=16, payloadBytes=65536,
          aggregateArguments=8, recordBytes=128, recordBatchFuel=2048, recordArgumentFuel=43008),
          limitations=['Private verified IR CALL execution only; source record parameters remain gated.',
                       'Native images are tool-managed; no guest CLI artifact was built.',
                       'Core and regressions are separate runs, not a combined aggregate invocation.',
                       'Other CLI/native matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.']))
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
