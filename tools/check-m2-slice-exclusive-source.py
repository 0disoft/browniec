"""Check public mutable scalar slices through the tool-free CLI."""
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
output = root / 'build/m2-slice-exclusive-source' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(source, category='public', runtime_error=None, fuel=1000000):
    data = source.encode()
    path = output / f'case-{len(rows):03}.brc'
    path.write_bytes(data)
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            command += ['--fuel', str(fuel)]
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
        result = json.loads(done.stdout)
        assert not done.stderr and result['schema'] == 'browniec.result/v1' and result['command'] == mode, (source, done)
        wanted = ('verification' if category == 'conflict' else 'source' if category == 'source'
                  else runtime_error if mode == 'run' else None)
        if wanted:
            code = 6 if category == 'conflict' else 3 if category == 'source' else 5
            kinds = ['type', 'syntax', 'compile_limit'] if wanted == 'source' else [wanted]
            assert done.returncode == code and result['status'] == 'error' and result['return_i32'] is None and result['error']['kind'] in kinds, (source, done)
            assert 0 <= result['error']['byte_offset'] < len(data), result
        else:
            assert done.returncode == 0 and result['error'] is None and result['status'] == ('checked' if mode == 'check' else 'completed'), (source, done)
            assert result['return_i32'] == (None if mode == 'check' else 42), (source, result)
        rows.append(dict(category=category, command=command, sourceSha256=hashlib.sha256(data).hexdigest(), exit=done.returncode, result=result))


native = (root / 'tests/m2/slice_exclusive_source.fy').read_text(encoding='utf-8')
fixtures = re.findall(r'run\(b"([^"\n]+)",(\d+)\)', native)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\)', native)
conflicts = re.findall(r'conflict\(b"([^"\n]+)"\)', native)
assert len(fixtures) == 20 and len(negatives) == 14 and len(conflicts) == 6
for source, error in fixtures:
    case(source, runtime_error={0: None, 6: 'overflow', 7: 'zero_divisor', 14: 'bounds'}[int(error)])
for source in negatives:
    case(source, 'source')
for source in conflicts:
    case(source, 'conflict')
for tag in ['i32', 'bool', 'i64', 'u8', 'u32', 'usize']:
    zero = 'false' if tag == 'bool' else '0'
    value = 'true' if tag == 'bool' else '42'
    for bounds in ['', '[..]', '[1..]', '[..1]', '[1..2]', '[2..2]']:
        case(f'module main;fn i32 main(){{var {tag}[2] a=[{zero};2];let ref mut {tag}[] p=ref mut a{bounds};return 42;}}')
    case(f'module main;fn i32 main(){{var {tag}[2] a=[{zero};2];let ref mut {tag}[] p=ref mut a;p[0]={value};if(p[0]=={value}){{return 42;}}return 0;}}')
    whole = f'module main;fn i32 main(){{var {tag}[1] a=[{zero};1];let ref mut {tag}[] p=ref mut a;p[0]={value};return 42;}}'
    width = 4 if tag in ['i32', 'u32'] else 8 if tag in ['i64', 'usize'] else 1
    exact = 148663 + 5 * width
    case(whole, fuel=exact)
    case(whole, runtime_error='fuel', fuel=exact-1)
    case(whole, runtime_error='fuel', fuel=0)
    case(f'module main;fn i32 main(){{var {tag}[1] a=[{zero};1];let ref mut {tag}[] p=ref mut a[1..];p[0]={value};return 42;}}', runtime_error='bounds')

mixed = 'module main;fn i32 main(){'
for i in range(16):
    mixed += f'var u8[1] a{i}=[42;1];let ref {"mut " if i<8 else ""}u8[] p{i}=ref {"mut " if i<8 else ""}a{i};'
case(mixed + 'p0[0]=p15[0];return p0[0] as i32;}', runtime_error='fuel')
mixed13 = 'module main;fn i32 main(){'
for i in range(13):
    mixed13 += f'var u8[1] a{i}=[42;1];let ref {"mut " if i<6 else ""}u8[] p{i}=ref {"mut " if i<6 else ""}a{i};'
case(mixed13 + 'p0[0]=p12[0];return p0[0] as i32;}')
case('module main;fn i32 main(){var u8[1] a=[0;1];' + '{let ref mut u8[] p=ref mut a;}'*17 + 'return 42;}', 'source')
case((root/'examples/mutable-slices.brc').read_text(encoding='utf-8'))
case('module main;fn i32 main(){var usize[4096] a=[0;4096];let ref mut usize[] p=ref mut a;var usize[4096] b=[0;4096];let ref mut usize[] q=ref mut b;var usize[1] c=[0;1];return 42;}', runtime_error='array_limit')
version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_slice_mutable'] is True and version['array_slice_scalar_elements'] is True and version['array_slice_parameters'] is True
assert version['restricted'] is False and version['embed'] is False
assert len(rows) == 222, len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.slice-exclusive-source-cli/v2', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} public mutable scalar-slice CLI cases')
