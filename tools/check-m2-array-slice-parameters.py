"""Check public readonly u8 slice CALLs through the real tool-free CLI."""
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
output = root / 'build/m2-array-slice-parameters-public' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(name, source, expected=42, error=None, fuel=1000000, anchor=None):
    data = source.encode()
    path = output / (name + '.brc')
    path.write_bytes(data)
    assert 0 <= fuel <= 1000000
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            command += ['--fuel', str(fuel)]
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
        result = json.loads(done.stdout)
        assert not done.stderr and result['command'] == mode and result['schema'] == 'browniec.result/v1', (name, done)
        active_error = error if mode == 'run' else None
        if active_error:
            assert done.returncode == 5 and result['status'] == 'error', (name, done)
            assert result['error']['kind'] == active_error and result['return_i32'] is None, (name, result)
            offset = result['error']['byte_offset']
            assert 0 <= offset < len(data), (name, result)
            if anchor is not None:
                assert offset == data.index(anchor.encode()), (name, result, anchor)
        else:
            assert done.returncode == 0 and result['error'] is None, (name, done)
            assert result['status'] == ('checked' if mode == 'check' else 'completed'), (name, result)
            assert result['return_i32'] == (None if mode == 'check' else expected), (name, result)
        rows.append(dict(case=name, command=command, sourceSha256=hashlib.sha256(data).hexdigest(),
                         exit=done.returncode, result=result))


# Independent expected values/errors from the native source integration corpus.
native = (root / 'tests/m2/slice_lifecycle_vm.fy').read_text(encoding='utf-8')
fixtures = re.findall(r'run\(b"([^"\n]+)",(\d+),(\d+),(-?\d+),(?:true|false)\)', native)
assert len(fixtures) == 13, len(fixtures)
kinds = {6: 'overflow', 7: 'zero_divisor', 8: 'fuel', 14: 'bounds'}
for index, (source, _, kind, value) in enumerate(fixtures):
    kind = int(kind)
    if kind == 13:
        # Pool exhaustion needs more than the CLI Fuel ceiling; the public VM
        # native test covers that path with an explicit higher host budget.
        continue
    case('lifecycle-' + str(index), source, int(value), kinds.get(kind),
         fuel=265000 if kind == 8 else 1000000)

for tag in ['u8', 'i32', 'i64', 'u32', 'usize']:
    case('mixed-' + tag,
         f'module main;fn i32 f(ref u8[] p,{tag} n){{if(n==42 && p.len==1){{return p[0] as i32;}}return 0;}}'
         'fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,42);}')

for length in [1, 4, 4096]:
    for start, end in [(0, 0), (0, length), (length, length)]:
        case(f'range-{length}-{start}-{end}',
             f'module main;fn i32 f(ref u8[] p){{if(text::valid_utf8(p) && p.len=={end-start}){{return 42;}}return 0;}}'
             + f'fn i32 main(){{let u8[{length}] a=[42;{length}];let ref u8[] p=ref a[{start}..{end}];return f(ref p);}}')

case('invalid-utf8', 'module main;fn i32 f(ref u8[] p){if(text::valid_utf8(p)){return 0;}return 42;}'
     'fn i32 main(){let u8[2] a=[255;2];let ref u8[] p=ref a;return f(ref p);}')
parameters = ','.join(f'ref u8[] p{i}' for i in range(8))
arguments = ','.join('ref p' for _ in range(8))
case('eight-duplicate-formals', f'module main;fn i32 f({parameters}){{return p0[0] as i32;}}'
     f'fn i32 main(){{let u8[1] a=[42;1];let ref u8[] p=ref a;return f({arguments});}}')
case('caller-write-after-scope', 'module main;fn i32 f(ref u8[] p){return p[0] as i32;}'
     'fn i32 main(){var u8[1] a=[42;1];var i32 n=0;{let ref u8[] p=ref a;n=f(ref p);}a[0]=1;return n;}')

exact = ('module main;fn i32 read(ref u8[] p){return p[0] as i32;}'
         'fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return read(ref p);}')
# Preparation 65537; main 1+59+1+1+65537+131076+4097+49+1;
# callee 1+4131+1+4097+1. No binary search or implementation-derived oracle.
assert 65537 + (1+59+1+1+65537+131076+4097+49+1) + (1+4131+1+4097+1) == 274590
case('exact-fuel', exact, fuel=274590)
case('one-short-fuel', exact, fuel=274589, error='fuel', anchor='return read(ref p);')
case('zero-fuel', exact, fuel=0, error='fuel', anchor='module')

version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_slice_parameters'] is True
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-slice-parameters-public-cli/v1',
    status='passed', profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} public array-slice-parameters CLI cases')
