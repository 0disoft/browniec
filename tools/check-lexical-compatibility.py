"""Exercise source-byte compatibility through the standalone native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe', type=Path, required=True)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = args.output.resolve() if args.output else root / 'build/lexical-compatibility'
output.mkdir(parents=True, exist_ok=True)
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {k: str(empty) for k in ['PATH', 'TEMP', 'TMP']}
env.update({k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ})
base = b'module main;fn i32 main(){return 42;}'
fixtures = [(base, None), (b'\xef\xbb\xbf' + base, None),
            (b'// header\n' + base, None), (b'// header\r\n' + base, None),
            (b'/* outer /* { } */ tail */' + base, None),
            (base.replace(b'fn i32', b'fn/* gap */i32'), None),
            ('/* 주석 */'.encode() + base, None),
            (b'\r' + base, 0), (base + b'\r', len(base)),
            (b'//raw\r' + base, 5), (b'/*raw\r*/' + base, 5),
            (b'\x00' + base, 0), (base + b'\x00', len(base)),
            (b'//raw\x00\n' + base, 5), (b'/*raw\x00*/' + base, 5),
            (b' \xef\xbb\xbf' + base, 1), (b'/*\xef\xbb\xbf*/' + base, 2),
            (b'/* unterminated /* inner */', 0)]
rows = []
receipt = output / 'cli.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
for index, (data, offset) in enumerate(fixtures):
    source = output / f'case-{index}.brc'
    source.write_bytes(data)
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(source), '--json']
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True,
                              text=True, timeout=15)
        result = json.loads(done.stdout)
        assert not done.stderr and result['schema'] == 'browniec.result/v1'
        assert result['command'] == mode
        if offset is None:
            assert done.returncode == 0 and result['error'] is None, (command, result)
            assert result['status'] == ('checked' if mode == 'check' else 'completed')
            assert result['return_i32'] == (None if mode == 'check' else 42)
        else:
            assert done.returncode == 3 and result['status'] == 'error', (command, result)
            assert result['error'] == dict(kind='lexical', byte_offset=offset), result
        rows.append(dict(command=command, sourceSha256=hashlib.sha256(data).hexdigest(),
                         exitCode=done.returncode, result=result))
receipt.write_text(json.dumps(dict(status='passed', count=len(rows),
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    environment='cleared; tool-free PATH', cases=rows), indent=2) + '\n', encoding='utf-8')
print(f'PASS: {len(rows)} standalone CLI lexical cases')
