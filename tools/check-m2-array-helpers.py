"""Exercise helper-local arrays and early cleanup through the native source CLI."""
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
output = root / 'build/m2-array-helpers' / args.profile
output.mkdir(parents=True, exist_ok=True)
report = output / 'cli-receipt.json'
report.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(functions, body='return f();', *, profile='read', error=None, code=0,
         mode='run', fuel=1000000, main_first=False):
    main = 'fn i32 main(){'+body+'}'
    source = ('module main; '+(main+functions if main_first else functions+main)).encode()
    path = output / f'helper-{len(rows):03}.brc'
    path.write_bytes(source)
    command = [str(exe), mode, str(path), '--json']
    if mode == 'run':
        command += ['--fuel', str(fuel)]
    ran = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=10)
    assert ran.returncode == code and not ran.stderr, (source, ran.returncode, ran.stdout, ran.stderr)
    result = json.loads(ran.stdout)
    assert set(result) == {'schema', 'profile', 'command', 'status', 'return_i32', 'error'}, result
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode, result
    assert result['profile'] == ('brownie.m1-scalar/1' if code == 3 else f'brownie.m2-array-{profile}/1'), result
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), result
    assert result['return_i32'] == (None if error or mode == 'check' else 42), (source, result)
    if error:
        assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(source), result
    else:
        assert result['error'] is None, result
    rows.append({'case': path.stem, 'sourceSha256': hashlib.sha256(source).hexdigest(), 'exit': code, 'result': result})


for tag, values in [('i32', ['-2147483648', '42', '2147483647']),
                    ('i64', ['-9223372036854775808', '42', '9223372036854775807']),
                    ('u8', ['0', '42', '255']), ('u32', ['0', '42', '4294967295']),
                    ('usize', ['0', '9223372036854775808', '18446744073709551615']),
                    ('bool', ['false', 'true'])]:
    for value in values:
        for binding in ['let', 'var']:
            zero = 'false' if tag == 'bool' else '0'
            case(f'fn i32 f(){{{binding} {tag}[2] a=[{value};2]; var {tag}[2] b=a; '
                 f'b[0]={zero}; b=a; if(b[0]=={value} && b[1]=={value} && b.len==2){{return 42;}} return 0;}}', profile='copy')
    value = values[-1]
    for parameter in [False, True]:
        params = f'{tag} n' if parameter else ''
        fill = 'n' if parameter else value
        argument = value if parameter else ''
        case(f'fn {tag} f({params}){{let {tag}[1] a=[{fill};1]; return a[0];}}',
             f'if(f({argument})=={value}){{return 42;}} return 0;')

case('fn i32 f(){let i32[1] a=[21;1]; return a[0];}',
     'let i32[1] a=[21;1]; return a[0]+f();', main_first=True)
case('fn i32 f(i32 n){let i32[1] a=[n;1]; if(n==0){return a[0];} let i32 child=f(n-1); return a[0]+child;}',
     'let i32[1] a=[36;1]; return f(3)+a[0];')
mutual = ('fn i32 f(i32 n){let i32[1] a=[n;1]; if(n==0){return a[0];} return a[0]+g(n-1);}'
          'fn i32 g(i32 n){let i32[1] a=[n;1]; if(n==0){return a[0];} return a[0]+f(n-1);}')
case(mutual, 'return f(3)+36;')
case('fn i32 f(){let i32[1] a=[1;1]; return a[0];}',
     'var i32 n=0; for(var i32 i=0;i<42;i=i+1){n=n+f();} return n;')
case('fn i32 f(){var i32 n=0; while(n<42){let i32[1] a=[1;1]; n=n+a[0]; if(n<42){continue;} break;} return n;}')
case('fn i32 f(){let Option<i32> x=.none; return switch(x){case .some(n):{n} case .none:{let i32[1] a=[42;1]; a[0]}};}')
case('fn i32 f(){let Option<i32> x=.none; let i32[1] a=[21;1]; let i32[1] b=[switch(x){case .some(n):{n} case .none:{let i32[1] c=a; return a[0]+c[0];}};1]; return b[0];}', profile='copy')

for wrapper, payload, success, failure, failure_pattern, failure_check in [
    ('Option<i32>', 'i32', '.some(42)', '.none', '.none', ''),
    ('Option<bool>', 'bool', '.some(true)', '.none', '.none', ''),
    ('Result<i32,i32>', 'i32', '.ok(42)', '.err(-2147483648)', '.err(e)', 'if(e!=-2147483648){return 0;}'),
    ('Result<i32,bool>', 'i32', '.ok(42)', '.err(true)', '.err(e)', 'if(!e){return 0;}'),
    ('Result<bool,i32>', 'bool', '.ok(true)', '.err(-2147483648)', '.err(e)', 'if(e!=-2147483648){return 0;}'),
    ('Result<bool,bool>', 'bool', '.ok(true)', '.err(true)', '.err(e)', 'if(!e){return 0;}'),
]:
    positive = '.some' if wrapper.startswith('Option') else '.ok'
    test = 'v==42' if payload == 'i32' else 'v'
    functions = (f'fn {wrapper} f({wrapper} x){{let i32[1] a=[42;1]; let {payload} n=x?; '
                 f'if(a[0]==42){{return {positive}(n);}} return {failure};}}')
    case(functions, f'switch(f({success})){{case {positive}(v):{{if({test}){{return 42;}} return 0;}} '
                   f'case {failure_pattern}:{{return 0;}}}}')
    case(functions, f'var i32 count=0; while(count<42){{switch(f({failure})){{case {positive}(v):{{return 0;}} '
                   f'case {failure_pattern}:{{{failure_check} count=count+1;}}}}}} return count;')

