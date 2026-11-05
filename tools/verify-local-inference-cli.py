"""Build the native CLI and check local inference without runtime tools."""
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
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--aggregate', action='store_true', help='add owned aggregate inference cases')
    selection.add_argument('--references', action='store_true', help='add reference and text inference cases')
    args = parser.parse_args()
    suite = 'reference' if args.references else 'aggregate' if args.aggregate else 'local'
    out = ROOT / ('build/' + suite + '-inference-cli') / args.profile
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
    if args.aggregate:
        array_read = 'brownie.m2-array-read/1'
        array_copy = 'brownie.m2-array-copy/1'
        record_read = 'brownie.m2-struct-read/1'
        record_copy = 'brownie.m2-struct-copy/1'
        nested = 'brownie.m2-struct-nested/1'
        cases += [
            ('array', b'module main;fn i32 main(){let a=[21;2];return a[0]+a[1];}', 'run', 42, None, 16000000, array_read),
            ('array-copy', b'module main;fn i32 main(){var a=[21;2];let b=a;a[0]=0;return b[0]+b[1];}', 'run', 42, None, 16000000, array_copy),
            ('array-call', b'module main;fn i32[2] make(){return [21;2];}fn i32 main(){let a=make();return a[0]+a[1];}', 'run', 42, None, 16000000, array_read),
            ('record', b'module main;struct P{i32 x;}fn i32 main(){let p=P{.x=42};return p.x;}', 'run', 42, None, 16000000, record_read),
            ('record-copy', b'module main;struct P{i32 x;}fn i32 main(){let p=P{.x=42};var q=p;q.x=0;return p.x+q.x;}', 'run', 42, None, 16000000, record_copy),
            ('call-child', b'module main;struct P{i32 x;}struct Box{P inner;}fn Box make(){return Box{.inner=P{.x=42}};}fn i32 main(){let p=make().inner;return p.x;}', 'run', 42, None, 16000000, nested),
            ('array-projection', b'module main;fn i32[1] make(){return [42;1];}fn i32 main(){let n=make()[0];return n;}', 'run', 42, None, 16000000, array_read),
            ('record-projection', b'module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){let n=make().x;return n;}', 'run', 42, None, 16000000, record_read),
            ('early-array', b'module main;fn i32[1] take(i32[1] a){return a;}fn i32 main(){let Option<i32> o=.none;let a=take([switch(o){case .some(v):{v}case .none:{return 42;}};1]);return a[0];}', 'run', 42, None, 16000000, array_read),
            ('array-shape-error', b'module main;fn i32 main(){var a=[1;2];a=[1;3];return 0;}', 'check', None, 'type', None, scalar),
            ('array-zero', b'module main;fn i32 main(){let a=[1;0];return 0;}', 'check', None, 'type', None, scalar),
            ('retained-array', b'module main;fn i32 main(){let ref u8[] marker=b"*";let a=[21;2];return a[0]+a[1];}', 'run', 42, None, 16000000, reference),
        ]
    if args.references:
        shared = b'module main;fn i32 main(){let a=b"*";let alias=a;return alias[0] as i32;}'
        returned = b'module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let p=id(ref [42;3]);let alias=p[1..];return alias[1] as i32;}'
        cases += [
            ('byte-alias-check', shared, 'check', None, None, None, reference),
            ('byte-alias-run', shared, 'run', 42, None, 16000000, reference),
            ('text', 'module main;fn i32 main(){let t="한";let alias=ref t;let b=text::bytes(alias);if(b.len==3){return b[0] as i32;}return 0;}'.encode(), 'run', 237, None, 16000000, reference),
            ('grouped', b'module main;fn i32 main(){let p=(text::bytes("*"))[..];let alias=(ref p);return alias[0] as i32;}', 'run', 42, None, 16000000, reference),
            ('scalar-projections', b'module main;fn i32 main(){let p=b"*";let n=(p[0]);let len=p.len;if(len==1){return n as i32;}return 0;}', 'run', 42, None, 16000000, reference),
            ('returned-check', returned, 'check', None, None, None, reference),
            ('returned-run', returned, 'run', 42, None, 16000000, reference),
            ('returned-early-exit', b'module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;let p=id(ref [42;2])[..switch(o){case .some(v):{1}case .none:{return 42;}}];return 0;}', 'run', 42, None, 16000000, reference),
            ('shared-root', b'module main;fn i32 main(){let a=[42;1];let p=ref a;let q=p;return q[0];}', 'run', 42, None, 16000000, 'brownie.m2-array-read/1'),
            ('exclusive-root', b'module main;fn i32 main(){var a=[0;1];{let p=ref mut a;p[0]=42;}return a[0];}', 'run', 42, None, 16000000, 'brownie.m2-array-write/1'),
            ('exclusive-reborrow', b'module main;fn i32 main(){var a=[0;1];{let p=ref mut a;{let q=ref mut p;q[0]=40;}p[0]=p[0]+2;}return a[0];}', 'run', 42, None, 16000000, 'brownie.m2-array-write/1'),
            ('mutable-view-error', b'module main;fn i32 main(){var p=b"*";return 0;}', 'check', None, 'type', None, scalar),
            ('mutable-literal-error', b'module main;fn i32 main(){let p=ref mut b"*";return 0;}', 'check', None, 'type', None, scalar),
            ('self-reference-error', b'module main;fn i32 main(){let p=ref p;return 0;}', 'check', None, 'type', None, scalar),
            ('borrow-conflict-error', b'module main;fn i32 main(){var a=[42;1];let p=ref a;let q=ref mut a;return p[0];}', 'check', None, 'verification', None, 'brownie.m2-array-write/1'),
            ('selected-owner-error', b'module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let p=id(ref a);let q=p;a[0]=0;return q[0] as i32;}', 'check', None, 'verification', None, scalar),
        ]
        native = b'module main;fn i32 main(){var i32[1] a=[0;1];{let p=ref mut a;p[0]=42;}let p=ref a;let q=p;return q[0];}'
        cases += [('reference-exact-fuel', native, 'run', 42, None, 286935, 'brownie.m2-array-write/1'),
                  ('reference-short-fuel', native, 'run', None, 'fuel', 286934, 'brownie.m2-array-write/1'),
                  ('alias-exact-fuel', shared, 'run', 42, None, 344121, reference),
                  ('alias-short-fuel', shared, 'run', None, 'fuel', 344120, reference)]
    results = []
    for identity, source, mode, expected, error, fuel, profile in cases:
        fixture = out / (identity + '.brc')
        fixture.write_bytes(source)
        argv = [mode, str(fixture), '--json'] + ([] if fuel is None else ['--fuel', str(fuel)])
        ran = subprocess.run([str(exe), *argv], cwd=empty, env=env, capture_output=True, timeout=15)
        expected_exit = 0 if error is None else (5 if error == 'fuel' else 6 if error == 'verification' else 3)
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
                selection='reference' if args.references else 'aggregate' if args.aggregate else 'scalar',
                startingHead=head, inputSnapshotCapturedAt=captured, inputs=inputs, compilerSha256=compiler_hash,
                compilerVersion=subprocess.check_output([str(compiler), '--version'], text=True).strip(),
                buildCommand=[compiler.relative_to(ROOT).as_posix(), *command[1:]],
                artifact=dict(path=exe.relative_to(ROOT).as_posix(), sha256=binary_hash),
                emptyRuntimeToolPath=True, cases=results, nativeOverrides=False, historicalResultReuse=False)
    receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'PASS {args.profile}: {len(results)} CLI cases; {len(inputs)} matching inputs', flush=True)


if __name__ == '__main__':
    main()
