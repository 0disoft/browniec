"""Check public readonly scalar slices using the tool-free native CLI."""
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
output = root / 'build/m2-slice-element-public' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(source, error=None, runtime_error=None, fuel=1000000):
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
        wanted = error or (runtime_error if mode == 'run' else None)
        if wanted:
            assert done.returncode == (3 if error else 5) and result['status'] == 'error', (source, done)
            assert result['error']['kind'] == wanted and result['return_i32'] is None, (source, result)
            assert 0 <= result['error']['byte_offset'] < len(data), (source, result)
        else:
            assert done.returncode == 0 and result['error'] is None, (source, done)
            assert result['status'] == ('checked' if mode == 'check' else 'completed'), (source, result)
            assert result['return_i32'] == (None if mode == 'check' else 42), (source, result)
        rows.append(dict(command=command, sourceSha256=hashlib.sha256(data).hexdigest(), exit=done.returncode, result=result))


native = (root / 'tests/m2/slice_element_public.fy').read_text(encoding='utf-8')
fixtures = re.findall(r'run\(b"([^"\n]+)",(\d+),(\d+)\)', native)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\)', native)
assert (len(fixtures), len(negatives)) == (13, 5)
for source, fuel, kind in fixtures:
    case(source, runtime_error={0: None, 7: 'zero_divisor', 14: 'bounds'}[int(kind)], fuel=int(fuel))
for source in negatives:
    case(source, error='type')
case((root / 'examples/slice-elements.brc').read_text(encoding='utf-8'))

tags = [('i32', '42', '0', 4), ('bool', 'true', 'false', 1), ('i64', '42', '0', 8),
        ('u8', '42', '0', 1), ('u32', '42', '0', 4), ('usize', '42', '0', 8)]
maxima = {'i32': '2147483647', 'i64': '9223372036854775807', 'u8': '255',
          'u32': '4294967295', 'usize': '18446744073709551615'}
for tag, fill, zero, stride in tags:
    exact = (f'module main;fn i32 read(ref {tag}[] p){{if(p[0]=={fill}){{return 42;}}return 0;}}'
             f'fn i32 main(){{let {tag}[1] a=[{fill};1];let ref {tag}[] p=ref a;return read(ref p);}}')
    # Independent instruction accounting: prep65537, main200819+3*stride,
    # callee8233+stride, with no inferred budget or binary search.
    budget = 65537 + (200819 + 3 * stride) + (8233 + stride)
    assert budget == {1: 274593, 4: 274605, 8: 274621}[stride]
    case(exact, fuel=budget)
    case(exact, fuel=budget - 1, runtime_error='fuel')
    case(exact, fuel=0, runtime_error='fuel')
    case(f'module main;fn i32 main(){{var {tag}[4] a=[{fill};4];a[2]={zero};let usize start=1;'
         f'let ref {tag}[] p=ref a[start..a.len-1];let ref {tag}[] q=ref p[1..];'
         f'if(q[0]=={zero} && q.len==1){{return 42;}}return 0;}}')
    case(f'module main;fn i32 main(){{let {tag}[4] a=[{fill};4];let ref {tag}[] p=ref a[4..4];'
         'if(p.len==0){return 42;}return 0;}')
    case(f'module main;fn i32 main(){{let {tag}[4] a=[{fill};4];let ref {tag}[] p=ref a[1..3];'
         f'if(p[2]=={fill}){{return 42;}}return 0;}}', runtime_error='bounds')
    if tag != 'bool':
        case(f'module main;fn i32 f(ref {tag}[] p){{if(p[0]+1==0){{return 42;}}return 0;}}'
             f'fn i32 main(){{let {tag}[1] a=[{maxima[tag]};1];let ref {tag}[] p=ref a;return f(ref p);}}', runtime_error='overflow')
    case(f'module main;fn i32 f(ref {tag}[] p,i32 n){{if(n==0){{if(p[0]=={fill}){{return 42;}}return 0;}}return f(ref p,n-1);}}'
         f'fn i32 main(){{let {tag}[1] a=[{fill};1];let ref {tag}[] p=ref a;return f(ref p,2);}}')
    params = ','.join(f'ref {tag}[] p{i}' for i in range(8))
    arguments = ','.join(['ref p'] * 8)
    case(f'module main;fn i32 f({params}){{if(p0[0]=={fill}){{return 42;}}return 0;}}'
         f'fn i32 main(){{let {tag}[1] a=[{fill};1];let ref {tag}[] p=ref a;return f({arguments});}}')
    case(f'module main;fn {tag}[1] make(ref {tag}[] p){{return [p[0];1];}}'
         f'fn i32 main(){{let {tag}[1] a=[{fill};1];let ref {tag}[] p=ref a;let {tag}[1] b=make(ref p);'
         f'if(b[0]=={fill}){{return 42;}}return 0;}}')
    case(f'module main;struct R{{{tag} x;}}fn R make(ref {tag}[] p){{return R{{.x=p[0]}};}}'
         f'fn i32 main(){{let {tag}[1] a=[{fill};1];let ref {tag}[] p=ref a;let R r=make(ref p);'
         f'if(r.x=={fill}){{return 42;}}return 0;}}')
    case(f'module main;fn i32 f(ref {tag}[] p){{var i32 n=0;while(n<2){{let ref {tag}[] q=ref p;n=n+1;continue;}}'
         f'while(true){{let ref {tag}[] q=ref p;break;}}if(p[0]=={fill}){{return 42;}}return 0;}}'
         f'fn i32 main(){{let {tag}[1] a=[{fill};1];let ref {tag}[] p=ref a;return f(ref p);}}')
    case(f'module main;fn i32 f(ref {tag}[] p){{return 42;}}'
         f'fn i32 main(){{var {tag}[1] a=[{fill};1];let ref {tag}[] p=ref a;let i32 n=f(ref p);a[0]={zero};return n;}}', error='type')

version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_slice_scalar_elements'] is True and version['array_slice_parameters'] is True
assert version['restricted'] is False and version['embed'] is False
assert len(rows) == 192, len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.slice-element-public-cli/v1', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} public scalar slice CLI cases')
