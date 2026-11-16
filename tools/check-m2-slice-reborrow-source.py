"""Exercise lexical mutable reborrows through a tool-free public CLI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exe', required=True, type=Path)
parser.add_argument('--profile', required=True)
selection = parser.add_mutually_exclusive_group()
selection.add_argument('--owned-calls', action='store_true', help='Check derived CALLs with owned array/record arguments')
selection.add_argument('--array-results', action='store_true', help='Check array results from derived CALLs')
selection.add_argument('--record-results', action='store_true', help='Check record results from derived CALLs')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
kind = 'slice-reborrow-record-results' if args.record_results else 'slice-reborrow-array-results' if args.array_results else 'slice-reborrow-owned-calls' if args.owned_calls else 'slice-reborrow-source'
output = root / f'build/m2-{kind}' / args.profile
output.mkdir(parents=True, exist_ok=True)
receipt = output / 'cli-receipt.json'
receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
empty = output / 'no-runtime-tools'
empty.mkdir(exist_ok=True)
exe = args.exe.resolve(strict=True)
env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
rows = []


def case(source, category='public', expected=0, fuel=1000000, value=42):
    data = source.encode()
    path = output / f'case-{len(rows):03}.brc'
    path.write_bytes(data)
    for mode in ['check', 'run']:
        command = [str(exe), mode, str(path), '--json']
        if mode == 'run':
            command += ['--fuel', str(fuel)]
        done = subprocess.run(command, cwd=empty, env=env, capture_output=True, timeout=15)
        result = json.loads(done.stdout)
        assert not done.stderr and result['schema'] == 'browniec.result/v1', (source, done)
        assert result['command'] == mode, result
        error = ('verification' if category == 'conflict' else 'source' if category == 'source'
                 else {0: None, 7: 'zero_divisor', 8: 'fuel', 12: 'frame_limit', 13: 'array_limit', 14: 'bounds'}[expected]
                 if mode == 'run' else None)
        if error:
            code = 6 if category == 'conflict' else 3 if category == 'source' else 5
            kinds = ['type', 'syntax', 'compile_limit'] if error == 'source' else [error]
            assert done.returncode == code and result['status'] == 'error', (source, done)
            assert result['return_i32'] is None and result['error']['kind'] in kinds, (source, result)
            assert 0 <= result['error']['byte_offset'] < len(data), result
        else:
            assert done.returncode == 0 and result['error'] is None, (source, done)
            assert result['status'] == ('checked' if mode == 'check' else 'completed'), result
            assert result['return_i32'] == (None if mode == 'check' else value), (source, result)
        rows.append(dict(category=category, command=command, sourceSha256=hashlib.sha256(data).hexdigest(),
                         exit=done.returncode, result=result))


native_file = 'slice_reborrow_record_results' if args.record_results else 'slice_reborrow_array_results' if args.array_results else 'slice_reborrow_owned_calls' if args.owned_calls else 'slice_reborrow_source'
native = (root / f'tests/m2/{native_file}.fy').read_text(encoding='utf-8')
fixtures = re.findall(r'run_source\(b"([^"\n]+)",(\d+)\)', native)
conflicts = re.findall(r'conflict\(b"([^"\n]+)"', native)
negatives = re.findall(r'rejected\(b"([^"\n]+)"', native)
assert (len(fixtures), len(conflicts), len(negatives)) == ((17, 2, 1) if args.record_results else (17, 1, 0) if args.array_results else (18, 1, 0) if args.owned_calls else (22, 5, 3))
for source, expected in fixtures:
    # Native tests have 16M Fuel; the public CLI intentionally caps it at 1M.
    expected = 8 if 'return f(ref mut q,n-1)' in source or 'return f(ref mut q,b,n-1)' in source else int(expected)
    # The larger nested mixed-record and repeated root-assignment fixtures
    # complete natively at 16M but exceed the public 1M budget after CALL effects.
    if args.record_results and ('if(r.inner.ok && r.lead==7 && v.inner.x==1)' in source
                                or 'out=f(ref mut q);out=f(ref mut q);' in source):
        expected = 8
    # The native copy-quota fixture uses 256-byte backing; the CLI has 64KiB.
    if (args.owned_calls or args.array_results or args.record_results) and expected == 13:
        expected = 0
    case(source, expected=expected)
for source in conflicts:
    case(source, 'conflict', fuel=0)
for source in negatives:
    case(source, 'source', fuel=0)
case(fixtures[0][0], expected=8, fuel=0)
example = 'mutable-slice-record-result' if args.record_results else 'mutable-slice-array-result' if args.array_results else 'mutable-slice-owned-call' if args.owned_calls else 'mutable-slice-reborrow'
case((root / f'examples/{example}.brc').read_text(encoding='utf-8'), value=(77 if example == 'mutable-slice-reborrow' else 42))
# Exactly 16 static sites fit; one more child fails at compilation, before Fuel.
for count in ([] if args.owned_calls or args.array_results or args.record_results else [15, 16]):
    source = 'module main;fn i32 main(){var i32[1] a=[42;1];let ref mut i32[] p=ref mut a;'
    for i in range(count):
        parent = 'p' if i == 0 else f'q{i-1}'
        source += f'let ref mut i32[] q{i}=ref mut {parent};'
    source += f'return q{count-1}[0];}}'
    case(source, 'public' if count == 15 else 'source', expected=8 if count == 15 else 0)
if args.owned_calls:
    case('module main;fn i32 f(ref mut i32[] q,i64[4096] b){return 42;}fn i32 main(){var i32[1] a=[0;1];let i64[4096] b=[0;4096];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut q,b);}', expected=13)
    case('module main;fn i32 f(ref mut i32[] q,i32[1] b){return b[0];}fn i32 unused(){var i32[1] a=[0;1];let i32[1] b=[42;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;return f(ref mut q,b);}fn i32 main(){return 42;}')
if args.array_results:
    case('module main;fn i64[4096] f(ref mut i32[] q){q[0]=42;return [0;4096];}fn i32 main(){var i32[1] a=[0;1];let i64[4096] keep=[0;4096];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i64[4096] r=f(ref mut q);return 42;}', expected=13)
    case('module main;fn i32[1] f(ref mut i32[] q){return [42;1];}fn i32 unused(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let i32[1] r=f(ref mut q);return r[0];}fn i32 main(){return 42;}')
if args.record_results:
    case('module main;struct P{i32 x;}fn P f(ref mut i32[] q,i32[1] b,P v,ref u8[] s){q[0]=b[0]+v.x+s[0] as i32;return P{.x=q[0]};}fn i32 main(){var i32[1] a=[0;1];let i32[1] b=[40;1];let P v=P{.x=1};let u8[1] c=[1;1];let ref u8[] s=ref c;let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q,b,v,ref s);return r.x;}')
    case('module main;struct P{i32 x;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=42};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;var P out=f(ref mut q);out=f(ref mut q);return out.x;}')
    case('module main;struct P{i32 x;}fn P f(ref mut i32[] q){q[0]=42;return P{.x=q[0]};}fn i32 unused(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let ref mut i32[] q=ref mut p;let P r=f(ref mut q);return r.x;}fn i32 main(){return 42;}')
version = json.loads(subprocess.check_output([str(exe), '--version', '--json'], cwd=empty, env=env))
assert version['array_slice_mutable_reborrow'] is True
if args.owned_calls:
    assert version['array_slice_reborrow_owned_arguments'] is True
if args.array_results:
    assert version['array_slice_reborrow_array_results'] is True
if args.record_results:
    assert version['array_slice_reborrow_record_results'] is True
assert len(rows) == (50 if args.record_results else 44 if args.array_results else 46 if args.owned_calls else 68), len(rows)
receipt.write_text(json.dumps(dict(schema=f'browniec.{kind}-cli/v1', status='passed',
    profile=args.profile, exeSha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
    runtimeEnvironment='cleared; tool-free PATH', count=len(rows), cases=rows, version=version), indent=2)+'\n', encoding='utf-8')
print(f'PASS: {args.profile}: {len(rows)} public {kind} CLI cases')
