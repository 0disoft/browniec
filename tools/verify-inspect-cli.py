"""Build public IR inspection in locked mirrors and exercise tool-free native CLI."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
sha = lambda data: hashlib.sha256(data).hexdigest()


def verify(profile, inputs):
    out = ROOT / 'build/inspect-cli' / profile
    out.mkdir(parents=True, exist_ok=True)
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_sha = sha(compiler.read_bytes())
    assert compiler_sha == json.loads((ROOT / 'toolchain.json').read_bytes())['platforms'][target]['sha256']
    assert not any(k.upper() in {'CL', '_CL_', 'LINK'} for k in os.environ)
    result = dict(schema='browniec.inspect-cli-verification/v1', status='incomplete', profile=profile,
                  recordedAt=datetime.now(timezone.utc).isoformat(), compilerSha256=compiler_sha,
                  inputs=inputs, commands=[], cases=[], nativeOverrides=False)

    def save():
        (out / 'receipt.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')

    def run(argv, name, cwd, env=None, expected=0, timeout=900):
        argv = list(map(str, argv))
        completed = subprocess.run(argv, cwd=cwd, env=env, capture_output=True, timeout=timeout)
        (out / (name + '.stdout')).write_bytes(completed.stdout)
        (out / (name + '.stderr')).write_bytes(completed.stderr)
        result['commands'].append(dict(argv=argv, exit=completed.returncode,
                                       stdoutSha256=sha(completed.stdout), stderrSha256=sha(completed.stderr)))
        save()
        assert completed.returncode == expected, (argv, completed.returncode, completed.stderr[-2000:])
        return completed

    save()
    with tempfile.TemporaryDirectory(dir=out, prefix='native-') as temporary:
        mirror = Path(temporary)
        for row in inputs:
            if row['path'].startswith('src/') or row['path'] in ['fairy.toml', 'fairy.lock']:
                destination = mirror / row['path']
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / row['path'], destination)
                assert sha(destination.read_bytes()) == row['sha256']
        run([compiler, 'check', '--locked'], 'check', mirror)
        run([compiler, 'build', '--locked'] + (['--release'] if profile == 'release' else []), 'build', mirror)
        exe = out / ('browniec.exe' if os.name == 'nt' else 'browniec')
        shutil.copyfile(mirror / 'build' / exe.name, exe)
        if os.name != 'nt':
            exe.chmod(exe.stat().st_mode | 0o111)
        empty = mirror / 'empty-tools'
        empty.mkdir()
        env = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
        env.update(PATH=str(empty), TEMP=str(empty), TMP=str(empty))

        def invoke(source, extra=('--ir', '--json'), expected=0, kind=None, command='inspect'):
            path = out / f'case-{len(result["cases"]):02}.brc'
            path.write_bytes(source.encode('utf-8') if isinstance(source, str) else source)
            done = run([exe, command, path, *extra], f'case-{len(result["cases"]):02}', empty, env, expected, 20)
            assert len(done.stdout) <= 131072
            json_mode = '--json' in extra
            data = json.loads(done.stdout) if json_mode else None
            if json_mode:
                assert not done.stderr
                if command == 'inspect':
                    assert data['schema'] == 'browniec.ir/v1' and data['command'] == command
                    assert data['status'] == ('error' if expected else 'inspected')
                else:
                    assert data['schema'] == 'browniec.result/v1' and data['command'] == command
                if expected:
                    assert data['error']['kind'] == kind
                    assert 'instructions' not in data
                elif command == 'inspect':
                    assert data['error'] is None and data['format'] == 'brownie.private-instructions/1'
                    assert len(data['instructions']) == data['instruction_count'] <= 256
                    assert len(data['register_types']) == data['register_count'] <= 128
                    assert 0 <= data['entry'] < len(data['functions']) <= 16
                    assert all(row['pc'] == pc and len(row['bytes']) == 8 and
                               all(type(n) is int and 0 <= n <= 255 for n in row['bytes']) and
                               0 <= row['byte_offset'] <= len(path.read_bytes())
                               for pc, row in enumerate(data['instructions']))
            result['cases'].append(dict(sourceSha256=sha(path.read_bytes()), argv=list(extra),
                                        command=command, exit=expected, result=data,
                                        stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr)))
            return data, done.stdout

        scalar = 'module main;fn i32 main(){return 42;}'
        data, _ = invoke(scalar)
        assert data['constants'] == [42] and data['instruction_count'] == 2
        assert [row['bytes'][0] for row in data['instructions']] == [1, 8]
        _, text = invoke(scalar, ('--ir',))
        assert text.startswith(b'Brownie C private IR diagnostics; not reloadable\n') and b'pc=1' in text
        data, _ = invoke('module main;fn i32 main(){return 1/0;}')
        assert 5 in [row['bytes'][0] for row in data['instructions']]
        invoke('module main;fn i32 main(){while(true){}return 42;}')
        data, _ = invoke('module main;fn i32 main(){let i32[2] a=[20,22];return a[0]+a[1];}')
        assert data['profile'].startswith('brownie.m2-array')
        data, _ = invoke('module main;struct P{i32 x;i32 y;}fn i32 main(){let P p=P{.x=20,.y=22};return p.x+p.y;}')
        assert data['profile'].startswith('brownie.m2-struct')
        literal = 'module main;fn i32 main(){let ref u8[] a=b"abc";if(a.len==3){return 42;}return 0;}'
        data, _ = invoke(literal)
        assert data['profile'] == 'brownie.m2-reference/1' and data['literal_bytes'] == 3
        nested = 'id(' * 32 + '42' + ')' * 32
        prefix = 'module main;fn i32 id(i32 n){return n;}fn i32 main(){'
        invoke(prefix + 'if(true){' * 32 + 'return ' + nested + ';' + '}' * 32 + 'return 0;}')
        for extra in [('--json',), ('--json', '--ir', '--ir'), ('--json', '--ir', '--json'),
                      ('--json', '--ir', '--fuel', '1'), ('--json', '--ir', '--input', 'x')]:
            invoke(scalar, extra, 2, 'usage')
        invoke(scalar, ('--json', '--ir', '--isolated'), 4, 'unavailable')
        invoke('module main;fn i32 main(){return 42}', expected=3, kind='syntax')
        invoke(b'module main;\xff', expected=3, kind='lexical')
        invoke(b' ' * 4097, expected=3, kind='compile_limit')
        invoke(scalar, ('--json',), command='check')
        data, _ = invoke(scalar, ('--json',), command='run')
        assert data['return_i32'] == 42
        version = json.loads(run([exe, '--version', '--json'], 'version', empty, env, timeout=20).stdout)
        assert version['inspect_ir'] and version['core'] and not version['embed'] and not version['restricted']
        assert version['fuel_default'] == 256 and version['fuel_limit'] == 16000000
        help_result = run([exe, '--help'], 'help', empty, env, timeout=20)
        assert b'inspect SOURCE --ir' in help_result.stdout
        result.update(artifactSha256=sha(exe.read_bytes()), version=version,
                      toolFreeRuntime=True, guestExecutionUsedForInspection=False)
    assert all(sha((ROOT / row['path']).read_bytes()) == row['sha256'] for row in inputs)
    assert sha(compiler.read_bytes()) == compiler_sha
    result.update(status='passed', casesPassed=len(result['cases']))
    save()
    print(f'PASS {profile}: {len(result["cases"])} CLI cases plus version/help', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    args = parser.parse_args()
    assert __debug__, 'Python assertions must remain enabled'
    paths = sorted({p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.fy')} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-inspect-cli.py'})
    inputs = [dict(path=p, sha256=sha((ROOT / p).read_bytes())) for p in paths]
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    with ThreadPoolExecutor(max_workers=len(profiles)) as pool:
        list(pool.map(lambda profile: verify(profile, inputs), profiles))


if __name__ == '__main__':
    main()
