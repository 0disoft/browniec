"""Run lexical-array cases against a native Brownie CLI with a tool-free PATH."""
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
output = root / 'build' / 'm2-array-scopes' / args.profile
output.mkdir(parents=True, exist_ok=True)
report = output / 'cli-receipt.json'
report.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {'SystemRoot': os.environ['SystemRoot'], 'WINDIR': os.environ['SystemRoot'],
       'PATH': str(empty), 'TEMP': str(empty), 'TMP': str(empty)}
rows = []


def case(body, *, profile='read', functions='', error=None, code=0, mode='run', fuel=1000000):
    source = ('module main; '+functions+' fn i32 main() { '+body+' }').encode()
    path = output / f'scope-{len(rows):03}.brc'
    path.write_bytes(source)
    argv = [str(exe), mode, str(path), '--json']
    if mode == 'run':
        argv += ['--fuel', str(fuel)]
    ran = subprocess.run(argv, cwd=empty, env=env, capture_output=True, timeout=10)
    assert ran.returncode == code and ran.stderr == b'', (body, ran.returncode, ran.stdout, ran.stderr)
    result = json.loads(ran.stdout)
    assert set(result) == {'schema', 'profile', 'command', 'status', 'return_i32', 'error'}
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode
    assert result['profile'] == ('brownie.m1-scalar/1' if code == 3 else f'brownie.m2-array-{profile}/1'), result
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed')
    assert result['return_i32'] == (None if error or mode == 'check' else 42), (body, result)
    if error:
        assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(source), result
    else:
        assert result['error'] is None
    rows.append({'case': path.stem, 'sourceSha256': hashlib.sha256(source).hexdigest(), 'exit': code, 'result': result})


for tag in ['bool', 'u8', 'i32', 'i64', 'u32', 'usize']:
    for binding in ['let', 'var']:
        value = 'true' if tag == 'bool' else '42'
        case(f'{{{binding} {tag}[2] a=[{value};2]; if(a.len==2 && a[1]=={value}) {{return 42;}}}} return 0;',
             profile='write' if binding == 'var' else 'read')
case('var i32 n=0; {let i32[1] a=[21;1]; n=a[0];} {let i32[1] a=[21;1]; n=n+a[0];} return n;')
case('var i32 n=0; while(n<42) {let i32[1] a=[1;1]; n=n+a[0];} return n;')
case('var i32 n=0; for(var usize i=0;i<42;i=i+1) {let i32[1] a=[1;1]; n=n+a[0]; continue;} return n;')
case('var i32 n=0; while(n<42) {let i32[1] a=[1;1]; n=n+a[0]; if(n<42) {continue;} break;} return n;')
case('var i32 n=0; for(var usize i=0;i<2;i=i+1) {let i32[1] a=[21;1]; while(true) {let i32[1] b=a; n=n+b[0]; break;} n=n+a[0]-21;} return n;', profile='copy')
case('var i32 n=0; while(true) {let i32[1] a=[21;1]; {let i32[1] b=a; n=a[0]+b[0]; break;}} let i32[2] c=[0;2]; return n+c[0];', profile='copy')
for variant in ['.some(0)', '.none']:
    case('let Option<i32> o='+variant+'; var i32 n=0; switch(o) {case .some(v): {let i32[1] a=[42;1]; n=a[0];} case .none: {let i32[1] a=[42;1]; n=a[0];}} return n;')
    case('let Option<i32> o='+variant+'; let i32 n=switch(o) {case .some(v): {let i32[1] a=[21;1]; a[0]} case .none: {let i32[1] a=[21;1]; a[0]}}; let i32[1] b=[21;1]; return n+b[0];')
case('if(false) {let i32[1] a=[1/0;1];} else {let i32[1] a=[42;1]; return a[0];} return 0;')
case('let Option<i32> o=.some(0); var i32 n=0; while(switch(o) {case .some(v): {let i32[1] a=[1;1]; n=n+a[0]; if(n==42) {break;} true} case .none: {false}}) {} return n;')
case('let Option<i32> o=.none; var i32 n=0; while(n<42) {let i32[1] a=[1;1]; let i32[1] b=[switch(o) {case .some(v): {v} case .none: {n=n+a[0]; continue;}};1];} return n;')
case('let Option<i32> o=.none; let i32[1] a=[21;1]; let i32[1] b=[switch(o) {case .some(v): {v} case .none: {let i32[1] c=a; return c[0]+a[0];}};1]; return b[0];', profile='copy')
case('var i32 n=0; while(n<42) {let u8[4096] a=[1;4096]; n=n+(a[4095] as i32);} return n;')
case('var i32 n=0; {let usize[4096] a=[1;4096]; if(a[0]==1) {n=21;}} {let usize[4096] a=[1;4096]; n=n+21;} return n;')
for body in [
    '{let i32[1] a=[42;1];} return a[0];',
    'let i32[1] a=[42;1]; {let i32[1] a=[0;1];} return a[0];',
    'while(false) {let i32[1] a=[42;1];} return a[0];',
    'for(let i32[1] a=[42;1];false;) {} return 0;',
    '{let i32[1] a=[42;1]; a[0]=0;} return 0;',
    '{let i32[1] a=[42;1]; let i64[1] b=a;} return 0;',
    '{let i32[1] a=[42;1];} return main();',
]:
    case(body, error='type', code=3)
case('return helper();', functions='fn i32 helper() {{let i32[1] a=[42;1];} return a[0];}', error='type', code=3)
case(''.join('{let i32[1] a=[42;1];}' for _ in range(17))+' return 42;', error='compile_limit', code=3)
basic = '{let i32[1] a=[0;1];} return 42;'
case(basic, fuel=65657)
case(basic, fuel=65656, error='fuel', code=5)
case(basic, mode='check')
case('{let i32[1] a=[42;1]; return a[1];}', error='bounds', code=5)
case('{let i32[1] a=[1/0;1];} return 42;', error='zero_divisor', code=5)
case('{let usize[4096] a=[0;4096]; let usize[4096] b=a; let u8[1] c=[0;1];} return 42;', profile='copy', error='array_limit', code=5)
case(basic)
report.write_text(json.dumps({'schema': 'browniec.m2-array-scopes-cli/v1', 'status': 'passed',
    'profile': args.profile, 'exeSha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment': 'cleared; tool-free PATH', 'count': len(rows), 'cases': rows}, indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} lexical array CLI cases')
