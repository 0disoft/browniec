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
output = root / 'build/m2-array-utf8-open-ranges' / args.profile
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


fixtures = (root / 'tests/m2/array_utf8_open_ranges.fy').read_text(encoding='utf-8')
positives = re.findall(r'value\(b"([^"\n]+)",\d+\);', fixtures)
negatives = re.findall(r'rejected\(b"([^"\n]+)"\);', fixtures)
assert len(positives)==9 and len(negatives)==6, (len(positives),len(negatives))
for source in positives:
    case(source)
for source,error in zip(negatives,['type']*5+['syntax']):
    case(source,error)

def program(form,n,byte,suffix,body='return 42;'):
    prefix=f'fn u8[{n}] make(){{return [{byte};{n}];}}' if form=='call' else ''
    bind=f'let u8[{n}] a=[{byte};{n}];' if form=='named' else ''
    arg='a' if form=='named' else 'make()' if form=='call' else f'[{byte};{n}]'
    return f'module main;{prefix}fn i32 main(){{{bind}let bool b=text::valid_utf8({arg}{suffix});{body}}}'
for n in [1,4096]:
    for byte in [65,255]:
        for form in ['named','call','literal']:
            for suffix,k in [('['+'..]',n),(f'[..{n}]',n),('[0..]',n),('[..0]',0),(f'[{n}..]',0)]:
                body='if(b){return 42;}return 0;' if byte==65 or k==0 else 'if(!b){return 42;}return 0;'
                case(program(form,n,byte,suffix,body))
for form in ['named','call','literal']:
    for suffix,k in [('[..]',4),('[..2]',2),('[2..]',2),('[4..]',0)]:
        source=program(form,4,65,suffix)
        exact=(65778 if form=='call' else 65712)+4+4*k
        case(source,fuel=exact)
        case(source,'fuel',fuel=exact-1)
        case(source,'fuel',fuel=exact-52,anchor='text::valid_utf8')
for form in ['named','call','literal']:
    for suffix,error in [('[...]','type'),('[..=1]','type'),('[..18446744073709551615]','type'),('[2..]','type'),('[..1][..]','syntax')]:
        case(program(form,1,65,suffix),error)
# Complete and cut multibyte scalars at inferred prefix/suffix boundaries.
for call in [False,True]:
    for prefix,suffix,valid in [(True,'[..4]',True),(True,'[..3]',False),(False,'[1..]',True),(False,'[2..]',False)]:
        data=[240,159,141,171,255] if prefix else [255,240,159,141,171]
        writes=''.join(f'a[{i}]={v};' for i,v in enumerate(data))
        if call:
            head='fn u8[5] make(){var u8[5] a=[0;5];'+writes+'return a;}'
            setup='';arg='make()'
        else:
            head='';setup='var u8[5] a=[0;5];'+writes;arg='a'
        neg='' if valid else '!'
        case('module main;'+head+'fn i32 main(){'+setup+'if('+neg+'text::valid_utf8('+arg+suffix+')){return 42;}return 0;}')
case('module main;fn i32 main(){let u8[1] a=[65;1];if(text::valid_utf8(a[ . . ])){return 42;}return 0;}')
assert len(rows)==270,len(rows)
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert all(version[k] is True for k in ['array_utf8_predicate','array_utf8_call_results','array_utf8_literals','array_utf8_ranges','array_utf8_temporary_ranges','array_utf8_open_ranges']),version
assert version['restricted'] is False and version['embed'] is False,version
receipt.write_text(json.dumps(dict(schema='browniec.m2-array-utf8-open-ranges-cli/v1',status='passed',
    profile=args.profile,exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH',count=len(rows),cases=rows,version=version),indent=2)+'\n',encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} array-utf8-open-ranges CLI cases')
