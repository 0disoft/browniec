"""Build the native CLI and check local inference without runtime tools."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release'], required=True)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--aggregate', action='store_true', help='add owned aggregate inference cases')
    selection.add_argument('--references', action='store_true', help='add reference and text inference cases')
    selection.add_argument('--options', action='store_true', help='add payload-derived Option constructor cases')
    selection.add_argument('--array-lists', action='store_true', help='add scalar element-list declarations')
    selection.add_argument('--array-list-assignment', action='store_true', help='add exact-shape list replacement and all earlier list cases')
    selection.add_argument('--array-literal-projections', action='store_true', help='add list/repeated scalar projections, UTF-8 and all earlier list cases')
    args = parser.parse_args()
    if args.array_literal_projections:
        args.array_list_assignment = True
    if args.array_list_assignment:
        args.array_lists = True
    suite = 'array-literal-projections' if args.array_literal_projections else 'array-list-assignment' if args.array_list_assignment else 'array-list' if args.array_lists else 'option' if args.options else 'reference' if args.references else 'aggregate' if args.aggregate else 'local'
    out = ROOT / ('build/' + suite + '-inference-cli') / args.profile
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / 'receipt.json'
    receipt.write_text('{"status":"incomplete"}\n', encoding='utf-8')
    assert not any(os.environ.get(key) for key in ['CL', '_CL_', 'LINK'])
    compiler = ROOT / 'build/toolchain' / ('fairyc.exe' if os.name == 'nt' else 'fairyc')
    target = 'windows/amd64' if os.name == 'nt' else 'linux/amd64'
    compiler_hash = sha(compiler)
    assert compiler_hash == json.loads((ROOT / 'toolchain.json').read_text())['platforms'][target]['sha256']
    production = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').rglob('*.fy'))
    assert all(b'\r' not in (ROOT / p).read_bytes() for p in production)
    paths = sorted(production + ['fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-local-inference-cli.py'])
    inputs = [dict(path=p, sha256=sha(ROOT / p)) for p in paths]
    captured = datetime.now(timezone.utc).isoformat()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    command = [str(compiler), 'build', '--locked']
    if args.profile == 'release':
        command.append('--release')
    built = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=1200)
    assert built.returncode == 0, (built.returncode, built.stdout, built.stderr)
    name = 'browniec.exe' if os.name == 'nt' else 'browniec'
    exe = out / name
    shutil.copy2(ROOT / 'build' / name, exe)
    binary_hash = sha(exe)
    empty = out / 'no-runtime-tools'
    empty.mkdir(exist_ok=True)
    env = {key: str(empty) for key in ['PATH', 'TEMP', 'TMP']}
    env.update({key: os.environ[key] for key in ['SystemRoot', 'WINDIR'] if key in os.environ})
    scalar = 'brownie.m1-scalar/1'
    reference = 'brownie.m2-reference/1'
    simple = b'module main;fn i32 main(){let n=42;return n;}'
    literal = b'module main;fn i32 main(){let n=b"*"[0];return n as i32;}'
    cases = [
        ('check', simple, 'check', None, None, None, scalar),
        ('run', simple, 'run', 42, None, None, scalar),
        ('mutable', b'module main;fn i32 main(){var n=40;n=n+2;return n;}', 'run', 42, None, None, scalar),
        ('wide', b'module main;fn i64 big(){return -9223372036854775808;}fn i32 main(){let n=big();if(n==-9223372036854775808){return 42;}return 0;}', 'run', 42, None, None, scalar),
        ('for', b'module main;fn i32 main(){var n=0;for(var i=0;i<4;i=i+1){n=n+i;}return n+36;}', 'run', 42, None, None, scalar),
        ('self', b'module main;fn i32 main(){let n=n;return n;}', 'check', None, 'type', None, scalar),
        ('changed-type', b'module main;fn i32 main(){var n=1;n=true;return n;}', 'run', None, 'type', None, scalar),
        ('ambiguous', b'module main;fn i32 main(){let n=.none;return 0;}', 'check', None, 'type', None, scalar),
        ('exact-fuel', simple, 'run', 42, None, 2, scalar),
        ('short-fuel', simple, 'run', None, 'fuel', 1, scalar),
        ('retained-run', literal, 'run', 42, None, 16000000, reference),
        ('retained-check', literal, 'check', None, None, None, reference),
    ]
    if args.aggregate:
        array_read = 'brownie.m2-array-read/1'
        array_copy = 'brownie.m2-array-copy/1'
        record_read = 'brownie.m2-struct-read/1'
        record_copy = 'brownie.m2-struct-copy/1'
        nested = 'brownie.m2-struct-nested/1'
        cases += [
            ('array', b'module main;fn i32 main(){let a=[21;2];return a[0]+a[1];}', 'run', 42, None, 16000000, array_read),
            ('array-copy', b'module main;fn i32 main(){var a=[21;2];let b=a;a[0]=0;return b[0]+b[1];}', 'run', 42, None, 16000000, array_copy),
            ('array-call', b'module main;fn i32[2] make(){return [21;2];}fn i32 main(){let a=make();return a[0]+a[1];}', 'run', 42, None, 16000000, array_read),
            ('record', b'module main;struct P{i32 x;}fn i32 main(){let p=P{.x=42};return p.x;}', 'run', 42, None, 16000000, record_read),
            ('record-copy', b'module main;struct P{i32 x;}fn i32 main(){let p=P{.x=42};var q=p;q.x=0;return p.x+q.x;}', 'run', 42, None, 16000000, record_copy),
            ('call-child', b'module main;struct P{i32 x;}struct Box{P inner;}fn Box make(){return Box{.inner=P{.x=42}};}fn i32 main(){let p=make().inner;return p.x;}', 'run', 42, None, 16000000, nested),
            ('array-projection', b'module main;fn i32[1] make(){return [42;1];}fn i32 main(){let n=make()[0];return n;}', 'run', 42, None, 16000000, array_read),
            ('record-projection', b'module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){let n=make().x;return n;}', 'run', 42, None, 16000000, record_read),
            ('early-array', b'module main;fn i32[1] take(i32[1] a){return a;}fn i32 main(){let Option<i32> o=.none;let a=take([switch(o){case .some(v):{v}case .none:{return 42;}};1]);return a[0];}', 'run', 42, None, 16000000, array_read),
            ('array-shape-error', b'module main;fn i32 main(){var a=[1;2];a=[1;3];return 0;}', 'check', None, 'type', None, scalar),
            ('array-zero', b'module main;fn i32 main(){let a=[1;0];return 0;}', 'check', None, 'type', None, scalar),
            ('retained-array', b'module main;fn i32 main(){let ref u8[] marker=b"*";let a=[21;2];return a[0]+a[1];}', 'run', 42, None, 16000000, reference),
        ]
    if args.references:
        shared = b'module main;fn i32 main(){let a=b"*";let alias=a;return alias[0] as i32;}'
        returned = b'module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let p=id(ref [42;3]);let alias=p[1..];return alias[1] as i32;}'
        cases += [
            ('byte-alias-check', shared, 'check', None, None, None, reference),
            ('byte-alias-run', shared, 'run', 42, None, 16000000, reference),
            ('text', 'module main;fn i32 main(){let t="한";let alias=ref t;let b=text::bytes(alias);if(b.len==3){return b[0] as i32;}return 0;}'.encode(), 'run', 237, None, 16000000, reference),
            ('grouped', b'module main;fn i32 main(){let p=(text::bytes("*"))[..];let alias=(ref p);return alias[0] as i32;}', 'run', 42, None, 16000000, reference),
            ('scalar-projections', b'module main;fn i32 main(){let p=b"*";let n=(p[0]);let len=p.len;if(len==1){return n as i32;}return 0;}', 'run', 42, None, 16000000, reference),
            ('returned-check', returned, 'check', None, None, None, reference),
            ('returned-run', returned, 'run', 42, None, 16000000, reference),
            ('returned-early-exit', b'module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;let p=id(ref [42;2])[..switch(o){case .some(v):{1}case .none:{return 42;}}];return 0;}', 'run', 42, None, 16000000, reference),
            ('shared-root', b'module main;fn i32 main(){let a=[42;1];let p=ref a;let q=p;return q[0];}', 'run', 42, None, 16000000, 'brownie.m2-array-read/1'),
            ('exclusive-root', b'module main;fn i32 main(){var a=[0;1];{let p=ref mut a;p[0]=42;}return a[0];}', 'run', 42, None, 16000000, 'brownie.m2-array-write/1'),
            ('exclusive-reborrow', b'module main;fn i32 main(){var a=[0;1];{let p=ref mut a;{let q=ref mut p;q[0]=40;}p[0]=p[0]+2;}return a[0];}', 'run', 42, None, 16000000, 'brownie.m2-array-write/1'),
            ('mutable-view-error', b'module main;fn i32 main(){var p=b"*";return 0;}', 'check', None, 'type', None, scalar),
            ('mutable-literal-error', b'module main;fn i32 main(){let p=ref mut b"*";return 0;}', 'check', None, 'type', None, scalar),
            ('self-reference-error', b'module main;fn i32 main(){let p=ref p;return 0;}', 'check', None, 'type', None, scalar),
            ('borrow-conflict-error', b'module main;fn i32 main(){var a=[42;1];let p=ref a;let q=ref mut a;return p[0];}', 'check', None, 'verification', None, 'brownie.m2-array-write/1'),
            ('selected-owner-error', b'module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let p=id(ref a);let q=p;a[0]=0;return q[0] as i32;}', 'check', None, 'verification', None, scalar),
        ]
        shadow = b'module main;fn ref u8[] owner(){return b"!";}fn ref u8[] take(ref u8[] input){let i32 owner=0;let x=owner;return ref input;}fn i32 main(){return take(ref b"*")[0] as i32;}'
        cases += [('shadowed-reference-function-check', shadow, 'check', None, None, None, reference),
                  ('shadowed-reference-function-run', shadow, 'run', 42, None, 16000000, reference)]
        native = b'module main;fn i32 main(){var i32[1] a=[0;1];{let p=ref mut a;p[0]=42;}let p=ref a;let q=p;return q[0];}'
        cases += [('reference-exact-fuel', native, 'run', 42, None, 286935, 'brownie.m2-array-write/1'),
                  ('reference-short-fuel', native, 'run', None, 'fuel', 286934, 'brownie.m2-array-write/1'),
                  ('alias-exact-fuel', shared, 'run', 42, None, 344121, reference),
                  ('alias-short-fuel', shared, 'run', None, 'fuel', 344120, reference)]
    if args.options:
        option = b'module main;fn i32 main(){let o=.some(42);switch(o){case .some(v):{return v;}case .none:{return 0;}}}'
        cases += [
            ('some-check', option, 'check', None, None, None, scalar),
            ('some-run', option, 'run', 42, None, None, scalar),
            ('some-exact', option, 'run', 42, None, 4, scalar),
            ('some-short', option, 'run', None, 'fuel', 3, scalar),
            ('some-bool', b'module main;fn i32 main(){let o=.some(false);switch(o){case .some(v):{if(v){return 0;}return 42;}case .none:{return 0;}}}', 'run', 42, None, None, scalar),
            ('some-mutable', b'module main;fn i32 main(){var o=.some(42);let copy=o;o=.none;switch(copy){case .some(v):{return v;}case .none:{return 0;}}}', 'run', 42, None, None, scalar),
            ('some-propagation', b'module main;fn Option<i32> f(Option<i32> o){let p=.some(o?+2);return p;}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{}}switch(f(.some(40))){case .some(v):{return v;}case .none:{return 0;}}}', 'run', 42, None, None, scalar),
            ('some-switch', b'module main;fn i32 main(){let o=switch(.some(true)){case .some(v):{.some(42)}case .none:{.none}};switch(o){case .some(v):{return v;}case .none:{return 0;}}}', 'run', 42, None, None, scalar),
            ('some-retained', b'module main;fn i32 main(){let o=.some(b"*"[0] as i32);switch(o){case .some(v):{return v;}case .none:{return 0;}}}', 'run', 42, None, 16000000, reference),
            ('some-unsupported-byte', b'module main;fn u8 byte(){return 42;}fn i32 main(){let o=.some(byte());return 0;}', 'check', None, 'type', None, scalar),
            ('some-nested', b'module main;fn i32 main(){let o=.some(.some(42));return 0;}', 'check', None, 'type', None, scalar),
            ('some-changing-type', b'module main;fn i32 main(){var o=.some(42);o=.some(true);return 0;}', 'check', None, 'type', None, scalar),
            ('err-ambiguous', b'module main;fn i32 main(){let o=.err(true);return 0;}', 'check', None, 'type', None, scalar),
        ]
    if args.array_lists:
        read = 'brownie.m2-array-read/1'
        write = 'brownie.m2-array-write/1'
        copy = 'brownie.m2-array-copy/1'
        pair = b'module main;fn i32 main(){let a=[20,22];return a[0]+a[1];}'
        cases += [
            ('list-check', pair, 'check', None, None, None, read),
            ('list-run', pair, 'run', 42, None, 16000000, read),
            ('list-default-fuel', pair, 'run', None, 'fuel', None, read),
            # 489 at eight backing bytes, plus 65536 - 8 public backing bytes.
            ('list-exact-fuel', pair, 'run', 42, None, 66017, read),
            ('list-short-fuel', pair, 'run', None, 'fuel', 66016, read),
            ('list-more-fuel', pair, 'run', 42, None, 66018, read),
            ('list-annotated', b'module main;fn i32 main(){let i32[2] a=[20,22];return a[0]+a[1];}', 'run', 42, None, 66017, read),
            ('list-single', b'module main;fn i32 main(){let a=[42];return a[0];}', 'run', 42, None, 16000000, read),
            ('list-trailing', b'module main;fn i32 main(){let a=[20,22,];return a[0]+a[1];}', 'run', 42, None, 16000000, read),
            ('list-bool', b'module main;fn i32 main(){let a=[true,false];if(a[0] && !a[1]){return 42;}return 0;}', 'run', 42, None, 16000000, read),
            ('list-u8', b'module main;fn i32 main(){let u8[2] a=[255,42];return a[1] as i32;}', 'run', 42, None, 16000000, read),
            ('list-wide', b'module main;fn i64 big(){return -9223372036854775808;}fn i32 main(){let a=[big(),9223372036854775807];if(a[0]==-9223372036854775808){return 42;}return 0;}', 'run', 42, None, 16000000, read),
            ('list-order', b'module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return c[0];}fn i32 main(){var c=[0];let a=[bump(ref mut c),bump(ref mut c)];return a[0]*10+a[1]+c[0]*15;}', 'run', 42, None, 16000000, write),
            ('list-copy', b'module main;fn i32 main(){var a=[20,22];let b=a;a[0]=0;return b[0]+b[1];}', 'run', 42, None, 16000000, copy),
            ('list-nested-separators', b'module main;fn i32 add(i32 a,i32 b){return a+b;}fn i32 main(){let a=[add(20,22)/* ,; */;1];let b=[a[0],b";],"[0] as i32];return b[0];}', 'run', 42, None, 16000000, reference),
            ('list-return-exit', b'module main;fn i32 main(){let prior=[7,8];let Option<i32> o=.none;let a=[20,switch(o){case .some(v):{v}case .none:{return 42;}}];return a[0];}', 'run', 42, None, 16000000, read),
            ('list-retained', b'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let a=[same(ref b"*")[0] as i32,0];return a[0]+a[1];}', 'run', 42, None, 16000000, reference),
            ('list-arity-error', b'module main;fn i32 main(){let i32[1] a=[20,22];return 0;}', 'check', None, 'type', None, scalar),
            ('list-mixed-error', b'module main;fn i32 main(){let a=[1,true];return 0;}', 'check', None, 'type', None, scalar),
            ('list-empty-error', b'module main;fn i32 main(){let a=[];return 0;}', 'check', None, 'type', None, scalar),
            ('list-self-error', b'module main;fn i32 main(){let a=[a[0],22];return 0;}', 'check', None, 'type', None, scalar),
            ('list-comma-error', b'module main;fn i32 main(){let a=[1,,2];return 0;}', 'check', None, 'syntax', None, scalar),
        ]
        argument = b'module main;fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){return take([20,22]);}'
        returned = b'module main;fn i32[2] make(){return [20,22];}fn i32 main(){let a=make();return a[0]+a[1];}'
        cases += [
            ('list-argument-check', argument, 'check', None, None, None, read),
            ('list-argument-run', argument, 'run', 42, None, 16000000, read),
            ('list-argument-exact', argument, 'run', 42, None, 66340, read),
            ('list-argument-short', argument, 'run', None, 'fuel', 66339, read),
            ('list-argument-more', argument, 'run', 42, None, 66341, read),
            ('list-result-check', returned, 'check', None, None, None, read),
            ('list-result-run', returned, 'run', 42, None, 16000000, read),
            ('list-result-exact', returned, 'run', 42, None, 66083, read),
            ('list-result-short', returned, 'run', None, 'fuel', 66082, read),
            ('list-result-more', returned, 'run', 42, None, 66084, read),
            ('list-nested-retained', b'module main;fn i32 take(i32[2] a){return a[0]+a[1];}fn i32[2] id(i32[2] a){return a;}fn i32 main(){let ref u8[] marker=b"*";return take(id([20,22]));}', 'run', 42, None, 16000000, reference),
            ('list-borrow-argument', b'module main;fn i32 take(ref i32[] a){return a[0]+a[1];}fn i32 main(){return take(ref [20,22]);}', 'run', 42, None, 16000000, read),
            ('list-exclusive-argument', b'module main;fn i32 take(ref mut i32[] a){a[0]=a[0]+2;return a[0]+a[1];}fn i32 main(){return take(ref mut [20,20][..]);}', 'run', 42, None, 16000000, write),
            ('list-selected-result', b'module main;fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref a;}fn i32 main(){let p=pick(ref [20,22],ref [0]);return p[0] as i32+p[1] as i32;}', 'run', 42, None, 16000000, reference),
            ('list-result-element-exit', b'module main;fn i32[1] make(){let Option<i32> o=.none;return [switch(o){case .some(v):{v}case .none:{return [42];}}];}fn i32 main(){let a=make();return a[0];}', 'run', 42, None, 16000000, read),
            ('list-argument-propagation', b'module main;fn i32 take(i32[1] a,i32[2] b){return b[0]+b[1];}fn Option<i32> work(Option<i32> o){return .some(take([7],[20,o?]));}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}', 'run', 42, None, 16000000, read),
            ('list-later-argument-exit', b'module main;fn i32 take(ref i32[] a,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;return take(ref [20,22],switch(o){case .some(v):{v}case .none:{return 42;}});}', 'run', 42, None, 16000000, read),
            ('list-argument-arity-error', b'module main;fn i32 take(i32[1] a){return 0;}fn i32 main(){return take([20,22]);}', 'check', None, 'type', None, scalar),
            ('list-result-arity-error', b'module main;fn i32[1] make(){return [20,22];}fn i32 main(){return 0;}', 'check', None, 'type', None, scalar),
            ('list-borrow-mode-error', b'module main;fn i32 take(ref mut i32[] a){return 0;}fn i32 main(){return take(ref [42]);}', 'check', None, 'syntax', None, scalar),
        ]
    if args.array_list_assignment:
        pair = b'module main;fn i32 main(){var a=[0;2];a=[20,22];return a[0]+a[1];}'
        cases += [
            ('assign-check', pair, 'check', None, None, None, write),
            ('assign-run', pair, 'run', 42, None, 16000000, write),
            ('assign-default-fuel', pair, 'run', None, 'fuel', None, write),
            # Native backing-eight oracle 555 + 65536 - 8 public backing bytes.
            ('assign-exact', pair, 'run', 42, None, 66083, write),
            ('assign-short', pair, 'run', None, 'fuel', 66082, write),
            ('assign-more', pair, 'run', 42, None, 66084, write),
            ('assign-bool', b'module main;fn i32 main(){var bool[2] a=[false;2];a=[true,false,];if(a[0] && !a[1]){return 42;}return 0;}', 'run', 42, None, 16000000, write),
            ('assign-i64', b'module main;fn i32 main(){var i64[2] a=[0;2];a=[-9223372036854775808,9223372036854775807];if(a[0]==-9223372036854775808 && a[1]==9223372036854775807){return 42;}return 0;}', 'run', 42, None, 16000000, write),
            ('assign-u8', b'module main;fn i32 main(){var u8[2] a=[0;2];a=[255,42];return a[1] as i32;}', 'run', 42, None, 16000000, write),
            ('assign-u32', b'module main;fn i32 main(){var u32[2] a=[0;2];a=[4294967295,42];if(a[0]==4294967295 && a[1]==42){return 42;}return 0;}', 'run', 42, None, 16000000, write),
            ('assign-usize', b'module main;fn i32 main(){var usize[2] a=[0;2];a=[18446744073709551615,42];if(a[0]==18446744073709551615 && a[1]==42){return 42;}return 0;}', 'run', 42, None, 16000000, write),
            ('assign-order', b'module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return c[0];}fn i32 main(){var c=[0];var a=[0;2];a=[bump(ref mut c),bump(ref mut c)];return a[0]*10+a[1]+c[0]*15;}', 'run', 42, None, 16000000, write),
            ('assign-self-read', b'module main;fn i32 main(){var a=[20,22];a=[a[1],a[0]];return a[0]+a[1];}', 'run', 42, None, 16000000, write),
            ('assign-early-return', b'module main;fn i32 main(){var a=[7,8];let Option<i32> o=.none;a=[20,switch(o){case .some(v):{v}case .none:{return a[0]+a[1]+27;}}];return 0;}', 'run', 42, None, 16000000, write),
            ('assign-rhs-effect', b'module main;fn i32 change(ref mut i32[] a){a[0]=20;return 0;}fn i32 main(){var a=[7,22];let Option<i32> o=.none;a=[change(ref mut a),switch(o){case .some(v):{v}case .none:{return a[0]+a[1];}}];return 0;}', 'run', 42, None, 16000000, write),
            ('assign-propagation', b'module main;fn Option<i32> work(Option<i32> o){var a=[7,8];a=[20,o?];return .some(a[0]+a[1]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}', 'run', 42, None, 16000000, write),
            ('assign-loop-exit', b'module main;fn i32 main(){var a=[20,22];let Option<i32> o=.none;var n=0;while(n<42){let prior=[1];a=[0,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}}];}while(true){a=[0,switch(o){case .some(v):{v}case .none:{break;}}];}return a[0]+a[1];}', 'run', 42, None, 16000000, write),
            ('assign-retained-call', b'module main;fn i32[2] make(){var a=[0;2];a=[20,22];return a;}fn i32 main(){let ref u8[] marker=b"*";var n=0;var sum=0;while(n<3){let a=make();sum=sum+a[0]+a[1];n=n+1;}return sum-84;}', 'run', 42, None, 16000000, reference),
            ('assign-after-last-alias', b'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[2] a=[0;2];a=[20,22];{let p=same(ref a);if(p[0]!=20){return 0;}}a=[22,20];let p=same(ref a);return p[0] as i32+p[1] as i32;}', 'run', 42, None, 16000000, reference),
            ('assign-arity-error', b'module main;fn i32 main(){var a=[0;2];a=[42];return 0;}', 'check', None, 'type', None, scalar),
            ('assign-type-error', b'module main;fn i32 main(){var a=[0;2];a=[1,true];return 0;}', 'check', None, 'type', None, scalar),
            ('assign-immutable-error', b'module main;fn i32 main(){let a=[0;2];a=[20,22];return 0;}', 'check', None, 'type', None, scalar),
            ('assign-borrow-error', b'module main;fn i32 main(){var a=[0;2];let p=ref a;a=[20,22];return p[0];}', 'check', None, 'type', None, scalar),
            ('assign-returned-alias-error', b'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[2] a=[0;2];let p=same(ref a);a=[20,22];return p[0] as i32;}', 'check', None, 'verification', None, scalar),
            ('assign-terminator-error', b'module main;fn i32 main(){var a=[0;2];a=[20,22] return 0;}', 'check', None, 'syntax', None, scalar),
        ]
    if args.array_literal_projections:
        pair = b'module main;fn i32 main(){return [20,42][1];}'
        repeated = b'module main;fn i32 main(){return [42;2][1];}'
        cases += [
            ('projection-check', pair, 'check', None, None, None, read),
            ('projection-run', pair, 'run', 42, None, 16000000, read),
            ('projection-default', pair, 'run', None, 'fuel', None, read),
            ('projection-exact', pair, 'run', 42, None, 65978, read),
            ('projection-short', pair, 'run', None, 'fuel', 65977, read),
            ('projection-more', pair, 'run', 42, None, 65979, read),
            ('repeat-projection-check', repeated, 'check', None, None, None, read),
            ('repeat-projection-exact', repeated, 'run', 42, None, 65698, read),
            ('repeat-projection-short', repeated, 'run', None, 'fuel', 65697, read),
            ('repeat-projection-more', repeated, 'run', 42, None, 65699, read),
            ('projection-inferred-scalar', b'module main;fn i32 main(){let n=[20,42,][1];var m=(([20,40]))[1];m=m+2;return n+m-42;}', 'run', 42, None, 16000000, read),
            ('projection-bool', b'module main;fn i32 main(){if([true,false][0] && ![false;2][1] && [20,22][0]==20){return 42;}return 0;}', 'run', 42, None, 16000000, read),
            ('projection-wide', b'module main;fn i64 big(){return [-9223372036854775808,0][0];}fn i32 main(){if(big()==-9223372036854775808){return 42;}return 0;}', 'run', 42, None, 16000000, read),
            ('projection-unsigned', b'module main;fn u8 byte(){return [255,42][1];}fn u32 word(){return [4294967295;2][0];}fn usize size(){return [18446744073709551615,0][0];}fn i32 main(){if(word()==4294967295 && size()==18446744073709551615){return byte() as i32;}return 0;}', 'run', 42, None, 16000000, read),
            ('projection-length', b'module main;fn i32 main(){let n=([true,false]).len;let m=([20;2]).len;if(n==2 && m==2){return -[20,22][0]+62;}return 0;}', 'run', 42, None, 16000000, read),
            ('projection-ordered-index', b'module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return 22;}fn usize pick(ref mut i32[] c){c[0]=c[0]+1;return 0;}fn i32 main(){var c=[20];let n=[c[0],bump(ref mut c)][pick(ref mut c)];return n+c[0];}', 'run', 42, None, 16000000, write),
            ('projection-length-effects', b'module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return c[0];}fn i32 main(){var c=[0];let n=[bump(ref mut c),bump(ref mut c)].len;let m=[bump(ref mut c);2].len;if(n==2 && m==2){return c[0]*14;}return 0;}', 'run', 42, None, 16000000, write),
            ('projection-index-exit', b'module main;fn i32 main(){let prior=[7];let Option<i32> o=.none;return [20,22][switch(o){case .some(v):{0}case .none:{return 42;}}];}', 'run', 42, None, 16000000, read),
            ('projection-index-propagation', b'module main;fn usize pick(i32 n){return 0;}fn Option<i32> work(Option<i32> o){return .some([42][pick(o?)]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}', 'run', 42, None, 16000000, read),
            ('projection-loop-exits', b'module main;fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let prior=[7];let v=[20,22][switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}];}while(true){let v=[42;1][switch(o){case .some(v):{0}case .none:{break;}}];}return n;}', 'run', 42, None, 16000000, read),
            ('projection-nested', b'module main;fn i32 main(){return [[20,22][0],[20,22][1]][0]+22;}', 'run', 42, None, 16000000, read),
            ('projection-retained', b'module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let marker=same(ref b"*");let n=([20,22])[1];var sum=0;var i=0;while(i<42){sum=sum+[1][0];i=i+1;}return n+sum-22;}', 'run', 42, None, 16000000, reference),
            ('utf8-list', b'module main;fn i32 main(){if(text::valid_utf8([195,169]) && !text::valid_utf8([195]) && text::valid_utf8([255][1..])){return 42;}return 0;}', 'run', 42, None, 16000000, read),
            ('utf8-list-computed', b'module main;fn usize end(){return 2;}fn i32 main(){if(text::valid_utf8([255,195,169][1+0..end()+1])){return 42;}return 0;}', 'run', 42, None, 16000000, read),
            ('utf8-list-loop-exit', b'module main;fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let valid=text::valid_utf8([65,66][0..switch(o){case .some(v):{1}case .none:{n=n+1;continue;}}]);}return n;}', 'run', 42, None, 16000000, read),
            ('projection-bounds', b'module main;fn i32 main(){return [20,22][2];}', 'run', None, 'bounds', 16000000, read),
            ('projection-retained-bounds', b'module main;fn i32 main(){let ref u8[] marker=b"*";return [42;2][2];}', 'run', None, 'bounds', 16000000, reference),
            ('projection-index-zero-divisor', b'module main;fn i32 main(){return [42][1/0];}', 'run', None, 'zero_divisor', 16000000, read),
            ('projection-mixed-type', b'module main;fn i32 main(){return [1,true][0];}', 'check', None, 'type', None, scalar),
            ('projection-bool-index', b'module main;fn i32 main(){return [1,2][true];}', 'check', None, 'type', None, scalar),
            ('projection-unknown-member', b'module main;fn i32 main(){return [1,2].missing;}', 'check', None, 'type', None, scalar),
            ('projection-bad-comma', b'module main;fn i32 main(){return [1,,2][0];}', 'check', None, 'syntax', None, scalar),
            ('utf8-list-bad-byte', b'module main;fn i32 main(){if(text::valid_utf8([256])){return 42;}return 0;}', 'check', None, 'type', None, scalar),
        ]
    version = None
    if args.array_lists:
        ran = subprocess.run([str(exe), '--version', '--json'], cwd=empty, env=env, capture_output=True, timeout=15)
        assert ran.returncode == 0 and not ran.stderr
        version = json.loads(ran.stdout)
        assert version['array_element_list_declarations'] is True
        assert all(version[key] is True for key in (
            'array_element_list_arguments', 'array_element_list_returns', 'array_element_list_temporary_borrows',
            'array_element_list_replacement'))
        assert version['fuel_default'] == 256 and version['fuel_limit'] == 16000000
        assert version['core'] is True and version['restricted'] is False and version['embed'] is False
        if args.array_literal_projections:
            assert version['array_literal_projections'] is True and version['array_utf8_element_lists'] is True
    results = []
    for identity, source, mode, expected, error, fuel, profile in cases:
        fixture = out / (identity + '.brc')
        fixture.write_bytes(source)
        argv = [mode, str(fixture), '--json'] + ([] if fuel is None else ['--fuel', str(fuel)])
        ran = subprocess.run([str(exe), *argv], cwd=empty, env=env, capture_output=True, timeout=15)
        expected_exit = 0 if error is None else (5 if error in ('fuel', 'bounds', 'zero_divisor') else 6 if error == 'verification' else 3)
        assert ran.returncode == expected_exit and not ran.stderr, (identity, ran.returncode, ran.stdout, ran.stderr)
        result = json.loads(ran.stdout)
        assert set(result) == {'schema', 'profile', 'command', 'status', 'return_i32', 'error'}, (identity, result)
        assert result['schema'] == 'browniec.result/v1' and result['command'] == mode and result['profile'] == profile, (identity, result)
        assert result['return_i32'] == expected, (identity, result)
        assert result['status'] == ('error' if error else 'completed' if mode == 'run' else 'checked'), (identity, result)
        if error:
            assert result['error']['kind'] == error and 0 <= result['error']['byte_offset'] <= len(source), (identity, result)
        else:
            assert result['error'] is None, (identity, result)
        recorded = [mode, fixture.relative_to(ROOT).as_posix(), '--json'] + ([] if fuel is None else ['--fuel', str(fuel)])
        results.append(dict(case=identity, sourceSha256=hashlib.sha256(source).hexdigest(), command=recorded,
                            exitCode=ran.returncode, result=result))
    assert all(sha(ROOT / i['path']) == i['sha256'] for i in inputs)
    assert sha(compiler) == compiler_hash and sha(exe) == binary_hash
    data = dict(schema='browniec.local-inference-cli/v1', status='passed', profile=args.profile,
                selection='array-literal-projections' if args.array_literal_projections else 'array-list-assignment' if args.array_list_assignment else 'array-list' if args.array_lists else 'option' if args.options else 'reference' if args.references else 'aggregate' if args.aggregate else 'scalar',
                startingHead=head, inputSnapshotCapturedAt=captured, inputs=inputs, compilerSha256=compiler_hash,
                compilerVersion=subprocess.check_output([str(compiler), '--version'], text=True).strip(),
                buildCommand=[compiler.relative_to(ROOT).as_posix(), *command[1:]],
                artifact=dict(path=exe.relative_to(ROOT).as_posix(), sha256=binary_hash),
                emptyRuntimeToolPath=True, cases=results, version=version,
                nativeOverrides=False, historicalResultReuse=False)
    receipt.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'PASS {args.profile}: {len(results)} CLI cases; {len(inputs)} matching inputs', flush=True)


if __name__ == '__main__':
    main()
