"""Exercise atomic subrecord constructor assignment through the native CLI."""
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
output=root/'build/m2-struct-subreplace-source'/args.profile
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
        assert result['error']['kind']==error and 0<=result['error']['byte_offset']<=len(data),(source,result)
    else:
        assert result['error'] is None and result['profile']==profile,result
    rows.append(dict(command=command,sourceSha256=hashlib.sha256(data).hexdigest(),exit=code,result=result))


def both(source,error=None,profile='brownie.m2-struct-nested/1'):
    case(source,error,'check',profile=profile)
    case(source,error,profile=profile)


import re
for text in re.findall(r'value\(b"([^"\n]+)"\);',(root/'tests/m2/struct_subreplace_source.fy').read_text()):both(text)
basic='module main;struct I{i32 x;}struct R{i32 head;I i;i32 tail;}fn i32 main(){var R p=R{.head=17,.i=I{.x=0},.tail=23};p.i=I{.x=42};return p.i.x;}'
both(basic)
case(basic,'fuel',fuel=0)
case(basic,fuel=240146)
case(basic,'fuel',fuel=240145)
for tag,value,zero in [('bool','true','false'),('u8','255','0'),('i32','-2147483648','0'),('i64','-9223372036854775808','0'),('u32','4294967295','0'),('usize','18446744073709551615','0')]:
 both(f'module main;struct I{{{tag} x;}}struct R{{u8 head;I i;i32 tail;}}fn i32 main(){{var R p=R{{.head=17,.i=I{{.x={zero}}},.tail=23}};p.i=I{{.x={value}}};if(p.head==17 && p.tail==23 && p.i.x=={value}){{return 42;}}return 0;}}')
for body,error in [
 ('let R p=R{.i=I{.x=0}};p.i=I{.x=42};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i=J{.x=42};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i=Missing{.x=42};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i=I{.x=true};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i=I{.wrong=42};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i=I{};return 42;','syntax'),
 ('var R p=R{.i=I{.x=0}};p.i=I{.x=42,.x=0};return 42;','syntax'),
 ('var R p=R{.i=I{.x=0}};p.i=I{.x=42}return 42;','syntax'),
 ('var R p=R{.i=I{.x=0}};p.i=(I{.x=42});return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i.x=I{.x=42};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.missing=I{.x=42};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i.x.x=I{.x=42};return 42;','syntax'),
 ('var R p=R{.i=I{.x=0}};for(p.i=I{.x=42};false;){}return 42;','type'),
 ('var R p=R{.i=I{.x=0}};for(;false;p.i=I{.x=42}){}return 42;','type'),
 ('{var R p=R{.i=I{.x=0}};}p.i=I{.x=42};return 42;','type'),
 ('var R p=R{.i=I{.x=0}};p.i=I{.x=p.i};return 42;','type'),
]:both('module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){'+body+'}',error)
# All roots share one owner table; replacement must work with the last slot used.
for count in [14,15,16]:
 arrays=''.join(f'let i32[1] a{n}=[0;1];' for n in range(count))
 src=basic.replace('var R p=',arrays+'var R p=')
 case(src,mode='check');case(src,'array_limit' if count==16 else None)
# Static sites may be exhausted even when lexical scopes are disjoint.
extra=''.join(f'{{let I t{n}=I{{.x=0}};}}' for n in range(15))
case(basic.replace('p.i=I{.x=42};',extra+'p.i=I{.x=42};'),mode='check')
case(basic.replace('p.i=I{.x=42};',extra+'{let I last=I{.x=0};}p.i=I{.x=42};'),'compile_limit',mode='check')
for tag in ['u8','usize']:
 fields=''.join(f'{tag} f{n};' for n in range(16));zeros=','.join(f'.f{n}=0' for n in range(16));vals=','.join(f'.f{n}=42' for n in range(16))
 src='module main;struct I{'+fields+'}struct R{I i;}fn i32 main(){var R p=R{.i=I{'+zeros+'}};p.i=I{'+vals+'};if(p.i.f0==42 && p.i.f15==42){return 42;}return 0;}'
 both(src)
 both(src.replace('struct R{I i;}','struct R{I i;u8 tail;}').replace('}};p.i=','},.tail=0};p.i='),'compile_limit')
for depth in [2,8,16,17]:
 defs='struct T0{i32 x;}'+''.join(f'struct T{n}{{T{n-1} c;}}' for n in range(1,depth))
 zero='T0{.x=0}'
 for n in range(1,depth):zero=f'T{n}{{.c={zero}}}'
 path='.c'*(depth-1)
 both('module main;'+defs+f'fn i32 main(){{var T{depth-1} p={zero};p{path}=T0{{.x=42}};return p{path}.x;}}','compile_limit' if depth==17 else None)
for expression,error in [('2147483647+1','overflow'),('1/0','zero_divisor')]:
 src=basic.replace('.x=42}',f'.x={expression}'+'}')
 case(src,mode='check');case(src,error)
for depth in [7,8]:
 expr='42'
 for _ in range(depth):expr='switch(f){case .some(_):{p.i=I{.x='+expr+'};42}case .none:{0}}'
 src=basic.replace('p.i=I{.x=42};','let Option<i32> f=.some(1);p.i=I{.x='+expr+'};')
 both(src,'compile_limit' if depth==8 else None)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_subrecord_constructor_assignment'] is True and version['struct_constructor_assignment'] is True and version['struct_nested_profile']=='brownie.m2-struct-nested/1',version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-subreplace-source-cli/v1',status='passed',profile=args.profile,
 exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} subrecord constructor-assignment CLI cases')
