"""Run in-place repeated-literal assignment programs through the actual native CLI."""
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
output = root / 'build/m2-array-literal-assignment' / args.profile
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


for tag,values in [('i32',['-2147483648','42','2147483647']),('i64',['-9223372036854775808','42','9223372036854775807']),('u8',['0','255']),('u32',['0','4294967295']),('usize',['0','9223372036854775808','18446744073709551615']),('bool',['false','true'])]:
    for value in values:
        for length in [1,4096]:
            for variable in [False,True]:
                zero='false' if tag=='bool' else '0'
                binding=f'let {tag} value={value};' if variable else ''
                fill='value' if variable else value
                case(f'module main;fn i32 main(){{var {tag}[{length}] a=[{zero};{length}];{binding}a=[{fill};{length}];if(a[{length-1}]=={value} && a.len=={length}){{return 42;}}return 0;}}')
fixtures=(root/'tests/m2/array_literal_assignment.fy').read_text(encoding='utf-8')
for source,_limit in re.findall(r'result\(b"([^"\n]+)",(\d+)\);',fixtures):
    case(source,mode='check')
    case(source)
for body,error in [
    ('let i32[1] a=[0;1];a=[42;1];','type'),
    ('var i32[1] a=[0;1];a=[42;2];','type'),
    ('var i32[1] a=[0;1];a=[42;0];','type'),
    ('var i32[1] a=[0;1];a=[42;4097];','type'),
    ('var i32[1] a=[0;1];a=[true;1];','type'),
    ('var i32[1] a=[0;1];let u32 n=42;a=[n;1];','type'),
    ('var u8[1] a=[0;1];a=[-1;1];','type'),
    ('var u8[1] a=[0;1];a=[256;1];','type'),
    ('var i32[1] a=[0;1];a=[42;1+0];','syntax'),
    ('var i32[1] a=[0;1];a=[21,21];','syntax'),
    ('var i32[1] a=[0;1];for(a=[42;1];false;){}','type'),
    ('var i32[1] a=[0;1];for(;false;a=[42;1]){}','type'),
]:
    source='module main;fn i32 main(){'+body+'return 42;}'
    case(source,error=error,code=3,mode='check')
    case(source,error=error,code=3)
basic='module main;fn i32 main(){var i32[1] a=[0;1];a=[42;1];return a[0];}'
case(basic,fuel=65756)
case(basic,error='fuel',code=5,fuel=65755)
case(basic,error='fuel',code=5,fuel=0)
for count in [16,17]:
    source='module main;fn i32 main(){'+''.join(f'var u8[1] a{i}=[0;1];' for i in range(count))+'a15=[42;1];if(a15[0]==42){return 42;}return 0;}'
    case(source,error='compile_limit' if count==17 else None,code=3 if count==17 else 0)
for extra in [False,True]:
    source='module main;fn i32 main(){'+''.join(f'var u8[4096] a{i}=[0;4096];' for i in range(16))
    # Sixteen occupied descriptors and the full 64KiB arena: no spare result site.
    source+=('var u8[1] extra=[0;1];' if extra else '')+'a15=[42;4096];if(a15[4095]==42 && a0[0]==0){return 42;}return 0;}'
    case(source,error='compile_limit' if extra else None,code=3 if extra else 0)
for value,error in [('2147483647+1','overflow'),('42/0','zero_divisor')]:
    case('module main;fn i32 main(){var i32[1] a=[0;1];a=['+value+';1];return a[0];}',error=error,code=5)
# Compose fills with nested value arms at the shared depth boundary. Keep these
# alongside the scalar suite's mixed-depth cases to catch native parser overflow.
for depth in [10,11]:
    expression='42'
    for _ in range(depth):
        expression='switch(x){case .some(_):{if(true){a=['+expression+';1];}42}case .none:{0}}'
    case('module main;fn i32 main(){var i32[1] a=[0;1];let Option<i32> x=.some(1);return '+expression+';}',
         error='compile_limit' if depth==11 else None,code=3 if depth==11 else 0)
assert len(rows)==115,len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-literal-assignment-cli/v1',status='passed',profile=args.profile,
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} in-place literal-assignment CLI cases')
