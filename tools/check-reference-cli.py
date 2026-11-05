"""Check public retained source admission through the tool-free native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


REFERENCE_PROFILE = 'brownie.m2-reference/1'
SCALAR_PROFILE = 'brownie.m1-scalar/1'
ARRAY_PROFILE = 'brownie.m2-array-read/1'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()

    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    empty = out / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    exe = args.exe.resolve(strict=True)
    receipt = out / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8', newline='\n')
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    rows = []
    sources = {}

    def source(name, text):
        path = out / f'{name}.brc'
        path.write_bytes(text.encode('utf-8'))
        sources[name] = dict(path=path, text=text)
        return path

    def invoke(name, mode, extra=(), error=None, value=None, profile=None,
               expected_exit=None):
        path = sources[name]['path']
        command = [str(exe), mode, str(path), '--json', *map(str, extra)]
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=20)
        data = json.loads(done.stdout)
        assert not done.stderr, (command, done.stderr)
        assert data['schema'] == 'browniec.result/v1' and data['command'] == mode, data
        if error is None:
            status = 'checked' if mode == 'check' else 'completed'
            assert data['status'] == status and data['return_i32'] == value, (command, data)
            assert data['error'] is None, data
            exit_code = 0
        else:
            allowed = {error} if isinstance(error, str) else set(error)
            assert data['status'] == 'error' and data['return_i32'] is None, (command, data)
            assert data['error']['kind'] in allowed, (command, data)
            kind = data['error']['kind']
            exit_code = {'usage': 2, 'lexical': 3, 'syntax': 3, 'type': 3,
                         'compile_limit': 3, 'fuel': 5, 'bounds': 5,
                         'allocation': 5, 'verification': 6, 'unavailable': 4}[kind]
        if expected_exit is not None:
            exit_code = expected_exit
        assert done.returncode == exit_code, (command, done.returncode, data)
        if profile is not None:
            assert data['profile'] == profile, (command, data)
        rows.append(dict(command=command, sourceSha256=hashlib.sha256(
            sources[name]['text'].encode('utf-8')).hexdigest(), exit=done.returncode,
            result=data))

    def successful(name, text, profile, value=42, fuel=16000000):
        source(name, text)
        invoke(name, 'check', profile=profile)
        invoke(name, 'run', ['--fuel', fuel], profile=profile, value=value)

    def rejected(name, text, kinds):
        source(name, text)
        invoke(name, 'check', error=kinds)
        invoke(name, 'run', error=kinds)

    scalar = 'module main;fn i32 main(){return 42;}'
    source('legacy-scalar', scalar)
    invoke('legacy-scalar', 'check', profile=SCALAR_PROFILE)
    invoke('legacy-scalar', 'run', profile=SCALAR_PROFILE, value=42)
    invoke('legacy-scalar', 'run', ['--fuel', 1], error='fuel', profile=SCALAR_PROFILE)
    invoke('legacy-scalar', 'run', ['--fuel', 2], profile=SCALAR_PROFILE, value=42)
    invoke('legacy-scalar', 'run', ['--fuel', 16000001], error='usage')

    # Both source routes preserve the established 32-deep expression budget.
    for retained in [False, True]:
        for depth in [32, 33, 64]:
            name = f'depth-{retained}-{depth}'
            prefix = 'module main;fn i32 id(i32 n){return n;}fn i32 main(){'
            if retained:
                prefix += 'let ref u8[] t=b"*";'
            source(name, prefix + 'return ' + 'id(' * depth + '42' + ')' * depth + ';}')
            if depth == 32:
                invoke(name, 'check', profile=REFERENCE_PROFILE if retained else SCALAR_PROFILE)
                invoke(name, 'run', ['--fuel', 16000000], value=42,
                       profile=REFERENCE_PROFILE if retained else SCALAR_PROFILE)
            else:
                invoke(name, 'check', error='compile_limit')
                invoke(name, 'run', ['--fuel', 16000000], error='compile_limit')

    old_array = 'module main;fn i32 main(){let i32[1] a=[42;1];return a[0];}'
    source('legacy-array', old_array)
    invoke('legacy-array', 'check', profile=ARRAY_PROFILE)
    invoke('legacy-array', 'run', error='fuel', profile=ARRAY_PROFILE)
    invoke('legacy-array', 'run', ['--fuel', 16000000], profile=ARRAY_PROFILE, value=42)

    source('byte-literal', 'module main;fn i32 main(){return b"*"[0] as i32;}')
    invoke('byte-literal', 'check', profile=REFERENCE_PROFILE)
    invoke('byte-literal', 'run', error='fuel', profile=REFERENCE_PROFILE)
    invoke('byte-literal', 'run', ['--fuel', 16000000], profile=REFERENCE_PROFILE, value=42)
    # Independent source oracle: entry 147456 + leave 196608 + OPEN 17,
    # index 1, READ 18, widening 1, CLOSE 1 and RETURN dispatch 1.
    for budget in [344102, 344103, 344104]:
        invoke('byte-literal', 'run', ['--fuel', budget],
               error='fuel' if budget < 344103 else None,
               profile=REFERENCE_PROFILE, value=None if budget < 344103 else 42)

    successful('text-bytes', 'module main;fn i32 main(){return text::bytes("한")[0] as i32;}',
               REFERENCE_PROFILE, 237)
    successful('equality', 'module main;fn i32 main(){if(text::equal(b"abc",b"abc")){return 42;}return 0;}',
               REFERENCE_PROFILE)
    successful('narrowed-alias',
               'module main;fn i32 main(){let ref u8[] text=b"*42";let ref u8[] tail=ref text[1..];return tail[0] as i32;}',
               REFERENCE_PROFILE, 52)
    successful('image-return',
               'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){return same(ref b"*")[0] as i32;}',
               REFERENCE_PROFILE)
    successful('owned-return',
               'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];return same(ref a)[0] as i32;}',
               REFERENCE_PROFILE)
    successful('literal-provider',
               'module main;fn ref u8[] literal(){return b"*";}fn i32 main(){return literal()[0] as i32;}',
               REFERENCE_PROFILE)
    successful('selected-temporary',
               'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref a;}fn i32 main(){let ref u8[] selected=pick(ref [42;2],ref [42;2]);var u8[2] unused=[42;2];unused[0]=7;let ref u8[] alias=ref selected;if(alias[1]==42 && unused[0]==7){return 42;}return 0;}',
               REFERENCE_PROFILE)
    successful('nested',
               'module main;fn ref u8[] id(ref u8[] p){return ref p;}fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref b;}fn ref u8[] nested(ref u8[] a,ref u8[] b){return pick(ref a,ref pick(ref b,ref a));}fn i32 main(){return nested(ref [42;2],ref b"!")[1] as i32;}',
               REFERENCE_PROFILE)
    successful('empty-view',
               'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] empty=same(ref a[1..]);if(empty.len==0){return 42;}return 0;}',
               REFERENCE_PROFILE)

    source('bounds',
           'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];return same(ref a)[1] as i32;}')
    invoke('bounds', 'check', profile=REFERENCE_PROFILE)
    invoke('bounds', 'run', ['--fuel', 16000000], error='bounds', profile=REFERENCE_PROFILE)

    successful('sixty-four-kibibytes',
               'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[4096] a=[42;4096];return same(ref a)[4095] as i32;}',
               REFERENCE_PROFILE, fuel=16000000)

    lifetime = {'type', 'verification'}
    rejected('lifetime',
             'module main;fn ref u8[] leak(){let u8[1] a=[42;1];return ref a;}fn i32 main(){return 0;}',
             lifetime)
    rejected('drop',
             'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=same(ref a);a=[42;1];return p[0] as i32;}',
             lifetime)
    rejected('write',
             'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=same(ref a);a[0]=0;return p[0] as i32;}',
             lifetime)
    rejected('exclusive',
             'module main;fn ref mut u8[] exclusive(ref mut u8[] p){return ref mut p;}fn i32 main(){return 0;}',
             lifetime)
    rejected('non-byte',
             'module main;fn ref i32[] wrong(ref i32[] p){return ref p;}fn i32 main(){return 0;}',
             lifetime)
    rejected('missing-argument',
             'module main;fn i32 main(){if(text::equal(b"a")){return 42;}return 0;}',
             {'syntax'})
    rejected('wrong-type',
             'module main;fn i32 main(){if(text::equal("a",b"a")){return 42;}return 0;}',
             {'type', 'verification'})
    rejected('mixed-origin',
             'module main;fn ref u8[] mixed(ref u8[] p,bool choose){if(choose){return ref p;}return b"*";}fn i32 main(){return 0;}',
             lifetime)
    rejected('conflicting-origin',
             'module main;fn ref u8[] conflicting(ref u8[] a,ref u8[] b,bool choose){if(choose){return ref a;}return ref b;}fn i32 main(){return 0;}',
             lifetime)

    lexical_prefix = 'module main;fn i32 main(){return '
    lexical = lexical_prefix + 'b"\\q"[0] as i32;}'
    source('lexical', lexical)
    for mode in ['check', 'run']:
        invoke('lexical', mode, error='lexical')
        assert rows[-1]['result']['error']['byte_offset'] == len(lexical_prefix.encode()) + 2, rows[-1]

    rejected('syntax', 'module main;fn i32 main(){return 42;', {'syntax'})

    version_cmd = [str(exe), '--version', '--json']
    version_run = subprocess.run(version_cmd, cwd=empty, env=env, capture_output=True, timeout=15)
    assert version_run.returncode == 0 and not version_run.stderr, version_run
    version = json.loads(version_run.stdout)
    assert version['schema'] == 'browniec.version/v1'
    assert version['reference_profile'] == REFERENCE_PROFILE
    for key in ['byte_literals', 'text_literals', 'immutable_byte_views',
                'shared_byte_parameters', 'shared_byte_results']:
        assert version[key] is True, (key, version)
    assert not version.get('array_slice_results', False)
    assert version['restricted'] is False and version['embed'] is False
    assert version['fuel_default'] == 256 and version['fuel_limit'] == 16000000
    rows.append(dict(command=version_cmd, exit=version_run.returncode, result=version))

    isolated_cmd = [str(exe), 'run', str(sources['byte-literal']['path']), '--json', '--isolated']
    isolated = subprocess.run(isolated_cmd, cwd=empty, env=env, capture_output=True, timeout=15)
    isolated_result = json.loads(isolated.stdout)
    assert isolated.returncode == 4 and not isolated.stderr, isolated
    assert isolated_result['status'] == 'error'
    assert isolated_result['error']['kind'] == 'unavailable', isolated_result
    rows.append(dict(command=isolated_cmd, exit=isolated.returncode, result=isolated_result))

    assert len(sources) == 31, len(sources)
    assert len(rows) == 72, len(rows)
    receipt.write_text(json.dumps(dict(
        schema='browniec.public-program-cli/v1', status='passed',
        exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
        harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        environment='cleared; tool-free PATH', distinctSources=len(sources),
        count=len(rows), cases=rows, version=version), indent=2, ensure_ascii=False) + '\n',
        encoding='utf-8', newline='\n')
    print(f'PASS: {len(rows)} public Program CLI cases from {len(sources)} sources')


if __name__ == '__main__':
    main()
