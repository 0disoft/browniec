"""Run selected-place source cases through a tool-free native public CLI."""
import argparse
import ast
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
    output = ROOT / 'build/slice-place-assignment' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'cli-receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {k: str(empty) for k in ['PATH', 'TEMP', 'TMP']}
    env.update({k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ})
    paths = ['tests/m2/slice_place_assignment.fy', 'tools/check-slice-place-assignment.py']
    inputs = [dict(path=p, sha256=digest(ROOT / p)) for p in paths]
    rows = []

    def case(source, error=None, fuel=16000000):
        path = output / f'case-{len(rows):03}.brc'
        path.write_bytes(source.encode())
        command = [str(exe), 'run', str(path), '--json', '--fuel', str(fuel)]
        ran = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=30)
        data = json.loads(ran.stdout)
        code = 3 if error in ['syntax', 'type', 'compile_limit'] else 5 if error else 0
        assert ran.returncode == code and not ran.stderr, (source, ran.returncode, data, ran.stderr)
        assert data['schema'] == 'browniec.result/v1' and data['command'] == 'run'
        assert data['status'] == ('error' if error else 'completed'), (source, data)
        assert data['return_i32'] == (None if error else 42), (source, data)
        assert data['error']['kind'] == error if error else data['error'] is None, (source, data)
        rows.append(dict(command=command, sourceSha256=digest(path), exit=ran.returncode, result=data))

    operations = [('20', '+=', '22'), ('64', '-=', '22'), ('6', '*=', '7'), ('84', '/=', '2'),
                  ('127', '%=', '85'), ('21', '<<=', '1'), ('84', '>>=', '1'),
                  ('63', '&=', '42'), ('0', '^=', '42'), ('40', '|=', '2')]
    for tag in ['i32', 'i64', 'u8', 'u32', 'usize']:
        for left, op, right in operations:
            case(f'module main;fn i32 main(){{var {tag}[1] a=[{left};1];let ref mut {tag}[] p=ref mut a;p[0]{op}{right};'
                 'if(p[0]==42){return 42;}return 0;}')
    fixtures = (ROOT / paths[0]).read_text()
    literal = r'(b"(?:[^"\\]|\\.)*")'
    for word in re.findall(r'(?:both|public_value)\(' + literal + r'\)', fixtures):
        source = ast.literal_eval(word).decode()
        case(source)
        if 'b"' not in source:
            case(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1))
    for word, kind in re.findall(r'failure\(' + literal + r',(\d+)\)', fixtures):
        source = ast.literal_eval(word).decode()
        error = {6: 'overflow', 7: 'zero_divisor', 14: 'bounds'}[int(kind)]
        case(source, error)
        case(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1), error)
    for word in re.findall(r'assert\(!compiler::compile\(' + literal + r'\)', fixtures):
        case(ast.literal_eval(word).decode(), 'type')
    case('module main;fn i32 main(){var a=[0];let ref mut i32[] p=ref mut a;return (p[0]+=1);}', 'syntax')
    declarations = ''.join(f'let x{i}=0;' for i in range(62))
    case('module main;fn i32 main(){var a=[0;1];let ref mut i32[] p=ref mut a;' + declarations + 'p[0]+=42;return p[0];}')
    case('module main;fn i32 main(){var a=[0;1];let ref mut i32[] p=ref mut a;' + declarations + 'let extra=0;return 42;}', 'compile_limit')
    case('module main;fn i32 main(){var a=[12;1];let ref mut i32[] p=ref mut a;' + 'p[0]+=1;' * 30 + 'return p[0];}')
    # Ordinary public oracles add 65537 backing +5067 setup; retained marker
    # adds 147456 entry +196608 leave, per-dispatch work and 18 marker units.
    for source, ordinary, retained in [
        ('module main;fn i32 main(){var a=[0;1];let ref mut i32[] p=ref mut a;p[0]=42;return p[0];}', 152817, 496907),
        ('module main;fn i32 main(){var a=[20;1];let ref mut i32[] p=ref mut a;p[0]+=22;return p[0];}', 156984, 501075),
    ]:
        for text, price in [(source, ordinary),
                            (source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1), retained)]:
            for budget in [price - 1, price, price + 1]:
                case(text, 'fuel' if budget < price else None, budget)
    version = subprocess.run([str(exe), '--version', '--json'], cwd=empty, env=env,
                             capture_output=True, timeout=15)
    metadata = json.loads(version.stdout)
    assert version.returncode == 0 and not version.stderr
    assert metadata['slice_selected_place_assignment'] and metadata['slice_element_compound_assignment']
    assert metadata['fuel_default'] == 256 and metadata['fuel_limit'] == 16000000
    assert all(digest(ROOT / entry['path']) == entry['sha256'] for entry in inputs)
    result = dict(schema='browniec.slice-place-assignment-cli/v1', status='passed', profile=args.profile,
                  exeSha256=digest(exe), inputs=inputs, runtimeEnvironment='cleared; tool-free PATH',
                  count=len(rows) + 1, cases=rows, version=metadata)
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'PASS {args.profile}: {len(rows) + 1} selected-place CLI cases')


if __name__ == '__main__':
    main()
