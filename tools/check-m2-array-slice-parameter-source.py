"""Check public borrowed slice source syntax through the tool-free native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe', type=Path, required=True)
parser.add_argument('--profile', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'build/m2-array-slice-parameter-source' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(source, errors=None, fuel=1000000, expected=42, runtime_error=None):
    data = source.encode()
    path = output / f'signature-{len(rows):03}.brc'
    path.write_bytes(data)
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            command += ['--fuel', str(fuel)]
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
        assert not done.stderr, (source, done)
        result = json.loads(done.stdout)
        assert result['schema'] == 'browniec.result/v1' and result['command'] == mode, result
        wanted = errors if errors else ((runtime_error,) if mode == 'run' and runtime_error else ())
        if wanted:
            kind = result['error']['kind']
            assert kind in wanted and done.returncode == (5 if kind in ('fuel', 'zero_divisor') else 3), (source, done)
            assert result['status'] == 'error' and result['return_i32'] is None
            assert 0 <= result['error']['byte_offset'] <= len(data), result
        else:
            assert done.returncode == 0 and result['error'] is None, (source, done)
            assert result['status'] == ('checked' if mode == 'check' else 'completed')
            assert result['return_i32'] == (None if mode == 'check' else expected), result
        rows.append(dict(command=command, sourceSha256=hashlib.sha256(data).hexdigest(),
                         exit=done.returncode, result=result))


fixtures = (root / 'tests/m2/slice_parameters_source.fy').read_text(encoding='utf-8')
positives = re.findall(r'(?:accepted|compiled)\(b"([^"\n]+)"\)', fixtures)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\)', fixtures)
assert len(positives) == 13 and len(negatives) == 15, (len(positives), len(negatives))
for source, expected in zip(positives, [42] * 10 + [84, 42, 42], strict=True):
    case(source, expected=expected)
for source in negatives:
    case(source, ('syntax', 'type'))
for arity in [1, 8, 9]:
    parameters = ','.join(f'ref u8[] p{i}' for i in range(arity))
    case(f'module main;fn i32 f({parameters}){{return 42;}}fn i32 main(){{return 42;}}',
         ('compile_limit',) if arity == 9 else None)
for sites in [15, 16, 17]:
    functions = []
    remaining = sites
    for name in ['a', 'b', 'c']:
        count = min(8, remaining)
        if count:
            parameters = ','.join(f'ref u8[] p{i}' for i in range(count))
            functions.append(f'fn i32 {name}({parameters}){{return 42;}}')
        remaining -= count
    case('module main;' + ''.join(functions) + 'fn i32 main(){return 42;}',
         ('compile_limit',) if sites == 17 else None)
for fuel in [0, 1, 1000000]:
    case('module main;fn i32 f(ref u8[] p){return p[0] as i32;}fn i32 main(){return 1/0;}', fuel=fuel, runtime_error='fuel' if fuel < 3 else 'zero_divisor')
version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_slice_alias'] is True and version['array_slice_parameters'] is True, version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-slice-parameter-source-cli/v1',
    status='passed', profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-slice-parameter-source CLI cases')
