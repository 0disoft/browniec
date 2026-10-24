"""Provision the reviewed native Fairy C compiler without shell dependencies."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import subprocess
import tempfile
from urllib.parse import urlsplit


class SetupError(Exception):
    pass


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def host_target(system=None, machine=None):
    system = system or platform.system()
    machine = (machine or platform.machine()).lower()
    if system not in ('Windows', 'Linux') or machine not in ('amd64', 'x86_64'):
        raise SetupError('Supported hosts are Windows/AMD64 and Linux/AMD64.')
    return ('windows' if system == 'Windows' else 'linux') + '/amd64'


def load_config(root):
    config = json.loads((root / 'toolchain.json').read_text(encoding='utf-8-sig'))
    lock = json.loads((root / 'fairy.lock').read_text(encoding='utf-8-sig'))
    if config.get('schema') != 'browniec.toolchain/v2':
        raise SetupError('Unsupported toolchain manifest.')
    compiler = config['compiler']
    if not re.fullmatch('[0-9a-f]{40}', compiler['revision']):
        raise SetupError('Invalid compiler revision.')
    expected_names = {'windows/amd64': 'fairyc.exe', 'linux/amd64': 'fairyc'}
    for target, item in config['platforms'].items():
        if target not in expected_names or item['executable'] != expected_names[target] or not re.fullmatch('[0-9a-f]{64}', item['sha256']):
            raise SetupError('Unsupported platform or invalid compiler identity.')
    std = [p for p in lock['packages'] if p['role'] == 'standard-library']
    if len(std) != 1 or lock['language'] != config['language'] or any(
        std[0][key] != value for key, value in (
            ('sdkIdentity', config['sdk']['identity']), ('version', config['sdk']['version']),
            ('runtimeAbi', config['runtimeAbi']), ('sourceDigest', config['sdk']['sourceDigest']))):
        raise SetupError('toolchain.json and fairy.lock disagree; adopt the SDK and language together.')
    recipe = config['bootstrap']
    if recipe['package'] != './cmd/fairyc' or recipe['buildFlags'] != ['-mod=readonly', '-trimpath', '-buildvcs=true']:
        raise SetupError('Unsupported bootstrap build recipe.')
    return config


def child_environment(target):
    env = os.environ.copy()
    for key in list(env):
        if key.upper().startswith('GIT_'):
            del env[key]
    env.update(GOENV='off', GOWORK='off', GOTOOLCHAIN='local', GOFLAGS='', GOEXPERIMENT='',
               CGO_ENABLED='0', GOOS=target.split('/')[0], GOARCH='amd64', GOAMD64='v1',
               GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='never', GIT_CONFIG_COUNT='0',
               GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    return env


def run(arguments, *, cwd=None, env=None, error='Command failed'):
    try:
        result = subprocess.run([str(a) for a in arguments], cwd=cwd, env=env,
                                capture_output=True, text=True, encoding='utf-8', errors='replace')
    except OSError as exc:
        raise SetupError(f'{error}: {exc.strerror}') from exc
    if result.returncode:
        raise SetupError(f'{error}: {result.stderr.strip() or result.stdout.strip()}')
    return result.stdout.strip()


def build_source(config, root, scratch, target, source_repository=None):
    env = child_environment(target)
    version = run(['go', 'env', 'GOVERSION'], env=env, error='Cannot identify Go')
    if version != config['bootstrap']['goVersion']:
        raise SetupError(f"Source bootstrap requires {config['bootstrap']['goVersion']}; install it separately or supply --compiler-file.")
    if source_repository:
        source = Path(source_repository).resolve()
        if not source.is_dir():
            raise SetupError('Source repository must be an existing local directory.')
    else:
        local = (root / config['source']['localRepository']).resolve()
        source = local if local.is_dir() else config['source']['repository']
        if isinstance(source, str):
            url = urlsplit(source)
            if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment:
                raise SetupError('Remote source must use HTTPS without embedded credentials.')
    checkout = scratch / 'source'
    template = scratch / 'empty-git-template'
    template.mkdir()
    run(['git', '-c', 'core.autocrlf=false', 'init', '--quiet', f'--template={template}', checkout], env=env,
        error='Cannot initialize isolated compiler source')
    for key, value in [('core.autocrlf', 'false'), ('core.longpaths', 'true')]:
        run(['git', '-C', checkout, 'config', key, value], env=env, error='Cannot configure isolated compiler source')
    run(['git', '-C', checkout, 'fetch', '--quiet', '--no-tags', '--depth=1', '--', source, config['compiler']['revision']],
        env=env, error='Cannot fetch the selected compiler commit')
    run(['git', '-C', checkout, 'checkout', '--quiet', '--detach', 'FETCH_HEAD'], env=env,
        error='Cannot check out the selected compiler commit')
    revision = run(['git', '-C', checkout, 'rev-parse', 'HEAD'], env=env)
    dirty = run(['git', '-C', checkout, 'status', '--porcelain', '--untracked-files=all'], env=env)
    if revision != config['compiler']['revision'] or dirty:
        raise SetupError('Compiler source identity mismatch or dirty isolated checkout.')
    candidate = scratch / config['platforms'][target]['executable']
    run(['go', 'build', *config['bootstrap']['buildFlags'], '-o', candidate, config['bootstrap']['package']],
        cwd=checkout, env=env, error='Compiler source build failed')
    return candidate


def validate_compiler(path, config, target):
    if digest(path) != config['platforms'][target]['sha256']:
        raise SetupError('Compiler SHA-256 mismatch; no executable was run or installed.')
    if target.startswith('linux/'):
        path.chmod(0o755)
    lines = run([path, '--version'], error='Cannot identify the verified compiler').splitlines()
    expected = [f"compiler: {config['compiler']['version']}",
                f"sdk: {config['sdk']['identity']} {config['sdk']['version']}",
                f"language: {config['language']}", f"runtime: {config['runtimeAbi']}",
                f"revision: {config['compiler']['revision']}", 'modified: false']
    for line in expected:
        if line not in lines:
            raise SetupError(f'Compiler identity mismatch: {line}')
    return lines


def write_receipt(path, data):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    os.replace(temporary, path)


def remove_scratch(path, parent, prefix):
    if path.is_symlink() or path.resolve().parent != parent.resolve() or not re.fullmatch(re.escape(prefix) + r'[a-zA-Z0-9_-]+', path.name):
        raise SetupError('Refusing cleanup outside the owned scratch directory.')

    def writable_retry(function, filename, error):
        if not isinstance(error[1], PermissionError):
            raise error[1]
        # Git marks packed objects read-only on Windows.
        os.chmod(filename, stat.S_IREAD | stat.S_IWRITE)
        function(filename)

    shutil.rmtree(path, onerror=writable_retry)


def setup(root, compiler_file=None, source_repository=None):
    root = Path(root).resolve()
    if compiler_file and source_repository:
        raise SetupError('Choose --compiler-file or --source-repository, not both.')
    config = load_config(root)
    target = host_target()
    if target not in config['platforms']:
        raise SetupError(f'No reviewed compiler identity for {target}.')
    output = (root / 'build/toolchain').resolve()
    if not output.is_relative_to(root):
        raise SetupError('Toolchain output must stay inside the repository.')
    output.mkdir(parents=True, exist_ok=True)
    receipt_path = output / 'setup-receipt.json'
    write_receipt(receipt_path, dict(status='incomplete'))
    destination = output / config['platforms'][target]['executable']
    scratch = None
    try:
        mode = 'existing'
        if not compiler_file and not source_repository and destination.exists():
            version = validate_compiler(destination, config, target)
        else:
            scratch = Path(tempfile.mkdtemp(prefix='.setup-', dir=output))
            if compiler_file:
                mode = 'file'
                candidate = scratch / config['platforms'][target]['executable']
                shutil.copyfile(Path(compiler_file).resolve(), candidate)
            else:
                mode = 'source-build'
                candidate = build_source(config, root, scratch, target, source_repository)
            version = validate_compiler(candidate, config, target)
            os.replace(candidate, destination)
        receipt = dict(schema='browniec.toolchain-setup/v2', status='passed', mode=mode, platform=target,
                       recordedAt=datetime.now(timezone.utc).isoformat(),
                       manifestSha256=digest(root / 'toolchain.json'), compilerSha256=digest(destination),
                       compilerVersion=version, artifact=destination.relative_to(root).as_posix())
        write_receipt(receipt_path, receipt)
        return receipt
    except (SetupError, OSError):
        # Diagnostics may contain private checkout paths. Keep them on stderr.
        write_receipt(receipt_path, dict(status='failed'))
        raise
    finally:
        if scratch is not None:
            remove_scratch(scratch, output, '.setup-')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    choice = parser.add_mutually_exclusive_group()
    choice.add_argument('--compiler-file')
    choice.add_argument('--source-repository')
    args = parser.parse_args()
    try:
        receipt = setup(Path(__file__).resolve().parent.parent, args.compiler_file, args.source_repository)
    except (SetupError, OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, f'toolchain setup: {exc}\n')
    print(f"PASS: {receipt['mode']}; {receipt['artifact']}")


if __name__ == '__main__':
    main()
