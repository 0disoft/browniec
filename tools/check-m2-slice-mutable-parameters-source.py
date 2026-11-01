"""Check public mutable parameter source execution through the tool-free CLI."""
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
output = root / 'build/m2-slice-mutable-parameters-source' / args.profile
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


native = (root / 'tests/m2/slice_mutable_parameters_source.fy').read_text(encoding='utf-8')
fixtures = re.findall(r'(?:run_source|compiled)\(b"([^"\n]+)"', native)
fixtures += re.findall(r'let ref u8\[\] source=b"([^"\n]+)"', native)
negatives = re.findall(r'rejected\(b"([^"\n]+)"', native)
conflicts = re.findall(r'conflict\(b"([^"\n]+)"', native)
assert (len(fixtures), len(negatives), len(conflicts)) == (17, 15, 2)
errors = {0: None, 7: 'zero_divisor', 12: 'frame_limit', 14: 'bounds'}
expected = {source: errors[int(kind)] for source, kind in re.findall(r'run_source\(b"([^"\n]+)",(\d+)\)', native)}
for source in fixtures:
    error = expected.get(source, 'bounds' if 'p[1]=0' in source else None)
    if ',30)' in source or ',31)' in source or 'return f(ref mut p,2)+f(ref mut p,2)' in source:
        error = 'fuel'
    case(source, runtime_error=error, fuel=1000000)
for source in conflicts:
    case(source, 'conflict', fuel=0)
for source in negatives:
    case(source, 'source', fuel=0)
# Valid admission reaches Fuel/array quotas; malformed programs above do not.
case(fixtures[0], runtime_error='fuel', fuel=0)
case('module main;fn i32 f(ref mut i32[] p){p[0]=42;return 42;}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;return f(ref mut p);}', runtime_error='fuel', fuel=65537)
case((root / 'examples/mutable-slice-parameters.brc').read_text(encoding='utf-8'), fuel=1000000)
version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_slice_mutable_parameters'] is True and version['array_slice_mutable'] is True and version['array_slice_parameters'] is True
assert len(rows) == 74, len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.slice-mutable-parameters-source-cli/v2', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} public mutable parameter source CLI cases')
