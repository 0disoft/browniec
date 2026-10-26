"""Exercise source struct declarations with the actual native CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--exe', required=True, type=Path)
parser.add_argument('--profile', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / 'build/m2-struct-source' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
exe = args.exe.resolve(strict=True)
rows = []
main = 'fn i32 main(){return 42;}'


def case(text, error=None, mode='run', fuel=256, arrays=False):
    data = text.encode()
    path = output / f'case-{len(rows):03}.brc'
    path.write_bytes(data)
    command = [str(exe), mode, str(path), '--json']
    if mode == 'run':
        command += ['--fuel', str(fuel)]
    ran = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=10)
    code = 5 if error == 'fuel' else 3 if error else 0
    assert ran.returncode == code and not ran.stderr, (text, ran.returncode, ran.stdout, ran.stderr)
    result = json.loads(ran.stdout)
    assert result['schema'] == 'browniec.result/v1' and result['command'] == mode, result
    assert result['status'] == ('error' if error else 'checked' if mode == 'check' else 'completed'), result
    assert result['return_i32'] == (None if error or mode == 'check' else 42), result
    if error:
        assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(data), result
    else:
        assert result['error'] is None, result
        assert result['profile'].startswith('brownie.m2-array-') if arrays else result['profile'] == 'brownie.m1-scalar/1', result
    rows.append(dict(command=command, sourceSha256=hashlib.sha256(data).hexdigest(), exit=code, result=result))


def both(text, error=None):
    for mode in ['check', 'run']:
        case(text, error, mode)


def chain(depth, fanout=1):
    return ''.join('struct T'+str(i)+'{'+''.join(
        (f'T{i+1}' if i+1 < depth else 'usize')+' '+chr(97+j)+';'
        for j in range(fanout))+'}' for i in range(depth))


for tag in ['i32', 'i64', 'u8', 'u32', 'usize', 'bool']:
    both('module main;struct Point{'+tag+' x;}'+main)
for declarations in [
    'struct Outer{Inner left;Inner right;bool flag;}struct Inner{i32 x;}',
    'struct Inner{i32 x;}struct Outer{Inner left;Inner right;bool flag;}',
    'struct A{i32 x;}struct B{i32 x;}',
    'struct All{i32 a;i64 b;u8 c;u32 d;usize e;bool f;}',
    'struct Many{'+''.join('i32 '+chr(97+i)+';' for i in range(16))+'}',
    ''.join(f'struct T{i}{{i32 x;}}' for i in range(32)),
    chain(16), chain(15, 16),
]:
    both('module main;'+declarations+main)
both('module main;fn i32 helper(){return 42;}struct P{i32 x;}fn i32 main(){return helper();}')
both('module main;'+main+'struct P{i32 x;}')
both('module main;struct P{i32 x;}fn i32 main(){let i32 P=42;return P;}')
valid = 'module main;struct P{i32 x;}'+main
both(valid+' '*(4096-len(valid)))
case(valid, fuel=2)
case(valid, 'fuel', fuel=1)
for declarations, error in [
    ('struct P{}', 'type'),
    ('struct P{i32 x;}struct P{bool y;}', 'type'),
    ('struct P{i32 x;bool x;}', 'type'),
    ('struct P{Missing x;}', 'type'),
    ('struct P{P x;}', 'type'),
    ('struct P{Q x;}struct Q{P x;}', 'type'),
    ('struct P{Option<i32> x;}', 'type'),
    ('struct P{Result<i32,bool> x;}', 'type'),
    ('struct P{i32[2] x;}', 'type'),
    ('struct P{i32 x}', 'syntax'),
    ('struct P{i32 x;', 'syntax'),
    ('struct P{i32 x;};', 'syntax'),
    ('struct P{i32 x=0;}', 'syntax'),
    ('struct P{ref i32 x;}', 'syntax'),
    ('struct main{i32 x;}', 'type'),
    ('struct P{i32 x;}fn i32 P(){return 0;}', 'type'),
    ('fn i32 P(){return 0;}struct P{i32 x;}', 'type'),
    ('struct P{'+''.join('i32 '+chr(97+i)+';' for i in range(17))+'}', 'compile_limit'),
    (''.join(f'struct T{i}{{i32 x;}}' for i in range(33)), 'compile_limit'),
    (chain(17), 'compile_limit'), (chain(16,16), 'compile_limit'),
]:
    both('module main;'+declarations+main, error)
for name in ['i32', 'bool', 'usize', 'Option', 'Result', 'struct', 'fn', '_']:
    both('module main;struct '+name+'{i32 x;}'+main, 'syntax')
    both('module main;struct P{i32 '+name+';}'+main, 'syntax')
for text, error in [
    ('struct P{i32 x;}'+main, 'syntax'),
    ('module main;struct P{i32 x;}', 'type'),
    ('module main;struct P{i32 x;}fn P helper(){return 0;}'+main, 'type'),
    ('module main;struct P{i32 x;}fn i32 helper(P x){return 0;}'+main, 'type'),
    ('module main;struct P{i32 x;}fn i32 main(){let i32 n=42;let P q=n;return 42;}', 'type'),
]:
    both(text, error)
for depth in [10, 11]:
    expression = '42'
    for _ in range(depth):
        expression = 'switch(x){case .some(_):{if(true){a=['+expression+';1];}42}case .none:{0}}'
    case('module main;struct P{i32 x;}fn i32 main(){var i32[1] a=[0;1];let Option<i32> x=.some(1);return '+expression+';}',
         error='compile_limit' if depth == 11 else None, fuel=1000000, arrays=True)
assert len(rows) == 124, len(rows)
receipt.write_text(json.dumps(dict(schema='browniec.m2-struct-source-cli/v1', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} source struct CLI cases')
