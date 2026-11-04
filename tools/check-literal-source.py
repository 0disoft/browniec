"""Check literal diagnostics and honest source gating in a tool-free native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


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
    env = {k: str(empty) for k in ['PATH', 'TEMP', 'TMP']}
    env.update({k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ})
    prefix = b'module main;fn i32 main(){return '
    fixtures = []
    for literal in [b'""', b'b""', b'"/* } not a comment */"', b'b"\\xFF\\0"',
                    b'"\\u{1F600}"', '"한"'.encode(), b'"\\xC3\\xA9"', b'"a" "b"']:
        fixtures.append((prefix + literal + b';}', 'syntax', len(prefix)))
    for literal in [b'"\\q"', b'b"\\u{41}"', b'"\\x0G"', b'"\\u{}"',
                    b'"\\u{D800}"', b'"\\u{110000}"', b'"\\u{0000041}"']:
        fixtures.append((prefix + literal + b';}', 'lexical',
                         len(prefix) + (2 if literal.startswith(b'b') else 1)))
    for literal in [b'"\\xFF"', b'"\\xC0\\x80"', b'"\\xED\\xA0\\x80"', b'"\\xE2\\x82"']:
        fixtures.append((prefix + literal + b';}', 'lexical', len(prefix)))
    for byte in [b'\x00', b'\n', b'\r', b'\xef\xbb\xbf']:
        fixtures.append((prefix + b'"' + byte + b'";}', 'lexical', len(prefix) + 1))
    fixtures.extend([(prefix + b'"unterminated', 'lexical', len(prefix)),
                     (prefix + b'c"no ffi";}', 'lexical', len(prefix)),
                     (prefix + b'b"\xff";}', 'lexical', 0)])
    rows = []
    for index, (source, kind, offset) in enumerate(fixtures):
        path = out / f'case-{index:03}.brc'
        path.write_bytes(source)
        for mode in ['check', 'run']:
            command = [str(exe), mode, str(path), '--json']
            result = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
            data = json.loads(result.stdout)
            assert result.returncode == 3 and not result.stderr, (command, result)
            assert data['schema'] == 'browniec.result/v1' and data['command'] == mode
            assert data['status'] == 'error' and data['return_i32'] is None, data
            assert data['error'] == dict(kind=kind, byte_offset=offset), data
            rows.append(dict(command=command, sourceSha256=hashlib.sha256(source).hexdigest(),
                             exitCode=result.returncode, result=data))
    receipt.write_text(json.dumps(dict(status='passed', count=len(rows),
        exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
        harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        environment='cleared; tool-free PATH', cases=rows), indent=2) + '\n',
        encoding='utf-8', newline='\n')
    print(f'PASS: {len(rows)} standalone literal CLI cases')


if __name__ == '__main__':
    main()
