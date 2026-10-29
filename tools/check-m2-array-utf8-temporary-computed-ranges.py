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
output = root / 'build/m2-array-utf8-temporary-computed-ranges' / args.profile
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



fixtures=(root/'tests/m2/array_utf8_temporary_computed_ranges.fy').read_text(encoding='utf-8')
positives=re.findall(r'value\(b"([^"\n]+)",\d+\);',fixtures)
negatives=re.findall(r'rejected\(b"([^"\n]+)"\);',fixtures)
errors=re.findall(r'error\(b"([^"\n]+)",(\d+)\);',fixtures)
fuels=re.findall(r'fuel\(b"([^"\n]+)",(\d+)\);',fixtures)
assert tuple(map(len,[positives,negatives,errors,fuels]))==(18,5,4,4)
for source in positives:case(source)
for source,error in zip(negatives,['type','type','syntax','syntax','type']):case(source,error)
for source,kind in errors:case(source,{'14':'bounds','6':'overflow','7':'zero_divisor'}[kind])
for source,native in fuels:
    exact=int(native)+65532
    case(source,fuel=exact)
    case(source,'fuel',fuel=exact-1)
    case(source,'fuel',fuel=exact-52,anchor='text::valid_utf8')
for n in [1,4,4096]:
    for lo,hi in [(0,n),(n,n),(n-1,n),(1,0),(0,n+1),(0,2**63),(0,2**64-1)]:
        for byte in [65,255]:
            for call in [False,True]:
                head=f'fn u8[{n}] make(){{return [{byte};{n}];}}' if call else ''
                arg='make()' if call else f'[{byte};{n}]'
                neg='' if byte==65 or lo==hi else '!'
                source=f'module main;{head}fn i32 main(){{let usize lo={lo};let usize hi={hi};if({neg}text::valid_utf8({arg}[lo+0..hi+0])){{return 42;}}return 0;}}'
                error='bounds' if lo>hi or hi>n else None
                case(source,error,anchor='text::valid_utf8' if error else None)
# Every range boundary around one complete UTF-8 scalar on a returned array.
for lo in range(7):
    for hi in range(lo,7):
        valid=lo==hi or (lo==1 and hi==5)
        neg='' if valid else '!'
        case('module main;fn u8[6] make(){var u8[6] a=[255;6];a[1]=240;a[2]=159;a[3]=141;a[4]=171;return a;}'+f'fn i32 main(){{if({neg}text::valid_utf8(make()[{lo}+0..{hi}+0])){{return 42;}}return 0;}}')
# A computed suffix needs one extra lexical capture; legacy simple forms do not.
for bindings in [63,64]:
    setup=''.join(f'let usize x{i}=0;' for i in range(bindings))
    case('module main;fn i32 main(){'+setup+'if(text::valid_utf8([65;1][0+0..1])){return 42;}return 0;}',None if bindings==63 else 'compile_limit')
    case('module main;fn i32 main(){'+setup+'if(text::valid_utf8([65;1][0..1])){return 42;}return 0;}')
assert len(rows)==310,len(rows)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert all(version[k] is True for k in ['array_utf8_temporary_computed_ranges','array_utf8_computed_ranges','array_utf8_temporary_dynamic_ranges']),version
assert version['restricted'] is False and version['embed'] is False,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-utf8-temporary-computed-ranges-cli/v1',status='passed',
    profile=args.profile,exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-utf8-temporary-computed-ranges CLI cases')
