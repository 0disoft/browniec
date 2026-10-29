"""Exercise qualified UTF-8 predicates through the native CLI without runtime tools."""
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
output = root / 'build/m2-array-utf8-ranges' / args.profile
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


fixtures = (root / 'tests/m2/array_utf8_ranges.fy').read_text(encoding='utf-8')
positives = re.findall(r'value\(b"([^"\n]+)", \d+\);', fixtures)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\);', fixtures)
assert len(positives) == 7 and len(negatives) == 13, (len(positives), len(negatives))
for source in positives:
    case(source)
for source, error in zip(negatives, ['type'] * 9 + ['syntax'] * 3 + ['type']):
    case(source, error)

# Valid/invalid corpus surrounded by invalid bytes; only the chosen range is scanned.
valid = [[0], [127], [194,128], [223,191], [224,160,128], [237,159,191],
         [239,191,191], [240,144,128,128], [244,143,191,191]]
invalid = [[128], [255], [192,128], [193,191], [194], [226,130], [224,159,191],
           [237,160,128], [240,143,191,191], [244,144,128,128], [245,128,128,128],
           [65,128], [194,65], [240,159,65,128]]
for expected, corpus in [(True, valid), (False, invalid)]:
    for data in corpus:
        n = len(data) + 2
        writes = ''.join(f'a[{i+1}]={v};' for i, v in enumerate(data))
        negate = '' if expected else '!'
        case(f'module main;fn i32 main(){{var u8[{n}] a=[255;{n}];{writes}if({negate}text::valid_utf8(a[1..{n-1}])){{return 42;}}return 0;}}')

for n in [1, 4, 4096]:
    for start in [n, n-1]:
        for byte in [65, 255]:
            source = f'module main;fn i32 main(){{let u8[{n}] a=[{byte};{n}];let bool b=text::valid_utf8(a[{start}..{n}]);return 42;}}'
            exact = 65712 + n + 4*(n-start)
            case(source, fuel=exact)
            case(source, 'fuel', fuel=exact-1)
            case(source, 'fuel', fuel=exact-52, anchor='text::valid_utf8')
for expr, error in [
    ('a[0]', 'syntax'), ('a[0..1', 'syntax'), ('a[0...1]', 'type'),
    ('a[0..=1]', 'type'), ('a[0..1][0..1]', 'syntax'),
    ('a[0+0..1]', 'syntax'), ('a[(0)..1]', 'type'), ('a[0..a.len]', 'type'),
    ('a[0..-1]', 'type'), ('a[0..4097]', 'type'),
    ('a[0..9223372036854775808]', 'type'), ('a[0..18446744073709551616]', 'type'),
    ('missing[0..1]', 'type'),
]:
    case(f'module main;fn i32 main(){{let u8[1] a=[0;1];let bool b=text::valid_utf8({expr});return 42;}}', error)
for tag in ['bool', 'i32', 'i64', 'u32', 'usize']:
    literal = 'true' if tag == 'bool' else '0'
    case(f'module main;fn i32 main(){{let {tag}[1] a=[{literal};1];let bool b=text::valid_utf8(a[0..1]);return 42;}}', 'type')
case('module main;fn i32 main(){{let u8[1] a=[0;1];}let bool b=text::valid_utf8(a[0..1]);return 42;}', 'type')
case('module main;fn i32 main(){let u8[1] a=[0;1];return text::valid_utf8(a[0..1]);}', 'type')
case('module main;fn i32 main(){let u8[2] a=[0;2];if(text::valid_utf8(a[0 . . 2])){return 42;}return 0;}')
# 16 existing source owners plus a predicate: a seventeenth owner would fail.
body = ''.join(f'let u8[1] a{i}=[65;1];' for i in range(16))
case('module main;fn i32 main(){'+body+'if(text::valid_utf8(a15[0..1])){return 42;}return 0;}')
assert len(rows) == 202, len(rows)
version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert all(version[k] is True for k in ['array_utf8_predicate', 'array_utf8_call_results', 'array_utf8_literals', 'array_utf8_ranges']), version
assert version['restricted'] is False and version['embed'] is False, version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-utf8-ranges-cli/v1', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2) + '\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-utf8-ranges CLI cases')
