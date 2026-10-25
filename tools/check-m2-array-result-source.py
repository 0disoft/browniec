"""Run source array-result programs through the actual native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--exe', required=True)
parser.add_argument('--profile', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'build/m2-array-result-source' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(source, error=None, code=0, mode='run', fuel=1000000):
    data = source.encode()
    path = output / f'result-{len(rows):03}.brc'
    path.write_bytes(data)
    command = [str(exe), mode, str(path), '--json']
    if mode == 'run':
        command += ['--fuel', str(fuel)]
    ran = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=10)
    assert ran.returncode == code and not ran.stderr, (source, ran.returncode, ran.stdout, ran.stderr)
    result = json.loads(ran.stdout)
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode, result
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), result
    assert result['return_i32'] == (None if error or mode == 'check' else 42), (source, result)
    if error:
        assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(data), result
    else:
        assert result['error'] is None and result['profile'].startswith('brownie.m2-array-'), result
    rows.append(dict(case=path.stem, sourceSha256=hashlib.sha256(data).hexdigest(),
                     command=command, exit=code, result=result))


for tag, values in [('i32', ['-2147483648', '42', '2147483647']),
                    ('i64', ['-9223372036854775808', '42', '9223372036854775807']),
                    ('u8', ['0', '255']), ('u32', ['0', '4294967295']),
                    ('usize', ['0', '9223372036854775808', '18446744073709551615']),
                    ('bool', ['false', 'true'])]:
    for value in values:
        for length in [1, 4096]:
            for binding in ['let', 'var']:
                helper = f'fn {tag}[{length}] f(){{let {tag}[{length}] a=[{value};{length}];return a;}}'
                main = (f'fn i32 main(){{{binding} {tag}[{length}] a=f();'
                        f'if(a[{length-1}]=={value} && a.len=={length}){{return 42;}}return 0;}}')
                case('module main;' + (helper+main if binding == 'let' else main+helper))

# The native fixtures also exercise exact small payload ceilings, which the CLI
# does not expose. Run their sources through check/run without runtime tools.
fixtures = (root / 'tests/m2/array_result_source.fy').read_text(encoding='utf-8')
for source, _limit in re.findall(r'result\(b"([^"\n]+)",(\d+)\);', fixtures):
    case(source, mode='check')
    case(source)
for source in re.findall(r'assert\(!compiler::compile\(b"([^"\n]+)"\)\.is_ok\);', fixtures):
    case(source, error='type', code=3, mode='check')
    case(source, error='type', code=3)

basic = 'module main;fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32 main(){let i32[1] a=f();return a[0];}'
case(basic, error='fuel', code=5, fuel=0)
case(basic, fuel=65760)
case(basic, error='fuel', code=5, fuel=65759)
for count in [13, 14]:
    source = ('module main;fn i32[1] f(){let i32[1] a=[42;1];return a;}fn i32 main(){'
              + ''.join(f'let i32[1] a{i}=[0;1];' for i in range(count))
              + 'let i32[1] b=f();return b[0];}')
    case(source, error='compile_limit' if count == 14 else None, code=3 if count == 14 else 0)
for depth, error in [(30, None), (31, 'frame_limit')]:
    source = ('module main;fn i32[1] f(i32 n){if(n==0){let i32[1] a=[42;1];return a;}'
              'let i32[1] a=f(n-1);return a;}fn i32 main(){let i32[1] a=f(' + str(depth) + ');return a[0];}')
    case(source, error=error, code=5 if error else 0)
# Parameter copies retain a live owner in each frame, even though results move.
for depth, error in [(14, None), (15, 'array_limit')]:
    source = ('module main;fn i32[1] f(i32[1] a,i32 n){if(n==0){return a;}'
              'let i32[1] b=f(a,n-1);return b;}fn i32 main(){let i32[1] a=[42;1];'
              'let i32[1] b=f(a,' + str(depth) + ');return b[0];}')
    case(source, error=error, code=5 if error else 0)
case('module main;fn usize[4096] f(usize[4096] a){return a;}'
     'fn i32 main(){let usize[4096] a=[42;4096];let usize[4096] b=f(a);'
     'if(b[4095]==42){return 42;}return 0;}')
case('module main;fn usize[4096] f(usize[4096] a){return a;}'
     'fn i32 main(){var usize[4096] a=[42;4096];let usize[4096] b=f(a);return 42;}',
     error='array_limit', code=5)
assert len(rows) == 119, len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-result-source-cli/v1',
    status='passed', profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} source array-result CLI cases')
