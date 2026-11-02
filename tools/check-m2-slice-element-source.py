"""Check readonly scalar slice source admission through the real native CLI."""
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
output = root / 'build/m2-slice-element-source' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(source, error=None, fuel=1000000, runtime_error=None):
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
            assert done.returncode == (5 if runtime_error and mode == 'run' else 3), (source, done)
            assert result['status'] == 'error' and result['return_i32'] is None and result['error']['kind'] == wanted, (source, result)
            assert 0 <= result['error']['byte_offset'] <= len(data), (source, result)
        else:
            assert done.returncode == 0 and result['error'] is None, (source, done)
            assert result['status'] == ('checked' if mode == 'check' else 'completed'), (source, result)
            assert result['return_i32'] == (None if mode == 'check' else 42), (source, result)
        rows.append(dict(command=command, sourceSha256=hashlib.sha256(data).hexdigest(), exit=done.returncode, result=result))


native = (root / 'tests/m2/slice_element_source.fy').read_text(encoding='utf-8')
positives = re.findall(r'accepted\(b"([^"\n]+)"\)', native)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\)', native)
signatures = re.findall(r'let ref u8\[\] source=b"([^"\n]+)"', native)
assert (len(positives), len(negatives), len(signatures)) == (16, 13, 1)
for source in [*signatures, *positives]:
    case(source)
for source in negatives:
    case(source, 'type')

# Both forwarding and alias declarations require nominal scalar equality,
# including same-width i32/u32 and i64/usize mismatches.
tags = ['i32', 'bool', 'i64', 'u8', 'u32', 'usize']
for target in tags:
    for source in tags:
        error = 'type' if target != source else None
        case(f'module main;fn i32 f(ref {target}[] p){{return 42;}}'
             f'fn i32 g(ref {source}[] p){{return f(ref p);}}fn i32 main(){{return 42;}}', error)
        case(f'module main;fn i32 f(ref {source}[] p){{let ref {target}[] q=ref p[..];return 42;}}'
             'fn i32 main(){return 42;}', error)
for tag in tags:
    if tag == 'u8':
        continue
    case(f'module main;fn i32 f(ref {tag}[] p){{if(text::valid_utf8(p)){{return 42;}}return 0;}}'
         'fn i32 main(){return 42;}', 'type')
    case(f'module main;fn i32 main(){{let {tag}[1] a=[{"true" if tag == "bool" else "42"};1];'
         f'let ref {tag}[] p=ref a;return 42;}}')
    for fuel in [0, 1]:
        case(f'module main;fn i32 f(ref {tag}[] p){{return 42;}}fn i32 main(){{return 42;}}', fuel=fuel, runtime_error='fuel')
for arity in [8, 9]:
    parameters = ','.join(f'ref i32[] p{i}' for i in range(arity))
    case(f'module main;fn i32 f({parameters}){{return 42;}}fn i32 main(){{return 42;}}',
         None if arity == 8 else 'compile_limit')
for sites in [16, 17]:
    functions = []
    remaining = sites
    for name in ['a', 'b', 'c']:
        count = min(8, remaining)
        if count:
            parameters = ','.join(f'ref i32[] p{i}' for i in range(count))
            functions.append(f'fn i32 {name}({parameters}){{return 42;}}')
        remaining -= count
    case('module main;' + ''.join(functions) + 'fn i32 main(){return 42;}',
         None if sites == 16 else 'compile_limit')
version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_slice_parameters'] is True and version['restricted'] is False and version['embed'] is False
assert version['array_slice_scalar_elements'] is True
assert len(rows) == 252, len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.slice-element-source-cli/v1', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} slice element source CLI cases')
