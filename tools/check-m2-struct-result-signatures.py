"""Check nominal record-result signatures and source lowering boundaries."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe',required=True,type=Path)
parser.add_argument('--profile',required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
kind='struct-result-signatures'
output=root/('build/m2-'+kind)/args.profile
output.mkdir(parents=True,exist_ok=True)
receipt=output/'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n',encoding='utf-8')
empty=output/'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe=args.exe.resolve(strict=True)
env={key:str(empty) for key in ['PATH','TEMP','TMP']}
env.update({key:os.environ[key] for key in ['SystemRoot','WINDIR'] if key in os.environ})
rows=[]


def case(source,error=None,anchor=None):
    data=source.encode('utf-8')
    for mode in ['check','run']:
        path=output/f'parameter-{len(rows):03}.brc'
        path.write_bytes(data)
        command=[str(exe),mode,str(path),'--json']
        if mode=='run':command.extend(['--fuel','1000000'])
        ran=subprocess.run(command,cwd=empty,env=env,capture_output=True,timeout=15)
        active_error=error
        expected=5 if active_error=='fuel' else 3 if active_error else 0
        assert ran.returncode==expected and not ran.stderr,(source,ran.returncode,ran.stdout,ran.stderr)
        result=json.loads(ran.stdout)
        assert result['schema']=='browniec.result/v1' and result['command']==mode,result
        assert result['status']==('error' if active_error else 'checked' if mode=='check' else 'completed'),result
        assert result['return_i32']==(None if active_error or mode=='check' else 42),result
        if active_error:assert result['error']['kind']==active_error and 0<=result['error']['byte_offset']<=len(data),(source,result)
        if anchor:assert result['error']['byte_offset']==data.index(anchor.encode('utf-8')),(source,result)
        if not active_error:
            assert result['error'] is None,result
            assert result['profile'] in ['brownie.m1-scalar/1','brownie.m2-array-read/1','brownie.m2-struct-read/1','brownie.m2-struct-write/1','brownie.m2-struct-copy/1','brownie.m2-struct-nested/1'],result
        rows.append(dict(command=command,sourceSha256=hashlib.sha256(data).hexdigest(),exit=expected,result=result))


fixtures=(root/'tests/m2/struct_result_signatures.fy').read_text(encoding='utf-8')
for source in re.findall(r'lowered\(b"([^"\n]+)",\d+\);',fixtures):case(source)
for source,error_kind in re.findall(r'invalid\(b"([^"\n]+)",(\d+)\);',fixtures):case(source,'compile_limit' if error_kind=='4' else 'type')
for source in re.findall(r'rejected\(b"([^"\n]+)"\);',fixtures):case(source,'compile_limit' if 'extra()' in source else 'type')
for source in re.findall(r'value\(b"([^"\n]+)"\);',fixtures):case(source)
for count in [1,16,32]:
    declarations=''.join(f'struct P{i}{{u8 x;}}' for i in range(count))
    for forward in [False,True]:
        helper=f'fn P{count-1} make(){{let P{count-1} p=P{count-1}{{.x=0}};return p;}}'
        main='fn i32 main(){return 42;}'
        case('module main;'+(main+helper+declarations if forward else declarations+helper+main))
for tag in ['bool','u8','i32','i64','u32','usize']:
    for forward in [False,True]:
        declarations=f'struct P{{{tag} x;}}'
        helper='fn P make(P p){return p;}'
        main='fn i32 main(){return 42;}'
        case('module main;'+(main+helper+declarations if forward else declarations+helper+main))
assert len(rows)==70,len(rows)

version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_parameters'] is True and version['struct_helper_locals'] is True,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-'+kind+'-cli/v1',status='passed',profile=args.profile,exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} {kind} CLI cases')
