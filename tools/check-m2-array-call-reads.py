"""Check direct array call-result reads and length."""
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
kind='array-call-reads'
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
        active_error=None if error in ('fuel','frame_limit','array_limit','bounds') and mode=='check' else error
        expected=5 if active_error in ('fuel','frame_limit','array_limit','bounds') else 3 if active_error else 0
        assert ran.returncode==expected and not ran.stderr,(source,ran.returncode,ran.stdout,ran.stderr)
        result=json.loads(ran.stdout)
        assert result['schema']=='browniec.result/v1' and result['command']==mode,result
        assert result['status']==('error' if active_error else 'checked' if mode=='check' else 'completed'),result
        assert result['return_i32']==(None if active_error or mode=='check' else 42),result
        if active_error:assert result['error']['kind']==active_error and 0<=result['error']['byte_offset']<=len(data),(source,result)
        if anchor:assert result['error']['byte_offset']==data.index(anchor.encode('utf-8')),(source,result)
        if not active_error:
            assert result['error'] is None,result
            assert result['profile'] in ['brownie.m1-scalar/1','brownie.m2-array-read/1','brownie.m2-array-write/1','brownie.m2-array-copy/1','brownie.m2-struct-read/1','brownie.m2-struct-write/1','brownie.m2-struct-copy/1','brownie.m2-struct-nested/1'],result
        rows.append(dict(command=command,sourceSha256=hashlib.sha256(data).hexdigest(),exit=expected,result=result))


fixtures=(root/'tests/m2/array_call_reads.fy').read_text(encoding='utf-8')
positives=re.findall(r'value\(b"([^"\n]+)",\d+\);',fixtures)
negatives=re.findall(r'rejected\(b"([^"\n]+)"\);',fixtures)
assert len(positives)==15 and len(negatives)==10,(len(positives),len(negatives))
for source in positives:case(source)
for source in negatives:case(source,'type')
for tag,values in [('bool',['false','true']),('u8',['0','255']),('i32',['-2147483648','2147483647']),('i64',['-9223372036854775808','9223372036854775807']),('u32',['0','4294967295']),('usize',['0','18446744073709551615'])]:
    for value in values:
        for length in [1,2]:
            source=f'module main;fn i32 main(){{if(make()[{length-1}]=={value} && make().len=={length}){{return 42;}}return 0;}}fn {tag}[{length}] make(){{return [{value};{length}];}}'
            case(source)
for index in ['1','18446744073709551615']:
    case(f'module main;fn i32[1] make(){{return [42;1];}}fn i32 main(){{return make()[{index}];}}','bounds')
for count in [14,15]:
    source='module main;fn i32[1] make(){return [42;1];}fn i32 main(){'+''.join(f'let i32 n{i}=make()[0];' for i in range(count))+f'return n{count-1};}}'
    case(source,None if count==14 else 'compile_limit')
assert len(rows)==106,len(rows)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['array_profile']=='brownie.m2-array-read/1' and version['array_copy_profile']=='brownie.m2-array-copy/1',version
receipt.write_text(json.dumps(dict(schema='browniec.m2-'+kind+'-cli/v1',status='passed',profile=args.profile,exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} {kind} CLI cases')
