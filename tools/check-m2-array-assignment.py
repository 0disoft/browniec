"""Exercise whole-array assignment through the real native CLI."""
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
output = root / 'build/m2-array-assignment' / args.profile
output.mkdir(parents=True, exist_ok=True)
report = output / 'cli-receipt.json'
report.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {'SystemRoot': os.environ['SystemRoot'], 'WINDIR': os.environ['SystemRoot'],
       'PATH': str(empty), 'TEMP': str(empty), 'TMP': str(empty)}
rows = []


def case(body, *, error=None, code=0, mode='run', fuel=1000000):
    source = ('module main; fn i32 main() { '+body+' }').encode()
    path = output / f'assignment-{len(rows):03}.brc'
    path.write_bytes(source)
    argv = [str(exe), mode, str(path), '--json']
    if mode == 'run':
        argv += ['--fuel', str(fuel)]
    ran = subprocess.run(argv, cwd=empty, env=env, capture_output=True, timeout=10)
    assert ran.returncode == code and ran.stderr == b'', (body, ran.returncode, ran.stdout, ran.stderr)
    result = json.loads(ran.stdout)
    assert set(result) == {'schema', 'profile', 'command', 'status', 'return_i32', 'error'}
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode
    assert result['profile'] == ('brownie.m1-scalar/1' if code == 3 else 'brownie.m2-array-copy/1'), result
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed')
    assert result['return_i32'] == (None if error or mode == 'check' else 42), (body, result)
    if error:
        assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(source), result
    else:
        assert result['error'] is None
    rows.append({'case': path.stem, 'sourceSha256': hashlib.sha256(source).hexdigest(), 'exit': code, 'result': result})


for tag, values in [('i32',['-2147483648','42','2147483647']),
                    ('i64',['-9223372036854775808','42','9223372036854775807']),
                    ('u8',['0','42','255']), ('u32',['0','42','4294967295']),
                    ('usize',['0','9223372036854775808','18446744073709551615']),
                    ('bool',['false','true'])]:
    for value in values:
        for binding in ['let','var']:
            zero = 'false' if tag == 'bool' else '0'
            changed = 'a[0]='+zero+';' if binding == 'var' else ''
            case(f'{binding} {tag}[2] a=[{value};2]; var {tag}[2] b=[{zero};2]; b=a; {changed} b=b; '
                 f'if(b[0]=={value} && b[1]=={value} && b.len==a.len) {{return 42;}} return 0;')
case('var i32[2] a=[0;2]; {var i32[2] b=[21;2]; a=b; b[0]=0;} return a[0]+a[1];')
case('let i32[1] a=[42;1]; var i32[1] b=[0;1]; for(var usize i=0;i<42;i=i+1) {b=a; continue;} return b[0];')
case('var i32[1] a=[0;1]; let Option<i32> o=.none; return switch(o) {case .some(v): {v} case .none: {let i32[1] b=[42;1]; a=b; a[0]}};')
case('var i32[1] a=[0;1]; var i32 n=0; while(n<2) {let i32[1] b=[21;1]; a=b; n=n+1;} return a[0]*2;')
case('let usize[4096] a=[18446744073709551615;4096]; var usize[4096] b=[0;4096]; b=a; b=b; if(b[4095]==a[4095]) {return 42;} return 0;')
case('let bool[4096] a=[true;4096]; var bool[4096] b=[false;4096]; b=a; if(b[0] && b[4095]) {return 42;} return 0;')
case('let i32[1] a0=[42;1]; '+''.join(f'var i32[1] a{i}=[0;1];' for i in range(1,16))+' a15=a0; return a15[0];')
prefix = 'let i32[1] a=[42;1]; var i32[1] b=[0;1]; '
for body in [
    'let i32[1] a=[42;1]; let i32[1] b=a; b=a; return 0;',
    'let i32[1] a=[42;1]; var i32[2] b=[0;2]; b=a; return 0;',
    'let i32[1] a=[42;1]; var i64[1] b=[0;1]; b=a; return 0;',
    'var i32[1] b=[0;1]; {let i32[1] a=[42;1];} b=a; return 0;',
    prefix+'b=missing; return 0;', prefix+'b=42; return 0;',
    prefix+'b=(a); return 0;', prefix+'b=[42;1]; return 0;',
    prefix+'for(b=a;false;) {} return 0;', prefix+'for(;false;b=a) {} return 0;',
]:
    case(body, error='type', code=3)
for rhs in ['a[0]', 'a.len', 'a+0']:
    case(prefix+'b='+rhs+'; return 0;', error='syntax', code=3)
basic = prefix+'b=a; return b[0];'
case(basic, fuel=65897)
case(basic, fuel=65896, error='fuel', code=5)
case(basic, mode='check')
case(prefix+'b=a; return b[1];', error='bounds', code=5)
case(basic)
report.write_text(json.dumps({'schema': 'browniec.m2-array-assignment-cli/v1', 'status': 'passed',
    'profile': args.profile, 'exeSha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment': 'cleared; tool-free PATH', 'count': len(rows), 'cases': rows}, indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} whole-array assignment CLI cases')
