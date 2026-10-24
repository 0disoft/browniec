"""Exercise native provisioning with isolated fixtures; no Brownie VM claims."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('toolchain_setup', ROOT / 'tools/setup-toolchain.py')
SETUP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SETUP)


def verify(source):
    config = SETUP.load_config(ROOT)
    target = SETUP.host_target()
    entry = config['platforms'][target]
    compiler = ROOT / 'build/toolchain' / entry['executable']
    SETUP.validate_compiler(compiler, config, target)
    output = (ROOT / 'build/toolchain-verification').resolve()
    if not output.is_relative_to(ROOT):
        raise SETUP.SetupError('Verification output must stay inside the repository.')
    output.mkdir(parents=True, exist_ok=True)
    receipt_path = output / 'receipt.json'
    SETUP.write_receipt(receipt_path, dict(status='incomplete'))
    scratch = Path(tempfile.mkdtemp(prefix='cases-', dir=output))
    cases = []

    def fixture(name):
        path = scratch / name
        (path / 'tools').mkdir(parents=True)
        for filename in ('toolchain.json', 'fairy.lock'):
            shutil.copyfile(ROOT / filename, path / filename)
        shutil.copyfile(ROOT / 'tools/setup-toolchain.py', path / 'tools/setup-toolchain.py')
        return path

    def run(path, arguments, success, expected):
        result = subprocess.run([sys.executable, '-B', str(path / 'tools/setup-toolchain.py'), *map(str, arguments)],
                                capture_output=True, text=True, encoding='utf-8', errors='replace')
        if (result.returncode == 0) != success or expected not in result.stdout + result.stderr:
            raise SETUP.SetupError(f'Fixture failed ({path.name}): {result.stdout}{result.stderr}')
        if list((path / 'build/toolchain').glob('.setup-*')):
            raise SETUP.SetupError('Setup left a scratch directory behind.')

    def preserved(path):
        if SETUP.digest(path / 'build/toolchain' / entry['executable']) != entry['sha256']:
            raise SETUP.SetupError('Existing compiler was replaced by a rejected candidate.')

    def changed(path, edit):
        data = json.loads((path / 'toolchain.json').read_text())
        edit(data)
        (path / 'toolchain.json').write_text(json.dumps(data), encoding='utf-8')

    try:
        installed = fixture('import')
        run(installed, ['--compiler-file', compiler], True, 'PASS: file')
        preserved(installed)
        cases.append('verified executable import')
        run(installed, [], True, 'PASS: existing')
        cases.append('existing compiler reuse')
        bad = scratch / entry['executable']
        bad.write_text('Unverified input must never execute.', encoding='utf-8')
        with patch.object(SETUP, 'run', side_effect=AssertionError('Unverified compiler executed')):
            try:
                SETUP.validate_compiler(bad, config, target)
            except SETUP.SetupError as exc:
                if 'SHA-256 mismatch' not in str(exc):
                    raise
            else:
                raise SETUP.SetupError('Corrupt candidate accepted.')
        run(installed, ['--compiler-file', bad], False, 'SHA-256 mismatch')
        preserved(installed)
        cases.append('corrupt input rejected before execution; existing compiler preserved')
        changed(installed, lambda c: c['compiler'].update(version='incorrect-version'))
        run(installed, ['--compiler-file', compiler], False, 'Compiler identity mismatch')
        preserved(installed)
        cases.append('version metadata mismatch rejected; existing compiler preserved')
        changed(installed, lambda c: c['sdk'].update(version='incorrect-sdk'))
        run(installed, [], False, 'toolchain.json and fairy.lock disagree')
        cases.append('SDK lock mismatch rejected')
        tampered = fixture('tampered')
        (tampered / 'build/toolchain').mkdir(parents=True)
        shutil.copyfile(bad, tampered / 'build/toolchain' / entry['executable'])
        run(tampered, [], False, 'SHA-256 mismatch')
        cases.append('tampered cached compiler rejected before execution')
        rebuilt = fixture('source')
        changed(rebuilt, lambda c: c['source'].update(localRepository=os.path.relpath(source, rebuilt)))
        run(rebuilt, [], True, 'PASS: source-build')
        preserved(rebuilt)
        cases.append('default exact-commit isolated source bootstrap reproduces native SHA-256')
        changed(rebuilt, lambda c: c['compiler'].update(revision='0' * 40))
        run(rebuilt, ['--source-repository', source], False, 'Cannot fetch the selected compiler commit')
        preserved(rebuilt)
        cases.append('unavailable source commit rejected; existing compiler preserved')
        if (SETUP.host_target('Windows', 'AMD64'), SETUP.host_target('Linux', 'x86_64')) != ('windows/amd64', 'linux/amd64'):
            raise SETUP.SetupError('Platform selection mismatch.')
        cases.append('Windows and Linux AMD64 platform selection (logic only)')
        for system, machine in [('Darwin', 'arm64'), ('Linux', 'aarch64'), ('Windows', 'ARM64')]:
            try:
                SETUP.host_target(system, machine)
            except SETUP.SetupError:
                pass
            else:
                raise SETUP.SetupError('Unsupported host accepted.')
        cases.append('unsupported OS and architecture rejected')
        inherited = os.environ.copy()
        with patch.dict(os.environ, {'GIT_WORK_TREE': 'untrusted', 'GIT_CONFIG_KEY_0': 'test', 'GOFLAGS': '-race'}):
            env = SETUP.child_environment(target)
            if 'GIT_WORK_TREE' in env or 'GIT_CONFIG_KEY_0' in env or env['GOFLAGS'] or env['GOTOOLCHAIN'] != 'local':
                raise SETUP.SetupError('Bootstrap environment was not sanitized.')
        if os.environ != inherited:
            raise SETUP.SetupError('Parent environment was modified.')
        cases.append('Git and Go overrides sanitized without mutating parent environment')
        receipt = dict(schema='browniec.toolchain-verification/v2', status='passed',
                       recordedAt=datetime.now(timezone.utc).isoformat(), platform=target,
                       pythonVersion=platform.python_version(), compilerSha256=entry['sha256'],
                       compilerRevision=config['compiler']['revision'], goVersion=config['bootstrap']['goVersion'],
                       cases=cases, count=len(cases), sourceSha256=[dict(path=p, sha256=SETUP.digest(ROOT / p))
                           for p in ['toolchain.json', 'fairy.lock', 'tools/setup-toolchain.py', 'tools/setup-toolchain.ps1',
                                     'tools/verify-toolchain.py', 'tools/verify-toolchain.ps1']],
                       limitations=['Native provisioning checks on the recorded host only; not a Brownie VM regression.',
                                    'Platform-selection logic does not establish Linux native execution.',
                                    'HTTPS acquisition, empty module caches and clean-machine setup were not exercised.'])
        SETUP.write_receipt(receipt_path, receipt)
        return receipt
    finally:
        SETUP.remove_scratch(scratch, output, 'cases-')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-repository', type=Path, default=ROOT.parent / 'fairyc')
    args = parser.parse_args()
    try:
        receipt = verify(args.source_repository.resolve())
    except (SETUP.SetupError, OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, f'toolchain verification: {exc}\n')
    print(f"PASS: {receipt['count']} provisioning cases; build/toolchain-verification/receipt.json")


if __name__ == '__main__':
    main()
