"""Exercise checked read-only slice alias bindings through the native CLI without runtime tools."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe', required=True, type=Path)
parser.add_argument('--profile', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'build/m2-array-slice-alias' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(source, error=None, *, fuel=1000000, anchor=None):
    data = source.encode('utf-8')
    for mode in ['check', 'run']:
        path = output / f'utf8-{len(rows):03}.brc'
        path.write_bytes(data)
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            command += ['--fuel', str(fuel)]
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
        active = None if error in ['fuel', 'bounds', 'overflow', 'zero_divisor'] and mode == 'check' else error
        code = 5 if active in ['fuel', 'bounds', 'overflow', 'zero_divisor'] else 3 if active else 0
        assert done.returncode == code and not done.stderr, (source, done)
        result = json.loads(done.stdout)
        assert result['schema'] == 'browniec.result/v1' and result['command'] == mode, result
        assert result['status'] == ('error' if active else 'checked' if mode == 'check' else 'completed'), result
        assert result['return_i32'] == (None if active or mode == 'check' else 42), result
        if active:
            assert result['error']['kind'] == active and 0 <= result['error']['byte_offset'] <= len(data), (source, result)
            if anchor:
                assert result['error']['byte_offset'] == data.index(anchor.encode()), result
        else:
            assert result['error'] is None, result
        rows.append(dict(command=command, sourceSha256=hashlib.sha256(data).hexdigest(), exit=code, result=result))



fixtures=(root/'tests/m2/array_slice_alias.fy').read_text(encoding='utf-8')
positives=re.findall(r'value\(b"([^"\n]+)",\d+\);',fixtures)
negatives=re.findall(r'rejected\(b"([^"\n]+)"\);',fixtures)
errors=re.findall(r'error\(b"([^"\n]+)",(\d+)\);',fixtures)
assert tuple(map(len,[positives,negatives,errors]))==(12,8,2),tuple(map(len,[positives,negatives,errors]))
for source in positives: case(source)
for source in negatives: case(source,'type')
for source,kind in errors: case(source,{'14':'bounds'}[kind])
for n in [1,4,4096]:
    for lo,hi in [(0,n),(n,n),(n-1,n),(0,0)]:
        for byte in [65,255]:
            neg='' if byte==65 or lo==hi else '!'
            case(f'module main;fn i32 main(){{let u8[{n}] a=[{byte};{n}];let ref u8[] parent=ref a[{lo}..{hi}];let ref u8[] part=ref parent;if(part.len=={hi-lo} && {neg}text::valid_utf8(part)){{return 42;}}return 0;}}')
for depth in [2,4,8]:
    body=''.join(f'let ref u8[] p{i}=ref p{i-1};' for i in range(1,depth))
    case('module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p0=ref a;'+body+f'return p{depth-1}[0] as i32;}}')
for n in [12,15,16,17]:
    body=''.join(f'{{let ref u8[] p{i}=ref parent;}}' for i in range(n-1))
    case('module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] parent=ref a;'+body+'return 42;}','compile_limit' if n==17 else 'fuel' if n>=15 else None)
for n in [61,62]:
    body=''.join(f'let usize x{i}=0;' for i in range(n))
    case('module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] parent=ref a;'+body+'let ref u8[] part=ref parent;return 42;}','compile_limit' if n==62 else None)
for expr,kind in [('2','bounds'),('1/0','zero_divisor'),('18446744073709551615','bounds')]:
    case('module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] parent=ref a[0..'+expr+'];let ref u8[] part=ref parent;return 42;}',kind)
source='module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] parent=ref a[..];let ref u8[] part=ref parent;if(part[0]==65){return 42;}return 0;}'
case(source,fuel=213154)
case(source,'fuel',fuel=213153)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert all(version[k] is True for k in ['array_slice_alias','array_slice_sub','array_slice_index','array_slice_length','array_utf8_slices']),version
assert version['restricted'] is False and version['embed'] is False,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-slice-alias-cli/v1',status='passed',profile=args.profile,
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-slice-alias CLI cases')
