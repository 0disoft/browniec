"""Check ordered aggregate stores, source Fuel and tool-free public execution."""
import argparse
import ast
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', required=True)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    args = parser.parse_args()
    exe = Path(args.exe).resolve()
    output = ROOT / 'build/aggregate-place-assignment' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'cli-receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {k: str(empty) for k in ['PATH', 'TEMP', 'TMP']}
    env.update({k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ})
    paths = ['tests/m2/aggregate_place_assignment.fy', 'tools/check-aggregate-place-assignment.py']
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    rows = []

    def case(source, fuel=16000000, error=None):
        path = output / f'case-{len(rows):03}.brc'
        path.write_bytes(source.encode())
        command = [str(exe), 'run', str(path), '--json', '--fuel', str(fuel)]
        ran = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=30)
        data = json.loads(ran.stdout)
        assert ran.returncode == (3 if error == 'type' else 5 if error else 0), (source, fuel, data)
        assert not ran.stderr and data['schema'] == 'browniec.result/v1'
        assert data['status'] == ('error' if error else 'completed'), (source, data)
        assert data['return_i32'] == (None if error else 42), (source, data)
        assert (data['error']['kind'] == error) if error else data['error'] is None, (source, data)
        rows.append(dict(command=command, sourceSha256=digest(path), exit=ran.returncode, result=data))

    def marked(source):
        header = 'fn i32 main(){'
        assert source.count(header) == 1
        return source.replace(header, header + 'let ref u8[] fuel_marker=b"*";', 1)

    for tag in ['i32', 'bool', 'i64', 'u8', 'u32', 'usize']:
        zero, full = ('false', 'true') if tag == 'bool' else ('0', '42')
        for grouped in [False, True]:
            target = '((a))' if grouped else 'a'
            for mode in range(4):
                initial = full if mode == 3 else zero
                rhs = ['b', f'[{full};2]', '[true,false]' if tag == 'bool' else '[20,22]', 'a'][mode]
                if grouped:
                    rhs = '((' + rhs + '))'
                condition = ('a[0] && !a[1]' if tag == 'bool' else 'a[0]+a[1]==42') if mode == 2 else ('a[0]' if tag == 'bool' else 'a[0]==42')
                source = (f'module main;fn i32 main(){{var {tag}[2] a=[{initial};2];'
                          f'let {tag}[2] b=[{full};2];{target}={rhs};if({condition}){{return 42;}}return 0;}}')
                case(source)
                case(marked(source))

    fixtures = (ROOT / paths[0]).read_text(encoding='utf-8')
    for raw in re.findall(r'\bboth\((b"(?:\\.|[^"\\])*")\);', fixtures):
        source = ast.literal_eval(raw).decode()
        case(source)
        case(marked(source))
    for raw in re.findall(r'\brejected\((b"(?:\\.|[^"\\])*")\);', fixtures):
        case(ast.literal_eval(raw).decode(), error='type')
    precise = re.findall(r'oracle\((b"(?:\\.|[^"\\])*")\s*,(\d+),(\d+),(\d)\);', fixtures)
    assert len(precise) == 5
    for raw, ordinary, retained, _ in precise:
        source = ast.literal_eval(raw).decode()
        for candidate, exact in [(source, int(ordinary)), (marked(source), int(retained) + 18)]:
            for delta in [-1, 0, 1]:
                case(candidate, exact + delta, 'fuel' if delta == -1 else None)
    extras = [
        'module main;fn i32 main(){var a=[0;2];var n=0;a=[if(true){n+=1;42}else{0};2];if(n==1 && a[1]==42){return a[0];}return 0;}',
        'module main;fn i32 main(){var a=[0;2];var n=0;a=[if(true){n+=1;20}else{0},if(n==1){n+=1;22}else{0}];if(n==2){return a[0]+a[1];}return 0;}',
        'module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=22};((p))=((p));return p.x+p.y;}',
        'module main;struct P{i32 x;}struct R{P a;P b;}fn i32 main(){var R r=R{.a=P{.x=0},.b=P{.x=0}};r.b=if(true){r.a=P{.x=42};r.a}else{P{.x=0}};return r.b.x;}',
    ]
    for source in extras:
        case(source)
        case(marked(source))
    assert all(digest(ROOT / row['path']) == row['sha256'] for row in inputs)
    result = dict(schema='browniec.aggregate-place-assignment-cli/v1', status='passed',
                  profile=args.profile, recordedAt=datetime.now(timezone.utc).isoformat(), inputs=inputs,
                  artifact=dict(path=exe.relative_to(ROOT).as_posix(), sha256=digest(exe)),
                  runtimeEnvironment='cleared; tool-free PATH', cliCases=len(rows), cli=rows)
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'PASS {args.profile}: {len(rows)} aggregate source CLI cases', flush=True)


if __name__ == '__main__':
    main()
