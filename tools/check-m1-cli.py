"""Black-box fixtures for the real native CLI; never an alternate Brownie runtime."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
from m1_tagged_cases import run_tagged
from m1_propagation_cases import run_propagation
from m1_switch_expression_cases import run_switch_expression
from m1_i64_cases import run_i64
from m1_unsigned_cases import run_unsigned
from m1_widening_cases import run_widening

parser = argparse.ArgumentParser()
parser.add_argument("--exe", required=True)
parser.add_argument("--profile", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = root / "build" / "m1" / args.profile
output.mkdir(parents=True, exist_ok=True)
exe = Path(args.exe).resolve()
report = output / "cli-receipt.json"
report.write_text(json.dumps({"status": "incomplete"}) + "\n", encoding="utf-8")
empty = output / "no-runtime-tools"
empty.mkdir(exist_ok=True)
env = {"SystemRoot": os.environ["SystemRoot"], "WINDIR": os.environ["SystemRoot"],
       "PATH": str(empty), "TEMP": str(empty), "TMP": str(empty)}
results = []


def invoke(argv, expected_exit):
    ran = subprocess.run([str(exe), *map(str, argv)], capture_output=True,
                         cwd=empty, env=env, timeout=10)
    assert ran.returncode == expected_exit, (argv, ran.returncode, ran.stdout, ran.stderr)
    return ran


def case(name, source, expected=None, error=None, mode="run", fuel=None):
    fixture = output / (name + ".brc")
    fixture.write_bytes(source)
    code = 0 if error is None else (5 if error in ("overflow", "zero_divisor", "fuel", "frame_limit") else 3)
    argv = [mode, fixture, "--json"]
    if fuel is not None:
        argv += ["--fuel", fuel]
    ran = invoke(argv, code)
    assert not ran.stderr, (name, ran.stderr)
    result = json.loads(ran.stdout)
    assert set(result) == {"schema", "profile", "command", "status", "return_i32", "error"}, result
    assert result["schema"] == "browniec.result/v1"
    assert result["profile"] == "brownie.m1-scalar/1" and result["command"] == mode
    assert result["return_i32"] == expected, (name, result)
    if error:
        assert result["status"] == "error" and result["error"]["kind"] == error, (name, result)
        assert isinstance(result["error"]["byte_offset"], int) and 0 <= result["error"]["byte_offset"] <= len(source)
    else:
        assert result["error"] is None
        assert result["status"] == ("completed" if mode == "run" else "checked")
    results.append({"case": name, "sourceSha256": hashlib.sha256(source).hexdigest(),
                    "exit": ran.returncode, "result": result})


def program(expr):
    return ("module main; fn i32 main() { return " + expr + "; }").encode()


for name, expr, value in [
    ("answer", "6*7", 42), ("nonzero-is-data", "-17", -17),
    ("minimum", "-2147483648", -2147483648), ("maximum", "2147483647", 2147483647),
    ("precedence", "2+3*4", 14), ("parentheses", "(2+3)*4", 20),
    ("associativity", "20-6-3", 11), ("negative-division", "-7/3", -2),
    ("negative-remainder", "-7%3", -1), ("double-negative", "--42", 42),
]:
    case(name, program(expr), value)
for name, expr, error in [
    ("overflow-add", "2147483647+1", "overflow"),
    ("overflow-sub", "-2147483648-1", "overflow"),
    ("overflow-mul", "2147483647*2", "overflow"),
    ("overflow-neg", "--2147483648", "overflow"),
    ("overflow-div", "-2147483648/-1", "overflow"),
    ("overflow-rem", "-2147483648%-1", "overflow"),
    ("zero-div", "1/0", "zero_divisor"), ("zero-rem", "1%0", "zero_divisor"),
    ("first-left-trap", "1/0+(2147483647+1)", "zero_divisor"),
    ("first-right-trap", "(2147483647+1)+1/0", "overflow"),
    ("positive-outside", "2147483648", "type"),
    ("integer-outside", "999999999999999999999", "type"),
]:
    case(name, program(expr), error=error)
case("check-does-not-execute", program("1/0"), mode="check")
case("fuel-exact", program("6*7"), 42, fuel=4)
case("fuel-one-short", program("6*7"), error="fuel", fuel=3)
case("fuel-zero", program("6*7"), error="fuel", fuel=0)
case("depth-exact", program("(" * 32 + "1" + ")" * 32), 1)
case("depth-over", program("(" * 33 + "1" + ")" * 33), error="compile_limit")
case("register-exact", program("-(" + "+".join(["1"] * 64) + ")"), -64)
case("register-over", program("+".join(["1"] * 65)), error="compile_limit")
base = program("42")
case("bytes-exact", base + b" " * (4096 - len(base)), 42)
case("bytes-over", base + b" " * (4097 - len(base)), error="compile_limit")
case("bad-utf8", b"\xff", error="lexical")
case("nul-token", program("1\x00+2"), error="lexical")
case("missing-semicolon", b"module main; fn i32 main() { return 1 }", error="syntax")
case("trailing-source", base + b" garbage", error="syntax")
case("unsupported-type", base.replace(b"i32", b"i64"), error="type")
case("undefined-variable", program("value"), error="type")
case("comment-utf8", b"// \xce\xbb\n" + base, 42)
def body(statements):
    return ("module main; fn i32 main() { " + statements + " }").encode()


for name, statements, value in [
    ("locals-copy-snapshot", "let i32 base=6; var i32 x=base; let i32 old=x; x=x*7; return x+old;", 48),
    ("locals-reassign", "var i32 x=1; x=x+2; x=x*3; return x;", 9),
    ("locals-var-copy", "var i32 x=10; var i32 y=x; x=20; return y;", 10),
    ("locals-minimum", "let i32 min=-2147483648; return min;", -2147483648),
    ("locals-names", "let i32 a=2; let i32 ab=3; let i32 A=5; return a+ab*10+A*100;", 532),
]:
    case(name, body(statements), value)
for name, statements, error in [
    ("locals-let-assign", "let i32 x=1; x=2; return x;", "type"),
    ("locals-duplicate", "let i32 x=1; var i32 x=2; return x;", "type"),
    ("locals-self-reference", "var i32 x=x; return x;", "type"),
    ("locals-forward-reference", "let i32 x=y; let i32 y=1; return x;", "type"),
    ("locals-assign-before-declare", "x=1; var i32 x=2; return x;", "type"),
    ("locals-uninitialized", "var i32 x; return x;", "syntax"),
    ("locals-annotation", "let i64 x=1; return x;", "type"),
    ("locals-initializer-type", "let i32 x=true; return x;", "type"),
    ("locals-reserved-name", "let i32 return=1; return 0;", "syntax"),
    ("locals-assignment-expression", "var i32 x=1; return x=2;", "syntax"),
    ("locals-compound-unsupported", "var i32 x=1; x+=2; return x;", "syntax"),
    ("locals-missing-semicolon", "let i32 x=1 return x;", "syntax"),
    ("locals-missing-return", "let i32 x=1;", "syntax"),
    ("locals-extra-after-return", "return 1; let i32 x=2;", "syntax"),
    ("locals-unused-trap", "let i32 unused=1/0; return 42;", "zero_divisor"),
    ("locals-reassign-overflow", "var i32 x=2147483647; x=x+1; return 0;", "overflow"),
]:
    case(name, body(statements), error=error)
case("locals-fuel-exact", body("var i32 x=6; let i32 old=x; x=x*7; return x+old;"), 48, fuel=10)
case("locals-fuel-short", body("var i32 x=6; let i32 old=x; x=x*7; return x+old;"), error="fuel", fuel=9)
case("locals-check-does-not-execute", body("let i32 unused=1/0; return 42;"), mode="check")
case("local-limit-exact", body("let i32 v0=1;" + "".join(f"let i32 v{i}=v0;" for i in range(1,64)) + "return v63;"), 1)
case("local-limit-over", body("let i32 v0=1;" + "".join(f"let i32 v{i}=v0;" for i in range(1,65)) + "return v64;"), error="compile_limit")
case("tokens-exact", body("let i32 a=0;" + "{let i32 x=a;}" * 125 + "return ((a));"), 0)
case("tokens-over", body("let i32 a=0;" + "{let i32 x=a;}" * 125 + "return (((a)));"), error="compile_limit")

# Real multi-function programs: calls are executed by the VM, not inlined by tests.
for name, source, expected in [
    ("calls-forward-nested", "module main; fn i32 main() { return add(6,twice(18)); } fn i32 add(i32 a,i32 b) { return a+b; } fn i32 twice(i32 x) { return x*2; }", 42),
    ("calls-main-last", "module main; fn i32 id(i32 x) { return x; } fn i32 main() { return id(20)+id(22); }", 42),
    ("calls-value-params", "module main; fn i32 change(i32 x) { var i32 y=x; y=y+1; return y; } fn i32 main() { let i32 x=41; return x+change(x); }", 83),
    ("calls-frame-reuse", "module main; fn i32 f(i32 a,i32 b) { return a*10+b; } fn i32 main() { return f(1,2)+f(3,4); }", 46),
    ("calls-unused-trap", "module main; fn i32 bad() { return 1/0; } fn i32 main() { return 42; }", 42),
    ("calls-eight-params", "module main; fn i32 main() { return last(0,1,2,3,4,5,6,7); } fn i32 last(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,i32 h) { return h; }", 7),
]:
    case(name, source.encode(), expected)
for name, source, error in [
    ("calls-undefined", "module main; fn i32 main() { return unknown(); }", "type"),
    ("calls-too-few", "module main; fn i32 id(i32 x) { return x; } fn i32 main() { return id(); }", "type"),
    ("calls-too-many", "module main; fn i32 id(i32 x) { return x; } fn i32 main() { return id(1,2); }", "type"),
    ("calls-wrong-param-type", "module main; fn i32 id(i64 x) { return 1; } fn i32 main() { let i32 x=1; return id(x); }", "type"),
    ("calls-wrong-return-type", "module main; fn i64 f() { return 1; } fn i32 main() { return f(); }", "type"),
    ("calls-duplicate-function", "module main; fn i32 main() { return 0; } fn i32 main() { return 1; }", "type"),
    ("calls-duplicate-param", "module main; fn i32 id(i32 x,i32 x) { return x; } fn i32 main() { return id(1,2); }", "type"),
    ("calls-main-params", "module main; fn i32 main(i32 x) { return x; }", "type"),
    ("calls-main-missing", "module main; fn i32 helper() { return 0; }", "type"),
    ("calls-param-immutable", "module main; fn i32 id(i32 x) { x=1; return x; } fn i32 main() { return id(2); }", "type"),
    ("calls-local-isolation", "module main; fn i32 helper() { return x; } fn i32 main() { let i32 x=1; return helper(); }", "type"),
    ("calls-local-not-callable", "module main; fn i32 f() { return 1; } fn i32 main() { let i32 f=2; return f(); }", "type"),
    ("calls-function-not-value", "module main; fn i32 id() { return 1; } fn i32 main() { return id; }", "type"),
    ("calls-trailing-comma", "module main; fn i32 id(i32 x) { return x; } fn i32 main() { return id(1,); }", "syntax"),
    ("calls-left-to-right", "module main; fn i32 add(i32 a,i32 b) { return a+b; } fn i32 main() { return add(1/0,2147483647+1); }", "zero_divisor"),
    ("calls-callee-overflow", "module main; fn i32 inc(i32 x) { return x+1; } fn i32 main() { return inc(2147483647); }", "overflow"),
]:
    case(name, source.encode(), error=error)
inc = b"module main; fn i32 inc(i32 x) { return x+1; } fn i32 main() { return inc(41); }"
case("calls-fuel-exact", inc, 42, fuel=7)
case("calls-fuel-short", inc, error="fuel", fuel=6)
recursion = b"module main; fn i32 main() { return main(); }"
case("calls-recursion-fuel", recursion, error="fuel", fuel=31)
case("calls-recursion-frame", recursion, error="frame_limit", fuel=32)
case("calls-mutual-recursion", b"module main; fn i32 main() { return f(); } fn i32 f() { return main(); }", error="frame_limit")
case("calls-check-does-not-execute", recursion, mode="check")
helpers = "".join(f"fn i32 f{i}() {{ return 1; }}" for i in range(15))
case("functions-exact", ("module main;" + helpers + "fn i32 main() { return f0(); }").encode(), 1)
case("functions-over", ("module main;" + helpers + "fn i32 extra() { return 1; } fn i32 main() { return 0; }").encode(), error="compile_limit")
params = ",".join(f"i32 x{i}" for i in range(9))
case("parameters-over", f"module main; fn i32 f({params}) {{ return x0; }} fn i32 main() {{ return 0; }}".encode(), error="compile_limit")
call_sequence = "module main; fn i32 id(i32 x) { return x; } fn i32 main() { var i32 x=0;"
case("call-sites-exact", (call_sequence + "x=id(x);" * 32 + "return x; }").encode(), 0, fuel=164)
case("call-sites-fuel", (call_sequence + "x=id(x);" * 32 + "return x; }").encode(), error="fuel", fuel=163)
case("call-sites-over", (call_sequence + "x=id(x);" * 33 + "return x; }").encode(), error="compile_limit")

randomizer = random.Random(20261023)
for index, (expr, expected) in enumerate([
    ("true", True), ("false", False), ("!true", False), ("!!true", True),
    ("!false", True), ("true==false", False), ("true!=false", True),
    ("false==false", True), ("true!=true", False), ("true==!false", True),
    ("1==1", True), ("1!=1", False), ("-1==1", False), ("-1!=1", True),
    ("-1<1", True), ("1<1", False), ("2<1", False),
    ("1<=1", True), ("2<=1", False), ("0<=1", True),
    ("2>1", True), ("1>1", False), ("0>1", False),
    ("1>=1", True), ("2>=1", True), ("0>=1", False),
    ("-2147483648<2147483647", True), ("2147483647>-2147483648", True),
    ("2+3*4==14", True), ("1<2==true", True),
    ("false || true && false", False), ("(false || true) && true", True),
    ("true && true", True), ("true && false", False),
    ("false && true", False), ("false && false", False),
    ("true || true", True), ("true || false", True),
    ("false || true", True), ("false || false", False),
    ("false && (1/0==0)", False), ("true || (1/0==0)", True),
    ("false || true || (1/0==0)", True),
    ("true && false && (1/0==0)", False),
]):
    case(f"boolean-value-{index}", body(f"if({expr}) {{return 1;}} else {{return 0;}}"), int(expected))
for name, expr, error in [
    ("and-evaluated", "true && 1/0==0", "zero_divisor"),
    ("or-evaluated", "false || 1/0==0", "zero_divisor"),
    ("logic-first-failure", "1/0==0 || 2147483647+1==0", "zero_divisor"),
    ("logic-overflow-first", "2147483647+1==0 && 1/0==0", "overflow"),
    ("and-integer", "1 && true", "type"),
    ("or-integer", "true || 1", "type"),
    ("skipped-invalid-type", "false && 1", "type"),
    ("comparison-chain", "1<2<3", "type"),
]:
    case(name, body(f"if({expr}) {{return 1;}} return 0;"), error=error)
for name, statements, expected in [
    ("branch-true", "if(true) {return 42;} return 1/0;", 42),
    ("branch-false", "if(false) {return 1/0;} return 42;", 42),
    ("branch-var-then", "var i32 x=1; if(true) {x=42;} return x;", 42),
    ("branch-var-skip", "var i32 x=1; if(false) {x=42;} return x;", 1),
    ("branch-var-else", "var i32 x=1; if(false) {x=2;} else {x=42;} return x;", 42),
    ("branch-copy", "var i32 x=1; let i32 old=x; if(true) {x=41;} else {x=0;} return x+old;", 42),
    ("branch-nested", "var i32 x=0; if(true) {if(false) {x=1;} else {x=42;}} return x;", 42),
    ("branch-empty", "if(true) {} else {} return 42;", 42),
    ("branch-sibling-scope", "var i32 x=0; {let i32 a=20; x=a;} {let i32 a=22; x=x+a;} return x;", 42),
    ("branch-bool-slot", "var bool b=true; let bool old=b; if(old) {b=false;} if(!b && old) {return 42;} return 0;", 42),
    ("branch-else-if", "if(false) {return 0;} else if(true) {return 42;} else {return 1;}", 42),
    ("branch-early-else", "var i32 x=0; if(true) {x=42;} else {return 1;} return x;", 42),
    ("branch-early-then", "var i32 x=0; if(false) {return 1;} else {x=42;} return x;", 42),
]:
    case(name, body(statements), expected)
for name, statements, error in [
    ("branch-integer-condition", "if(1) {return 1;} return 0;", "type"),
    ("branch-scope-escape", "if(true) {let i32 x=1;} return x;", "type"),
    ("branch-else-scope", "if(true) {let i32 x=1;} else {return x;} return 0;", "type"),
    ("branch-immutable", "let i32 x=1; if(true) {x=2;} return x;", "type"),
    ("branch-shadow", "let i32 x=1; {let i32 x=2;} return x;", "type"),
    ("branch-missing-return", "if(true) {return 1;}", "syntax"),
    ("branch-unreachable", "if(true) {return 1;} else {return 0;} return 2;", "syntax"),
    ("branch-no-braces", "if(true) return 1; return 0;", "syntax"),
    ("branch-else-without-if", "else {return 1;} return 0;", "syntax"),
    ("branch-skipped-invalid-body", "if(false) {return true;} return 0;", "type"),
    ("single-and", "let bool b=true & false; return 0;", "lexical"),
    ("single-or", "let bool b=true | false; return 0;", "lexical"),
]:
    case(name, body(statements), error=error)
case("block-depth-exact", body("{" * 32 + "return 42;" + "}" * 32), 42)
case("block-depth-over", body("{" * 33 + "return 42;" + "}" * 33), error="compile_limit")
instruction_prefix = "let i32 c=0; var i32 x=c;" + "x=x;" * 125
case("instruction-exact", body(instruction_prefix + "x=c;x=c;return x;"), 0)
case("instruction-over", body(instruction_prefix + "x=c;x=c;x=c;return x;"), error="compile_limit")
branch = body("if(true) {return 42;} return 1/0;")
case("branch-fuel-exact", branch, 42, fuel=4)
case("branch-fuel-short", branch, error="fuel", fuel=3)
short = body("let bool b=false && 1/0==0; if(b) {return 1;} return 42;")
case("short-circuit-fuel-exact", short, 42, fuel=7)
case("short-circuit-fuel-short", short, error="fuel", fuel=6)
factorial = b"module main; fn i32 factorial(i32 n) {if(n<=1) {return 1;} return n*factorial(n-1);} fn i32 main() {return factorial(5);}"
case("factorial", factorial, 120)
case("factorial-check", factorial, mode="check")
case("factorial-overflow", factorial.replace(b"factorial(5)", b"factorial(13)"), error="overflow")
deep = b"module main; fn i32 f(i32 n) {if(n==0) {return 0;} return f(n-1);} fn i32 main() {return f(30);}"
case("branch-frames-exact", deep, 0, fuel=1000)
case("branch-frames-over", deep.replace(b"f(30)",b"f(31)"), error="frame_limit", fuel=1000)
case("branch-recursion-fuel", deep, error="fuel", fuel=10)
case("branch-frame-reuse", b"module main; fn i32 f(bool b) {var i32 x=1; if(b) {x=7;} return x;} fn i32 main() {return f(true)*10+f(false);}", 71)
case("short-call-skipped", b"module main; fn bool bad() {return bad();} fn i32 main() {if(true || bad()) {return 42;} return 0;}", 42)
case("short-call-taken", b"module main; fn bool bad() {return bad();} fn i32 main() {if(false || bad()) {return 42;} return 0;}", error="frame_limit")

case("bool-pipeline", b"module main; fn bool f(i32 x,bool b) { return !(x<=42)==b; } fn i32 sink(bool b) { return 42; } fn i32 main() { return sink(f(41,true)); }", 42)
for name, statements in [
    ("bool-integer-init", "let bool b=1; return 0;"),
    ("bool-integer-assign", "var bool b=true; b=1; return 0;"),
    ("bool-add", "let bool b=true+1; return 0;"),
    ("bool-mixed-equality", "let bool b=true==1; return 0;"),
    ("bool-order", "let bool b=true<false; return 0;"),
    ("bool-not-integer", "let bool b=!1; return 0;"),
    ("bool-negate", "let bool b=-true; return 0;"),
    ("bool-return", "return true;"),
]:
    case(name, body(statements), error="type")
case("bool-main", b"module main; fn bool main() { return true; }", error="type")
case("bool-argument", b"module main; fn bool f(bool b) { return b; } fn i32 main() { let bool b=f(1); return 0; }", error="type")

for name, statements, expected in [
    ("while-sum", "var i32 n=0; var i32 sum=0; while(n<10) {sum=sum+n; n=n+1;} return sum;",45),
    ("while-zero", "while(false) {return 1/0;} return 42;",42),
    ("while-snapshot", "var i32 n=0; var i32 sum=0; while(n<3) {let i32 old=n; n=n+1; sum=sum+old;} return sum;",3),
    ("while-continue-break", "var i32 n=0; var i32 sum=0; while(n<10) {n=n+1; if(n%2==0) {continue;} sum=sum+n; if(n==7) {break;}} return sum;",16),
    ("while-nested-break", "var i32 n=0; var i32 sum=0; while(n<3) {n=n+1; var i32 j=0; while(j<5) {j=j+1; if(j==3) {break;} sum=sum+1;}} return sum;",6),
    ("while-all-transfers", "var i32 n=0; while(true) {n=n+1; if(n<3) {continue;} else {break;}} return n;",3),
    ("while-local-reinit", "var i32 n=0; var i32 sum=0; while(n<3) {var i32 x=10; x=x+n; sum=sum+x; n=n+1;} return sum;",33),
    ("while-short-condition", "var i32 n=0; while(n<2 && true) {n=n+1;} return n;",2),
    ("while-bool-toggle", "var bool go=true; while(go) {go=false;} return 42;",42),
]:
    case(name,body(statements),expected,fuel=10000)
for name, statements, error in [
    ("break-outside","break; return 0;","syntax"),
    ("continue-outside","continue; return 0;","syntax"),
    ("while-integer","while(1) {} return 0;","type"),
    ("while-scope-escape","while(false) {let i32 x=1;} return x;","type"),
    ("while-after-break","while(true) {break; return 1;} return 0;","syntax"),
    ("while-after-continue","while(true) {continue; return 1;} return 0;","syntax"),
    ("while-overflow","var i32 n=2147483647; while(true) {n=n+1;} return n;","overflow"),
    ("while-trap","while(true) {return 1/0;} return 0;","zero_divisor"),
    ("while-missing-return","while(true) {}","syntax"),
]:
    case(name,body(statements),error=error)
once=body("var bool go=true; while(go) {go=false;} return 42;")
case("while-fuel-exact",once,42,fuel=11)
case("while-fuel-short",once,error="fuel",fuel=10)
case("while-fuel-loop",body("while(true) {} return 0;"),error="fuel",fuel=1000)
case("while-check-no-execution",body("while(true) {} return 0;"),mode="check")
case("while-call-condition",b"module main; fn bool keep(i32 n) {return n<3;} fn i32 main() {var i32 n=0; while(keep(n)) {n=n+1;} return n;}",3)

for name, statements, expected in [
    ("for-sum","var i32 sum=0; for(var i32 i=0;i<10;i=i+1) {sum=sum+i;} return sum;",45),
    ("for-continue-post","var i32 sum=0; for(var i32 i=0;i<10;i=i+1) {if(i%2==0) {continue;} sum=sum+i;} return sum;",25),
    ("for-break-skips-post","var i32 n=2147483647; for(;;n=n+1) {break;} return n;",2147483647),
    ("for-return-skips-post","var i32 n=2147483647; for(;;n=n+1) {return 42;} return 0;",42),
    ("for-zero-skips-post","var i32 n=0; for(;false;n=1/0) {return 0;} return 42;",42),
    ("for-assignment-init","var i32 n=9; for(n=0;n<4;n=n+1) {} return n;",4),
    ("for-empty-post","var i32 n=0; for(;n<4;) {n=n+1; continue;} return n;",4),
    ("for-empty-condition","var i32 n=0; for(;;n=n+1) {if(n==3) {break;}} return n;",3),
    ("for-all-clauses-empty","var i32 n=0; for(;;) {n=n+1; if(n==3) {break;}} return n;",3),
    ("for-header-let","var i32 n=0; for(let bool yes=true;yes;n=n+1) {if(n==2) {break;}} return n;",2),
    ("for-short-post","var bool go=true; var i32 n=0; for(;go;go=false && 1/0==0) {n=n+1;} return n;",1),
    ("for-nested-while","var i32 n=0; for(var i32 i=0;i<3;i=i+1) {var i32 j=0; while(j<3) {j=j+1; if(j==2) {continue;} n=n+1;}} return n;",6),
    ("for-nested-for","var i32 n=0; for(var i32 i=0;i<3;i=i+1) {for(var i32 j=0;j<4;j=j+1) {if(j==2) {break;} n=n+1;}} return n;",6),
    ("for-while-outer","var i32 n=0; var i32 sum=0; while(n<3) {n=n+1; for(var i32 j=0;j<3;j=j+1) {continue;} sum=sum+n;} return sum;",6),
    ("for-sibling-scopes","for(var i32 i=0;i<1;i=i+1) {} for(var i32 i=0;i<1;i=i+1) {} return 42;",42),
    ("for-body-local-reinit","var i32 sum=0; for(var i32 i=0;i<3;i=i+1) {var i32 x=10; x=x+i; sum=sum+x;} return sum;",33),
    ("for-long-run","var i32 sum=0; for(var i32 i=0;i<10000;i=i+1) {sum=sum+i;} return sum;",49995000),
]:
    case(name,body(statements),expected,fuel=200000)
for name, statements, error in [
    ("for-header-scope-escape","for(var i32 i=0;i<1;i=i+1) {} return i;","type"),
    ("for-post-body-local","var i32 n=0; for(;;n=x) {let i32 x=1; break;} return n;","type"),
    ("for-post-type","var bool b=true; for(;;b=1) {break;} return 0;","type"),
    ("for-post-declaration","for(;;let i32 x=1) {break;} return 0;","syntax"),
    ("for-post-expression","for(;;1+1) {break;} return 0;","syntax"),
    ("for-condition-type","for(;1;) {break;} return 0;","type"),
    ("for-immutable-post","for(let i32 i=0;i<1;i=i+1) {} return 0;","type"),
    ("for-continue-overflow","var i32 n=2147483647; for(;;n=n+1) {continue;} return 0;","overflow"),
    ("for-init-first-trap","for(var i32 i=1/0;false;i=i+1) {} return 42;","zero_divisor"),
    ("for-post-trap","var i32 n=0; for(;;n=1/0) {continue;} return 0;","zero_divisor"),
    ("for-unreachable-transfer","for(;;) {continue; return 42;} return 0;","syntax"),
    ("for-missing-return","for(;;) {}","syntax"),
]:
    case(name,body(statements),error=error)
for name, source in [
    ("for-init-call","module main; fn i32 f() {return 0;} fn i32 main() {for(var i32 i=f();i<1;i=i+1) {} return 0;}"),
    ("for-condition-call","module main; fn bool f() {return true;} fn i32 main() {for(;f();) {break;} return 0;}"),
    ("for-post-call","module main; fn i32 f() {return 0;} fn i32 main() {var i32 n=0; for(;;n=f()) {break;} return 0;}"),
    ("for-skipped-header-call","module main; fn bool f() {return true;} fn i32 main() {for(;false && f();) {} return 0;}"),
    ("for-cross-function-break","module main; fn i32 f() {break; return 1;} fn i32 main() {while(true) {return f();} return 0;}"),
]:
    case(name,source.encode(),error="syntax" if name=="for-cross-function-break" else "type")
post_once=body("var i32 i=0; for(;i<1;i=i+1) {continue;} return i;")
case("for-fuel-exact",post_once,1,fuel=18)
case("loop-example",(root/"examples/loops.brc").read_bytes(),42,fuel=1000)
case("loop-body-calls",b"module main; fn i32 inc(i32 n) {return n+1;} fn i32 main() {var i32 sum=0; for(var i32 i=0;i<10;i=i+1) {sum=sum+inc(i);} return sum;}",55,fuel=1000)
case("loop-call-frame-reuse",b"module main; fn i32 f(i32 n) {var i32 i=n; var i32 sum=0; while(i>0) {sum=sum+i; i=i-1;} return sum;} fn i32 main() {return f(3)+f(2);}",9,fuel=1000)
case("for-fuel-short",post_once,error="fuel",fuel=17)
case("for-empty-fuel",body("for(;;) {continue;} return 0;"),error="fuel",fuel=1000)
case("for-check-no-execution",body("for(;;) {} return 0;"),mode="check")
case("loop-depth-exact",body("for(;;){"*32+"break;"+"}"*32+"return 0;"),mode="check")
case("loop-depth-over",body("for(;;){"*33+"break;"+"}"*33+"return 0;"),error="compile_limit")
for n in [0,1,2,5,10,31]:
    for factor in [-3,1,7]:
        statements=f"var i32 sum=0; for(var i32 i=0;i<{n};i=i+1) {{sum=sum+i*{factor};}} return sum;"
        case(f"independent-loop-{n}-{factor}",body(statements),sum(i*factor for i in range(n)),fuel=10000)

run_tagged(case, body, root)
run_propagation(case, root)
run_switch_expression(case, body, root)
run_i64(case, body, root)
run_unsigned(case, body, root)
run_widening(case, body, root)

for index in range(32):
    a, b, c = [randomizer.randint(-1000, 1000) for _ in range(3)]
    case(f"independent-arithmetic-{index}", program(f"({a}*{b})+{c}"), a * b + c)

fixture = output / "answer.brc"
for name, argv, code, error in [
    ("unknown-option", ["run", fixture, "--json", "--bogus"], 2, "usage"),
    ("duplicate-json", ["run", fixture, "--json", "--json"], 2, "usage"),
    ("duplicate-fuel", ["run", fixture, "--json", "--fuel", "1", "--fuel", "1"], 2, "usage"),
    ("negative-fuel", ["run", fixture, "--json", "--fuel", "-1"], 2, "usage"),
    ("large-fuel", ["run", fixture, "--json", "--fuel", "1000001"], 2, "usage"),
    ("check-fuel", ["check", fixture, "--json", "--fuel", "1"], 2, "usage"),
    ("isolated-unavailable", ["run", fixture, "--json", "--isolated"], 4, "unavailable"),
    ("missing-file", ["run", output / "missing.brc", "--json"], 7, "input_io"),
]:
    ran = invoke(argv, code)
    result = json.loads(ran.stdout)
    assert not ran.stderr and result["return_i32"] is None and result["error"]["kind"] == error
    results.append({"case": name, "exit": code, "result": result})
ran = invoke(["run", fixture], 0)
assert ran.stdout == b"" and ran.stderr == b"return_i32=42\n"
results.append({"case": "text-stream-separation", "exit": 0})
version = json.loads(invoke(["--version", "--json"], 0).stdout)
assert version["restricted"] is False and version["embed"] is False
assert version["profile"] == "brownie.m1-scalar/1"
results.append({"case": "version-availability", "exit": 0, "result": version})
report.write_text(json.dumps({"schema": "browniec.m1-cli-checks/v1", "status": "passed",
    "profile": args.profile, "exeSha256": hashlib.sha256(exe.read_bytes()).hexdigest(),
    "runtimeEnvironment": "cleared; tool-free PATH", "count": len(results), "cases": results}, indent=2) + "\n", encoding="utf-8")
print(f"PASS: {args.profile}: {len(results)} native CLI cases")
