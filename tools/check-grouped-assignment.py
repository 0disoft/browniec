"""Check grouped assignment source execution, old-value ordering and exact public Fuel."""
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
    output = ROOT / 'build/grouped-assignment' / args.profile
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'cli-receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    empty = output / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {k: str(empty) for k in ['PATH', 'TEMP', 'TMP']}
    env.update({k: os.environ[k] for k in ['SystemRoot', 'WINDIR'] if k in os.environ})
    paths = ['tests/m2/grouped_assignment.fy', 'tools/check-grouped-assignment.py']
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
    for kind in range(4):
        for tag in ['i32', 'i64', 'u8', 'u32', 'usize']:
            for left, op, right in operations:
                if kind == 0:
                    source=f'module main;fn i32 main(){{var {tag} x={left};((x)){op}{right};if(x==42){{return 42;}}return 0;}}'
                elif kind == 1:
                    source=f'module main;fn i32 main(){{var {tag}[1] a=[{left}];((a)[0]){op}{right};if(a[0]==42){{return 42;}}return 0;}}'
                elif kind == 2:
                    source=f'module main;fn i32 main(){{var {tag}[1] a=[{left}];let ref mut {tag}[] s=ref mut a;(((s))[0]){op}{right};if(s[0]==42){{return 42;}}return 0;}}'
                else:
                    source=f'module main;struct P{{{tag} x;}}fn i32 main(){{var P p=P{{.x={left}}};((p).x){op}{right};if(p.x==42){{return 42;}}return 0;}}'
                case(source)
    fixtures = (ROOT / paths[0]).read_text()
    # A preceding aggregate and a preceding scalar both contribute leaf ordinals.
    # Check neighboring fields as well as the chosen nonzero nested ordinal.
    nested = ('module main;struct I{i32 x;i32 y;}struct P{I first;I second;}'
              'fn i32 main(){var P p=P{.first=I{.x=7,.y=99},.second=I{.x=0,.y=20}};'
              '((p).second).y+=22;if(p.first.x==7 && p.first.y==99 && p.second.x==0){return p.second.y;}return 0;}')
    case(nested)
    case(nested.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1))
    literal = r'(b"(?:[^"\\]|\\.)*")'
    for word in re.findall(r'(?:both|public_value)\(' + literal + r'\)', fixtures):
        source = ast.literal_eval(word).decode()
        case(source)
        if 'b"' not in source:
            case(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1))
    for original, grouped in re.findall(r'same\(' + literal + ',' + literal + r'\)', fixtures):
        source = ast.literal_eval(grouped).decode()
        case(source)
        case(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1))
    for helper in ['failure', 'rejected']:
        for word, kind in re.findall(helper + r'\(' + literal + r',(\d+)\)', fixtures):
            source = ast.literal_eval(word).decode()
            error = {2: 'syntax', 3: 'type', 4: 'compile_limit', 6: 'overflow', 7: 'zero_divisor', 14: 'bounds'}[int(kind)]
            case(source, error)
            case(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1), error)
    for kind, setup, target, result in [
        (0, 'var x=0;', '(x)', 'x'),
        (1, 'var a=[0];', '(a[0])', 'a[0]'),
        (2, 'var a=[0];let ref mut i32[] s=ref mut a;', '(s[0])', 's[0]'),
        (3, 'var P p=P{.x=0};', '(p.x)', 'p.x'),
    ]:
        head='module main;' + ('struct P{i32 x;}' if kind==3 else '') + 'fn i32 main(){'
        count=62 if kind==2 else 63
        declarations=''.join(f'let v{i}=0;' for i in range(count))
        case(head+setup+declarations+target+'+=42;return '+result+';}')
        case(head+setup+declarations+'let extra=0;return 42;}', 'compile_limit')
    for depth in [32,33]:
        case('module main;fn i32 main(){var x=0;'+'('*depth+'x'+')'*depth+'+=42;return x;}', 'compile_limit' if depth==33 else None)
    case('module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=12};'+'((p).x)+=1;'*30+'return p.x;}')
    for word, ordinary, retained in re.findall(r'exact\(' + literal + r',(\d+),(\d+)\)', fixtures):
        source=ast.literal_eval(word).decode()
        marker=source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1)
        for text,cost in [(source,int(ordinary)),(marker,int(retained)+18)]:
            for budget in [cost-1,cost,cost+1]:
                case(text, 'fuel' if budget<cost else None, budget)
    # The shared arm classifier also sees grouped final values. They must remain
    # expressions, and read-only lookahead must not execute an index CALL.
    value_arms = [
        'module main;fn i32 main(){let a=[42];let Option<i32> o=.some(0);return switch(o){case .some(_):{((a))[0]}case .none:{0}};}',
        'module main;fn i32[1] make(){return [42];}fn i32 main(){return if(true){((make()))[0]}else{0};}',
        'module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return if(true){((p)).x}else{0};}',
        'module main;struct P{i32 x;}fn i32 main(){let Option<i32> o=.some(0);return switch(o){case .some(_):{(P{.x=42}).x}case .none:{0}};}',
        'module main;fn usize pick(ref mut i32[] c){c[0]+=1;return 0;}fn i32 main(){let a=[41];var c=[0];return if(true){((a))[pick(ref mut c)]+c[0]}else{0};}',
        'module main;fn i32 main(){let x=20;return if(true){((x))+22}else{0};}',
    ]
    for source in value_arms:
        case(source)
        case(source.replace('fn i32 main(){', 'fn i32 main(){let ref u8[] marker=b"*";', 1))
    version = subprocess.run([str(exe), '--version', '--json'], cwd=empty, env=env, capture_output=True, timeout=15)
    metadata = json.loads(version.stdout)
    assert version.returncode == 0 and not version.stderr
    assert metadata['grouped_assignment_targets']
    assert metadata['fuel_default'] == 256 and metadata['fuel_limit'] == 16000000
    assert all(digest(ROOT / i['path']) == i['sha256'] for i in inputs)
    result = dict(schema='browniec.grouped-assignment-cli/v1', status='passed', profile=args.profile,
        exeSha256=digest(exe), inputs=inputs, runtimeEnvironment='cleared; tool-free PATH',
        count=len(rows) + 1, cases=rows, version=metadata)
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'PASS {args.profile}: {len(rows) + 1} grouped-assignment CLI cases')


if __name__ == '__main__':
    main()
