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
output = root / 'build' / 'm2-array-copy-source' / args.profile
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
    assert result['profile'] == ('brownie.m1-scalar/1' if code == 3 else 'brownie.m2-array-copy/1'), (name, result)
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed')
    assert result['return_i32'] == (None if error or mode == 'check' else expected), (name, result)
    if error:
        assert result['error']['kind'] == error, (name, result)
        assert 0 <= result['error']['byte_offset'] <= len(source)
    else:
        assert result['error'] is None
    rows.append({'case': name, 'sourceSha256': hashlib.sha256(source).hexdigest(),
                 'exit': code, 'result': result})

for tag, values in [('i32', ['-2147483648','42','2147483647']),
                    ('i64', ['-9223372036854775808','42','9223372036854775807']),
                    ('u8', ['0','42','255']), ('u32', ['0','42','4294967295']),
                    ('usize', ['0','9223372036854775808','18446744073709551615']),
                    ('bool', ['false','true'])]:
    for value in values:
        zero='false' if tag=='bool' else '0'
        case(f'var {tag}[2] a=[{value};2]; var {tag}[2] b=a; a[0]={zero}; b[1]={zero}; '
             f'if(b[0]=={value} && a[1]=={value}) {{return 42;}} return 0;')
for source in ['let','var']:
    for target in ['let','var']:
        writes=('a[0]=0;' if source=='var' else '')+('b[1]=0;' if target=='var' else '')
        case(f'{source} i32[2] a=[21;2]; {target} i32[2] b=a; {writes} return a[1]+b[0];')
case('var i32[1] a=[0;1]; a[0]=42; let i32[1] b=a; a[0]=1; let i32[1] c=b; return c[0];')
case('let u8[4096] a=[0;4096]; var u8[4096] b=a; b[4095]=42; return b[4095] as i32;')
case('let bool[4096] a=[true;4096]; var bool[4096] b=a; b[4095]=false; if(a[4095] && !b[4095]) {return 42;} return 0;')
case('let usize[4096] a=[42;4096]; let usize[4096] b=a; if(b[4095]==42) {return 42;} return 0;')
case('let i32[1] a=[42;1]; var i32[1] b=a; {b[0]=41;} b[0]=b[0]+1; return b[0];')
case('let i32[2] a=[0;2]; var i32[2] b=a; for(var usize i=0;i<2;i=i+1) {b[i]=21;} return b[0]+b[1]+a[0];')
case('let i32[1] a=[42;1]; let i32[1] b=a; let Option<i32> o=.some(0); return switch(o) {case .some(n): {return b[0];} case .none: {a[0]}};')
case('let i32[1] a=[42;1]; let i32[1] b=a; let Option<i32> o=.none; let i32[1] c=[switch(o) {case .some(n): {n} case .none: {return b[0];}};1]; return c[0];')
case('let i32[2] a=[fill();2]; let i32[2] b=a; return b[0]+b[1];', functions='fn i32 fill() {return 21;}')
for count in [16,17]:
    case('let i32[1] a0=[42;1]; '+''.join(f'let i32[1] a{i}=a{i-1};' for i in range(1,count))+' return a0[0];',
         error='compile_limit' if count==17 else None, code=3 if count==17 else 0)
for body in [
    'let i32[1] a=[42;1]; let i32[2] b=a; return 0;',
    'let i32[1] a=[42;1]; let i64[1] b=a; return 0;',
    'let bool[1] a=[true;1]; let u8[1] b=a; return 0;',
    'let i32 x=42; let i32[1] b=x; return 0;',
    'let i32[1] b=missing; return 0;',
    'let i32[1] b=b; return 0;',
    'let i32[1] a=[42;1]; let i32[1] a=a; return 0;',
    'let i32[1] a=[42;1]; {let i32[1] b=a;} return 0;',
    'let i32[1] a=[42;1]; for(let i32[1] b=a;false;) {} return 0;',
    'let i32[1] a=[42;1]; let i32[1] b=a; b[0]=0; return 0;',
    'let i32[1] a=[42;1]; var i32[1] b=a; b=a; return 0;',
    'let i32[1] a=[42;1]; let i32[1] b=a; return b;',
    'let i32[1] a=[42;1]; let i32[1] b=a; return main();',
]:
    case(body,error='type',code=3)
for rhs in ['(a)','a[0]','a+0']:
    case('let i32[1] a=[42;1]; let i32[1] b='+rhs+'; return 0;',error='syntax',code=3)
case('return 0;',functions='fn i32 helper() {let i32[1] a=[42;1]; let i32[1] b=a; return b[0];}',error='type',code=3)
basic='let i32[1] a=[42;1]; let i32[1] b=a; return b[0];'
case(basic,fuel=65803)
case(basic,fuel=65802,error='fuel',code=5)
case(basic,fuel=None,error='fuel',code=5)
case(basic,mode='check')
quota='let usize[4096] a=[0;4096]; let usize[4096] b=a; let usize[4096] c=b; return 0;'
case(quota,error='array_limit',code=5)
case(quota,mode='check')
case('let i32[1] a=[42;1]; let i32[1] b=a; return b[1];',error='bounds',code=5)
case(basic)  # fresh invocation after failures
version=json.loads(invoke(['--version','--json'],0).stdout)
assert version['array_copy_profile']=='brownie.m2-array-copy/1'
assert version['array_write_profile']=='brownie.m2-array-write/1'
assert version['array_profile']=='brownie.m2-array-read/1' and version['profile']=='brownie.m1-scalar/1'
rows.append({'case':'version-profiles','exit':0})
report.write_text(json.dumps({'schema':'browniec.m2-array-copy-source-cli/v1','status':'passed',
    'profile':args.profile,'exeSha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment':'cleared; tool-free PATH','count':len(rows),'cases':rows},indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} source-array copy CLI cases')
