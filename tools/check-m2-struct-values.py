"""Exercise entry-owned scalar-field struct values through the native CLI."""
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
output=root/'build/m2-struct-values'/args.profile
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
    code=5 if error in ['fuel','array_limit'] else 3 if error else 0
    assert ran.returncode==code and not ran.stderr,(source,ran.returncode,ran.stdout,ran.stderr)
    result=json.loads(ran.stdout)
    assert result['schema']=='browniec.result/v1' and result['command']==mode,result
    assert result['status']==('error' if error else 'checked' if mode=='check' else 'completed'),result
    assert result['return_i32']==(None if error or mode=='check' else 42),result
    if error:
        assert result['error']['kind']==error and 0<=result['error']['byte_offset']<=len(data),result
    else:
        assert result['error'] is None and result['profile']=='brownie.m2-struct-read/1',result
    rows.append(dict(command=command,sourceSha256=hashlib.sha256(data).hexdigest(),exit=code,result=result))


def both(source,error=None):
    case(source,error,'check')
    case(source,error)


for tag,values in [('i32',['-2147483648','42','2147483647']),('i64',['-9223372036854775808','42','9223372036854775807']),('u8',['0','255']),('u32',['0','4294967295']),('usize',['0','9223372036854775808','18446744073709551615']),('bool',['false','true'])]:
    for value in values:
        for binding in ['let','var']:
            both(f'module main;struct P{{{tag} x;}}fn i32 main(){{{binding} P p=P{{.x={value}}};if(p.x=={value}){{return 42;}}return 0;}}')
point='module main;struct Pair{i32 x;i32 y;}fn i32 main(){let Pair p=Pair{.x=20,.y=22};return p.x+p.y;}'
both(point)
case(point,fuel=194317)
case(point,'fuel',fuel=194316)
case(point,'fuel',fuel=65536)
case(point,'fuel',fuel=0)
for count in [15,16]:
    source='module main;struct P{i32 x;}fn i32 main(){let i32[1] a=[2;1];'+''.join(f'let P p{i}=P{{.x=40}};' for i in range(count))+'return a[0]+p14.x;}'
    case(source,'array_limit' if count==16 else None)
both('module main;struct P{'+''.join(f'usize f{i};' for i in range(16))+'}fn i32 main(){let P p=P{'+','.join(f'.f{i}=42' for i in range(16))+'};if(p.f15==42){return 42;}return 0;}')
fixtures=(root/'tests/m2/struct_values.fy').read_text()
import re
for text in re.findall(r'value\(b"([^"\n]+)"\);',fixtures): both(text)
for count in [16,17]:
    source='module main;struct P{i32 x;}fn i32 main(){'+''.join(f'let P p{i}=P{{.x=42}};' for i in range(count))+'return p15.x;}'
    both(source,'compile_limit' if count==17 else None)
for count in [15,16]:
    source='module main;struct P{i32 x;}fn i32 main(){'+''.join(f'{{let P p{i}=P{{.x=42}};}}' for i in range(count))+'let P last=P{.x=42};return last.x;}'
    both(source,'compile_limit' if count>=16 else None)
for fields in [16,17]:
    declarations=''.join(f'u8 f{i};' for i in range(fields))
    initializers=','.join(f'.f{i}=42' for i in range(fields))
    both('module main;struct P{'+declarations+'}fn i32 main(){let P p=P{'+initializers+'};if(p.f15==42){return 42;}return 0;}', 'compile_limit' if fields==17 else None)
for source,error in [
    ('struct P{i32 x;i32 y;}fn i32 main(){let P p=P{.x=42};return 42;}','syntax'),
    ('struct P{i32 x;i32 y;}fn i32 main(){let P p=P{.y=42,.x=0};return 42;}','type'),
    ('struct P{i32 x;i32 y;}fn i32 main(){let P p=P{.x=42,.x=0};return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=true};return 42;}','type'),
    ('struct P{u8 x;}fn i32 main(){let P p=P{.x=256};return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.other=42};return 42;}','type'),
    ('struct P{i32 x;}struct Q{i32 x;}fn i32 main(){let P p=Q{.x=42};return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=p.x};return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=42};let P p=P{.x=42};return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=42};let P q=p;return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){var P p=P{.x=42};p.x=0;return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){var P p=P{.x=42};p=p;return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return p;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return p.missing;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return p.x.y;}','syntax'),
    ('struct P{i32 x;}fn i32 main(){{let P p=P{.x=42};}return p.x;}','type'),
    ('struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};return p.x;}fn i32 main(){return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){for(let P p=P{.x=42};false;){}return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=42};for(;false;p=p){}return 42;}','type'),
    ('struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return main();}','type'),
    ('struct P{i32 x;}struct Outer{P p;}fn i32 main(){let Outer o=Outer{.p=P{.x=42}};return 42;}','type'),
    ('struct P{usize a;usize b;usize c;usize d;usize e;usize f;usize g;usize h;usize i;usize j;usize k;usize l;usize m;usize n;usize o;usize p;u8 q;}fn i32 main(){return 42;}','compile_limit'),
]: both('module main;'+source,error)
for depth in [1,3,5,7,8]:
    expression='42'
    for i in range(depth):
        expression='switch(f){case .some(_):{let P inner'+str(i)+'=P{.x='+expression+'};inner'+str(i)+'.x}case .none:{0}}'
    both('module main;struct P{i32 x;}fn i32 main(){let Option<i32> f=.some(1);let P p=P{.x='+expression+'};return p.x;}', 'compile_limit' if depth==8 else None)
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-values-cli/v1',status='passed',profile=args.profile,
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} struct value CLI cases')