initializer = 'fn Option<i32> f(Option<i32> x){let i32[1] a=[21;1]; let i32[1] b=[x?;1]; return .some(a[0]+b[0]);}'
case(initializer, 'switch(f(.some(21))){case .some(n):{return n;} case .none:{return 0;}}')
case(initializer, 'var i32 n=0; while(n<42){switch(f(.none)){case .some(v):{return 0;} case .none:{n=n+1;}}} return n;')
write = 'fn Option<i32> f(Option<i32> x){var i32[1] a=[0;1]; a[999]=x?; return .some(a[0]);}'
case(write, 'switch(f(.none)){case .some(v):{return 0;} case .none:{return 42;}}', profile='write')
case(write, 'switch(f(.some(42))){case .some(v):{return v;} case .none:{return 0;}}', profile='write', error='bounds', code=5)
case('fn Option<bool> f(Option<i32> x){let i32[1] a=[42;1]; return .some(x?==a[0]);}',
     'switch(f(.some(42))){case .some(v):{if(v){return 42;} return 0;} case .none:{return 0;}}')
case('fn Option<i32> f(Option<bool> x){let i32[1] a=[42;1]; while(x?){return .some(a[0]);} return .some(0);}',
     'switch(f(.none)){case .some(v):{return 0;} case .none:{return 42;}}')
case('fn Option<i32> f(Option<i32> x){let i32[1] a=[21;1]; {let i32[1] b=a; let i32 n=x?; return .some(n+a[0]+b[0]);}}',
     'var i32 n=0; while(n<42){switch(f(.none)){case .some(v):{return 0;} case .none:{n=n+1;}}} return n;', profile='copy')

recursive = 'fn i32 f(i32 n){let i32[1] a=[n;1]; if(n==0){return a[0];} return a[0]+f(n-1);}'
case(recursive, 'if(f(15)==120){return 42;} return 0;')
case(recursive, 'return f(16);', error='array_limit', code=5)
late = 'fn i32 f(i32 n){if(n>0){let i32 child=f(n-1); let i32[1] a=[1;1]; return child+a[0];} let i32[1] a=[12;1]; return a[0];}'
case(late, 'return f(30);')
case(late, 'return f(31);', error='frame_limit', code=5)
case('fn i32 f(){let usize[4096] a=[1;4096]; return 42;}',
     'let usize[4096] a=[1;4096]; let i32 n=f(); if(a[4095]==1){return n;} return 0;')
case('fn i32 f(){let usize[4096] a=[1;4096]; let bool[1] b=[true;1]; return 42;}',
     'let usize[4096] a=[1;4096]; return f();', error='array_limit', code=5)
case('fn i32 f(){'+''.join(f'let i32[1] a{i}=[1;1];' for i in range(17))+'return 42;}', error='compile_limit', code=3)

for functions, body, error in [
    ('fn i32 f(){let i32[1] a=[42;1]; return a;}', 'return f();', 'type'),
    ('fn i32 f(){let i32[1] a=[0;1]; a[0]=42; return a[0];}', 'return f();', 'type'),
    ('fn i32 f(){return a[0];}', 'let i32[1] a=[42;1]; return f();', 'type'),
    ('fn i32 f(){let i32[1] a=[42;1]; let i32[2] b=a; return b[0];}', 'return f();', 'type'),
    ('fn i32 f(){for(let i32[1] a=[0;1];false;){} return 0;}', 'return f();', 'type'),
    ('fn i32 f(){var i32[1] a=[0;1]; for(;false;a[0]=1){} return 0;}', 'return f();', 'type'),
    ('fn i32 f(){let Option<i32>[1] a=[.none;1]; return 0;}', 'return f();', 'type'),
    ('fn i32 f(i32[1] a){return a[0];}', 'return 0;', 'type'),
    ('fn i32[1] f(){return 0;}', 'return 0;', 'syntax'),
    ('fn i32 f(i32 n){return n;}', 'let i32[1] a=[42;1]; return f(a);', 'type'),
    ('fn i32 f(){let i32[1] a=[42;1]; return main();}', 'return f();', 'type'),
    ('fn i32 f(){let i32[1] a=[42;1]; {let i32[1] a=[0;1];} return 0;}', 'return f();', 'type'),
]:
    case(functions, body, error=error, code=3)
basic = 'fn i32 f(){let i32[1] a=[42;1]; return a[0];}'
case(basic, fuel=65696)
case(basic, fuel=65695, error='fuel', code=5)
case(basic, mode='check')
case('fn i32 f(){let i32[1] a=[42;1]; return a[1];}', error='bounds', code=5)
case('fn i32 f(){let i32[1] a=[1/0;1]; return a[0];}', error='zero_divisor', code=5)
case(basic)

report.write_text(json.dumps({'schema': 'browniec.m2-array-helpers-cli/v1', 'status': 'passed',
    'profile': args.profile, 'exeSha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment': 'cleared; tool-free PATH', 'count': len(rows), 'cases': rows}, indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} helper-local array CLI cases')
