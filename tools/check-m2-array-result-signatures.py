"""Check array-result signatures and invalid bodies through the native CLI."""
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
output = root / 'build/m2-array-result-signatures' / args.profile
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
        path = output / f'result-{len(rows):03}.brc'
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

main = 'fn i32 main(){return 42;}'
for tag in ['bool', 'u8', 'i32', 'i64', 'u32', 'usize']:
    for length in [1, 4096]:
        helper = f'fn {tag}[{length}] make(){{return 0;}}'
        case('module main; ' + helper + main, anchor='0;')
        case('module main; ' + main + helper, anchor='0;')
    case(f'module main; fn {tag}[1] main(){{return 0;}}', anchor='main(')
for length in ['0', '4097', '-1', '9223372036854775808', '18446744073709551615',
               '18446744073709551616', '', '1+1']:
    case(f'module main; fn i32[{length}] make(){{return 0;}}' + main,
         error='syntax' if length == '1+1' else 'type')
for tag in ['Option<i32>', 'Result<bool,bool>']:
    case(f'module main; fn {tag}[1] make(){{return 0;}}' + main)
for shape in ['i32[1][1]', 'i32[1']:
    case(f'module main; fn {shape} make(){{return 0;}}' + main, error='syntax')
case('module main; fn i32 main(){return missing;} fn i32[1] make(){return 42;}', anchor='missing')
params = ','.join(f'i32[1] {name}' for name in 'abcdefgh')
case(f'module main; fn i32 a({params}){{return 0;}} fn i32 b({params}){{return 0;}}'
     + 'fn i32[1] make(i32[1] a){return 0;}' + main, error='compile_limit')
for helper, body, array in [
    ('fn i32 id(i32 x){return x;}', 'return id(42);', False),
    ('fn Option<i32> unused(){return .some(42);}', 'return 42;', False),
    ('fn Result<bool,bool> unused(){return .ok(true);}', 'return 42;', False),
    ('fn i32 id(i32[1] a){return a[0];}', 'let i32[1] a=[42;1];return id(a);', True),
]:
    case('module main;' + helper + 'fn i32 main(){' + body + '}', error=None, array=array)
assert len(rows) == 96
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-result-signatures-cli/v1',
    status='passed', profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-result signature CLI cases')
