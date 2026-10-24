"""Black-box array length checks against the native CLI, with a tool-free PATH."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--exe', required=True)
parser.add_argument('--profile', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'build' / 'm2-array-length' / args.profile
output.mkdir(parents=True, exist_ok=True)
report = output / 'cli-receipt.json'
report.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {'SystemRoot': os.environ['SystemRoot'], 'WINDIR': os.environ['SystemRoot'],
       'PATH': str(empty), 'TEMP': str(empty), 'TMP': str(empty)}
rows = []


def case(body, *, functions='', profile='read', error=None, code=0, mode='run', fuel=1000000):
    source = ('module main; ' + functions + ' fn i32 main() { ' + body + ' }').encode()
    path = output / f'length-{len(rows):03}.brc'
    path.write_bytes(source)
    argv = [str(exe), mode, str(path), '--json']
    if mode == 'run':
        argv += ['--fuel', str(fuel)]
    ran = subprocess.run(argv, cwd=empty, env=env, capture_output=True, timeout=10)
    assert ran.returncode == code and ran.stderr == b'', (body, ran.returncode, ran.stdout, ran.stderr)
    result = json.loads(ran.stdout)
    assert set(result) == {'schema', 'profile', 'command', 'status', 'return_i32', 'error'}
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode
    expected_profile = 'brownie.m1-scalar/1' if code == 3 else f'brownie.m2-array-{profile}/1'
    assert result['profile'] == expected_profile, result
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed')
    assert result['return_i32'] == (None if error or mode == 'check' else 42), (body, result)
    if error:
        assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(source), result
    else:
        assert result['error'] is None
    rows.append({'case': path.stem, 'sourceSha256': hashlib.sha256(source).hexdigest(), 'exit': code, 'result': result})


for tag in ['i32', 'i64', 'u8', 'u32', 'usize', 'bool']:
    for count in [1, 4096]:
        value = 'true' if tag == 'bool' else '0'
        case(f'let {tag}[{count}] a=[{value};{count}]; if(a.len=={count}) {{return 42;}} return 0;')
for source in ['let', 'var']:
    for target in ['let', 'var']:
        case(f'{source} i32[2] a=[21;2]; {target} i32[2] b=a; if(a.len==b.len && b.len==2) {{return 42;}} return 0;', profile='copy')
case('var i32[3] a=[14;3]; var i32 total=0; for(var usize i=0;i<a.len;i=i+1) {total=total+a[i];} return total;', profile='write')
case('var i32[2] a=[0;2]; a[1]=42; {let usize len=a.len; if(len==2) {return a[1];}} return 0;', profile='write')
case('let i32[2] a=[0;2]; if(full(a.len)) {return 42;} return 0;', functions='fn bool full(usize n) {return n==2;}')
case('let i32[1] a=[0;1]; let Option<i32> o=.none; let usize n=switch(o) {case .some(v): {a.len} case .none: {a.len}}; if(n==1) {return 42;} return 0;')
case('let i32[1] a=[0;1]; if(a.len==1) {return len();} return 0;', functions='fn i32 len() {return 42;}')
case('let i32[1] a=[0;1]; var usize i=0; while(i<a.len) {i=i+1;} if(i==a.len) {return 42;} return 0;')
basic = 'let i32[1] a=[42;1]; let usize n=a.len; return a[0];'
case(basic, fuel=65695)
case(basic, fuel=65694, error='fuel', code=5)
case(basic, mode='check')
for body in [
    'let i32[1] a=[42;1]; return a.len;',
    'let i32[1] a=[42;1]; let i32 n=a.len; return 0;',
    'let i32[1] a=[42;1]; let usize n=a.size; return 0;',
    'let i32[1] a=[42;1]; let usize n=a.Len; return 0;',
    'let i32[1] a=[42;1]; let usize n=missing.len; return 0;',
]:
    case(body, error='type', code=3)
for expr in ['a.len()', 'a.', 'a.0', 'a.len.len', 'a.len[0]']:
    case(f'let i32[1] a=[42;1]; let usize n={expr}; return 0;',
         error='type' if expr in ['a.', 'a.0'] else 'syntax', code=3)
case('let i32 a=0; let usize n=a.len; return 0;', error='type', code=3)
case('var i32[1] a=[42;1]; a.len=2; return 0;', error='type', code=3)
case('let i32[1] a=[42;1]; var usize i=0; for(;i<a.len;i=i+a.len) {} if(i==1) {return 42;} return 0;')
case('let i32[1] a=[42;1]; for(var usize i=a.len;i==a.len;) {return a[0];} return 0;')
case(basic)  # Recovery uses a fresh invocation after failures.
report.write_text(json.dumps({'schema': 'browniec.m2-array-length-cli/v1', 'status': 'passed',
    'profile': args.profile, 'exeSha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment': 'cleared; tool-free PATH', 'count': len(rows), 'cases': rows}, indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array length CLI cases')
