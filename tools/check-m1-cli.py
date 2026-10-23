"""Black-box fixtures for the real native CLI; never an alternate Brownie runtime."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess

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
    code = 0 if error is None else (5 if error in ("overflow", "zero_divisor", "fuel") else 3)
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
    ("locals-initializer-type", "let i32 x=true; return x;", "syntax"),
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
case("locals-fuel-exact", body("var i32 x=6; let i32 old=x; x=x*7; return x+old;"), 48, fuel=5)
case("locals-fuel-short", body("var i32 x=6; let i32 old=x; x=x*7; return x+old;"), error="fuel", fuel=4)
case("locals-check-does-not-execute", body("let i32 unused=1/0; return 42;"), mode="check")
case("local-limit-exact", body("let i32 v0=1;" + "".join(f"let i32 v{i}=v0;" for i in range(1,64)) + "return v63;"), 1)
case("local-limit-over", body("let i32 v0=1;" + "".join(f"let i32 v{i}=v0;" for i in range(1,65)) + "return v64;"), error="compile_limit")
case("tokens-exact", body("var i32 x=0;" + "x=x;" * 251 + "return x;"), 0)
case("tokens-over", body("var i32 x=0;" + "x=x;" * 252 + "return x;"), error="compile_limit")

randomizer = random.Random(20261023)
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
