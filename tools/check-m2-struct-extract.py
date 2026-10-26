"""Exercise entry-owned scalar-field nested struct subrecord extraction through the native CLI."""
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
output=root/'build/m2-struct-extract'/args.profile
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
for text in re.findall(r'value\(b"([^"\n]+)"\);',(root/'tests/m2/struct_extract_source.fy').read_text()):both(text)
basic='module main;struct I{i32 x;}struct R{I i;}fn i32 main(){let R p=R{.i=I{.x=42}};let I i=p.i;return i.x;}'
both(basic)
case(basic,fuel=240523)
case(basic,'fuel',fuel=240522)
case(basic,'fuel',fuel=0)
for tag,value in [('bool','true'),('u8','255'),('i32','-2147483648'),('i64','-9223372036854775808'),('u32','4294967295'),('usize','18446744073709551615')]:
 for source_kind in ['let','var']:
  for target_kind in ['let','var']:
   both(f'module main;struct I{{{tag} x;}}struct R{{u8 head;I i;}}fn i32 main(){{{source_kind} R p=R{{.head=255,.i=I{{.x={value}}}}};{target_kind} I i=p.i;if(i.x=={value}){{return 42;}}return 0;}}')
for body,error in [
 ('let I i=unknown.i;return 42;','type'),
 ('let I i=i.i;return 42;','type'),
 ('let i32 p=42;let I i=p.i;return 42;','type'),
 ('let i32[1] p=[42;1];let I i=p.i;return 42;','type'),
 ('{let R p=R{.i=I{.x=42}};}let I i=p.i;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let J i=p.i;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let I i=p.i.x;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let I i=p.missing;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let I i=p..i;return 42;','syntax'),
 ('let R p=R{.i=I{.x=42}};let I i=p.i();return 42;','syntax'),
 ('let R p=R{.i=I{.x=42}};let I i=(p.i);return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let I i=p.i+1;return 42;','syntax'),
 ('let R p=R{.i=I{.x=42}};let I i=p.i;return p.i;','type'),
 ('var R p=R{.i=I{.x=42}};p.i=p.i;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};var I i=I{.x=0};i=p.i;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let I i=p.i;i.x=0;return 42;','type'),
 ('let R p=R{.i=I{.x=42}};for(let I i=p.i;false;){}return 42;','type'),
 ('let R p=R{.i=I{.x=42}};let I i=p.i;let I i=p.i;return 42;','type'),
]:both('module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){'+body+'}',error)
for count in [14,15]:
 arrays=''.join(f'let i32[1] a{n}=[0;1];' for n in range(count))
 src=basic.replace('let R p=',arrays+'let R p=')
 case(src,mode='check');case(src,'array_limit' if count==15 else None)
for depth in [2,8,16]:
 defs='struct T0{i32 x;}'+''.join(f'struct T{n}{{T{n-1} c;}}' for n in range(1,depth))
 init='T0{.x=42}'
 for n in range(1,depth):init=f'T{n}{{.c={init}}}'
 both('module main;'+defs+f'fn i32 main(){{let T{depth-1} p={init};let T0 i=p'+'.c'*(depth-1)+';return i.x;}')
for leaves in [16,17]:
 fields=''.join(f'usize f{n};' for n in range(16))
 vals=','.join(f'.f{n}=42' for n in range(16))
 extra='u8 tail;' if leaves==17 else ''
 extra_value=',.tail=0' if leaves==17 else ''
 src='module main;struct I{'+fields+'}struct R{I i;'+extra+'}fn i32 main(){let R p=R{.i=I{'+vals+'}'+extra_value+'};let I i=p.i;if(i.f15==42){return 42;}return 0;}'
 both(src,'compile_limit' if leaves==17 else None)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_subrecord_initializers'] is True and version['struct_nested_profile']=='brownie.m2-struct-nested/1',version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-extract-cli/v1',status='passed',profile=args.profile,
 exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} subrecord-extraction CLI cases')
