"""Check the public scalar CLI contract using an already built executable."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
from unittest.mock import patch

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


def check_scalar_mismatch(exe, args, source, at, related, declaration, actual='u32'):
    def position(offset):
        return {
            'line': source.count(b'\n', 0, offset) + 1,
            'byte_column': offset - source.rfind(b'\n', 0, offset),
        }

    def described(offset):
        point = position(offset)
        return f"byte {offset} (line {point['line']}, byte column {point['byte_column']})"

    ran = invoke(exe, args, 3)
    assert not ran.stdout and ran.stderr.splitlines() == [
        (f'browniec: type at {described(at)}, expected i32, got {actual}, '
         f'{declaration} declared at {described(related)}').encode()
    ], ran
    assert check_json(exe, args, 3) == {'kind': 'type', 'byte_offset': at}
    assert check_json(exe, args, 3, version=2) == {
        'kind': 'type', 'location': {'kind': 'source_byte', 'offset': at, **position(at)},
        'expected_type': 'i32', 'actual_type': actual,
        'related_location': {'kind': 'source_byte', 'offset': related, **position(related)},
    }


def check_argument_types(exe, directory):
    path = directory / 'argument-types.brc'
    declaration = b'module main;\nfn i32 price(i32 cents) { return cents; }\n'
    for command, entry in (('check', b'main()'), ('eval-i32', b'evaluate(i32 ignored)')):
        args = [command, path, *([0] if command == 'eval-i32' else [])]
        body = b'fn i32 ' + entry + ' { let u32 cost = 1; return /* 배송 */ price(cost); }\n'.encode()
        source = declaration + body
        if command == 'eval-i32':
            source = source.replace(b'\n', b'\r\n')
        path.write_bytes(source)
        call = source.index(b'price(cost)')
        formal = source.index(b'cents')
        check_scalar_mismatch(exe, args, source, call, formal, 'parameter')

    source = declaration + b'fn i32 main() { return price(); }\n'
    path.write_bytes(source)
    error = check_json(exe, ['check', path], 3, version=2)
    assert error == {'kind': 'type', 'location': {'kind': 'source_byte', 'offset': source.index(b'price()')}}
    print('PASS: scalar call argument types and declaration in text and JSON v2 with JSON v1 compatibility')


def check_return_types(exe, directory):
    path = directory / 'return-types.brc'
    source = ('module main;\nfn i32 price() { let u32 cost = 1; /* 배송 */ return cost; }\n'
              'fn i32 main() { return price(); }\n').encode()
    path.write_bytes(source)
    for command in ('check', 'run'):
        check_scalar_mismatch(exe, [command, path], source, source.index(b'return cost'),
                              source.index(b'price()'), 'function')
    source = 'module main;\r\nfn i32 evaluate(i32 cents) { /* 배송 */ return cents < 30000; }\r\n'.encode()
    path.write_bytes(source)
    check_scalar_mismatch(exe, ['eval-i32', path, 0], source, source.index(b'return cents'),
                          source.index(b'evaluate'), 'function', actual='bool')
    print('PASS: scalar return types and function declaration in text and JSON v2 with JSON v1 compatibility')


def check_initializer_types(exe, directory):
    path = directory / 'initializer-types.brc'
    source = ('module main;\nfn i32 main() { let u32 cost = 1; '
              'let /* 배송 */ i32 fee = cost; return fee; }\n').encode()
    path.write_bytes(source)
    for command in ('check', 'run'):
        check_scalar_mismatch(exe, [command, path], source, source.index(b'fee'),
                              source.index(b'i32 fee'), 'local type')
    source = ('module main;\r\nfn i32 evaluate(i32 cents) { '
              'var /* 배송 */ i32 fee = cents < 30000; return fee; }\r\n').encode()
    path.write_bytes(source)
    check_scalar_mismatch(exe, ['eval-i32', path, 0], source, source.index(b'fee'),
                          source.index(b'i32 fee'), 'local type', actual='bool')
    print('PASS: scalar initializer types and local type annotation with JSON v1 compatibility')


def check_output_table(exe, identity, host_check, host_run, project_host_check, project_host_run,
                       adapter):
    subprocess.run([sys.executable, '-B', str(ROOT / 'tools/sync-cli-output.py'), '--check'],
                   check=True, timeout=10)
    answer = ROOT / 'examples/answer.brc'
    project = ROOT / 'examples/projects/hello/project.json'
    shipping = ROOT / 'examples/shipping-fee.brc'
    sources = {'check': [answer], 'run': [answer], 'eval-i32': [identity, 41],
               'test-i32': [shipping, shipping.with_suffix('.csv')]}
    tokens = {'--version': b'Brownie C experimental:', 'check': b'checked',
              'run': b'return_i32=77', 'eval-i32': b'return_i32=41',
              'test-i32': b'test-i32: 2 cases passed',
              'inspect': b'Brownie C private IR diagnostics;'}
    rows = json.loads((ROOT / 'docs-site/cli-output.json').read_bytes())
    for row in rows:
        command = row['command']
        adapter_row = '--host-adapter' in row['arguments']
        if command == 'inspect':
            args = [answer, row['arguments'].split()[-1]]
        elif adapter_row:
            if adapter is None:
                continue
            request = project_host_check if row['arguments'].startswith('--project ') else host_check
            args = [*request[1:], '--host-adapter', '0', 'v1', adapter]
        elif row['arguments'].startswith('--project FILE --catalog'):
            args = (project_host_run if command == 'run' else project_host_check)[1:]
        elif '--host-replies' in row['arguments']:
            args = host_run[1:]
        elif '--catalog' in row['arguments']:
            args = host_check[1:]
        elif '--policy' in row['arguments']:
            args = configured_arguments(CONFIGURED)[1:]
            if '--isolated' in row['arguments'] and command == 'run':
                args.extend(['--input', answer])
        elif '--isolated' in row['arguments']:
            args = ['--project', project] if row['arguments'].startswith('--project ') else sources[command]
        elif row['arguments'].startswith('--project '):
            args = ['--project', project]
        else:
            args = sources.get(command, [])
        if '--isolated' in row['arguments']:
            args = [*args, '--isolated']
        for mode in row['formats']:
            option = mode['option']
            fixture_environment = {'BC_ENGINE_ADAPTER_FIXTURE': 'g'} if adapter_row else {}
            with patch.dict(os.environ, fixture_environment):
                ran = invoke(exe, [command, *args, *([option] if option else [])], 0)
            written = getattr(ran, mode['channel'])
            other = ran.stderr if mode['channel'] == 'stdout' else ran.stdout
            assert written and not other, (row, mode, ran)
            schema = mode['schema']
            if schema is None:
                legacy_project = command == 'run' and args[0] == '--project' and '--catalog' not in args
                expected = b'return_i32=42' if legacy_project else tokens[command]
                assert written.startswith(expected), (row, mode, ran)
            else:
                assert len(written.splitlines()) == 1 and written.endswith(b'\n'), ran
                obj = json.loads(written)
                assert type(obj) is dict and obj['schema'] == schema, (mode, obj)
                if command != '--version':
                    assert obj['command'] == command, obj
    print('PASS: documented CLI channels and schemas match native output')
    if adapter is None:
        print('SKIP: documented process-adapter output requires --adapter-exe')


def make_host_check(folder):
    source = folder / 'host-check.brc'
    source.write_bytes(b'module main; import host::example as api; '
                       b'fn i32 main(){return api::check(41)+35;}')
    policy = folder / 'host-policy.json'
    run = folder / 'host-run.json'
    catalog = folder / 'host-catalog.json'
    capability = 'host.example.check'
    ceiling = json.loads((CONFIGURED / 'policy.json').read_bytes())
    ceiling['capabilities'] = [capability]
    config = {'schema': 'brownie.run/0.3', 'entry': {'module': 'main', 'function': 'main'},
              'requires': [capability], 'grants': [capability], 'limits': ceiling['run']}
    imports = {'schema': 'brownie.catalog/1', 'imports': [
        {'id': 0, 'module': 'host::example', 'symbol': 'check', 'parameters': ['i32'],
         'result': 'Result<i32,u32>', 'effect': 'read', 'capability': capability,
         'adapter_revision': 'v1'},
    ]}
    for path, data in ((policy, ceiling), (run, config), (catalog, imports)):
        path.write_text(json.dumps(data), encoding='utf-8')
    return ['check', source, '--catalog', catalog, '--policy', policy, '--run', run]


def make_host_run(check_args, path):
    entries = json.loads(check_args[3].read_bytes())['imports']

    def size(value):
        return value.to_bytes(4, 'little')

    def string(value):
        raw = value.encode('ascii')
        return size(len(raw)) + raw

    canonical = bytearray(b'BRC-CATALOG-1\n' + size(len(entries)))
    for entry in entries:
        canonical.extend(size(entry['id']))
        for field in ('module', 'symbol', 'result', 'effect', 'capability', 'adapter_revision'):
            canonical.extend(string(entry[field]))
        canonical.extend(size(len(entry['parameters'])))
        canonical.extend(b''.join(map(string, entry['parameters'])))
    row = {'import_id': 0, 'request_hex': '0100030000000400000029000000',
           'kind': 0, 'reply_hex': '03000000040000002a000000'}
    table = {'schema': 'brownie.host-replies/1',
             'catalog_sha256': hashlib.sha256(canonical).hexdigest(), 'replies': [row]}
    path.write_text(json.dumps(table), encoding='utf-8')
    return ['run', *check_args[1:], '--host-replies', path]


def check_host_run(exe, check_args, args):
    source, run, response = args[1], args[7], args[9]
    for version in (1, 2):
        assert check_json(exe, args, 0, version=version, value=77) is None
    for invalid in ([*args, '--fuel', 256], [*args, '--stdin'],
                    [*args, '--host-replies', response], args[:-2],
                    [*check_args, '--host-replies', response]):
        invoke(exe, invalid, 2)

    config = json.loads(run.read_bytes())
    run.write_text(json.dumps(config | {'requires': []}), encoding='utf-8')
    assert check_json(exe, args, 4, version=2)['kind'] == 'unavailable'
    run.write_text(json.dumps(config), encoding='utf-8')

    table = json.loads(response.read_bytes())
    row = table['replies'][0]
    for bad in (table | {'catalog_sha256': '0' * 64},
                table | {'replies': [row, row]},
                table | {'replies': [row | {'request_hex': '0aXz'}]},
                table | {'replies': [row | {'request_hex': '00'}]},
                table | {'replies': [row | {'import_id': 1}]},
                table | {'replies': [row | {'kind': 1}]},
                table | {'replies': [row | {'reply_hex': row['reply_hex'] + '00'}]}):
        response.write_text(json.dumps(bad), encoding='utf-8')
        assert check_json(exe, args, 2, version=2)['kind'] == 'usage'
    serialized = json.dumps(table)
    for bad in (serialized + ' {}', serialized[:-1] + ', "replies": []}'):
        response.write_text(bad, encoding='utf-8')
        assert check_json(exe, args, 2, version=2)['kind'] == 'usage'

    for entries in ([], [row | {'request_hex': '0100030000000400000028000000'}],
                    [row | {'kind': 2, 'reply_hex': ''}]):
        response.write_text(json.dumps(table | {'replies': entries}), encoding='utf-8')
        assert check_json(exe, args, 4, version=2)['kind'] == 'unavailable'

    original = source.read_bytes()
    response.write_text(json.dumps(table | {'replies': [
        row | {'kind': 1, 'reply_hex': '0500000004000000ffffffff'}]}), encoding='utf-8')
    assert check_json(exe, args, 4, version=2) == {
        'kind': 'unavailable', 'location': {'kind': 'none'},
    }
    source.write_bytes(b'module main; fn i32 main(){return switch(host::example::check(41)){'
                       b'case .ok(n): { n } case .err(_): { -7 } };}')
    assert check_json(exe, args, 0, version=2, value=-7) is None
    source.write_bytes(original)
    response.write_text(serialized, encoding='utf-8')

    run.write_text(json.dumps(config | {'limits': config['limits'] | {'fuel': 1}}), encoding='utf-8')
    assert check_json(exe, args, 5, version=2)['kind'] == 'fuel'
    run.write_text(json.dumps(config), encoding='utf-8')
    print('PASS: configured host run, typed Result arms, exact matching, fail-closed replies and Fuel')


def make_host_project(folder, *, bounded_transport=False):
    folder.mkdir()
    base = make_host_check(folder)
    app = folder / 'app.brc'
    helper = folder / 'helper.brc'
    project = folder / 'project.json'
    app.write_bytes(b'module app; import helpers as service; pub fn i32 start(){return service::calculate()+35;}')
    helper.write_bytes(b'module helpers; import host::example as service; pub fn i32 calculate(){return service::check(41);}')
    run = base[7]
    config = json.loads(run.read_bytes())
    config['entry'] = {'module': 'app', 'function': 'start'}
    if bounded_transport:
        # The broker reserves worst-case wire bytes for all admitted calls.
        config['limits'].update(host_calls=1, host_request_bytes=14, host_response_bytes=12)
    run.write_text(json.dumps(config), encoding='utf-8')
    project.write_text(json.dumps({
        'schema': 'brownie.project/0.3', 'name': 'host-project', 'entry': config['entry'],
        'sources': [{'module': 'app', 'path': app.name}, {'module': 'helpers', 'path': helper.name}],
        'requires': config['requires'],
    }), encoding='utf-8')
    run_args = make_host_run(base, folder / 'replies.json')
    return ['check', '--project', project, *base[2:]], ['run', '--project', project, *run_args[2:]]


def check_process_adapter(exe, adapter, folder):
    check_args = make_host_check(folder)
    args = ['run', *check_args[1:], '--host-adapter', '0', 'v1', adapter]
    _, project_run = make_host_project(folder / 'adapter-project')
    assert b'--host-adapter ID REVISION EXE' in invoke(exe, ['--help'], 0).stdout
    with patch.dict(os.environ, {'BC_ENGINE_ADAPTER_FIXTURE': 'g'}):
        for version in (1, 2):
            assert check_json(exe, args, 0, version=version, value=77) is None
        assert check_json(exe, [*project_run[:-2], *args[-4:]], 0, version=2, value=77) is None
        for invalid in ([*args, '--host-replies', folder/'missing.json'], args[:-1],
                        [*check_args, *args[-4:]], [*args[:-3], '-1', 'v1', adapter]):
            invoke(exe, invalid, 2)
        for denied in ([*args[:-3], '1', 'v1', adapter], [*args[:-2], 'v2', adapter],
                       [*args[:-1], adapter.name]):
            assert check_json(exe, denied, 4, version=2)['kind'] == 'unavailable'
        run = check_args[7]
        original = json.loads(run.read_bytes())
        run.write_text(json.dumps(original | {'grants': []}), encoding='utf-8')
        assert check_json(exe, args, 4, version=2)['kind'] == 'unavailable'
        run.write_text(json.dumps(original), encoding='utf-8')
    with patch.dict(os.environ, {'BC_ENGINE_ADAPTER_FIXTURE': 'x'}):
        assert check_json(exe, args, 4, version=2)['kind'] == 'unavailable'
    with patch.dict(os.environ, {'BC_ENGINE_ADAPTER_FIXTURE': 's'}):
        run.write_text(json.dumps(original | {'limits': original['limits'] | {'deadline_ms': 150}}),
                       encoding='utf-8')
        assert check_json(exe, args, 5, version=2)['kind'] == 'deadline'
    print('PASS: Windows process adapter for source and project, revision and authority, crossed reply and expiry')


def check_host_project(exe, check_args, run_args):
    help_text = invoke(exe, ['--help'], 0)
    assert not help_text.stderr
    usage = help_text.stdout.splitlines()
    flags = b' --catalog FILE --policy FILE --run FILE'
    formats = b' [--json|--json-v2]'
    assert b'browniec check --project FILE' + flags + formats in usage
    assert (b'browniec run --project FILE' + flags + b' --host-replies FILE [--input FILE|--stdin] [--output FILE|--output-text FILE]'
            + formats in usage)
    project = check_args[2]
    helper = project.parent / 'helper.brc'
    run_file = check_args[8]
    assert check_json(exe, check_args, 0, version=2) is None
    assert check_json(exe, run_args, 0, version=2, value=77) is None
    policy_file = check_args[6]
    original_policy = policy_file.read_bytes()
    policy = json.loads(original_policy)
    try:
        # Two Fuel cover the app match and the first candidate for helper.brc.
        for limit, expected_path in (({'fuel': 2}, helper.name), ({'functions': 1}, None)):
            policy_file.write_text(json.dumps(policy | {'compile': policy['compile'] | limit}),
                                   encoding='utf-8')
            for args in (check_args, run_args):
                error = check_json(exe, args, 3, version=2)
                assert error['kind'] == 'compile_limit', error
                if expected_path:
                    assert error['location']['path'] == expected_path, error
                    assert error['location']['source_index'] == 1, error
                else:
                    assert error['location'] == {'kind': 'none'}, error
    finally:
        policy_file.write_bytes(original_policy)
    config = json.loads(run_file.read_bytes())
    for change in ({'requires': []}, {'entry': {'module': 'app', 'function': 'wrong'}}):
        run_file.write_text(json.dumps(config | change), encoding='utf-8')
        assert check_json(exe, check_args, 4, version=2)['kind'] == 'unavailable'
    run_file.write_text(json.dumps(config), encoding='utf-8')

    original = helper.read_bytes()
    absolute = b'module helpers; pub fn i32 calculate(){return host /* scope */ :: example::check(41);}'
    helper.write_bytes(absolute)
    assert check_json(exe, run_args, 0, version=2, value=77) is None
    helper.write_bytes(original.replace(b'host::example', b'host::unknown'))
    error = check_json(exe, check_args, 3, version=2)
    assert error['kind'] == 'type' and error['location']['path'] == 'helper.brc', error
    assert error['location']['source_index'] == 1, error
    helper.write_bytes(original.replace(b'check(41)', b'check(true)'))
    error = check_json(exe, check_args, 3, version=2)
    assert error['kind'] == 'type' and error['location']['path'] == 'helper.brc', error
    helper.write_bytes(original.replace(b'pub fn', b'fn'))
    assert check_json(exe, check_args, 3, version=2)['kind'] == 'type'
    helper.write_bytes(original)

    overflowing = original.replace(b'return service::check(41);',
                                   b'\n    return service::check(41) + 2147483647;\n')
    offset = overflowing.index(b'+')
    helper.write_bytes(overflowing)
    check_located_result(exe, run_args, 5, 'overflow', 1, helper.name, overflowing, offset, offset + 1)
    helper.write_bytes(original)

    manifest = json.loads(project.read_bytes())
    project.write_text(json.dumps(manifest | {'requires': []}), encoding='utf-8')
    helper.unlink()
    assert check_json(exe, check_args, 4, version=2)['kind'] == 'unavailable'
    project.write_text(json.dumps(manifest), encoding='utf-8')
    assert check_json(exe, check_args, 7, version=2)['kind'] == 'input_io'
    helper.write_bytes(original)
    print('PASS: catalog-backed project calls, compile Fuel and function limits, locations, and authority-before-file-read')


def check_host_project_input(exe, check_args, run_args):
    project = check_args[2]
    source = project.parent / 'app.brc'
    catalog = check_args[4]
    run = check_args[8]
    replies = run_args[-1]
    payload = project.parent / 'input.bin'
    original_run = json.loads(run.read_bytes())
    imports = json.loads(catalog.read_bytes())
    imports['imports'][0]['parameters'] = ['ref u8[]']
    (project.parent / 'helper.brc').write_bytes(b'module helpers; pub fn i32 calculate(){return 35;}')
    catalog.write_text(json.dumps(imports), encoding='utf-8')
    make_host_run(check_args[1:], replies)
    table = json.loads(replies.read_bytes())
    row = table['replies'][0]

    def request(data, result):
        return row | {
            'request_hex': (b'\x01\x00\x07\x00\x00\x00' + len(data).to_bytes(4, 'little') + data).hex(),
            'reply_hex': (b'\x03\x00\x00\x00\x04\x00\x00\x00' + result.to_bytes(4, 'little')).hex(),
        }

    message = b'A\x00\xff'
    payload.write_bytes(message)
    replies.write_text(json.dumps(table | {'replies': [request(message, 42), request(b'', 7)]}),
                       encoding='utf-8')
    source.write_bytes(b'module app; import host::example as service; '
                       b'pub fn i32 start(ref u8[] data){return service::check(ref data)+35;}')
    assert check_json(exe, check_args, 0, version=2) is None
    assert check_json(exe, [*run_args, '--input', payload], 0, version=2, value=77) is None
    assert check_json(exe, [*run_args, '--stdin'], 0, value=77, input_bytes=message) is None
    assert check_json(exe, run_args, 0, version=2, value=42) is None
    assert check_json(exe, [*run_args, '--stdin'], 4, version=2, input_bytes=b'B\x00\xff')['kind'] == 'unavailable'
    error = check_json(exe, [*run_args, '--input', project.parent / 'missing.bin'], 7, version=2)
    assert error['kind'] == 'input_io', error
    run.write_text(json.dumps(original_run | {'limits': original_run['limits'] | {'input_bytes': 2}}),
                   encoding='utf-8')
    assert check_json(exe, [*run_args, '--input', payload], 5, version=2)['kind'] == 'input_limit'
    run.write_text(json.dumps(original_run), encoding='utf-8')

    source.write_bytes(b'module app; pub fn i32 start(){return 77;}')
    assert check_json(exe, [*run_args, '--stdin'], 2, input_bytes=b'')['kind'] == 'usage'
    for signature in (b'ref mut u8[]', b'ref i32[]', b'i32'):
        source.write_bytes(b'module app; pub fn i32 start(' + signature + b' data){return 77;}')
        error = check_json(exe, check_args, 3, version=2)
        assert error['kind'] == 'type' and error['location']['path'] == 'app.brc', error
    print('PASS: project guest bytes reach catalog-bound requests from files, stdin and empty input')


def check_host_catalog(exe, args):
    _, source, _, catalog, _, policy, _, run = args
    for version in (1, 2):
        assert check_json(exe, args, 0, version=version) is None
    # The ordinary run and compiler never inherit a catalog or grant.
    invoke(exe, ['run', *args[1:]], 2)
    invoke(exe, ['check', source], 3)
    for invalid in (args[:-2], [*args, '--catalog', catalog], [*args, '--stdin']):
        invoke(exe, invalid, 2)

    config = json.loads(run.read_bytes())
    for change in ({'requires': []}, {'requires': [], 'grants': []},
                   {'entry': {'module': 'main', 'function': 'wrong'}}):
        run.write_text(json.dumps(config | change), encoding='utf-8')
        denied = check_json(exe, args, 4, version=2)
        assert denied == {'kind': 'unavailable', 'location': {'kind': 'none'}}, denied
    run.write_text(json.dumps(config), encoding='utf-8')

    ceiling = json.loads(policy.read_bytes())
    policy.write_text(json.dumps(ceiling | {'capabilities': []}), encoding='utf-8')
    assert check_json(exe, args, 4, version=2)['kind'] == 'unavailable'
    policy.write_text(json.dumps(ceiling), encoding='utf-8')

    source.write_bytes(b'module main; fn i32 helper(){return 41;} fn i32 main(){return helper();}')
    # 25 source tokens, four instructions, and one register in each of two functions.
    exact = ceiling['compile'] | {'tokens': 25, 'functions': 2, 'instructions': 4,
                                  'registers_per_function': 1}
    policy.write_text(json.dumps(ceiling | {'compile': exact}), encoding='utf-8')
    assert check_json(exe, args, 0, version=2) is None
    for field in ('tokens', 'functions', 'instructions'):
        bounds = exact | {field: exact[field] - 1}
        policy.write_text(json.dumps(ceiling | {'compile': bounds}), encoding='utf-8')
        assert check_json(exe, args, 3, version=2)['kind'] == 'compile_limit'

    source.write_bytes(b'module main; fn i32 main(){return 1+2;}')
    for registers, status in ((3, 0), (2, 3)):
        bounds = ceiling['compile'] | {'registers_per_function': registers}
        policy.write_text(json.dumps(ceiling | {'compile': bounds}), encoding='utf-8')
        error = check_json(exe, args, status, version=2)
        assert (error and error['kind']) == (None if status == 0 else 'compile_limit'), error
    policy.write_text(json.dumps(ceiling), encoding='utf-8')

    source.write_bytes(b'module main; fn i32 main(){return host::example::check(true);}')
    bad = check_json(exe, args, 3, version=2)
    assert bad['kind'] == 'type' and bad['location']['kind'] == 'source_byte', bad

    # Invalid and missing catalogs take precedence over a missing source path.
    source.unlink()
    for malformed in (b'{"schema": "brownie.catalog/1", "imports": [], "imports": []}',
                      b' ' * 16385):
        catalog.write_bytes(malformed)
        assert check_json(exe, args, 2, version=2)['kind'] == 'usage'
    catalog.unlink()
    missing = check_json(exe, args, 7, version=2)
    assert missing == {'kind': 'input_io', 'location': {'kind': 'none'}}, missing
    print('PASS: explicit host catalog, grants, typed imports and exact compiler policy limits')


def configured_arguments(folder):
    return ['run', '--project', folder / 'project.json', '--policy', folder / 'policy.json',
            '--run', folder / 'run.json']


def check_console_cancellation(exe, args, ready, destination, profile='brownie.m1-scalar/1'):
    # The helper owns a separate console. Target only the test CLI process group.
    driver = r"""
