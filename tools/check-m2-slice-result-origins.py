"""Check the closed public borrowed-result signature boundary through a tool-free native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe',required=True,type=Path)
parser.add_argument('--profile',required=True,choices=['development','release'])
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
output=root/'build/m2-slice-result-origins'/args.profile
output.mkdir(parents=True,exist_ok=True)
receipt=output/'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n',encoding='utf-8')
empty=output/'no-runtime-tools';empty.mkdir(exist_ok=True)
exe=args.exe.resolve(strict=True)
env={key:str(empty) for key in ['PATH','TEMP','TMP']}
env.update({key:os.environ[key] for key in ['SystemRoot','WINDIR'] if key in os.environ})
rows=[]

def case(source, category='public', expected=0, fuel=1000000):
    data = source.encode()
    path = output / f'case-{len(rows):03}.brc'
    path.write_bytes(data)
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            command += ['--fuel', str(fuel)]
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
        result = json.loads(done.stdout)
        assert not done.stderr and result['schema'] == 'browniec.result/v1', (source, done)
        assert result['command'] == mode, result
        error = ('verification' if category == 'conflict' else 'source' if category == 'source'
                 else {0: None, 7: 'zero_divisor', 8: 'fuel', 12: 'frame_limit', 13: 'array_limit', 14: 'bounds'}[expected]
                 if mode == 'run' else None)
        if error:
            code = 6 if category == 'conflict' else 3 if category == 'source' else 5
            kinds = ['type', 'syntax', 'compile_limit'] if error == 'source' else [error]
            assert done.returncode == code and result['status'] == 'error', (source, done)
            assert result['return_i32'] is None and result['error']['kind'] in kinds, (source, result)
            assert 0 <= result['error']['byte_offset'] < len(data), result
        else:
            assert done.returncode == 0 and result['error'] is None, (source, done)
            assert result['status'] == ('checked' if mode == 'check' else 'completed'), result
            assert result['return_i32'] == (None if mode == 'check' else 42), (source, result)
        rows.append(dict(category=category, command=command, sourceSha256=hashlib.sha256(data).hexdigest(),
                         exit=done.returncode, result=result))


native=(root/'tests/m2/slice_result_origins.fy').read_text(encoding='utf-8')
fixtures=re.findall(r'(?:proved|rejected)\(b"([^"\n]+)"',native)
assert len(fixtures)==44,len(fixtures)
for source in fixtures:case(source,'source',fuel=0)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert not version.get('array_slice_results',False)
receipt.write_text(json.dumps(dict(schema='browniec.slice-result-origins-cli/v1',status='passed',profile=args.profile,
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',
    count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} borrowed-result origin gate CLI cases')
