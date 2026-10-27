"""Verify the nominal record-result signature foundation and focused regressions."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {'signatures': {'struct_result_signatures': 6, 'struct_parameter_signatures': 6,
                         'array_result_signatures': 6, 'functions': 4}}


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
    output = ROOT / ('build/m2-struct-result-signatures-' + phase)
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
                                   'tools/verify-m2-struct-result-signatures.py'])
    # Hash both phase selections so later stepwise evidence can prove identical
    # runtime, fixture, harness and SDK inputs across the implementation commit.
    paths.update(ROOT / ('tests/' + ('' if name == 'functions' else 'm2/') + name + '.fy')
                 for groups in GROUPS.values() for name in groups)
    paths.update(ROOT.glob('tests/**/*.fy'))
    paths.update(ROOT.glob('tools/*.py'))
    paths.update(ROOT.glob('examples/*.brc'))
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
        build_command = [compiler, 'build', '--locked']
        if profile == 'release': build_command.append('--release')
        build = run(build_command)
        exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
        exe_hash = digest(exe)
        selections = ['struct-result-signatures', 'struct-parameter-signatures',
                      'struct-parameters-source', 'array-result-signatures', 'm1']
        cli = []
        for selection in selections:
            script = 'check-m1-cli.py' if selection == 'm1' else 'check-m2-' + selection + '.py'
            print(run([os.sys.executable, '-B', ROOT / 'tools' / script, '--exe', exe, '--profile', profile]), flush=True)
            report = ROOT / ('build/m1' if selection == 'm1' else 'build/m2-' + selection) / profile / 'cli-receipt.json'
            cases = json.loads(report.read_text(encoding='utf-8'))
            require(cases['status'] == 'passed' and cases['exeSha256'] == exe_hash and cases['count'] == len(cases['cases']), 'CLI result/artifact mismatch')
            cli.append(cases)
        results.append(dict(profile=profile, native=native, build=build, exeSha256=exe_hash, cli=cli))
        print(f'PASS: {phase} {profile}: {expected} native groups', flush=True)
    require({t['identity'] for t in results[0]['native']['tests']} ==
            {t['identity'] for t in results[1]['native']['tests']}, 'Profile identities differ')
    require(all(digest(ROOT / p['path']) == p['sha256'] for p in inputs), 'Input changed during verification')
    require(digest(compiler) == compiler_hash, 'Compiler changed during verification')
    write(receipt, dict(schema='browniec.m2-struct-result-signatures/v1', status='passed', phase=phase,
          recordedAt=datetime.now(timezone.utc).isoformat(), baselineCommit=baseline,
          compilerVersion=version, compilerSha256=compiler_hash,
          standardLibraryLockIdentity=[p for p in lock['packages'] if p['role'] != 'root'],
          os=platform.platform(), lockedCheck=check, commands=commands, sourceSha256=inputs,
          results=results, limits=dict(functions=16, nominalRecords=32, addedSignatureBytes=16),
          limitations=['Signature-only nominal record results. Compiler gate precedes IR/catalog/body lowering; record returns remain unavailable.',
                       'No IR, VM, opcode, Fuel or version capability change. Existing record parameters and array results remain supported.',
                       'Other CLI/native matrices, M0, Linux, isolation, DLL, packaging, allocation instrumentation and performance were not run.']))
    print('PASS: ' + receipt.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main()
