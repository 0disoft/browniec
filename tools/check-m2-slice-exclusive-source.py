"""Check the private mutable-slice source gate through the tool-free CLI."""
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


def case(source, category):
    data = source.encode()
    path = output / f'case-{len(rows):03}.brc'
    path.write_bytes(data)
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            # The public gate must win over allocation and zero execution Fuel.
            command += ['--fuel', '0']
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
        result = json.loads(done.stdout)
        kinds = ['verification'] if category != 'source' else ['type', 'syntax']
        assert not done.stderr and done.returncode == (3 if category == 'source' else 6), (source, done)
        assert result['schema'] == 'browniec.result/v1' and result['command'] == mode, result
        assert result['status'] == 'error' and result['return_i32'] is None and result['error']['kind'] in kinds, (source, result)
        assert 0 <= result['error']['byte_offset'] < len(data), result
        if category == 'gate':
            assert result['error']['byte_offset'] == 0, result
        rows.append(dict(category=category, command=command, sourceSha256=hashlib.sha256(data).hexdigest(), exit=done.returncode, result=result))


native = (root / 'tests/m2/slice_exclusive_source.fy').read_text(encoding='utf-8')
fixtures = re.findall(r'run\(b"([^"\n]+)",\d+\)', native)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\)', native)
conflicts = re.findall(r'conflict\(b"([^"\n]+)"\)', native)
assert len(fixtures) == 20 and len(negatives) == 14 and len(conflicts) == 6
for source in fixtures:
    case(source, 'gate')
for source in negatives:
    case(source, 'source')
for source in conflicts:
    case(source, 'conflict')
for tag in ['i32', 'bool', 'i64', 'u8', 'u32', 'usize']:
    zero = 'false' if tag == 'bool' else '0'
    value = 'true' if tag == 'bool' else '42'
    for bounds in ['', '[..]', '[1..]', '[..1]', '[1..2]', '[2..2]']:
        case(f'module main;fn i32 main(){{var {tag}[2] a=[{zero};2];let ref mut {tag}[] p=ref mut a{bounds};return 42;}}', 'gate')
    case(f'module main;fn i32 main(){{var {tag}[2] a=[{zero};2];let ref mut {tag}[] p=ref mut a;p[0]={value};return 42;}}', 'gate')
assert len(rows) == 164, len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.slice-exclusive-source-cli/v1', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} private exclusive source CLI cases')
