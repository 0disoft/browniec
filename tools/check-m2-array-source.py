"""Black-box checks of the native Brownie CLI; no substitute VM."""
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
output = root / 'build' / 'm2-array-source' / args.profile
output.mkdir(parents=True, exist_ok=True)
report = output / 'cli-receipt.json'
report.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {'SystemRoot': os.environ['SystemRoot'], 'WINDIR': os.environ['SystemRoot'],
       'PATH': str(empty), 'TEMP': str(empty), 'TMP': str(empty)}
rows = []

def invoke(argv, code):
    ran = subprocess.run([str(exe), *map(str, argv)], cwd=empty, env=env,
                         capture_output=True, timeout=10)
    assert ran.returncode == code, (argv, ran.returncode, ran.stdout, ran.stderr)
    return ran

def case(body, expected=42, error=None, code=0, mode='run', fuel=1000000, functions='', name=None):
    name = name or f'array-{len(rows):03}'
    source = ('module main; ' + functions + ' fn i32 main() { ' + body + ' }').encode()
    path = output / (name + '.brc')
    path.write_bytes(source)
    argv = [mode, path, '--json']
    if mode == 'run' and fuel is not None:
        argv += ['--fuel', fuel]
    ran = invoke(argv, code)
    assert ran.stderr == b'', (name, ran.stderr)
    result = json.loads(ran.stdout)
    assert set(result) == {'schema', 'profile', 'command', 'status', 'return_i32', 'error'}
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode
    assert result['profile'] == ('brownie.m1-scalar/1' if code == 3 else 'brownie.m2-array-read/1'), (name, result)
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed')
    assert result['return_i32'] == (None if error or mode == 'check' else expected), (name, result)
    if error:
        assert result['error']['kind'] == error, (name, result)
        assert 0 <= result['error']['byte_offset'] <= len(source)
    else:
        assert result['error'] is None
    rows.append({'case': name, 'sourceSha256': hashlib.sha256(source).hexdigest(),
                 'exit': code, 'result': result})

for tag, values in [('i32', ['-2147483648', '0', '2147483647']),
                    ('i64', ['-9223372036854775808', '0', '9223372036854775807']),
                    ('u8', ['0', '42', '255']), ('u32', ['0', '42', '4294967295']),
                    ('usize', ['0', '9223372036854775808', '18446744073709551615']),
                    ('bool', ['false', 'true'])]:
    for value in values:
        case(f'let {tag}[2] a = [{value}; 2]; if (a[1] == {value}) {{ return 42; }} return 0;')
case('let i32[2] a = [21; 2]; return a[0] + a[1];')
case('let u8[4096] a = [42; 4096]; return a[4095] as i32;')
case('let i32[2] a = [fill(); 2]; return a[index()] * 2;',
     functions='fn i32 fill() { return 21; } fn usize index() { return 1; }')
case('let i32[1] a = [42; 1]; let usize[1] i = [0; 1]; return a[i[0]];')
case('let u8[1] a = [42; 1]; let u8 i = 0; return a[i as usize] as i32;')
case('let i32[2] a = [21; 2]; var i32 n = 0; for (var usize i = 0; i < 2; i = i+1) { n = n+a[i]; } return n;')
case('let i32[1] a = [42; 1]; var usize i = 0; while (i < 2) { i = i+1; if (i == 1) { continue; } return a[0]; } return 0;')
case('let i32[1] a = [42; 1]; while (true) { break; } return a[0];')
case('let i32[1] a = [42; 1]; let Option<i32> o = .some(a[0]); return switch(o) { case .some(n): { n } case .none: { return a[0]; } };')
for variant in ['.some(1)', '.none']:
    case('let i32[1] a = [42; 1]; let Option<i32> o = '+variant+'; '
         'let i32[1] b = [switch(o) { case .some(n): { return a[0]; } case .none: { a[0] } }; 1]; return b[0];')
for n in [16, 17]:
    case(' '.join(f'let i32[1] a{i} = [42; 1];' for i in range(n))+' return a0[0];',
         error='compile_limit' if n == 17 else None, code=3 if n == 17 else 0)
for depth in [32, 33]:
    expression = 'a[' * depth + '0' + ']' * depth
    case('let usize[1] a = [0; 1]; if ('+expression+' == 0) { return 42; } return 0;',
         error='compile_limit' if depth == 33 else None, code=3 if depth == 33 else 0)
for body in [
    'let i32[0] a = [0; 0]; return 0;',
    'let i32[4097] a = [0; 4097]; return 0;',
    'let i32[18446744073709551615] a = [0; 1]; return 0;',
    'let i32[2] a = [1; 1]; return 0;',
    'let i32[1] a = [true; 1]; return 0;',
    'let u8[1] a = [256; 1]; return 0;',
    'let Option<i32>[1] a = [.none; 1]; return 0;',
    'let i32[1] a = [a[0]; 1]; return 0;',
    'let i32[1] a = [42; 1]; let i32[1] a = [42; 1]; return 0;',
    'let i32 a = 42; let i32[1] a = [42; 1]; return 0;',
    '{ let i32[1] a = [42; 1]; } return 0;',
    'if (true) { let i32[1] a = [42; 1]; } return 0;',
    'while (false) { let i32[1] a = [42; 1]; } return 0;',
    'for (let i32[1] a = [42; 1]; false;) {} return 0;',
    'var i32[1] a = [42; 1]; a = 1; return 0;',
    'let i32[1] a = [42; 1]; let i32 n = 0; return a[n];',
    'let i32[1] a = [42; 1]; return a[true];',
    'let i32[1] a = [42; 1]; return a;',
    'let i32[1] a = [42; 1]; a[0] = 1; return 0;',
    'let i32[1] a = [42; 1]; return main();',
]:
    case(body, error='type', code=3)
for body in ['let i32[1+1] a = [0; 2]; return 0;', 'let i32[1] a = [1, 2]; return 0;', 'let i32[1] a = [42; 1]; let i32[1] b = a; return 0;']:
    case(body, error='syntax', code=3)
case('return f();', functions='fn i32 f() { let i32[1] a = [42; 1]; return a[0]; }', error='type', code=3)
case('let i32[1] a = [42; 1]; return a[0];', functions='fn i32 unused() { return main(); }', error='type', code=3)
basic = 'let i32[2] a = [42; 2]; return a[0];'
case(basic, fuel=65698)
case(basic, fuel=65697, error='fuel', code=5)
case(basic, fuel=None, error='fuel', code=5)
case('let i32[1] a = [42; 1]; return a[1];', error='bounds', code=5)
case('let i32[1] a = [42; 1]; return a[18446744073709551615];', error='bounds', code=5)
case('let i32[1] a = [42; 1]; return a[1/0];', error='zero_divisor', code=5)
case('let i32[1] a = [1/0; 1]; return a[0];', error='zero_divisor', code=5)
case('let i32[1] a = [42; 1]; return a[999];', mode='check')
case('let usize[4096] a = [1; 4096]; let usize[4096] b = [1; 4096]; let bool[1] c = [true; 1]; return 0;', error='array_limit', code=5)
version = json.loads(invoke(['--version', '--json'], 0).stdout)
assert version['array_profile'] == 'brownie.m2-array-read/1' and version['profile'] == 'brownie.m1-scalar/1'
rows.append({'case': 'version-profiles', 'exit': 0})
report.write_text(json.dumps({'schema': 'browniec.m2-array-source-cli/v1', 'status': 'passed',
    'profile': args.profile, 'exeSha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment': 'cleared; tool-free PATH', 'count': len(rows), 'cases': rows}, indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} source-array CLI cases')
