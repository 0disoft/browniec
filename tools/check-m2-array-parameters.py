"""Run source array-parameter programs through the real native CLI."""
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
output = root / 'build/m2-array-parameters' / args.profile
output.mkdir(parents=True, exist_ok=True)
report = output / 'cli-receipt.json'
report.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(functions, body='return f();', *, profile='read', error=None,
         code=0, mode='run', fuel=1000000, main_first=False, source_text=None):
    main = 'fn i32 main(){' + body + '}'
    source = (source_text if source_text is not None else
              'module main; ' + (main + functions if main_first else functions + main)).encode()
    path = output / f'parameter-{len(rows):03}.brc'
    path.write_bytes(source)
    command = [str(exe), mode, str(path), '--json']
    if mode == 'run':
        command += ['--fuel', str(fuel)]
    ran = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=10)
    assert ran.returncode == code and not ran.stderr, (source, ran.returncode, ran.stdout, ran.stderr)
    result = json.loads(ran.stdout)
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode, result
    expected_profile = 'brownie.m1-scalar/1' if code == 3 else f'brownie.m2-array-{profile}/1'
    assert result['profile'] == expected_profile, (source, result)
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), result
    assert result['return_i32'] == (None if error or mode == 'check' else 42), (source, result)
    if error:
        assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(source), result
    else:
        assert result['error'] is None, result
    rows.append({'case': path.stem, 'sourceSha256': hashlib.sha256(source).hexdigest(),
                 'exit': code, 'result': result})


for tag, values in [('i32', ['-2147483648', '42', '2147483647']),
                    ('i64', ['-9223372036854775808', '42', '9223372036854775807']),
                    ('u8', ['0', '42', '255']), ('u32', ['0', '42', '4294967295']),
                    ('usize', ['0', '9223372036854775808', '18446744073709551615']),
                    ('bool', ['false', 'true'])]:
    for value in values:
        for binding in ['let', 'var']:
            case(f'fn i32 f(i32 n,{tag}[2] a){{if(a[0]=={value} && a[1]=={value} && a.len==2){{return n;}}return 0;}}',
                 f'{binding} {tag}[2] a=[{value};2];return f(42,a);',
                 profile='read' if binding == 'let' else 'copy', main_first=binding == 'var')

case('fn i32 f(u8[3] a,i32 n,bool[2] b){if(a[2]==255 && b[1]){return n;}return 0;}',
     'let u8[3] a=[255;3];let bool[2] b=[true;2];return f(a,42,b);', main_first=True)
for values in [list(range(1, 9)), list(range(8, 0, -1)), [3, 7, 1, 8, 2, 6, 4, 5]]:
    names = 'abcdefgh'
    parameters = ','.join(f'i32[1] {n}' for n in names)
    weighted = '+'.join(f'{n}[0]*{i+1}' for i, n in enumerate(names))
    expected = sum((i + 1) * v for i, v in enumerate(values))
    declarations = ''.join(f'let i32[1] {n}=[{v};1];' for n, v in zip(names, values))
    case(f'fn i32 sum({parameters}){{return {weighted}-{expected-42};}}',
         declarations + 'return sum(' + ','.join(names) + ');', main_first=True)

capture = 'fn i32 f(i32[1] a,i32 n,i32[1] b){return a[0]*10+n+b[0];}'
mutation = ('var i32[1] a=[2;1];var i32 n=0;let Option<i32> o=.none;'
            'let i32 r=f(a,switch(o){case .some(v):{v}case .none:{n=n+1;a[0]=4;18}},a);return r+n-1;')
case(capture, mutation, profile='copy')
case(capture, mutation, profile='copy', mode='check')
take = 'fn i32 take(i32[1] a,i32 n){return a[0]+n;}'
case(take, 'var i32[1] a=[1;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{return 42;}});', profile='copy')
case(take, 'var i32 n=0;while(n<42){var i32[1] a=[1;1];let Option<i32> o=.none;n=n+take(a,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}return n;', profile='copy')
case(take, 'while(true){var i32[1] a=[1;1];let Option<i32> o=.none;let i32 n=take(a,switch(o){case .some(v):{v}case .none:{break;}});}return 42;', profile='copy')
case(take, 'var i32[1] a=[21;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{var i32 n=0;while(n<21){n=n+1;continue;}n}});', profile='copy')
case(take + 'fn Option<i32> f(Option<i32> x){var i32[1] a=[21;1];return .some(take(a,take(a,x?)));}',
     'var i32 i=0;while(i<42){switch(f(.none)){case .some(v):{return 0;}case .none:{i=i+1;}}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}', profile='copy')
case('fn Result<bool,bool> f(i32[1] a,Result<i32,bool> x){return .ok(a[0]==x?);}',
     'let i32[1] a=[42;1];var i32 i=0;while(i<42){switch(f(a,.err(true))){case .ok(v):{return 0;}case .err(e):{i=i+1;}}}switch(f(a,.ok(42))){case .ok(v):{if(v){return 42;}return 0;}case .err(e):{return 0;}}')
