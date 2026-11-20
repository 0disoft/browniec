"""Check the public scalar CLI contract using an already built executable."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
CONFIGURED = ROOT / 'examples/projects/configured-output'


def invoke(exe, args, exit_code, *, cwd=None, input_bytes=None, stdin=None):
    ran = subprocess.run([str(exe), *map(str, args)], cwd=cwd, input=input_bytes, stdin=stdin,
                         capture_output=True, timeout=10)
    assert ran.returncode == exit_code, (args, exit_code, ran)
    return ran


def check_json(exe, args, exit_code, *, version=1, value=None, profile='brownie.m1-scalar/1',
               input_bytes=None, stdin=None, output_b64=None):
    flag = '--json' if version == 1 else '--json-v2'
    ran = invoke(exe, [*args, flag], exit_code, input_bytes=input_bytes, stdin=stdin)
    assert not ran.stderr and len(ran.stdout.splitlines()) == 1, ran
    assert ran.stdout.endswith(b'\n'), ran
    result = json.loads(ran.stdout)
    error = result.pop('error')
    expected = {
        'schema': f'browniec.result/v{version}',
        'profile': profile,
        'command': args[0],
        'status': 'error' if exit_code else 'checked' if args[0] == 'check' else 'completed',
        'return_i32': value,
    }
    if output_b64 is not None:
        expected['output_b64'] = output_b64
    assert result == expected and type(result['return_i32']) is type(value), (args, result)
    return error


def check_diagnostic(exe, path, code, kind, location, text):
    args = ['check', path]
    ran = invoke(exe, args, code)
    assert not ran.stdout and ran.stderr.splitlines() == [text], (args, ran)
    legacy = check_json(exe, args, code)
    assert legacy == {'kind': kind, 'byte_offset': 0}, legacy
    assert type(legacy['byte_offset']) is int, legacy
    v2 = check_json(exe, args, code, version=2)
    assert v2 == {'kind': kind, 'location': location}, v2
    if 'offset' in location:
        assert type(v2['location']['offset']) is int, v2


def check_output_table(exe, identity):
    subprocess.run([sys.executable, '-B', str(ROOT / 'tools/sync-cli-output.py'), '--check'],
                   check=True, timeout=10)
    answer = ROOT / 'examples/answer.brc'
    project = ROOT / 'examples/projects/hello/project.json'
    sources = {'check': [answer], 'run': [answer], 'eval-i32': [identity, 41]}
    tokens = {'--version': b'Brownie C experimental:', 'check': b'checked',
              'run': b'return_i32=77', 'eval-i32': b'return_i32=41',
              'inspect': b'Brownie C private IR diagnostics;'}
    rows = json.loads((ROOT / 'docs-site/cli-output.json').read_bytes())
    for row in rows:
        command = row['command']
        if command == 'inspect':
            args = [answer, row['arguments'].split()[-1]]
        elif '--policy' in row['arguments']:
            args = configured_arguments(CONFIGURED)[1:]
        elif row['arguments'].startswith('--project '):
            args = ['--project', project]
        else:
            args = sources.get(command, [])
        for mode in row['formats']:
            option = mode['option']
            ran = invoke(exe, [command, *args, *([option] if option else [])], 0)
            written = getattr(ran, mode['channel'])
            other = ran.stderr if mode['channel'] == 'stdout' else ran.stdout
            assert written and not other, (row, mode, ran)
            schema = mode['schema']
            if schema is None:
                expected = b'return_i32=42' if command == 'run' and args[0] == '--project' else tokens[command]
                assert written.startswith(expected), (row, mode, ran)
            else:
                assert len(written.splitlines()) == 1 and written.endswith(b'\n'), ran
                obj = json.loads(written)
                assert type(obj) is dict and obj['schema'] == schema, (mode, obj)
                if command != '--version':
                    assert obj['command'] == command, obj
    print('PASS: documented CLI channels and schemas match native output')


def configured_arguments(folder):
    return ['run', '--project', folder / 'project.json', '--policy', folder / 'policy.json',
            '--run', folder / 'run.json']


def check_configured_output(exe, folder):
    project = folder / 'configured'
    shutil.copytree(CONFIGURED, project)
    args = configured_arguments(project)
    source = project / 'app.brc'
    original = source.read_bytes()
    payload = project / 'payload.bin'
    payload.write_bytes(b'A\x00')
    run_file = project / 'run.json'
    config = json.loads(run_file.read_bytes())

    def update(**overrides):
        run_file.write_text(json.dumps(config | overrides), encoding='utf-8')

    profile = 'brownie.m2-reference/1'
    for version in (1, 2):
        assert check_json(exe, [*args, '--input', payload], 0, value=77, version=version,
                          profile=profile, output_b64='QQA=') is None
    assert check_json(exe, [*args, '--stdin'], 0, value=77, version=2, profile=profile,
                      input_bytes=b'A\x00', output_b64='QQA=') is None
    assert check_json(exe, args, 0, value=77, version=2, profile=profile, output_b64='') is None
    for invalid in (args, [*args[:-2], '--json'], [*args, '--fuel', 1, '--json'],
                    [*args, '--run', run_file, '--json']):
        invoke(exe, invalid, 2)

    for field, limit, expected in (('input_bytes', 1, 'input_limit'),
                                   ('output_bytes', 1, 'output_limit')):
        update(limits=config['limits'] | {field: limit})
        error = check_json(exe, [*args, '--input', payload], 5, version=2, profile=profile)
        assert error['kind'] == expected, error
    update()

    source.write_bytes(b'module app;pub fn i32 transform(ref u8[] data){'
                       b'output::emit(ref data);let i32 z=data[0] as i32;return 1/(z-z);}')
    error = check_json(exe, [*args, '--input', payload], 5, version=2, profile=profile)
    assert error['kind'] == 'zero_divisor' and error['location']['path'] == 'app.brc', error

    source.write_bytes(b'module app;pub fn i32 transform(ref u8[] data){'
                       b'output::emit(ref data);while(true){}return 77;}')
    update(limits=config['limits'] | {'deadline_ms': 1})
    error = check_json(exe, [*args, '--input', payload], 5, version=2, profile=profile)
    assert error == {'kind': 'deadline', 'location': {'kind': 'none'}}, error
    update()

    source.write_bytes(b'module app;pub fn i32 transform(ref u8[] data){return true;}')
    error = check_json(exe, [*args, '--input', folder / 'missing.bin'], 3, version=2)
    assert error['kind'] == 'type' and error['location']['path'] == 'app.brc', error
    source.unlink()
    for overrides in ({'entry': {'module': 'app', 'function': 'wrong'}}, {'grants': []}):
        update(**overrides)
        error = check_json(exe, [*args, '--input', folder / 'missing.bin'], 4, version=2)
        assert error == {'kind': 'unavailable', 'location': {'kind': 'none'}}, error
    update()
    source.write_bytes(original)
    no_requirements = json.loads((project / 'project.json').read_bytes()) | {'requires': []}
    (project / 'project.json').write_text(json.dumps(no_requirements), encoding='utf-8')
    update(requires=[], grants=[])
    error = check_json(exe, [*args, '--input', folder / 'missing.bin'], 4, version=2)
    assert error == {'kind': 'unavailable', 'location': {'kind': 'none'}}, error
    print('PASS: configured project grants, binary publication, quotas, diagnostics and deadline')


def check_project_location(exe, manifest, command, code, kind, index, name, source, offset, end):
    args = [command, '--project', manifest]
    line = source[:offset].count(b'\n') + 1
    column = offset - source.rfind(b'\n', 0, offset)
    expected = {
        'kind': 'source_byte', 'offset': offset, 'end_offset': end,
        'path': name, 'source_index': index, 'line': line, 'byte_column': column,
    }
    assert check_json(exe, args, code, version=2) == {'kind': kind, 'location': expected}
    assert check_json(exe, args, code) == {'kind': kind, 'byte_offset': offset}
    ran = invoke(exe, args, code)
    assert not ran.stdout and ran.stderr == f'browniec: {kind} at {name}:{line}:{column}\n'.encode(), ran


def check_project(exe, folder):
    help_text = invoke(exe, ['--help'], 0)
    assert b'check --project FILE' in help_text.stdout and b'run --project FILE' in help_text.stdout
    project = folder / '프로젝트'
    project.mkdir()
    manifest = project / 'rules.json'
    main = project / 'app.brc'
    helper = project / 'helper.brc'
    config = {
        'schema': 'brownie.project/0.3', 'name': 'fixture',
        'entry': {'module': 'app', 'function': 'chosen'},
        'sources': [{'module': 'app', 'path': main.name}, {'module': 'helper', 'path': helper.name}],
        'requires': [],
    }

    def write():
        manifest.write_text(json.dumps(config), encoding='utf-8')

    args = ['run', '--project', manifest]
    main.write_bytes(b'module app; import helper as h; pub fn i32 chosen(){return h::answer()+35;}')
    helper.write_bytes(b'module helper; pub fn i32 answer(){return 42;}')
    write()
    assert not invoke(exe, [*args, '--json'], 0, cwd=folder).stderr
    assert check_json(exe, args, 0, value=77) is None
    assert check_json(exe, args, 0, version=2, value=77) is None
    relative = invoke(exe, ['run', '--project', manifest.name], 0, cwd=project)
    assert not relative.stdout and relative.stderr.strip() == b'return_i32=77', relative
    assert check_json(exe, ['check', '--project', manifest], 0) is None
    assert check_json(exe, [*args, '--fuel', '0'], 5)['kind'] == 'fuel'

    main.write_bytes(b'module app; pub fn i32 chosen(){return 1/0;}')
    assert check_json(exe, ['check', '--project', manifest], 0) is None
    assert check_json(exe, args, 5)['kind'] == 'zero_divisor'

    helper_path = 'lib/helper-file.brc'
    library = project / helper_path
    library.parent.mkdir()
    config['sources'][1]['path'] = helper_path
    write()
    library.write_bytes(helper.read_bytes())
    main.write_bytes(b'@')
    check_project_location(exe, manifest, 'check', 3, 'lexical', 0, main.name, b'@', 0, 1)

    main.write_bytes(b'module app;import helper as h;pub fn i32 chosen(){return h::answer();}')
    for command, code, kind, suffix, token in (
        ('check', 3, 'type', b'true;}', b'return'),
        ('run', 5, 'zero_divisor', b'1/0;}', b'/0'),
    ):
        source = 'module helper;\r\npub fn i32 answer(){/* 한 */ return '.encode() + suffix
        library.write_bytes(source)
        offset = source.index(token)
        check_project_location(exe, manifest, command, code, kind, 1, helper_path, source, offset, offset + 1)

    config['sources'][1]['path'] = 'lib/invalid\npath.brc'
    write()
    invalid = check_json(exe, args, 2, version=2)
    assert invalid['kind'] == 'usage' and 'path' not in invalid['location'], invalid

    config['sources'][1]['path'] = 'absent.brc'
    config['requires'] = ['host.demo.read']
    write()
    denied = check_json(exe, args, 4, version=2)
    assert denied == {'kind': 'unavailable', 'location': {'kind': 'none'}}, denied
    config['requires'] = []
    write()
    assert check_json(exe, args, 7)['kind'] == 'input_io'

    config['sources'][1]['path'] = '../helper.brc'
    write()
    assert check_json(exe, args, 2)['kind'] == 'usage'
    config['sources'][1]['path'] = helper.name
    write()
    alias = folder / 'outside.brc'
    alias.hardlink_to(helper)
    assert check_json(exe, args, 7)['kind'] == 'input_io'
    alias.unlink()
    alias.hardlink_to(manifest)
    assert check_json(exe, args, 7)['kind'] == 'input_io'
    alias.unlink()

    manifest.write_bytes(b' ' * 65537)
    assert check_json(exe, args, 2)['kind'] == 'usage'
    assert not invoke(exe, ['run', '--project'], 2).stdout
    print('PASS: project entry, rooted files, checks without execution, Fuel, and denial paths')


def check_project_input(exe, folder):
    assert b'[--input FILE|--stdin]' in invoke(exe, ['--help'], 0).stdout
    manifest = folder / 'binary-project.json'
    source = folder / 'binary.brc'
    payload = folder / '입력.bin'
    config = {
        'schema': 'brownie.project/0.3', 'name': 'binary',
        'entry': {'module': 'app', 'function': 'chosen'},
        'sources': [{'module': 'app', 'path': source.name}], 'requires': [],
    }
    manifest.write_text(json.dumps(config), encoding='utf-8')
    source.write_bytes(
        b'module app;pub fn i32 chosen(ref u8[] data){if(data.len==0){return 0;}'
        b'if(data[0]!=0){return -1;}let i32 last=data[data.len-1] as i32;'
        b'if(data.len==3){return last+1;}if(data.len==4097){return last+2;}'
        b'if(data.len==1048576){return last+3;}return -1;}'
    )
    args = ['run', '--project', manifest, '--input', payload, '--fuel', 16000000]
    stdin_args = ['run', '--project', manifest, '--stdin', '--fuel', 16000000]
    profile = 'brownie.m2-reference/1'
    for length, value in ((0, 0), (3, 256), (4097, 257), (1048576, 258)):
        binary = bytes(length-1) + bytes([255]) if length else b''
        payload.write_bytes(binary)
        for version in (1, 2):
            assert check_json(exe, args, 0, value=value, version=version, profile=profile) is None
            assert check_json(exe, stdin_args, 0, value=value, version=version,
                              profile=profile, input_bytes=binary) is None
    with payload.open('rb') as redirected:
        assert check_json(exe, stdin_args, 0, value=258, version=2,
                          profile=profile, stdin=redirected) is None
    ran = invoke(exe, ['run', '--project', manifest.name, '--input', payload.name, '--fuel', 16000000],
                 0, cwd=folder)
    assert not ran.stdout and ran.stderr == b'return_i32=258\n', ran

    payload.write_bytes(bytes(1048577))
    assert check_json(exe, args, 5, version=2, profile=profile) == {
        'kind': 'input_limit', 'location': {'kind': 'none'},
    }
    assert check_json(exe, stdin_args, 5, version=2, profile=profile,
                      input_bytes=bytes(1048577)) == {
        'kind': 'input_limit', 'location': {'kind': 'none'},
    }
    assert check_json(exe, stdin_args, 7, version=2, profile=profile, stdin=subprocess.DEVNULL) == {
        'kind': 'input_io', 'location': {'kind': 'none'},
    }
    payload.unlink()
    assert check_json(exe, args, 7, version=2, profile=profile) == {
        'kind': 'input_io', 'location': {'kind': 'none'},
    }
    payload.write_bytes(b'\x00\xff')
    assert check_json(exe, [*args[:-1], 0], 5, version=2, profile=profile)['kind'] == 'fuel'
    for rejected in (
        ['check', '--project', manifest, '--input', payload],
        ['run', source, '--input', payload],
        ['run', '--project', manifest, '--input'],
        [*args, '--input', payload],
        [*args, '--stdin'],
        [*stdin_args, '--input', payload],
        [*stdin_args, '--stdin'],
        ['check', '--project', manifest, '--stdin'],
        ['run', source, '--stdin'],
    ):
        invoke(exe, rejected, 2)
    invoke(exe, ['run', '--project', manifest], 3)

    payload.unlink()
    source.write_bytes(b'module app;pub fn i32 chosen(ref u8[] data){return true;}')
    bad = check_json(exe, args, 3, version=2)
    assert bad['kind'] == 'type' and bad['location']['path'] == source.name, bad
    stdin_bad = check_json(exe, stdin_args, 3, version=2, stdin=subprocess.DEVNULL)
    assert stdin_bad == bad, stdin_bad
    config['requires'] = ['host.demo.read']
    manifest.write_text(json.dumps(config), encoding='utf-8')
    source.unlink()
    assert check_json(exe, args, 4, version=2) == {
        'kind': 'unavailable', 'location': {'kind': 'none'},
    }
    assert check_json(exe, stdin_args, 4, version=2, stdin=subprocess.DEVNULL) == {
        'kind': 'unavailable', 'location': {'kind': 'none'},
    }
    print('PASS: project file/pipe input, disk stdin, 0/3/4097/1048576-byte boundaries, Fuel and denials')


def inspect_json(exe, source, *options, exit_code=0, schema='browniec.limits/v1'):
    ran = invoke(exe, ['inspect', source, *options], exit_code)
    assert not ran.stderr and len(ran.stdout.splitlines()) == 1 and ran.stdout.endswith(b'\n'), ran
    obj = json.loads(ran.stdout)
    assert type(obj) is dict and obj['schema'] == schema and obj['command'] == 'inspect', obj
    return obj


def check_inspection_limits(exe, folder):
    path = folder / 'limits.brc'
    ceilings = {'source_bytes': 4096, 'instructions': 256, 'functions': 16, 'registers': 128}
    for count in (15, 16, 17):
        raw = ('module main; fn i32 main(){ return 1/0; }\n' +
               ''.join(f'fn i32 helper{i}(){{ return {i}; }}\n' for i in range(count - 1))).encode()
        if count == 16:
            raw = raw.ljust(4096, b' ')
        path.write_bytes(raw)
        if count == 17:
            obj = inspect_json(exe, path, '--limits', '--json', exit_code=3)
            assert obj['status'] == 'error' and obj['error']['kind'] == 'compile_limit', obj
            assert 'limits' not in obj, obj
            continue
        result = inspect_json(exe, path, '--json', '--limits')
        ir = inspect_json(exe, path, '--ir', '--json', schema='browniec.ir/v1')
        used = {'source_bytes': len(raw), 'instructions': ir['instruction_count'],
                'functions': len(ir['functions']), 'registers': ir['register_count']}
        assert used['functions'] == count
        expected = {key: {'used': value, 'limit': ceilings[key], 'remaining': ceilings[key] - value}
                    for key, value in used.items()}
        assert result['status'] == 'inspected' and result['error'] is None and result['limits'] == expected, result
        assert result['profile'] == ir['profile'], result
        # The divide by zero is reachable only when the VM executes the guest.
        invoke(exe, ['run', path], 5)

    path.write_bytes(b' ' * 4097)
    too_large = inspect_json(exe, path, '--limits', '--json', exit_code=3)
    assert too_large['error'] == {'kind': 'compile_limit', 'byte_offset': 4096}, too_large
    path.write_bytes(b'module main; fn i32 main(){ return b"abc"[0] as i32; }')
    retained = inspect_json(exe, path, '--limits', '--json')
    assert retained['profile'] == 'brownie.m2-reference/1' and retained['limits']['functions']['used'] == 1, retained
    for invalid in (('--limits', '--limits'), ('--limits', '--ir'), ('--limits', '--fuel', '1')):
        obj = inspect_json(exe, path, '--json', *invalid, exit_code=2)
        assert obj['error']['kind'] == 'usage', obj
    text = invoke(exe, ['inspect', path, '--limits'], 2)
    assert not text.stdout and b'usage' in text.stderr, text
    print('PASS: limits at 15/16/17 functions, 4096/4097 source bytes, and retained IR')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    exe = parser.parse_args().exe.resolve(strict=True)
    print(f'CLI SHA-256: {hashlib.sha256(exe.read_bytes()).hexdigest()}', flush=True)

    shipping = ROOT / 'examples/shipping-fee.brc'
    with TemporaryDirectory(prefix='browniec-cli-') as temp:
        source_zero = Path(temp) / 'source-zero.brc'
        source_zero.write_bytes(b'\xff')
        missing = Path(temp) / 'missing.brc'
        identity = Path(temp) / 'identity.brc'
        identity.write_bytes(b'module main; fn i32 evaluate(i32 x) { return x; }\n')

        check_output_table(exe, identity)
        check_project(exe, Path(temp))
        check_project_input(exe, Path(temp))
        check_configured_output(exe, Path(temp))
        check_inspection_limits(exe, Path(temp))
        check_diagnostic(exe, source_zero, 3, 'lexical',
                         {'kind': 'source_byte', 'offset': 0}, b'browniec: lexical at byte 0')
        check_diagnostic(exe, missing, 7, 'input_io',
                         {'kind': 'none'}, b'browniec: input_io')
        print('PASS: source byte zero and absent location in text, JSON v1 and JSON v2')

        for source, number, expected in (
            (shipping, 29999, 3000), (shipping, 30000, 0),
            (identity, -2147483648, -2147483648), (identity, 2147483647, 2147483647),
        ):
            error = check_json(exe, ['eval-i32', source, number], 0, value=expected)
            assert error is None, (number, error)

        # A missing source would give exit 7 if the CLI tried to open it first.
        for invalid in ('not-a-number', '-2147483649', '2147483648'):
            error = check_json(exe, ['eval-i32', missing, invalid], 2)
            assert error == {'kind': 'usage', 'byte_offset': 0}, (invalid, error)
            assert type(error['byte_offset']) is int, error
        fuel = check_json(exe, ['eval-i32', shipping, 29999, '--fuel', 0], 5)
        assert set(fuel) == {'kind', 'byte_offset'} and fuel['kind'] == 'fuel', fuel
        assert type(fuel['byte_offset']) is int and fuel['byte_offset'] >= 0, fuel
        print('PASS: eval-i32 shipping and i32 boundaries (0), invalid input (2), Fuel exhaustion (5)')


if __name__ == '__main__':
    main()
