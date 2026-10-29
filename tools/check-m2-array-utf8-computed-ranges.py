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
output = root / 'build/m2-array-utf8-computed-ranges' / args.profile
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



fixtures = (root / 'tests/m2/array_utf8_computed_ranges.fy').read_text(encoding='utf-8')
positives = re.findall(r'value\(b"([^"\n]+)",\d+\);',fixtures)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\);',fixtures)
errors = re.findall(r'error\(b"([^"\n]+)",(\d+)\);',fixtures)
assert tuple(map(len,[positives,negatives,errors]))==(12,8,5)
for source in positives:case(source)
for source,error in zip(negatives,['type']*4+['syntax']*3+['type']):case(source,error)
for source,kind in errors:case(source,{'14':'bounds','6':'overflow','7':'zero_divisor'}[kind])
source='module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[0+0..4]);return 42;}'
case(source,fuel=65736)
case(source,'fuel',fuel=65735)
case(source,'fuel',fuel=65684,anchor='text::valid_utf8')
for n in [1,4,4096]:
    for lo in [0,n-1,n]:
        for hi in [n,n+1]:
            for byte in [65,255]:
                neg='' if byte==65 or lo==hi else '!'
                source=f'module main;fn i32 main(){{let u8[{n}] a=[{byte};{n}];let usize lo={lo};let usize hi={hi};if({neg}text::valid_utf8(a[lo+0..hi+0])){{return 42;}}return 0;}}'
                case(source,'bounds' if hi>n else None,anchor='text::valid_utf8' if hi>n else None)
valid=[[0],[127],[194,128],[223,191],[224,160,128],[237,159,191],[239,191,191],[240,144,128,128],[244,143,191,191]]
invalid=[[128],[255],[192,128],[193,191],[194],[226,130],[224,159,191],[237,160,128],[240,143,191,191],[244,144,128,128],[245,128,128,128],[65,128],[194,65],[240,159,65,128]]
for expected,corpus in [(True,valid),(False,invalid)]:
    for data in corpus:
        n=len(data)+2
        writes=''.join(f'a[{i+1}]={v};' for i,v in enumerate(data))
        neg='' if expected else '!'
        case(f'module main;fn usize end(){{return {n-1};}}fn i32 main(){{var u8[{n}] a=[255;{n}];{writes}if({neg}text::valid_utf8(a[1+0..end()])){{return 42;}}return 0;}}')
for tag,value in [('i32','0'),('i64','0'),('u8','0'),('u32','0'),('bool','false')]:
    case(f'module main;fn i32 main(){{let u8[1] a=[65;1];let {tag} lo={value};let bool b=text::valid_utf8(a[(lo)..1]);return 0;}}','type')
for lo,hi in [(0,2**63),(0,2**64-1),(3,1),(2**63,4)]:
    case(f'module main;fn i32 main(){{let u8[4] a=[65;4];let usize lo={lo};let usize hi={hi};let bool b=text::valid_utf8(a[lo+0..hi+0]);return 42;}}','bounds',anchor='text::valid_utf8')
for depth,error in [(4,None),(40,'compile_limit')]:
    expr='('*depth+'0'+')'*depth
    case('module main;fn i32 main(){let u8[1] a=[65;1];let bool b=text::valid_utf8(a['+expr+'..1]);return 42;}',error)
assert len(rows)==196,len(rows)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert all(version[k] is True for k in ['array_utf8_computed_ranges','array_utf8_dynamic_ranges','array_utf8_temporary_dynamic_ranges']),version
assert version['restricted'] is False and version['embed'] is False,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-utf8-computed-ranges-cli/v1',status='passed',
    profile=args.profile,exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-utf8-computed-ranges CLI cases')