case(take + 'fn Result<i32,i32> f(Result<i32,i32> x){var i32[1] a=[21;1];return .ok(take(a,take(a,x?)));}',
     'var i32 i=0;while(i<42){switch(f(.err(9))){case .ok(v):{return 0;}case .err(e):{i=i+1;}}}switch(f(.ok(0))){case .ok(v):{return v;}case .err(e):{return 0;}}', profile='copy')

recursive = 'fn i32 f(i32[1] a,i32 n){if(n==0){return a[0];}return a[0]+f(a,n-1);}'
case(recursive, 'let i32[1] a=[7;1];return f(a,5);')
case(recursive, 'let i32[1] a=[7;1];if(f(a,14)==105){return 42;}return 0;')
case(recursive, 'let i32[1] a=[7;1];return f(a,15);', error='array_limit', code=5)
case('fn i32 f(i32[1] a,i32 n){if(n==0){return a[0];}return a[0]+g(a,n-1);}'
     'fn i32 g(i32[1] a,i32 n){if(n==0){return a[0];}return a[0]+f(a,n-1);}',
     'let i32[1] a=[7;1];return f(a,5);', main_first=True)
case('fn i32 f(i32[1] a){return a[0];}', 'var i32[1] a=[1;1];var i32 n=0;while(n<42){n=n+f(a);}return n;', profile='copy')
case('fn i32 f(i32[1] a){var i32[1] b=a;b[0]=0;return a[0]+21;}', 'var i32[1] a=[21;1];return f(a);', profile='copy')
case('fn i32 f(i64[4096] a){if(a[4095]==42){return 42;}return 0;}', 'let i64[4096] a=[42;4096];return f(a);')
case('fn i32 f(i64[4096] a){return 42;}', 'var i64[4096] a=[42;4096];return f(a);', profile='copy', error='array_limit', code=5)
case('fn i32 f(i32[1] a){return a[0];}', 'return 42;')
for binding, price in [('let', 66013), ('var', 66122)]:
    for short in [False, True]:
        case('fn i32 f(i32[1] a){return a[0];}', f'{binding} i32[1] a=[42;1];return f(a);',
             profile='read' if binding == 'let' else 'copy', fuel=price-int(short),
             error='fuel' if short else None, code=5 if short else 0)
eight = ','.join(f'i32[1] {n}' for n in 'abcdefgh')
case(f'fn i32 f({eight}){{return 42;}}',
     'var i32[1] a=[42;1];return f(a,a,a,a,a,a,a,a);', error='compile_limit', code=3)
case(f'fn i32 f({eight}){{return 42;}}fn i32 g({eight}){{return 42;}}', 'return 42;')

for functions, body, error in [
    ('fn i32 f(i32[1] a){a[0]=0;return 42;}', 'let i32[1] a=[42;1];return f(a);', 'type'),
    ('fn i32 f(i32[1] a){let i32[1] b=[42;1];a=b;return 42;}', 'let i32[1] a=[42;1];return f(a);', 'type'),
    ('fn i32 f(i32[2] a){return a[0];}', 'let i32[1] a=[42;1];return f(a);', 'type'),
    ('fn i32 f(u32[1] a){return 42;}', 'let i32[1] a=[42;1];return f(a);', 'type'),
    ('fn i32 f(i32[1] a){return 42;}', 'return f(42);', 'type'),
    ('fn i32 f(i32[1] a){return 42;}', 'let i32[1] a=[42;1];return f((a));', 'type'),
    ('fn i32 f(i32[1] a){return 42;}', 'let i32[1] a=[42;1];return f(a[0]);', 'type'),
    ('fn i32 f(i32[1] a){return 42;}', 'let i32[1] a=[42;1];return f(a.len);', 'type'),
    ('fn i32 f(i32[1] a){return a;}', 'let i32[1] a=[42;1];return f(a);', 'type'),
    ('fn i32 f(i32[1] a){let i32 a=42;return a;}', 'return 42;', 'type'),
    ('fn i32 f(i32[1] a){return 0;}', 'let i32[1] a=[42;1];for(var i32 n=f(a);n<1;n=n+1){}return 42;', 'type'),
    ('fn bool f(i32[1] a){return false;}', 'let i32[1] a=[42;1];for(;f(a);){}return 42;', 'type'),
    ('fn i32 f(i32[1] a){return 1;}', 'let i32[1] a=[42;1];var i32 n=0;for(;n<1;n=f(a)){}return 42;', 'type'),
    ('fn i32 f(Option<i32>[1] a){return 42;}', 'return 42;', 'type'),
    ('fn i32[1] f(){return 0;}', 'return 42;', 'syntax'),
    ('fn i32 f(i32[] a){return 42;}', 'return 42;', 'type'),
    ('fn i32 f(ref i32[1] a){return 42;}', 'return 42;', 'type'),
]:
    case(functions, body, error=error, code=3)

example = root / 'examples/array-parameters.brc'
case('', profile='copy', source_text=example.read_text(encoding='utf-8'))
report.write_text(json.dumps({'schema': 'browniec.m2-array-parameters-cli/v1', 'status': 'passed',
    'profile': args.profile, 'exeSha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'runtimeEnvironment': 'cleared; tool-free PATH', 'count': len(rows), 'cases': rows}, indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} source array parameter CLI cases')
