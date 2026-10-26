"""Exercise entry-owned scalar-field struct copies and whole-record assignment through the native CLI."""
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
output=root/'build/m2-struct-source-copy'/args.profile
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
        assert result['error'] is None and result['profile']=='brownie.m2-struct-copy/1',result
    rows.append(dict(command=command,sourceSha256=hashlib.sha256(data).hexdigest(),exit=code,result=result))


def both(source,error=None):
    case(source,error,'check')
    case(source,error)


for tag,values in [('i32',['-2147483648','42','2147483647']),('i64',['-9223372036854775808','9223372036854775807']),('u8',['0','255']),('u32',['0','4294967295']),('usize',['0','18446744073709551615']),('bool',['false','true'])]:
    zero='false' if tag=='bool' else '0'
    for value in values:
        both(f'module main;struct P{{{tag} x;}}fn i32 main(){{let P p=P{{.x={value}}};var P q=p;let P r=q;q.x={zero};q=r;if(q.x=={value} && p.x=={value}){{return 42;}}return 0;}}')
import re
fixtures=(root/'tests/m2/struct_source_copy.fy').read_text()
for text in re.findall(r'value\(b"([^"\n]+)"\);',fixtures): both(text)
copy='module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};let P q=p;return q.x;}'
assign='module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=42};p=p;return p.x;}'
both(copy)
both(assign)
both('module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x=42;let P q=p;return q.x;}')
both('module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};{let P q=P{.x=42};p=q;}return p.x;}')
case(copy,'fuel',fuel=0)
case(assign,'fuel',fuel=65536)
for body,error in [
    ('let P p=p;return 42;','type'),
    ('let P p=P{.x=42};let P p=p;return 42;','type'),
    ('let P p=P{.x=42};p=p;return 42;','type'),
    ('let i32 n=42;let P p=n;return 42;','type'),
    ('let i32[1] a=[42;1];let P p=a;return 42;','type'),
    ('let P p=P{.x=42};let Q q=p;return 42;','type'),
    ('var P p=P{.x=42};let Q q=Q{.x=42};p=q;return 42;','type'),
    ('var P p=P{.x=42};let i32 n=42;p=n;return 42;','type'),
    ('var P p=P{.x=42};p=unknown;return 42;','type'),
    ('var P p=P{.x=42};p=P{.x=42};return 42;','type'),
    ('let P p=P{.x=42};let P q=p.x;return 42;','type'),
    ('let P p=P{.x=42};let P q=(p);return 42;','type'),
    ('let P p=P{.x=42};let P q=p();return 42;','syntax'),
    ('let P p=P{.x=42};let P q=p return 42;','syntax'),
    ('var P p=P{.x=42};p=p return 42;','syntax'),
    ('var P p=P{.x=42};p=p=p;return 42;','syntax'),
    ('var P p=P{.x=42};let P q=p;for(p=q;false;){}return 42;','type'),
    ('var P p=P{.x=42};let P q=p;for(;false;p=q){}return 42;','type'),
    ('let P p=P{.x=42};for(let P q=p;false;){}return 42;','type'),
    ('{let P p=P{.x=42};}let P q=p;return 42;','type'),
    ('var P p=P{.x=42};{let P q=p;}p=q;return 42;','type'),
    ('let P p=P{.x=42};return p;','type'),
    ('let P p=P{.x=42};let P q=p;return main();','type'),
]: both('module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){'+body+'}',error)
both('module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};let P q=p;return 42;}fn i32 main(){return 42;}','type')
# Sixteen static record sites remain bounded even when runtime scopes are disjoint.
for count in [15,16]:
    body='let P p=P{.x=42};'+''.join(f'let P q{i}=p;' for i in range(count))
    both('module main;struct P{i32 x;}fn i32 main(){'+body+'return p.x;}', 'compile_limit' if count==16 else None)
for count in [14,15]:
    arrays=''.join(f'let i32[1] a{i}=[0;1];' for i in range(count))
    source='module main;struct P{i32 x;}fn i32 main(){'+arrays+'let P p=P{.x=42};let P q=p;return q.x;}'
    case(source,mode='check')
    case(source,'array_limit' if count==15 else None)
# A full shared owner table can still overwrite or self-assign an existing record.
arrays=''.join(f'let i32[1] a{i}=[0;1];' for i in range(14))
both('module main;struct P{i32 x;}fn i32 main(){'+arrays+'let P p=P{.x=42};var P q=P{.x=0};q=p;q=q;return q.x;}')
# Full 128-byte, sixteen-field roots copy/assign with no shape widening.
fields=''.join(f'usize f{i};' for i in range(16))
values=','.join(f'.f{i}=18446744073709551615' for i in range(16))
both('module main;struct P{'+fields+'}fn i32 main(){let P p=P{'+values+'};var P q=p;q=p;if(q.f0==18446744073709551615 && q.f15==18446744073709551615){return 42;}return 0;}')
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_copy_profile']=='brownie.m2-struct-copy/1' and version['struct_write_profile']=='brownie.m2-struct-write/1',version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-source-copy-cli/v1',status='passed',profile=args.profile,
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} struct copy/assignment CLI cases')
