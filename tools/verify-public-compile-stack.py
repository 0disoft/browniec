"""Verify public compilation stack containment, original depth fixtures and admission parity."""
import importlib.util
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('bottom', ROOT / 'tools/verify-value-bottom.py')
bottom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bottom)
bottom.DESCRIPTION = __doc__
bottom.DIRECTORY = 'build/public-compile-stack'
bottom.EXTRA_INPUTS = {'tools/verify-public-compile-stack.py'}
bottom.MODULES = {
    'array_expression_projections': ['combined_group_index_and_32_deep_captured_call_bounds_stay_original'],
    'record_expression_projections': ['grouping_and_32_deep_calls_keep_original_bounded_parser_stack'],
    'public_compile_stack': None,
    'public_program': [
        'lifetime_drop_write_and_exclusive_violations_fail_before_publication'],
}
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    runner = bottom.runner
    runner.MODULES = bottom.MODULES
    expected = runner.discover()
    if args.discover:
        print(json.dumps(sorted(expected), indent=2))
        raise SystemExit(0)
    sources = {}
    for path in (ROOT / 'src').glob('*.fy'):
        source = path.read_text(encoding='utf-8')
        module = re.search(r'\bmodule\s+([\w:]+)\s*;', source)
        assert module and module[1] not in sources, path
        sources[module[1]] = (path, source)
    def imports(source):
        return re.findall(r'\bimport\s+([\w:]+)\s+as\s+\w+\s*;', source)
    tests = [ROOT / f'tests/m2/{name}.fy' for name in bottom.MODULES]
    pending = ['main'] + [name for path in tests for name in imports(path.read_text(encoding='utf-8'))]
    selected = set()
    while pending:
        name = pending.pop()
        if name.startswith('std::') or name in selected:
            continue
        assert name in sources, name
        selected.add(name)
        pending.extend(imports(sources[name][1]))
    paths = sorted([sources[name][0] for name in selected] + tests + [ROOT / name for name in
        ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
         'tools/verify-value-bottom.py', 'tools/verify-public-compile-stack.py']])
    output = ROOT / bottom.DIRECTORY
    output.mkdir(parents=True, exist_ok=True)
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if runner.os.name == 'nt' else 'fairyc')
    assert runner.digest(compiler) == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][
        'windows/amd64' if runner.os.name == 'nt' else 'linux/amd64']['sha256']
    original_hashes = {path.relative_to(ROOT).as_posix(): runner.digest(path) for path in paths}
    with tempfile.TemporaryDirectory(dir=output, prefix='closure-') as temporary:
        mirror = Path(temporary)
        assert mirror.resolve().parent == output.resolve()
        for path in paths + [compiler]:
            destination = mirror / path.relative_to(ROOT)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, destination)
        assert all(runner.digest(mirror / name) == digest for name, digest in original_hashes.items())
        # The source set is smaller, so generate its own lock. Never substitute
        # this identity for the full repository lock or change production bytes.
        checked = subprocess.run([str(compiler), 'check'], cwd=mirror, capture_output=True, timeout=900)
        (output / 'scope-check.txt').write_bytes(checked.stdout)
        assert checked.returncode == 0 and not checked.stderr, checked.stderr
        shutil.copyfile(mirror / 'fairy.lock', output / 'scoped.fairy.lock')
        inputs = [dict(path=path.relative_to(ROOT).as_posix(),
                       sha256=runner.digest(mirror / path.relative_to(ROOT))) for path in paths]
        runner.ROOT = mirror
        profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
        # Keep MSVC's unchanged host timeout; do not overlap profile builds.
        for profile in profiles:
            runner.verify_profile(profile, False, expected, inputs, 'native', str(output))
        assert all(runner.digest(ROOT / name) == digest for name, digest in original_hashes.items())
        assert mirror.resolve().parent == output.resolve()
        runner.write(output / 'scope.json', dict(schema='browniec.public-compile-stack-scope/v1',
            status='passed', method='Transitive imports of unchanged production main and selected tests',
            productionModules=len(selected), repositoryProductionModules=len(sources),
            productionPaths=sorted(sources[name][0].relative_to(ROOT).as_posix() for name in selected),
            fullRootLockSha256=original_hashes['fairy.lock'],
            scopedLockSha256=runner.digest(output / 'scoped.fairy.lock'),
            productionBytesMatch=True, originalTestsUnchanged=True, profiles=profiles))
