"""Exercise exact record-field shorthand through the standalone native CLI."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'build/struct-shorthand'
output.mkdir(parents=True, exist_ok=True)
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {k: str(empty) for k in ['PATH', 'TEMP', 'TMP']}
env.update({k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ})
native = (root / 'tests/m2/struct_shorthand.fy').read_text(encoding='utf-8')
positive = re.findall(r'value\(b"([^"\n]+)"\)', native)
negative = re.findall(r'!compiler::compile\(b"([^"\n]+)"\)', native)
assert len(positive)==8 and len(negative)==6
positive += [
 'module main;struct I{i32 x;}struct R{I pair;i32 tail;}fn i32 main(){var I pair=I{.x=20};let Option<i32> v=.some(22);let R r=R{.pair,.tail=switch(v){case .some(n):{pair.x=0;n}case .none:{0}}};return r.pair.x+r.tail;}',
 'module main;struct P{i32 x;i32 y;}fn i32 main(){var i32 x=20;let Option<i32> v=.some(22);let P p=P{.x,.y=switch(v){case .some(n):{x=0;n}case .none:{0}}};return p.x+p.y;}'
]
negative += [
 'module main;struct P{i32 x;i32 y;}fn i32 main(){var i32 x=42;let P p=P{.x,.x};return p.x;}',
 'module main;struct I{i32 x;}struct R{I pair;}fn i32 main(){let I pair=I{.x=42};let R p=R{.pair.x};return p.pair.x;}'
]
fixtures = [(s.encode(), None) for s in positive]+[(s.encode(), 0) for s in negative]
rows = []
receipt = output / 'cli.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
for index, (data, offset) in enumerate(fixtures):
    source = output / f'case-{index}.brc'
    source.write_bytes(data)
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(source), '--json']
        if mode == 'run':
            command.extend(['--fuel','1000000'])
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
            assert result['error']['kind'] in ['type','syntax'] and 0<=result['error']['byte_offset']<len(data), result
        rows.append(dict(command=command, sourceSha256=hashlib.sha256(data).hexdigest(),
                         exitCode=done.returncode, result=result))
version=json.loads(subprocess.check_output([str(exe),'--version','--json'],cwd=empty,env=env))
assert version['struct_field_shorthand'] is True
receipt.write_text(json.dumps(dict(version=version,status='passed', count=len(rows),
    exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    harnessSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    environment='cleared; tool-free PATH', cases=rows), indent=2) + '\n', encoding='utf-8')
print(f'PASS: {len(rows)} standalone CLI record shorthand cases')
