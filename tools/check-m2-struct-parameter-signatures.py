"""Check record-parameter signature compilation gates through the native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--exe', required=True)
parser.add_argument('--profile', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'build/m2-struct-parameter-signatures' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = Path(args.exe).resolve()
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []

def case(source, error='type', anchor=None, array=False):
    data = source.encode()
    for mode in ['check', 'run']:
        path = output / f'parameter-{len(rows):03}.brc'
        path.write_bytes(data)
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            command += ['--fuel', '1000000']
        ran = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=10)
        assert ran.returncode == (3 if error else 0) and not ran.stderr, (source, ran)
        payload = json.loads(ran.stdout)
        assert payload['schema'] == 'browniec.result/v1' and payload['command'] == mode
        assert payload['profile'] == ('brownie.m2-array-read/1' if array else 'brownie.m1-scalar/1')
        assert payload['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed')
        assert payload['return_i32'] == (None if error or mode == 'check' else 42)
        if error:
            assert payload['error']['kind'] == error, (source, payload)
            assert 0 <= payload['error']['byte_offset'] <= len(data)
            if anchor:
                assert payload['error']['byte_offset'] == data.index(anchor.encode()), (source, payload)
        else:
            assert payload['error'] is None
        rows.append(dict(case=path.stem, sourceSha256=hashlib.sha256(data).hexdigest(),
                         exit=ran.returncode, result=payload))


import re
main='fn i32 main(){return 42;}'
for tag in ['bool','u8','i32','i64','u32','usize']:
 for order in [False,True]:
  defs='struct P{'+tag+' x;}'
  helper='fn i32 helper(P record){return 42;}'
  case('module main;'+defs+(main+helper if order else helper+main),anchor='record')
for params,anchor in [('P record','record'),('i32 n,P record','record'),('P a,P record','a,'),('i32[1] a,P record','record'),('Option<i32> o,P record','record')]:
 case('module main;struct P{i32 x;}fn i32 helper('+params+'){return 42;}'+main,anchor=anchor)
case('module main;fn i32 helper(P record){return record.x;}'+main+'struct P{i32 x;}',anchor='record')
case('module main;struct Inner{i32 x;}struct P{Inner child;}fn i32 helper(P record){return record.child.x;}'+main,anchor='record')
fixtures=(root/'tests/m2/struct_parameter_signatures.fy').read_text()
for text in re.findall(r'gated\(b"([^"\n]+)",\d+\);',fixtures):case(text,anchor='record')
for text in re.findall(r'rejected\(b"([^"\n]+)"\);',fixtures):case(text,error='compile_limit' if 'P i)' in text else 'syntax' if 'P p,)' in text else 'type')
# Every nominal catalog position is preserved; the compilation boundary is uniform.
for count in [1,16,32]:
 defs=''.join('struct P'+str(i)+'{i32 x;}' for i in range(count))
 case('module main;'+defs+'fn i32 helper(P'+str(count-1)+' record){return 42;}'+main,anchor='record')
for body in ['return missing;','return 42;']:
 case('module main;struct P{i32 x;}fn i32 main(){'+body+'}fn i32 unused(P record){return 0;}',anchor='record')
case('module main;fn i32 helper(i32 n){return n;}fn i32 main(){return helper(42);}',error=None)
case('module main;fn i32 helper(i32[1] a){return a[0];}fn i32 main(){let i32[1] a=[42;1];return helper(a);}',error=None,array=True)
case('module main;fn Option<i32> helper(i32 n){return .some(n);}fn i32 main(){let Option<i32> r=helper(42);return switch(r){case .some(n):{n}case .none:{0}};}',error=None)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_helper_locals'] is True and 'struct_parameters' not in version,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-parameter-signatures-cli/v1',status='passed',profile=args.profile,
 exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} record-parameter signature CLI cases')
