"""Build and run the actual Windows anchored source collector (private C01 primitive)."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
FEATURES = ['native/anchored_sources.c', 'native/anchored_sources.h',
            'tests/native/anchored_sources_host.c', 'tools/verify-anchored-sources.py',
            'docs/engineering/anchored-sources.md', 'src/project_names.fy', 'src/source_snapshot.fy',
            'tools/verify-runtime-store-probe.py']
GRAMMAR_SHA256 = 'e59954d2f1636aca1edd2cf29b87e043f47cfb3d924c08a7379bb65f53c2d9c1'
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('native_probe_tools', ROOT / 'tools/verify-runtime-store-probe.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def need(value, message):
    if not value:
        raise RuntimeError(message)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value.encode('utf-8') if isinstance(value, str) else value)


def record(path, value):
    write(path, json.dumps(value, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    args = parser.parse_args()
    need(os.name == 'nt', 'Actual Windows required')
    need(not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ), 'CL/_CL_/LINK must be absent')
    output = ROOT / 'build/anchored-sources' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output.mkdir(parents=True)
    receipt_file = output / 'receipt.json'
    receipt = dict(schema='browniec.anchored-sources-verification/v1', status='incomplete',
                   scope='Actual anchored read-only Windows snapshots; no parser/VM/Engine bindings',
                   commands=[], profiles=[], sourceFiles=16, sourceBytes=4096,
                   environment=dict(osVersion=sys.getwindowsversion().build, compilerOverrides=False))
    initial_lock = (ROOT / 'fairy.lock').read_bytes()

    def run(command, cwd=output, env=None):
        command = list(map(str, command))
        done = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=120)
        index = len(receipt['commands'])
        stdout, stderr = f'logs/{index:02d}.stdout', f'logs/{index:02d}.stderr'
        write(output / stdout, done.stdout)
        write(output / stderr, done.stderr)
        receipt['commands'].append(dict(argv=command, cwd=str(cwd), exit=done.returncode,
                                       stdout=stdout, stderr=stderr,
                                       stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr)))
        record(receipt_file, receipt)
        need(done.returncode == 0, f'Failed {command}: {done.stdout[-2000:]!r} {done.stderr[-2000:]!r}')
        return done.stdout

    try:
        inputs = {n: (ROOT / n).read_bytes() for n in FEATURES}
        need(all(b'\r' not in b for b in inputs.values()), 'Preserve LF')
        receipt['inputs'] = [dict(path=n, sha256=sha(b), bytes=len(b)) for n, b in inputs.items()]
        need(sha(inputs['src/project_names.fy']) == GRAMMAR_SHA256,
             'Authoritative member_path grammar changed; review the native port deliberately')
        snapshot = inputs['src/source_snapshot.fy'].decode()
        for name, expected in [('source_limit', 4096), ('file_limit', 16)]:
            found = re.search(r'pub fn usize ' + name + r'\(\)\{return (\d+);\}', snapshot)
            need(found is not None and int(found[1]) == expected, 'Current snapshot bound changed: ' + name)
        cl, env, receipt['msvc'] = helper.native_environment(run)
        empty = output / 'empty-tools'
        empty.mkdir()
        runtime = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
        runtime['PATH'] = str(empty)
        for profile in (['development', 'release'] if args.profile == 'all' else [args.profile]):
            folder = output / profile
            folder.mkdir()
            objects = []
            # Production build independently proves all test hooks are absent.
            flags = ['/nologo', '/TC', '/std:c11', '/MT', '/W4', '/WX',
                     '/Od' if profile == 'development' else '/O2', '/I' + str(ROOT / 'native')]
            production = folder / 'anchored_sources-production.obj'
            run([cl, *flags, '/c', ROOT / 'native/anchored_sources.c', '/Fo' + str(production)], env=env)
            symbols = run([cl.parent / 'dumpbin.exe', '/symbols', production], env=env)
            need(b'bc_as_test_' not in symbols, 'Test hooks leaked into production')
            for source, name in [('native/anchored_sources.c', 'collector'), ('tests/native/anchored_sources_host.c', 'host')]:
                obj = folder / (name + '.obj')
                run([cl, *flags, '/DBC_ANCHORED_SOURCES_TEST', '/c', ROOT / source, '/Fo' + str(obj)], env=env)
                objects.append(obj)
            exe = folder / 'anchored-sources-host.exe'
            run([cl, '/nologo', *objects, 'ntdll.lib', '/Fe' + str(exe), '/link', '/INCREMENTAL:NO', '/Brepro'], env=env)
            fixtures = folder / 'fixtures'
            stdout = run([exe, fixtures], env=runtime).decode('utf-8')
            need(stdout.count('PASS ') == 5 and 'RESULT groups=5 live_allocations=0' in stdout,
                 'Exact native group results required')
            need(receipt['commands'][-1]['stderrSha256'] == sha(b''), 'Unexpected native stderr')
            # Windows rmtree does not follow directory junctions. The final target
            # itself is checked explicitly within this run before recursive delete.
            need(fixtures.resolve().parent == folder.resolve() and not fixtures.is_symlink(), 'Unsafe fixture cleanup target')
            shutil.rmtree(fixtures)
            need(not fixtures.exists(), 'OS fixture cleanup incomplete')
            receipt['profiles'].append(dict(profile=profile, nativeGroups=5, result=stdout.splitlines(),
                host=helper.image(exe), objects=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p.read_bytes()))
                                               for p in [production, *objects]],
                fixtureCleanup=True, productionTestHooksAbsent=True))
            print(f'PASS {profile}: 5 actual OS groups, junction/symlink/identity/limits/interleavings/cleanup', flush=True)
        need((ROOT / 'fairy.lock').read_bytes() == initial_lock, 'Root lock changed')
        need(all((ROOT / n).read_bytes() == b for n, b in inputs.items()), 'Input changed while running')
        receipt.update(status='passed', rootLockUnchanged=True, defaultStackVerified=True,
                       noGuestBindings=True, skipped=['non-NTFS/network/other OS support', 'hostile kernel/filter drivers',
                       'global atomic multi-file transactions', 'broad compiler/VM regressions'])
    except Exception as error:
        receipt.update(status='failed', error=str(error))
        raise
    finally:
        record(receipt_file, receipt)
        print('Receipt: ' + str(receipt_file), flush=True)


if __name__ == '__main__':
    main()
