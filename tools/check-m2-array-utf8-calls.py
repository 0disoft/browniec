"""Exercise UTF-8 array-result calls through the native CLI without runtime tools."""
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
output = root / 'build/m2-array-utf8-calls' / args.profile
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
        active = None if error == 'fuel' and mode == 'check' else error
        code = 5 if active == 'fuel' else 3 if active else 0
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


fixtures = (root / 'tests/m2/array_utf8_calls.fy').read_text(encoding='utf-8')
positives = re.findall(r'value\(b"([^"\n]+)",\d+\);', fixtures)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\);', fixtures)
assert len(positives) == 13 and len(negatives) == 8, (len(positives), len(negatives))
for source in positives:
    case(source)
for source, error in zip(negatives, ['type'] * 6 + ['syntax'] * 2):
    case(source, error)

for n in [1, 4, 4096]:
    for byte in [65, 255]:
        source = f'module main;fn u8[{n}] make(){{return [{byte};{n}];}}fn i32 main(){{let bool b=text::valid_utf8(make());return 42;}}'
        exact = 65746 + 5*n
        case(source, fuel=exact)
        case(source, 'fuel', fuel=exact-1)
        case(source, 'fuel', fuel=65694+5*n, anchor='text::valid_utf8')
for tag in ['bool', 'i32', 'i64', 'u32', 'usize']:
    literal = 'true' if tag == 'bool' else '0'
    case(f'module main;fn {tag}[1] make(){{return [{literal};1];}}fn i32 main(){{let bool b=text::valid_utf8(make());return 0;}}', 'type')
for n in [1, 4096]:
    for byte in [65, 255]:
        negate = '' if byte == 65 else '!'
        case(f'module main;fn u8[{n}] make(){{return [{byte};{n}];}}fn i32 main(){{if({negate}text::valid_utf8(make())){{return 42;}}return 0;}}')
case('module main;fn u8[2] echo(u8[2] a){return a;}fn i32 main(){var u8[2] a=[65;2];if(text::valid_utf8(echo(a)) && a[0]==65){return 42;}return 0;}')
case('module main;fn u8[1] make(){return [65;1];}fn i32 main(){if(text::valid_utf8(make())){return 42;}return 0;}')
assert len(rows) == 100, len(rows)
version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_utf8_predicate'] is True and version['array_utf8_call_results'] is True, version
assert version['restricted'] is False and version['embed'] is False, version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-utf8-calls-cli/v1', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2) + '\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-utf8-calls CLI cases')
