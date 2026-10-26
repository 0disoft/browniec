"""Exercise entry-owned scalar-field struct field writes through the native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser=argparse.ArgumentParser()
parser.add_argument('--exe',required=True,type=Path)
parser.add_argument('--profile',required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
output=root/'build/m2-struct-write'/args.profile
output.mkdir(parents=True,exist_ok=True)
receipt=output/'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n',encoding='utf-8')
empty=output/'no-runtime-tools'
empty.mkdir(exist_ok=True)
env={key:str(empty) for key in ['PATH','TEMP','TMP']}
env.update({key:os.environ[key] for key in ['SystemRoot','WINDIR'] if key in os.environ})
exe=args.exe.resolve(strict=True)
rows=[]


def case(source,error=None,mode='run',fuel=1000000):
    data=source.encode()
    path=output/f'case-{len(rows):03}.brc'
    path.write_bytes(data)
    command=[str(exe),mode,str(path),'--json']
    if mode=='run': command+=['--fuel',str(fuel)]
    ran=subprocess.run(command,cwd=empty,env=env,capture_output=True,timeout=10)
    code=5 if error in ['fuel','array_limit','overflow','zero_divisor'] else 3 if error else 0
    assert ran.returncode==code and not ran.stderr,(source,ran.returncode,ran.stdout,ran.stderr)
    result=json.loads(ran.stdout)
    assert result['schema']=='browniec.result/v1' and result['command']==mode,result
    assert result['status']==('error' if error else 'checked' if mode=='check' else 'completed'),result
    assert result['return_i32']==(None if error or mode=='check' else 42),result
    if error:
        assert result['error']['kind']==error and 0<=result['error']['byte_offset']<=len(data),result
    else:
        assert result['error'] is None and result['profile']=='brownie.m2-struct-write/1',result
    rows.append(dict(command=command,sourceSha256=hashlib.sha256(data).hexdigest(),exit=code,result=result))


def both(source,error=None):
    case(source,error,'check')
    case(source,error)


for tag,values in [('i32',['-2147483648','42','2147483647']),('i64',['-9223372036854775808','42','9223372036854775807']),('u8',['0','255']),('u32',['0','4294967295']),('usize',['0','9223372036854775808','18446744073709551615']),('bool',['false','true'])]:
    zero='false' if tag=='bool' else '0'
    for value in values:
        both(f'module main;struct P{{{tag} x;}}fn i32 main(){{var P p=P{{.x={zero}}};p.x={value};if(p.x=={value}){{return 42;}}return 0;}}')
        both(f'module main;struct P{{{tag} x;}}fn i32 main(){{let P p=P{{.x={zero}}};p.x={value};return 42;}}','type')
import re
fixtures=(root/'tests/m2/struct_write.fy').read_text()
for text in re.findall(r'value\(b"([^"\n]+)"\);',fixtures): both(text)
basic='module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x=42;return p.x;}'
both(basic)
case(basic,fuel=194314)
case(basic,'fuel',fuel=194313)
case(basic,'fuel',fuel=65536)
case(basic,'fuel',fuel=0)
for body,error in [
    ('let P p=P{.x=0};p.x=42;return p.x;','type'),
    ('var P p=P{.x=0};p.x=true;return 42;','type'),
    ('var P p=P{.x=0};let u32 n=42;p.x=n;return 42;','type'),
    ('var P p=P{.x=0};p.missing=42;return 42;','type'),
    ('var P p=P{.x=0};p.x.y=42;return 42;','syntax'),
    ('var P p=P{.x=0};p.x+=42;return 42;','syntax'),
    ('var P p=P{.x=0};p.x=42 return 42;','syntax'),
    ('var P p=P{.x=0};return p.x=42;','syntax'),
    ('var P p=P{.x=0};for(p.x=1;false;){}return 42;','type'),
    ('var P p=P{.x=0};for(;false;p.x=1){}return 42;','type'),
    ('var P p=P{.x=0};p=p;return 42;','type'),
    ('{var P p=P{.x=0};}p.x=42;return 42;','type'),
]: both('module main;struct P{i32 x;}fn i32 main(){'+body+'}',error)
for expression,error in [('1/0','zero_divisor'),('2147483647+1','overflow')]:
    case('module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x='+expression+';return p.x;}',error)
both('module main;struct P{u32 x;}fn i32 main(){var P p=P{.x=0};let u8 n=42;p.x=n as u32;if(p.x==42){return 42;}return 0;}')
both('module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};for(var i32 i=0;p.x<2;i=i+1){p.x=p.x+1;}p.x=p.x+40;return p.x;}')
both('module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};var i32 n=0;while(n<3){var P q=P{.x=0};let i32[1] a=[14;1];q.x=a[0];p.x=p.x+q.x;n=n+1;if(n<3){continue;}break;}return p.x;}')
for count in [15,16]:
    source='module main;struct P{i32 x;}fn i32 main(){'+''.join(f'var P p{i}=P{{.x=0}};' for i in range(count))+f'p{count-1}.x=42;return p{count-1}.x;}}'
    both(source)
for depth in [1,10,11]:
    expression='42'
    for _ in range(depth):
        expression='switch(f){case .some(_):{if(true){p.x='+expression+';}42}case .none:{0}}'
    both('module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};let Option<i32> f=.some(1);p.x='+expression+';return p.x;}', 'compile_limit' if depth==11 else None)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_write_profile']=='brownie.m2-struct-write/1' and version['struct_read_profile']=='brownie.m2-struct-read/1',version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-write-cli/v1',status='passed',profile=args.profile,
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} struct field-write CLI cases')
