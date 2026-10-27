"""Exercise function-local records through the native CLI."""
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
output=root/'build/m2-struct-function-source'/args.profile
output.mkdir(parents=True,exist_ok=True)
receipt=output/'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n',encoding='utf-8')
empty=output/'no-runtime-tools'
empty.mkdir(exist_ok=True)
env={key:str(empty) for key in ['PATH','TEMP','TMP']}
env.update({key:os.environ[key] for key in ['SystemRoot','WINDIR'] if key in os.environ})
exe=args.exe.resolve(strict=True)
rows=[]


def case(source,error=None,mode='run',fuel=1000000,profile='brownie.m2-struct-read/1'):
    data=source.encode()
    path=output/f'case-{len(rows):03}.brc'
    path.write_bytes(data)
    command=[str(exe),mode,str(path),'--json']
    if mode=='run': command+=['--fuel',str(fuel)]
    ran=subprocess.run(command,cwd=empty,env=env,capture_output=True,timeout=10)
    code=5 if error in ['fuel','array_limit','overflow','zero_divisor','frame_limit'] else 3 if error else 0
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


def both(source,error=None,profile='brownie.m2-struct-read/1'):
    case(source,error,'check',profile=profile)
    case(source,error,profile=profile)


import re
fixtures=(root/'tests/m2/struct_function_source.fy').read_text()
positives=re.findall(r'value\(b"([^"\n]+)"\);',fixtures)
profiles=['write','nested','copy']+['read']*8
assert len(positives)==len(profiles)
for source,kind in zip(positives,profiles):both(source,profile=f'brownie.m2-struct-{kind}/1')
for source in re.findall(r'assert\(!compiler::compile\(b"([^"\n]+)"\).is_ok\);',fixtures):both(source,'type')
for tag,values in [('i32',['-2147483648','42','2147483647']),('i64',['-9223372036854775808','9223372036854775807']),('u8',['0','255']),('u32',['0','4294967295']),('usize',['0','18446744073709551615']),('bool',['false','true'])]:
 for val in values:
  zero='false' if tag=='bool' else '0'
  both(f'module main;struct P{{{tag} x;}}fn i32 helper(){{let P p=P{{.x={val}}};var P q=p;q.x={zero};q=p;if(q.x=={val}){{return 42;}}return 0;}}fn i32 main(){{return helper();}}',profile='brownie.m2-struct-copy/1')
basic='module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};return p.x;}fn i32 main(){return helper();}'
both(basic)
case(basic,'fuel',fuel=0)
case(basic,'fuel',fuel=153033)
case(basic,fuel=153034)
for depth in [0,7,14,15]:
 src='module main;struct P{i32 x;}fn i32 helper(i32 n){let P p=P{.x=0};if(n==0){return 42;}return helper(n-1);}fn i32 main(){let i32[1] a=[0;1];return helper('+str(depth)+')+a[0];}'
 case(src,mode='check');case(src,'array_limit' if depth==15 else None)
for count in [15,16,17]:
 # The static catalog is shared across functions, independently of lexical liveness.
 helper=''.join(f'{{let P p=P{{.x=0}};}}' for _ in range(count-1))
 src='module main;struct P{i32 x;}fn i32 helper(){'+helper+'return 42;}fn i32 main(){let P p=P{.x=0};return helper()+p.x;}'
 both(src,'compile_limit' if count==17 else None)
for expression,error in [('2147483647+1','overflow'),('1/0','zero_divisor')]:
 src=basic.replace('.x=42}',f'.x={expression}'+'}')
 case(src,mode='check');case(src,error)
# An initializer may call a helper before publishing its own binding.
both('module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};return p.x;}fn i32 main(){let P p=P{.x=helper()};return p.x;}')
example=root/'examples/helper-records.brc'
both(example.read_text())
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_helper_locals'] is True and version['restricted'] is False,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-function-source-cli/v1',status='passed',profile=args.profile,
 exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} helper-local record CLI cases')
