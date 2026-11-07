"""Check composed loop owners, catalog/wire tags, depth and optional public CLI."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('bottom_suite', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/parallel-integration'
suite.EXTRA_INPUTS = {'tools/verify-parallel-integration.py'}
suite.MODULES = {
    'value_fresh_loop_owners_source': ['fresh_payload_ranges_and_classic_continue_keep_concrete_bytes'],
    'value_fresh_loop_owners_runtime': ['pinned_move_keeps_serial_token_range_aliases_price_and_failure_drain'],
    'host_catalog': ['admitted_catalog_tags_compose_with_real_wire_decoders'],
    'value_source_control': ['admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
}


def cli_smoke():
    out = ROOT / 'build/parallel-integration/release'
    native = json.loads((out / 'receipt.json').read_bytes())
    assert native['status'] == 'passed'
    sha = lambda data: hashlib.sha256(data).hexdigest()
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    assert sha(compiler.read_bytes()) == native['compilerSha256']
    built = subprocess.run([compiler, 'build', '--release', '--locked'], cwd=ROOT, capture_output=True, timeout=900)
    (out / 'cli-build.stdout').write_bytes(built.stdout)
    (out / 'cli-build.stderr').write_bytes(built.stderr)
    assert built.returncode == 0 and not built.stderr, built.stderr[-3000:]
    exe = ROOT / 'build' / ('browniec.exe' if os.name == 'nt' else 'browniec')
    empty = out / 'empty-tools'
    empty.mkdir(exist_ok=True)
    assert not any(empty.iterdir())
    env = {k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ}
    env.update(PATH=str(empty), TEMP=str(empty), TMP=str(empty))
    cases = [
        ('module main;fn i32 main(){return 42;}', 'inspect', ['--ir', '--json']),
        ('module main;fn i32 main(){let ref u8[] a=b"abc";if(a.len==3){return 42;}return 0;}', 'inspect', ['--ir', '--json']),
        ('module main;fn i32 main(){let i32[2] a=[20,22];return a[0]+a[1];}', 'run', ['--fuel', '1000000', '--json']),
    ]
    rows = []
    for source, command, options in cases:
        path = out / f'cli-composed-{len(rows)}.brc'
        path.write_bytes(source.encode('utf-8'))
        argv = list(map(str, [exe, command, path, *options]))
        done = subprocess.run(argv, cwd=empty, env=env, capture_output=True, timeout=20)
        assert done.returncode == 0 and not done.stderr
        data = json.loads(done.stdout)
        assert data['command'] == command and data['error'] is None
        assert data['status'] == ('inspected' if command == 'inspect' else 'completed')
        if command == 'run':
            assert data['return_i32'] == 42
        rows.append(dict(argv=argv, sourceSha256=sha(path.read_bytes()), result=data,
                         stdoutSha256=sha(done.stdout), stderrSha256=sha(done.stderr)))
    assert all(sha((ROOT / row['path']).read_bytes()) == row['sha256'] for row in native['inputs'])
    result = dict(schema='browniec.parallel-cli-smoke/v1', status='passed',
                  compilerSha256=native['compilerSha256'], artifactSha256=sha(exe.read_bytes()),
                  buildCommand=list(map(str, [compiler, 'build', '--release', '--locked'])),
                  buildStdoutSha256=sha(built.stdout), buildStderrSha256=sha(built.stderr),
                  toolFreeRuntime=True, nativeOverrides=False, inputs=native['inputs'], cases=rows)
    (out / 'cli-receipt.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('PASS release: 3 composed public CLI cases', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='release')
    parser.add_argument('--cli-smoke', action='store_true')
    args = parser.parse_args()
    if args.cli_smoke and args.profile != 'release':
        parser.error('--cli-smoke verifies the final release build; select --profile release')
    sys.argv[1:] = ['--profile', args.profile]
    suite.main()
    if args.cli_smoke:
        cli_smoke()
