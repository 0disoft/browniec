"""Check the public scalar CLI contract using an already built executable."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]


def invoke(exe, args, exit_code, *, cwd=None):
    ran = subprocess.run([str(exe), *map(str, args)], cwd=cwd, capture_output=True, timeout=10)
    assert ran.returncode == exit_code, (args, exit_code, ran)
    return ran


def check_json(exe, args, exit_code, *, version=1, value=None):
    flag = '--json' if version == 1 else '--json-v2'
    ran = invoke(exe, [*args, flag], exit_code)
    assert not ran.stderr and len(ran.stdout.splitlines()) == 1, ran
    assert ran.stdout.endswith(b'\n'), ran
    result = json.loads(ran.stdout)
    error = result.pop('error')
    expected = {
        'schema': f'browniec.result/v{version}',
        'profile': 'brownie.m1-scalar/1',
        'command': args[0],
        'status': 'error' if exit_code else 'checked' if args[0] == 'check' else 'completed',
        'return_i32': value,
    }
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
