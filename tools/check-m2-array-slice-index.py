"""Exercise checked read-only slice indexing through the native CLI without runtime tools."""
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
output = root / 'build/m2-array-slice-index' / args.profile
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



fixtures=(root/'tests/m2/array_slice_index.fy').read_text(encoding='utf-8')
positives=re.findall(r'value\(b"([^"\n]+)",\d+\);',fixtures)
negatives=re.findall(r'rejected\(b"([^"\n]+)"\);',fixtures)
errors=re.findall(r'error\(b"([^"\n]+)",(\d+)\);',fixtures)
assert tuple(map(len,[positives,negatives,errors]))==(12,8,4),tuple(map(len,[positives,negatives,errors]))
for source in positives: case(source)
for source in negatives: case(source,'type')
for source,kind in errors: case(source,{'14':'bounds','7':'zero_divisor'}[kind])
# Relative bounds, including empty selections and both halves of the usize domain.
for n in [1,4,4096]:
    for lo,hi in [(0,n),(n,n),(n-1,n),(0,0)]:
        for index in [0,hi-lo-1 if hi>lo else 0,hi-lo,2**63,2**64-1]:
            case(f'module main;fn i32 main(){{let u8[{n}] a=[255;{n}];let ref u8[] part=ref a[{lo}..{hi}];let usize i={index};if(part[i+0]==255){{return 42;}}return 0;}}',None if index<hi-lo else 'bounds',anchor='part[i' if index>=hi-lo else None)
for suffix in ['', '[..]', '[..3]', '[1..]', '[2..3]']:
    case('module main;fn i32 main(){var u8[4] a=[0;4];a[2]=42;let ref u8[] part=ref a'+suffix+';if(part['+('1' if suffix=='[1..]' else '0' if suffix=='[2..3]' else '2')+']==42){return 42;}return 0;}')
for expr,kind in [('1/0','zero_divisor'),('18446744073709551615+1','overflow')]:
    case('module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] part=ref a;if(part['+expr+']==65){return 42;}return 0;}',kind)
source='module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] part=ref a[..];if(part[0]==65){return 42;}return 0;}'
case(source,fuel=139422)
case(source,'fuel',fuel=139421)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert all(version[k] is True for k in ['array_slice_index','array_slice_length','array_utf8_slices']),version
assert version['restricted'] is False and version['embed'] is False,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-slice-index-cli/v1',status='passed',profile=args.profile,
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-slice-index CLI cases')
