"""Exercise entry-owned scalar-field nested struct constructors, paths and root copies through the native CLI."""
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
output=root/'build/m2-struct-source-nested'/args.profile
output.mkdir(parents=True,exist_ok=True)
receipt=output/'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n',encoding='utf-8')
empty=output/'no-runtime-tools'
empty.mkdir(exist_ok=True)
env={key:str(empty) for key in ['PATH','TEMP','TMP']}
env.update({key:os.environ[key] for key in ['SystemRoot','WINDIR'] if key in os.environ})
exe=args.exe.resolve(strict=True)
rows=[]


def case(source,error=None,mode='run',fuel=1000000,profile='brownie.m2-struct-nested/1'):
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
        assert result['error'] is None and result['profile']==profile,result
    rows.append(dict(command=command,sourceSha256=hashlib.sha256(data).hexdigest(),exit=code,result=result))


def both(source,error=None,profile='brownie.m2-struct-nested/1'):
    case(source,error,'check',profile=profile)
    case(source,error,profile=profile)


import re
fixtures=(root/'tests/m2/struct_source_nested.fy').read_text()
for text in re.findall(r'value\(b"([^"\n]+)"\);',fixtures): both(text)
for tag,values in [('i32',['-2147483648','42','2147483647']),('i64',['-9223372036854775808','9223372036854775807']),('u8',['0','255']),('u32',['0','4294967295']),('usize',['0','18446744073709551615']),('bool',['false','true'])]:
    zero='false' if tag=='bool' else '0'
    for value in values:
        both(f'module main;struct I{{{tag} x;}}struct R{{u8 head;I a;I b;i32 tail;}}fn i32 main(){{var R p=R{{.head=1,.a=I{{.x={value}}},.b=I{{.x={zero}}},.tail=0}};p.b.x=p.a.x;p.tail=42;if(p.a.x=={value} && p.b.x=={value}){{return p.tail;}}return 0;}}')
basic='module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};return p.i.x;}'
both(basic)
case(basic,'fuel',fuel=0)
for body,error in [
 ('let R p=R{.i=R{.i=I{.x=42}}};return 42;','type'),
 ('let i32 n=42;let R p=R{.i=n};return 42;','type'),
 ('let R p=R{.i=I{.x=true}};return 42;','type'),
 ('let R p=R{.i=I{.x=42}};p.i.x=0;return 42;','type'),
 ('var R p=R{.i=I{.x=42}};p.i.x=true;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};return p.i;','type'),
 ('let R p=R{.i=I{.x=42}};return p.i.missing;','type'),
 ('let R p=R{.i=I{.x=42}};p.i=p.i;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let I i=p.i.x;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};return p.i.x.y;','syntax'),
 ('let R p=R{.i=I{.x=42}};return p.i..x;','syntax'),
 ('let R p=R{.i=I{.x=42}};let R q=(p);return 42;','type'),
 ('let R p=R{.i=I{.x=p.i.x}};return 42;','type'),
 ('{let R p=R{.i=I{.x=42}};}return p.i.x;','type'),
 ('let R p=R{.i=I{.x=42}};return main();','type'),
 ('var R p=R{.i=I{.x=0}};for(p.i.x=1;false;){}return 42;','type'),
 ('var R p=R{.i=I{.x=0}};for(;false;p.i.x=1){}return 42;','type'),
 ('for(let R p=R{.i=I{.x=42}};false;){}return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p=R{.i=I{.x=42}};return 42;','type'),
]: both('module main;struct I{i32 x;}struct R{I i;}fn i32 main(){'+body+'}',error)
for fields,error in [('.y=20,.x=22','type'),('.x=20,.x=22','type'),('.x=42','syntax'),('.x=20,.y=22,.y=0','syntax')]:
 both('module main;struct I{i32 x;i32 y;}struct R{I i;}fn i32 main(){let R p=R{.i=I{'+fields+'}};return 42;}',error)
both('module main;struct I{i32 x;}struct R{I i;}fn i32 helper(){let R p=R{.i=I{.x=42}};return p.i.x;}fn i32 main(){return 42;}','type')
# Maximum source traversal depth and sixteen-leaf staging bounds.
for depth in [2,8,16,17]:
 defs='struct T0{i32 x;}'+''.join(f'struct T{i}{{T{i-1} child;}}' for i in range(1,depth))
 value='T0{.x=42}'
 for i in range(1,depth):value=f'T{i}{{.child={value}}}'
 path='p'+'.child'*(depth-1)+'.x'
 both('module main;'+defs+f'fn i32 main(){{var T{depth-1} p={value};{path}=42;return {path};}}', 'compile_limit' if depth==17 else None)
for leaves in [16,17]:
 fields=''.join(f'u8 f{i};' for i in range(leaves-1))
 values=','.join(f'.f{i}=1' for i in range(leaves-1))
 both('module main;struct I{'+fields+'}struct R{I i;i32 tail;}fn i32 main(){let R p=R{.i=I{'+values+'},.tail=42};return p.tail;}', 'compile_limit' if leaves==17 else None)
# Oversized selected root, although the same unselected declaration is legal.
fields=''.join(f'usize f{i};' for i in range(16))
values=','.join(f'.f{i}=0' for i in range(16))
both('module main;struct I{'+fields+'}struct R{I i;u8 extra;}fn i32 main(){let R p=R{.i=I{'+values+'},.extra=0};return 42;}','compile_limit')
both('module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let I p=I{.x=42};return p.x;}',profile='brownie.m2-struct-read/1')
# Nested subobjects do not consume extra sites/owners.
for count in [16,17]:
 both('module main;struct I{i32 x;}struct R{I i;}fn i32 main(){'+''.join(f'let R p{i}=R{{.i=I{{.x=42}}}};' for i in range(count))+'return p15.i.x;}', 'compile_limit' if count==17 else None)
arrays=''.join(f'let i32[1] a{i}=[0;1];' for i in range(15))
both('module main;struct I{i32 x;}struct R{I i;}fn i32 main(){'+arrays+'var R p=R{.i=I{.x=0}};p.i.x=42;p=p;return p.i.x;}')
case('module main;struct I{i32 x;}struct R{I i;}fn i32 main(){'+arrays+'let R p=R{.i=I{.x=42}};let R q=p;return q.i.x;}','array_limit')
# Existing composed constructor expression guard must still reject cleanly.
for depth in [1,5,7,8]:
 expression='42'
 for i in range(depth):
  expression='switch(f){case .some(_):{let R inner'+str(i)+'=R{.i=I{.x='+expression+'}};inner'+str(i)+'.i.x}case .none:{0}}'
 both('module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let Option<i32> f=.some(1);let R p=R{.i=I{.x='+expression+'}};return p.i.x;}', 'compile_limit' if depth==8 else None)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_nested_profile']=='brownie.m2-struct-nested/1' and version['struct_copy_profile']=='brownie.m2-struct-copy/1',version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-source-nested-cli/v1',status='passed',profile=args.profile,
 exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} nested struct CLI cases')
