"""Exercise atomic root constructor assignment through the native CLI."""
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
output=root/'build/m2-struct-replace-source'/args.profile
output.mkdir(parents=True,exist_ok=True)
receipt=output/'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n',encoding='utf-8')
empty=output/'no-runtime-tools'
empty.mkdir(exist_ok=True)
env={key:str(empty) for key in ['PATH','TEMP','TMP']}
env.update({key:os.environ[key] for key in ['SystemRoot','WINDIR'] if key in os.environ})
exe=args.exe.resolve(strict=True)
rows=[]


def case(source,error=None,mode='run',fuel=1000000,profile='brownie.m2-struct-copy/1'):
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


def both(source,error=None,profile='brownie.m2-struct-copy/1'):
    case(source,error,'check',profile=profile)
    case(source,error,profile=profile)


import re
for text in re.findall(r'value\(b"([^"\n]+)"\);',(root/'tests/m2/struct_replace_source.fy').read_text()):
 both(text,profile='brownie.m2-struct-nested/1' if 'struct R{' in text else 'brownie.m2-struct-copy/1')
basic='module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p=P{.x=42};return p.x;}'
both(basic)
case(basic,'fuel',fuel=0)
case(basic,fuel=199180)
case(basic,'fuel',fuel=199179)
for tag,value,zero in [('bool','true','false'),('u8','255','0'),('i32','-2147483648','0'),('i64','-9223372036854775808','0'),('u32','4294967295','0'),('usize','18446744073709551615','0')]:
 both(f'module main;struct P{{{tag} x;}}fn i32 main(){{var P p=P{{.x={zero}}};p=P{{.x={value}}};if(p.x=={value}){{return 42;}}return 0;}}')
for body,error in [
 ('let P p=P{.x=0};p=P{.x=42};return 42;','type'),
 ('var P p=P{.x=0};p=Q{.x=42};return 42;','type'),
 ('var P p=P{.x=0};p=Missing{.x=42};return 42;','type'),
 ('var P p=P{.x=0};p=P{.x=true};return 42;','type'),
 ('var P p=P{.x=0};p=P{.wrong=42};return 42;','type'),
 ('var P p=P{.x=0};p=P{};return 42;','syntax'),
 ('var P p=P{.x=0};p=P{.x=42,.x=0};return 42;','syntax'),
 ('var P p=P{.x=0};p=P{.x=42}return 42;','syntax'),
 ('var P p=P{.x=0};p=(P{.x=42}).x;return 42;','type'),
 ('var P p=P{.x=0};for(p=P{.x=42};false;){}return 42;','type'),
 ('var P p=P{.x=0};for(;false;p=P{.x=42}){}return 42;','type'),
 ('{var P p=P{.x=0};}p=P{.x=42};return 42;','type'),
 ('var P p=P{.x=0};p=P{.x=p};return 42;','type'),
 ('var P p=P{.x=0};p=P{.x=.some(42)};return 42;','type'),
]:both('module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){'+body+'}',error)
for count in [15,16]:
 arrays=''.join(f'let i32[1] a{n}=[0;1];' for n in range(count))
 src=basic.replace('var P p=',arrays+'var P p=')
 case(src,mode='check');case(src,'array_limit' if count==16 else None)
# Fill all sixteen static sites without exhausting runtime Fuel in the CLI.
extra=''.join(f'{{let P t{n}=P{{.x=0}};}}' for n in range(15))
case(basic.replace('p=P{.x=42};',extra+'p=P{.x=42};'),mode='check')
case(basic.replace('p=P{.x=42};',extra+'{let P last=P{.x=0};}p=P{.x=42};'),'compile_limit',mode='check')
for tag in ['u8','usize']:
 fields=''.join(f'{tag} f{n};' for n in range(16));zeros=','.join(f'.f{n}=0' for n in range(16));vals=','.join(f'.f{n}=42' for n in range(16))
 both('module main;struct P{'+fields+'}fn i32 main(){var P p=P{'+zeros+'};p=P{'+vals+'};if(p.f0==42 && p.f15==42){return 42;}return 0;}')
for depth in [2,8,16,17]:
 defs='struct T0{i32 x;}'+''.join(f'struct T{n}{{T{n-1} c;}}' for n in range(1,depth))
 zero='T0{.x=0}';value='T0{.x=42}'
 for n in range(1,depth):zero=f'T{n}{{.c={zero}}}';value=f'T{n}{{.c={value}}}'
 both('module main;'+defs+f'fn i32 main(){{var T{depth-1} p={zero};p={value};return p'+'.c'*(depth-1)+'.x;}','compile_limit' if depth==17 else None,profile='brownie.m2-struct-nested/1')
# RHS faults abort; they cannot publish partial replacement output.
for expression,error in [('2147483647+1','overflow'),('1/0','zero_divisor')]:
 src=basic.replace('.x=42}',f'.x={expression}'+'}')
 case(src,mode='check');case(src,error)
# Guard parser stack limits when constructors contain statement-bearing value arms.
for depth in [15,16]:
 expr='42'
 for _ in range(depth):expr='switch(f){case .some(_):{'+expr+'}case .none:{0}}'
 src=basic.replace('p=P{.x=42};','let Option<i32> f=.some(1);p=P{.x='+expr+'};')
 both(src,'compile_limit' if depth==16 else None)
for depth in [7,8]:
 expr='42'
 for _ in range(depth):expr='switch(f){case .some(_):{p=P{.x='+expr+'};42}case .none:{0}}'
 src=basic.replace('p=P{.x=42};','let Option<i32> f=.some(1);p=P{.x='+expr+'};')
 both(src,'compile_limit' if depth==8 else None)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_constructor_assignment'] is True and version['struct_copy_profile']=='brownie.m2-struct-copy/1',version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-replace-source-cli/v1',status='passed',profile=args.profile,
 exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} constructor-assignment CLI cases')