import signal
import subprocess
import sys
import time
from pathlib import Path

ready = Path(sys.argv[1]) if sys.argv[1] else None
with subprocess.Popen(sys.argv[2:], stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0,
                      stdin=None if ready else subprocess.PIPE,
                      creationflags=subprocess.CREATE_NEW_PROCESS_GROUP) as guest:
    try:
        if ready:
            deadline = time.monotonic() + 8
            while not ready.exists():
                assert guest.poll() is None, guest.communicate()
                assert time.monotonic() < deadline, 'Adapter did not receive the request'
                time.sleep(0.01)
        else:
            # Larger than the pipe buffer, so this returns only after input starts.
            assert guest.stdin.write(b'A' * 65536) == 65536
        guest.send_signal(signal.CTRL_BREAK_EVENT)
        # Keep the stdin writer open until cancellation has actually ended the run.
        guest.wait(timeout=5)
        out, err = guest.communicate(timeout=5)
        assert guest.returncode == 5, (guest.returncode, out, err)
    finally:
        if guest.poll() is None:
            guest.kill()
    sys.stdout.buffer.write(out)
    sys.stderr.buffer.write(err)
"""
    startup = subprocess.STARTUPINFO()
    startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    env = os.environ | ({'BC_ENGINE_ADAPTER_FIXTURE': 'c', 'BC_ENGINE_ADAPTER_READY': str(ready)} if ready else {})
    run = subprocess.run([sys.executable, '-B', '-c', driver, str(ready) if ready else '', str(exe),
                          *map(str, args), '--json-v2'],
                         creationflags=subprocess.CREATE_NEW_CONSOLE, startupinfo=startup,
                         capture_output=True, timeout=15, env=env)
    assert run.returncode == 0 and not run.stderr and len(run.stdout.splitlines()) == 1, run
    assert json.loads(run.stdout) == {
        'schema': 'browniec.result/v2', 'command': 'run', 'status': 'error',
        'profile': profile, 'return_i32': None,
        'error': {'kind': 'cancelled', 'location': {'kind': 'none'}},
    }, run.stdout
    assert not destination.exists()


def check_host_project_output(exe, folder, adapter):
    check, run = make_host_project(folder)
    manifest, policy, config, replies = check[2], check[6], check[8], run[-1]
    source = folder / 'app.brc'
    source.write_bytes(b'module app; import helpers as h; pub fn i32 start(ref u8[] data){'
                       b'output::emit(ref data); let i32 n=h::calculate(); output::emit(b"!"); return n+35;}')
    assert check_json(exe, check, 4, version=2)['kind'] == 'unavailable'
    config_obj = json.loads(config.read_bytes())
    caps = [*config_obj['requires'], 'brownie.output.emit']
    for path, fields in ((manifest, {'requires': caps}), (policy, {'capabilities': caps}),
                         (config, {'requires': caps, 'grants': caps})):
        path.write_text(json.dumps(json.loads(path.read_bytes()) | fields), encoding='utf-8')
    allowed = json.loads(config.read_bytes())
    message = b'X' * 4096 + b'\x00'
    args = [*run, '--stdin']
    assert check_json(exe, check, 0, version=2) is None
    assert check_json(exe, args, 0, value=77, input_bytes=message,
                      output_b64=base64.b64encode(message+b'!').decode('ascii')) is None
    for flag in ('--output', '--output-text'):
        destination = folder / (flag[2:] + '.txt')
        assert check_json(exe, [*args, flag, destination], 0, version=2, value=77,
                          input_bytes=message) is None
        assert destination.read_bytes() == message+b'!'
    destination = folder / 'unpublished.bin'
    file_run = [*args, '--output', destination]
    config.write_text(json.dumps(allowed | {'limits': allowed['limits'] | {'output_bytes': len(message)}}),
                      encoding='utf-8')
    assert check_json(exe, file_run, 5, version=2, input_bytes=message)['kind'] == 'output_limit'
    assert not destination.exists()
    config.write_text(json.dumps(allowed), encoding='utf-8')
    replies.write_text(json.dumps(json.loads(replies.read_bytes()) | {'replies': []}), encoding='utf-8')
    assert check_json(exe, file_run, 4, version=2, input_bytes=message)['kind'] == 'unavailable'
    assert not destination.exists()
    if adapter:
        payload = folder / 'payload.bin'
        payload.write_bytes(message)
        ready = folder / 'adapter-ready'
        limits = allowed['limits'] | {'deadline_ms': 10000}
        config.write_text(json.dumps(allowed | {'limits': limits}), encoding='utf-8')
        policy.write_text(json.dumps(json.loads(policy.read_bytes()) | {'run': limits}), encoding='utf-8')
        adapter_args = [*run[:-2], '--host-adapter', '0', 'v1', adapter,
                        '--input', payload, '--output', destination]
        check_console_cancellation(exe, adapter_args, ready, destination)
        print('PASS: Windows CTRL+BREAK cancels configured execution without publishing output')
    else:
        print('SKIP: console cancellation requires --adapter-exe')
    print('PASS: catalog project emits across host suspension, with exact file/JSON output and failure rollback')


def check_unframe_example(exe, folder):
    args = ['run', '--project', CONFIGURED / 'unframe.json', '--policy', CONFIGURED / 'policy.json',
            '--run', CONFIGURED / 'run.json']
    profile = 'brownie.m2-reference/1'
    assert check_json(exe, ['check', *args[1:]], 0, version=2, profile=profile) is None
    source = folder / 'unframe-input.bin'
    for data, value, output in ((b'\x01\x00\xff\x0a', 1, 'AP8K'), (b'', 0, ''),
                                (b'\x01', 0, ''), (b'\x02\x00\xff\x0a', 0, '')):
        source.write_bytes(data)
        assert check_json(exe, [*args, '--input', source], 0, version=2, value=value,
                          profile=profile, output_b64=output) is None
    print('PASS: unframe example strips the version byte and rejects incomplete or unsupported frames')


def check_configured_output(exe, folder):
    project = folder / 'configured'
    shutil.copytree(CONFIGURED, project)
    args = configured_arguments(project)
    check = ['check', *args[1:]]
    source = project / 'app.brc'
    original = source.read_bytes()
    payload = project / 'payload.bin'
    payload.write_bytes(b'A\x00')
    run_file = project / 'run.json'
    config = json.loads(run_file.read_bytes())

    policy_file = project / 'policy.json'
    policy_data = policy_file.read_bytes()
    policy = json.loads(policy_data)
    denied_output = project / 'compile-denied.bin'
    try:
        for bounds, location_kind in (({'fuel': 1}, 'source_byte'), ({'types': 1}, 'none')):
            restricted = policy | {'compile': policy['compile'] | bounds}
            policy_file.write_text(json.dumps(restricted), encoding='utf-8')
            for command in (check, [*args, '--input', payload, '--output', denied_output]):
                error = check_json(exe, command, 3, version=2)
                assert error['kind'] == 'compile_limit', error
                assert error['location']['kind'] == location_kind, error
                if location_kind == 'source_byte':
                    assert error['location']['path'] == source.name and error['location']['offset'] == 0, error
            assert not denied_output.exists()
    finally:
        policy_file.write_bytes(policy_data)

    def update(**overrides):
        run_file.write_text(json.dumps(config | overrides), encoding='utf-8')

    profile = 'brownie.m2-reference/1'
    for version in (1, 2):
        assert check_json(exe, check, 0, version=version, profile=profile) is None
        assert check_json(exe, [*args, '--input', payload], 0, value=77, version=version,
                          profile=profile, output_b64='QQA=') is None
    stalled = project / 'stalled-stdin.bin'
    for flags, failure_profile in [([], profile), (['--isolated'], 'brownie.m1-scalar/1')]:
        stdin_args = [*args, *flags, '--stdin']
        assert check_json(exe, stdin_args, 0, value=77, version=2, profile=profile,
                          input_bytes=b'A\x00', output_b64='QQA=') is None
        # The unrestricted path also exercises suppression of a requested file sink.
        if not flags:
            stdin_args.extend(['--output', stalled])
        pipe_command = [str(exe), *map(str, [*stdin_args, '--json-v2'])]
        with subprocess.Popen(pipe_command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE) as guest:
            try:
                guest.stdin.write(b'A\x00')
                guest.stdin.flush()
                assert guest.wait(timeout=5) == 5
                assert not guest.stderr.read()
                result = json.loads(guest.stdout.read())
                assert result['return_i32'] is None and 'output_b64' not in result, result
                assert result['error'] == {'kind': 'deadline', 'location': {'kind': 'none'}}, result
            finally:
                if guest.poll() is None:
                    guest.kill()
        assert not stalled.exists()
        check_console_cancellation(exe, stdin_args, None, stalled, failure_profile)
    assert check_json(exe, args, 0, value=77, version=2, profile=profile, output_b64='') is None
    empty_sink = project / 'empty.bin'
    assert check_json(exe, [*args, '--output', empty_sink], 0, value=77, profile=profile) is None
    assert empty_sink.read_bytes() == b''
    sink = project / '출력.bin'
    file_run = [*args, '--input', payload, '--output', sink]
    assert check_json(exe, file_run, 0, value=77, version=2, profile=profile) is None
    assert sink.read_bytes() == b'A\x00'
    output_error = {'kind': 'output_io', 'location': {'kind': 'none'}}
    assert check_json(exe, [*args, '--output', sink], 7, version=2, profile=profile) == output_error
    assert sink.read_bytes() == b'A\x00'
    isolated = [*args, '--isolated']
    isolated_sink = project / 'isolated.bin'
    assert check_json(exe, [*isolated, '--input', payload, '--output', isolated_sink],
                      0, value=77, version=2, profile=profile) is None
    assert isolated_sink.read_bytes() == b'A\x00'
    assert check_json(exe, [*isolated, '--input', payload, '--output', isolated_sink],
                      7, version=2, profile=profile) == output_error
    assert isolated_sink.read_bytes() == b'A\x00'
    other = folder / 'other-project'
    shutil.copytree(CONFIGURED, other)
    destinations = folder / 'contested-output'
    destinations.mkdir()
    first_input = project / 'contender.bin'
    second_input = other / 'contender.bin'
    first_input.write_bytes(b'A\x00')
    second_input.write_bytes(b'B\xff')

    def contender(root, incoming, destination, flags):
        command = [str(exe), *map(str, [*configured_arguments(root), *flags, '--input', incoming,
                                       '--output', destination, '--json-v2'])]
        return subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    for name, flags in [('contested.bin', []), ('isolated-contested.bin', ['--isolated'])]:
        contested = destinations / name
        with contender(project, first_input, contested, flags) as first:
            with contender(other, second_input, contested, flags) as second:
                candidates = [(first, b'A\x00'), (second, b'B\xff')]
                codes = []
                for guest, data in candidates:
                    stdout, stderr = guest.communicate(timeout=10)
                    assert not stderr and len(stdout.splitlines()) == 1, (stdout, stderr)
                    result = json.loads(stdout)
                    codes.append(guest.returncode)
                    if guest.returncode == 0:
                        assert result['return_i32'] == 77 and contested.read_bytes() == data, result
                    else:
                        assert result['error'] == output_error, (flags, guest.args, result)
                assert sorted(codes) == [0, 7], (flags, codes)
    assert not list(folder.rglob('.browniec-*'))
    assert check_json(exe, [*args, '--output', folder / 'missing' / 'result.bin'],
                      7, version=2, profile=profile) == output_error
    assert check_json(exe, [*args, '--output', f'{sink}:extra'],
                      7, version=2, profile=profile) == output_error
    assert sink.read_bytes() == b'A\x00'
    text_sink = project / 'output.txt'
    utf8 = '한😀\x00\r\n'.encode()
    assert check_json(exe, [*args, '--stdin', '--output-text', text_sink], 0, value=77,
                      version=2, profile=profile, input_bytes=utf8) is None
    assert text_sink.read_bytes() == utf8
    isolated_text = project / 'isolated.txt'
    assert check_json(exe, [*isolated, '--stdin', '--output-text', isolated_text], 0, value=77,
                      version=2, profile=profile, input_bytes=utf8) is None
    assert isolated_text.read_bytes() == utf8
    invalid_isolated = project / 'isolated-invalid.txt'
    assert check_json(exe, [*isolated, '--stdin', '--output-text', invalid_isolated], 7,
                      version=2, profile=profile, input_bytes=b'\xff') == {
        'kind': 'output_encoding', 'location': {'kind': 'none'},
    }
    assert not invalid_isolated.exists()
    assert check_json(exe, [*args, '--output-text', text_sink], 7,
                      version=2, profile=profile) == output_error
    assert text_sink.read_bytes() == utf8
    empty_text = project / 'empty.txt'
    assert check_json(exe, [*args, '--output-text', empty_text], 0, value=77, profile=profile) is None
    assert empty_text.read_bytes() == b''
    invalid_text = project / 'invalid.txt'
    for malformed in (b'\xff', b'\xc0\x80', b'\xf0\x9f'):
        assert check_json(exe, [*args, '--stdin', '--output-text', invalid_text], 7,
                          version=2, profile=profile, input_bytes=malformed) == {
            'kind': 'output_encoding', 'location': {'kind': 'none'},
        }
        assert not invalid_text.exists()
    binary_sink = project / 'non-utf8.bin'
    assert check_json(exe, [*args, '--stdin', '--output', binary_sink], 0, value=77,
                      profile=profile, input_bytes=b'\xff') is None
    assert binary_sink.read_bytes() == b'\xff'
    invoke(exe, [*args, '--json-v2', '--output', invalid_text, '--output-text', text_sink], 2)
    assert not invalid_text.exists()
    unpublished = project / 'unpublished.bin'
    file_run = [*args, '--input', payload, '--output', unpublished]
    for invalid in (['check', *args[1:]], ['run', *args[1:3]]):
        invoke(exe, [*invalid, '--json-v2', '--output', unpublished], 2)
    assert not unpublished.exists()
    for invalid in (args, [*args[:-2], '--json'], [*args, '--fuel', 1, '--json'],
                    [*args, '--run', run_file, '--json']):
        invoke(exe, invalid, 2)
    for invalid in (check[:-2], [*check, '--input', payload], [*check, '--stdin'],
                    [*check, '--fuel', 1], [*check, '--policy', project / 'policy.json']):
        invoke(exe, [*invalid, '--json'], 2)

    for field, limit, expected in (('input_bytes', 1, 'input_limit'),
                                   ('output_bytes', 1, 'output_limit')):
        update(limits=config['limits'] | {field: limit})
        error = check_json(exe, [*args, '--input', payload], 5, version=2, profile=profile)
        assert error['kind'] == expected, error
    update()

    source.write_bytes(b'module app;pub fn i32 transform(ref u8[] data){'
                       b'output::emit(ref data);let i32 z=data[0] as i32;return 1/(z-z);}')
    assert check_json(exe, check, 0, version=2, profile=profile) is None
    error = check_json(exe, [*args, '--input', payload], 5, version=2, profile=profile)
    assert error['kind'] == 'zero_divisor' and error['location']['path'] == 'app.brc', error
    assert check_json(exe, [*file_run, '--isolated'], 5, version=2, profile=profile) == error
    assert not unpublished.exists()
    assert check_json(exe, file_run, 5, version=2, profile=profile) == error
    assert not unpublished.exists()

    source.write_bytes(b'module app;pub fn i32 transform(ref u8[] data){'
                       b'output::emit(ref data);while(true){}return 77;}')
    update(limits=config['limits'] | {'deadline_ms': 1})
    error = check_json(exe, [*args, '--input', payload], 5, version=2, profile=profile)
    assert error == {'kind': 'deadline', 'location': {'kind': 'none'}}, error
    assert check_json(exe, file_run, 5, version=2, profile=profile) == error
    assert not unpublished.exists()

    update()

    source.write_bytes(b'module app;pub fn i32 transform(ref u8[] data){return true;}')
    error = check_json(exe, [*args, '--input', folder / 'missing.bin'], 3, version=2)
    assert error['kind'] == 'type' and error['location']['path'] == 'app.brc', error
    assert check_json(exe, check, 3, version=2) == error
    source.unlink()
    for overrides in ({'entry': {'module': 'app', 'function': 'wrong'}}, {'grants': []}):
        update(**overrides)
        error = check_json(exe, [*args, '--input', folder / 'missing.bin'], 4, version=2)
        assert error == {'kind': 'unavailable', 'location': {'kind': 'none'}}, error
        assert check_json(exe, check, 4, version=2) == error
    update()
    source.write_bytes(original)
    no_requirements = json.loads((project / 'project.json').read_bytes()) | {'requires': []}
    (project / 'project.json').write_text(json.dumps(no_requirements), encoding='utf-8')
    update(requires=[], grants=[])
    error = check_json(exe, [*args, '--input', folder / 'missing.bin'], 4, version=2)
    assert error == {'kind': 'unavailable', 'location': {'kind': 'none'}}, error
    assert check_json(exe, check, 4, version=2) == error
    source.write_bytes(b'module app;pub fn i32 transform(ref u8[] data){return 77;}')
    assert check_json(exe, args, 0, value=77, version=2, profile=profile, output_b64='') is None
    assert check_json(exe, file_run, 4, version=2, profile=profile) == {
        'kind': 'output_denied', 'location': {'kind': 'none'},
    }
    assert not unpublished.exists()
    print('PASS: configured checks, grants, Base64 and binary/UTF-8 file sinks, quotas, diagnostics and deadline')


def check_project_location(exe, manifest, command, code, kind, index, name, source, offset, end):
    check_located_result(exe, [command, '--project', manifest], code, kind, index, name, source, offset, end)


def check_located_result(exe, args, code, kind, index, name, source, offset, end):
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
        ['run', '--project', manifest, '--input'],
        [*args, '--input', payload],
        [*args, '--stdin'],
        [*stdin_args, '--input', payload],
        [*stdin_args, '--stdin'],
        ['check', '--project', manifest, '--stdin'],
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


def check_project_input_entry(exe, folder):
    manifest = folder / 'entry-input.json'
    source = folder / 'entry-input.brc'
    manifest.write_text(json.dumps({
        'schema': 'brownie.project/0.3', 'name': 'binary',
        'entry': {'module': 'app', 'function': 'chosen'},
        'sources': [{'module': 'app', 'path': source.name}], 'requires': [],
    }), encoding='utf-8')
    ordinary = ['check', '--project', manifest]
    entry_input = [*ordinary, '--entry-input']
    profile = 'brownie.m2-reference/1'
    assert b'check --project FILE [--entry-input]' in invoke(exe, ['--help'], 0).stdout
    source.write_bytes(b'module app;pub fn i32 chosen(ref u8[] data){return data[0] as i32;}')
    assert check_json(exe, entry_input, 0, version=2, profile=profile, stdin=subprocess.DEVNULL) is None
    assert check_json(exe, entry_input, 0, profile=profile) is None
    assert check_json(exe, ordinary, 3, version=2)['kind'] == 'type'
    assert check_json(exe, ['run', '--project', manifest, '--stdin', '--fuel', 16000000],
                      5, version=2, profile=profile, input_bytes=b'')['kind'] == 'bounds'
    for rejected in ([*entry_input, '--entry-input'], [*entry_input, '--isolated'],
                     [*entry_input, '--policy', 'missing.json'],
                     [*entry_input, '--input', 'missing.bin'], [*entry_input, '--stdin'],
                     ['check', source, '--entry-input'],
                     ['run', '--project', manifest, '--entry-input']):
        result = invoke(exe, rejected, 2)
        assert not result.stdout and b'browniec: usage' in result.stderr, result

    for signature in (b'()', b'(ref mut u8[] data)'):
        source.write_bytes(b'module app;pub fn i32 chosen' + signature + b'{return 77;}')
        assert check_json(exe, entry_input, 3, version=2)['kind'] == 'type'
    source.write_bytes(b'module app;pub fn i32 chosen(){return 77;}')
    assert check_json(exe, ordinary, 0) is None
    print('PASS: project shared-byte entry compiled without input acquisition or guest execution')


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


def check_source_input(exe, folder):
    source = folder / 'source-input.brc'
    payload = folder / 'source-input.bin'
    original = (b'module main; pub fn i32 main(ref u8[] data) {'
                b'if(data.len==0){return 0;}return data[data.len-1] as i32;}')
    source.write_bytes(original)
    payload.write_bytes(b'\x00\xff')
    args = ['run', source, '--fuel', 16000000]
    profile = 'brownie.m2-reference/1'
    assert check_json(exe, [*args, '--input', payload], 0, value=255, profile=profile) is None
    assert check_json(exe, [*args, '--stdin'], 0, version=2, value=255, profile=profile,
                      input_bytes=b'\x00\xff') is None
    assert check_json(exe, [*args, '--stdin'], 0, version=2, value=0, profile=profile,
                      input_bytes=b'') is None
    invoke(exe, [*args, '--input', payload, '--stdin'], 2)
    invoke(exe, ['check', source, '--stdin'], 2)
    invoke(exe, ['eval-i32', source, 0, '--stdin'], 2)

    payload.unlink()
    missing = check_json(exe, [*args, '--input', payload], 7, version=2, profile=profile)
    assert missing == {'kind': 'input_io', 'location': {'kind': 'none'}}, missing
    source.write_bytes(b'module main; pub fn i32 main(ref u8[] data){return true;}')
    bad = check_json(exe, [*args, '--input', payload], 3, version=2)
    assert bad['kind'] == 'type' and bad['location']['kind'] == 'source_byte', bad
    source.write_bytes(b'\xff')
    lexical = check_json(exe, [*args, '--input', payload], 3, version=2)
    assert lexical == {'kind': 'lexical', 'location': {'kind': 'source_byte', 'offset': 0}}, lexical
    print('PASS: source-mode binary file and pipe input, empty input and compile-first diagnostics')


def check_test_i32(exe, directory, identity, shipping):
    path = directory / 'scalar-cases.csv'
    args = ['test-i32', identity, path]

    def batch(cases, code, expected, *options, command=args):
        path.write_bytes(cases)
        ran = invoke(exe, [*command, *options], code)
        assert not ran.stdout and ran.stderr.splitlines() == [expected], ran

    batch(b'-2147483648,-2147483648\r\n2147483647,2147483647', 0,
          b'test-i32: 2 cases passed')
    cases = b'29999,3000\n30000,0\n' * 500
    shipping_args = ['test-i32', shipping, path]
    batch(cases, 0, b'test-i32: 1000 cases passed', '--fuel', 16000, command=shipping_args)
    batch(cases, 2, b'browniec: usage', '--fuel', 16001, command=shipping_args)
    batch(b'1,1\n2,1\n3,3\n', 1, b'test-i32: row 2: expected 1, got 2')
    for invalid in (b'', b'\n', b'2147483648,0', b'0,-2147483649', b'1,1,1',
                    b'0,0\x00', b'0,0' + b'0' * 30):
        batch(invalid, 2, b'test-i32: row 1: browniec: usage',
              command=['test-i32', directory / 'missing.brc', path])
    batch(b'1,1\n' * 1001, 2, b'test-i32: row 1001: browniec: usage')
    batch(b'0' * 34001, 2, b'browniec: usage')

    # Compare the exact guest exit and diagnostic across the first successful Fuel.
    for fuel in range(10):
        single = subprocess.run([str(exe), 'eval-i32', str(identity), '1', '--fuel', str(fuel)],
                                capture_output=True, timeout=10)
        if single.returncode == 0:
            assert single.stderr.splitlines() == [b'return_i32=1'], single
            batch(b'1,1\n2,2', 0, b'test-i32: 2 cases passed', '--fuel', fuel)
            assert fuel > 0
            break
        assert single.returncode == 5 and single.stderr.startswith(b'browniec: fuel'), single
        batch(b'1,1\n2,2', 5, b'test-i32: row 1: ' + single.stderr.rstrip(b'\r\n'),
              '--fuel', fuel)
    else:
        raise AssertionError('identity rule did not complete within 9 Fuel')

    trap = directory / 'scalar-trap.brc'
    trap.write_bytes(b'module main; fn i32 evaluate(i32 x) { return 12 / x; }\n')
    single = invoke(exe, ['eval-i32', trap, 0], 5)
    assert single.stderr.startswith(b'browniec: zero_divisor'), single
    batch(b'2,6\n0,0\n', 5, b'test-i32: row 2: ' + single.stderr.rstrip(b'\r\n'),
          command=['test-i32', trap, path])
    print('PASS: test-i32 batch, bounded CSV and Fuel, mismatches and guest diagnostics')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--adapter-exe', type=Path, help='Built tools/runtime-engine/adapter-fixture.c')
    settings = parser.parse_args()
    exe = settings.exe.resolve(strict=True)
    adapter = settings.adapter_exe.resolve(strict=True) if settings.adapter_exe else None
    print(f'CLI SHA-256: {hashlib.sha256(exe.read_bytes()).hexdigest()}', flush=True)

    shipping = ROOT / 'examples/shipping-fee.brc'
    with TemporaryDirectory(prefix='browniec-cli-') as temp:
        source_zero = Path(temp) / 'source-zero.brc'
        source_zero.write_bytes(b'\xff')
        missing = Path(temp) / 'missing.brc'
        identity = Path(temp) / 'identity.brc'
        identity.write_bytes(b'module main; fn i32 evaluate(i32 x) { return x; }\n')

        host_check = make_host_check(Path(temp))
        host_run = make_host_run(host_check, Path(temp) / 'host-replies.json')
        project_host_check, project_host_run = make_host_project(Path(temp) / 'host-project', bounded_transport=True)
        check_output_table(exe, identity, host_check, host_run, project_host_check, project_host_run, adapter)
        check_host_run(exe, host_check, host_run)
        if adapter:
            adapter_dir = Path(temp) / 'process-adapter'
            adapter_dir.mkdir()
            check_process_adapter(exe, adapter, adapter_dir)
        check_host_catalog(exe, host_check)
        check_host_project(exe, project_host_check, project_host_run)
        check_host_project_input(exe, project_host_check, project_host_run)
        check_host_project_output(exe, Path(temp) / 'host-output', adapter)
        check_project(exe, Path(temp))
        check_project_input(exe, Path(temp))
        check_project_input_entry(exe, Path(temp))
        check_source_input(exe, Path(temp))
        check_configured_output(exe, Path(temp))
        check_unframe_example(exe, Path(temp))
        check_inspection_limits(exe, Path(temp))
        check_diagnostic(exe, source_zero, 3, 'lexical',
                         {'kind': 'source_byte', 'offset': 0}, b'browniec: lexical at byte 0')
        check_diagnostic(exe, missing, 7, 'input_io',
                         {'kind': 'none'}, b'browniec: input_io')
        print('PASS: source byte zero and absent location in text, JSON v1 and JSON v2')
        check_argument_types(exe, Path(temp))
        check_return_types(exe, Path(temp))
        check_initializer_types(exe, Path(temp))

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
        check_test_i32(exe, Path(temp), identity, shipping)


if __name__ == '__main__':
    main()
