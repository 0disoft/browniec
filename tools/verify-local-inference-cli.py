"""Build the native CLI and check scalar local inference without runtime tools."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    args = parser.parse_args()
    out = ROOT / 'build/local-inference-cli' / args.profile
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_hash = sha(compiler)
    assert compiler_hash == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    production = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy'))
    assert all(b'\r' not in (ROOT / p).read_bytes() for p in production)
    paths = sorted(production + ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-local-inference-cli.py'])
    inputs = [dict(path=p, sha256=sha(ROOT / p)) for p in paths]
    captured = datetime.now(timezone.utc).isoformat()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    command = [str(compiler), 'build', '--locked']
    if args.profile == 'release':
        command.append('--release')
    built = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=1200)
    assert built.returncode == 0, (built.returncode, built.stdout, built.stderr)
    name = 'browniec.exe' if os.name == 'nt' else 'browniec'
    exe = out / name
    shutil.copy2(ROOT / 'build' / name, exe)
    binary_hash = sha(exe)
    empty = out / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    scalar = 'brownie.m1-scalar/1'
    reference = 'brownie.m2-reference/1'
    simple = b'module main;fn i32 main(){let n=42;return n;}'
    literal = b'module main;fn i32 main(){let n=b"*"[0];return n as i32;}'
    cases = [
        ('check', simple, 'check', None, None, None, scalar),
        ('run', simple, 'run', 42, None, None, scalar),
        ('mutable', b'module main;fn i32 main(){var n=40;n=n+2;return n;}', 'run', 42, None, None, scalar),
        ('wide', b'module main;fn i64 big(){return -9223372036854775808;}fn i32 main(){let n=big();if(n==-9223372036854775808){return 42;}return 0;}', 'run', 42, None, None, scalar),
        ('for', b'module main;fn i32 main(){var n=0;for(var i=0;i<4;i=i+1){n=n+i;}return n+36;}', 'run', 42, None, None, scalar),
        ('self', b'module main;fn i32 main(){let n=n;return n;}', 'check', None, 'type', None, scalar),
        ('changed-type', b'module main;fn i32 main(){var n=1;n=true;return n;}', 'run', None, 'type', None, scalar),
        ('ambiguous', b'module main;fn i32 main(){let n=.none;return 0;}', 'check', None, 'type', None, scalar),
        ('exact-fuel', simple, 'run', 42, None, 2, scalar),
        ('short-fuel', simple, 'run', None, 'fuel', 1, scalar),
        ('retained-run', literal, 'run', 42, None, 16000000, reference),
        ('retained-check', literal, 'check', None, None, None, reference),
    ]
    results = []
    for identity, source, mode, expected, error, fuel, profile in cases:
        fixture = out / (identity + '.brc')
        fixture.write_bytes(source)
        argv = [mode, str(fixture), '--json'] + ([] if fuel is None else ['--fuel', str(fuel)])
        ran = subprocess.run([str(exe), *argv], cwd=empty, env=env, capture_output=True, timeout=15)
        expected_exit = 0 if error is None else (5 if error == 'fuel' else 3)
        assert ran.returncode == expected_exit and not ran.stderr, (identity, ran.returncode, ran.stdout, ran.stderr)
        result = json.loads(ran.stdout)
        assert set(result) == {'schema', 'profile', 'command', 'status', 'return_i32', 'error'}, (identity, result)
        assert result['schema'] == 'browniec.result/v1' and result['command'] == mode and result['profile'] == profile, (identity, result)
        assert result['return_i32'] == expected, (identity, result)
        assert result['status'] == ('error' if error else 'completed' if mode == 'run' else 'checked'), (identity, result)
        if error:
            assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(source), (identity, result)
        else:
            assert result['error'] is None, (identity, result)
        recorded = [mode, fixture.relative_to(ROOT).as_posix(), '--json'] + ([] if fuel is None else ['--fuel', str(fuel)])
        results.append(dict(case=identity, sourceSha256=hashlib.sha256(source).hexdigest(), command=recorded,
                            exitCode=ran.returncode, result=result))
    assert all(sha(ROOT / i['path']) == i['sha256'] for i in inputs)
    assert sha(compiler) == compiler_hash and sha(exe) == binary_hash
    data = dict(schema='browniec.local-inference-cli/v1', status='passed', profile=args.profile,
                startingHead=head, inputSnapshotCapturedAt=captured, inputs=inputs, compilerSha256=compiler_hash,
                compilerVersion=subprocess.check_output([str(compiler), '--version'], text=True).strip(),
                buildCommand=[compiler.relative_to(ROOT).as_posix(), *command[1:]],
                artifact=dict(path=exe.relative_to(ROOT).as_posix(), sha256=binary_hash),
                emptyRuntimeToolPath=True, cases=results, nativeOverrides=False, historicalResultReuse=False)
    receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'PASS {args.profile}: {len(results)} CLI cases; {len(inputs)} matching inputs', flush=True)


if __name__ == '__main__':
    main()
