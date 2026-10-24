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
output = root / 'build' / 'm2-array-write' / args.profile
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
    assert result['profile'] == ('brownie.m1-scalar/1' if code == 3 else 'brownie.m2-array-write/1'), (name, result)
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed')
    assert result['return_i32'] == (None if error or mode == 'check' else expected), (name, result)
    if error:
        assert result['error']['kind'] == error, (name, result)
        assert 0 <= result['error']['byte_offset'] <= len(source)
    else:
        assert result['error'] is None
    rows.append({'case': name, 'sourceSha256': hashlib.sha256(source).hexdigest(),
                 'exit': code, 'result': result})

for tag, values in [('i32', ['-2147483648', '42', '2147483647']),
                    ('i64', ['-9223372036854775808', '42', '9223372036854775807']),
                    ('u8', ['0', '42', '255']), ('u32', ['0', '42', '4294967295']),
                    ('usize', ['0', '9223372036854775808', '18446744073709551615']),
                    ('bool', ['false', 'true'])]:
    for value in values:
        zero = 'false' if tag == 'bool' else '0'
        case(f'var {tag}[2] a=[{zero};2]; a[1]={value}; if(a[1]=={value}) {{return 42;}} return 0;')
case('var i32[2] a=[0;2]; a[0]=20; a[1]=22; return a[0]+a[1];')
case('var u8[4096] a=[0;4096]; a[4095]=42; return a[4095] as i32;')
case('var i32[1] a=[42;1]; return a[0];')
case('var i32[1] a=[0;1]; a[ix()]=value(); return a[0];',
     functions='fn usize ix() {return 0;} fn i32 value() {return 42;}')
case('var i32[2] a=[0;2]; for(var usize i=0;i<2;i=i+1) {a[i]=21;} return a[0]+a[1];')
case('var i32[1] a=[0;1]; var usize i=0; while(i<3) {i=i+1; if(i==1) {continue;} a[0]=42; break;} return a[0];')
case('var i32[1] a=[0;1]; {if(true) {a[0]=42;}} return a[0];')
case('var i32[1] a=[0;1]; let Option<i32> o=.some(0); switch(o) {case .some(n): {a[0]=42;} case .none: {a[0]=1;}} return a[0];')
for variant in ['.some(0)', '.none']:
    case('var i32[1] a=[0;1]; let Option<i32> o='+variant+'; return switch(o) {case .some(n): {a[0]=42; a[0]} case .none: {a[0]=42; a[0]}};')
case('var i32[2] a=[0;2]; var usize i=0; let Option<i32> o=.some(0); a[i]=switch(o) {case .some(n): {i=1; 42} case .none: {0}}; return a[0];')
case('var i32[1] a=[0;1]; var i32 hits=0; let Option<i32> o=.some(0); a[switch(o) {case .some(n): {hits=hits+1; 0} case .none: {0}}]=switch(o) {case .some(n): {hits=hits+1; 42} case .none: {0}}; if(hits==2) {return a[0];} return 0;')
case('var i32[1] a=[0;1]; let Option<i32> o=.some(0); a[switch(o) {case .some(n): {return 42;} case .none: {0}}]=1/0; return 0;')
case('var i32[1] a=[0;1]; let Option<i32> o=.some(0); a[999]=switch(o) {case .some(n): {return 42;} case .none: {0}}; return 0;')
case('var i32[1] a=[0;1]; let Option<i32> o=.some(0); return switch(o) {case .some(n): {a[switch(o) {case .some(m): {0} case .none: {0}}]=42; a[0]} case .none: {0}};')
case('var i32[1] a=[0;1]; let usize[1] ix=[0;1]; a[ix[0]]=42; return a[0];')
case('var i32[1] a=[0;1]; let u8 i=0; a[i as usize]=42; return a[0];')
for body in [
    'let i32[1] a=[0;1]; a[0]=42; return 0;',
    'var i32[1] a=[0;1]; a=42; return 0;',
    'var i32[1] a=[0;1]; a[true]=42; return 0;',
    'var i32[1] a=[0;1]; let i32 i=0; a[i]=42; return 0;',
    'var i32[1] a=[0;1]; a[0]=true; return 0;',
    'var u8[1] a=[0;1]; a[0]=256; return 0;',
    'var u8[1] a=[0;1]; let i32 x=42; a[0]=x; return 0;',
    'var i32[1] a=[0;1]; for(a[0]=1;false;) {} return 0;',
    'var i32[1] a=[0;1]; for(;false;a[0]=1) {} return 0;',
    '{var i32[1] a=[0;1];} return a[0];',
    'var i32[1] a=[0;1]; return main();',
]:
    case(body, error='type', code=3)
case('return helper();', functions='fn i32 helper() {var i32[1] a=[0;1]; return a[0];}', error='type', code=3)
case('var i32[1] a=[0;1]; a[0]+=1; return 0;', error='syntax', code=3)
for depth in [31, 32]:
    index = 'ix[' * depth + '0' + ']' * depth
    case('var i32[1] a=[0;1]; let usize[1] ix=[0;1]; a['+index+']=42; return a[0];',
         error='compile_limit' if depth == 32 else None, code=3 if depth == 32 else 0)
basic='var i32[1] a=[0;1]; a[0]=42; return a[0];'
case(basic, fuel=65737)
case(basic, fuel=65736, error='fuel', code=5)
case(basic, fuel=None, error='fuel', code=5)
case(basic, mode='check')
case('var i32[1] a=[0;1]; a[999]=42; return 0;', expected=0, mode='check')
for index in ['1', '18446744073709551615']:
    case('var i32[1] a=[0;1]; a['+index+']=42; return 0;', error='bounds', code=5)
case('var i32[1] a=[0;1]; a[999]=1/0; return 0;', error='zero_divisor', code=5)
case('var i32[1] a=[0;1]; a[1/0]=2147483647+1; return 0;', error='zero_divisor', code=5)
case('var i32[1] a=[0;1]; a[0]=2147483647+1; return 0;', error='overflow', code=5)
case('var i32[1] a=[0;1]; a[0]=42; return a[0];')  # fresh process after failures
version=json.loads(invoke(['--version','--json'],0).stdout)
assert version['array_write_profile']=='brownie.m2-array-write/1'
assert version['array_profile']=='brownie.m2-array-read/1' and version['profile']=='brownie.m1-scalar/1'
rows.append({'case':'version-profiles','exit':0})
report.write_text(json.dumps({'schema':'browniec.m2-array-write-cli/v1','status':'passed',
    'profile':args.profile,'exeSha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment':'cleared; tool-free PATH','count':len(rows),'cases':rows},indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} source-array write CLI cases')
