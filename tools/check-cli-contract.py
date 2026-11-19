"""Check the public scalar CLI contract using an already built executable."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory


def invoke(exe, args, exit_code):
    ran = subprocess.run([str(exe), *map(str, args)], capture_output=True, timeout=10)
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
        'status': 'error' if exit_code else 'completed',
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    exe = parser.parse_args().exe.resolve(strict=True)
    print(f'CLI SHA-256: {hashlib.sha256(exe.read_bytes()).hexdigest()}', flush=True)

    shipping = Path(__file__).resolve().parents[1] / 'examples' / 'shipping-fee.brc'
    with TemporaryDirectory(prefix='browniec-cli-') as temp:
        source_zero = Path(temp) / 'source-zero.brc'
        source_zero.write_bytes(b'\xff')
        missing = Path(temp) / 'missing.brc'
        identity = Path(temp) / 'identity.brc'
        identity.write_bytes(b'module main; fn i32 evaluate(i32 x) { return x; }\n')

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
