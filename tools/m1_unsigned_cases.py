"""Unsigned boundary expectations checked against the real native source CLI."""
from math import isqrt
import random


def run_unsigned(case, body, root):
    for tag, width in [("u8", 8), ("u32", 32), ("usize", 64)]:
        maximum = (1 << width) - 1

        def result(name, expression, expected):
            case(f"unsigned-{tag}-{name}", body(f"let {tag} actual={expression}; let {tag} expected={expected}; if(actual==expected) {{return 42;}} return 0;"), 42)

        for index, n in enumerate([0, 1, maximum // 2, maximum // 2 + 1, maximum - 1, maximum]):
            result(f"literal-{index}", str(n), n)
        result("leading-zeros", f"000{maximum}", maximum)
        square = isqrt(maximum)
        pairs = [(0, 0), (maximum, 0), (maximum, 1), (maximum, 2), (0, maximum),
                 (1, maximum), (maximum, maximum), (maximum // 2 + 1, 2),
                 (square, square), (square + 1, square + 1),
                 (maximum, maximum // 2 + 1), (maximum // 2 + 1, maximum // 2 + 1)]
        for index, (a, b) in enumerate(pairs):
            for op_index, op in enumerate(["+", "-", "*", "/", "%"]):
                expression = f"({a}){op}({b})"
                error, expected = None, None
                if op in ["/", "%"]:
                    if b == 0:
                        error = "zero_divisor"
                    else:
                        expected = a // b if op == "/" else a % b
                else:
                    expected = a + b if op == "+" else a - b if op == "-" else a * b
                    if expected < 0 or expected > maximum:
                        error = "overflow"
                name = f"matrix-{index}-{op_index}"
                if error:
                    case(f"unsigned-{tag}-{name}", body(f"let {tag} n={expression}; return 42;"), error=error)
                else:
                    result(name, expression, expected)
        for index, (a, b) in enumerate([(0, maximum), (maximum, maximum), (maximum, maximum // 2)]):
            for op_index, op in enumerate(["<", "<=", ">", ">=", "==", "!="]):
                expected = {"<": a < b, "<=": a <= b, ">": a > b, ">=": a >= b, "==": a == b, "!=": a != b}[op]
                case(f"unsigned-{tag}-compare-{index}-{op_index}", body(f"let {tag} n={a}; if(n{op}{b}) {{return 42;}} return 0;"), 42 if expected else 0)
        rng = random.Random(width)
        for index in range(6):
            a, b = rng.randrange(maximum + 1), rng.randrange(1, maximum + 1)
            result(f"independent-div-{index}", f"{a}/{b}", a // b)
            result(f"independent-rem-{index}", f"{a}%{b}", a % b)
        for name, statements in [
            ("assignment", f"var {tag} n=0; let {tag} old=n; n={maximum}; if(n=={maximum} && old==0) {{return 42;}} return 0;"),
            ("parentheses", f"let {tag} n=((( {maximum} ))); if(n=={maximum}) {{return 42;}} return 0;"),
            ("for", f"var {tag} total=0; for(var {tag} n=0;n<8;n=n+1) {{if(n==3) {{continue;}} if(n==7) {{break;}} total=total+n;}} if(total==18) {{return 42;}} return 0;"),
            ("while", f"var {tag} n={maximum - 3}; while(n<{maximum}) {{n=n+1;}} if(n=={maximum}) {{return 42;}} return 0;"),
            ("switch", f"let Option<i32> x=.some(1); let {tag} n=switch(x) {{case .some(_): {{var {tag} n={maximum - 1}; n=n+1; n}} case .none: {{1/0}}}}; if(n=={maximum}) {{return 42;}} return 0;"),
            ("inferred-switch", f"let Option<bool> x=.some(true); let {tag} n={maximum}; if(switch(x) {{case .some(_): {{n}} case .none: {{0}}}}==n) {{return 42;}} return 0;"),
            ("short-and", f"let {tag} n={maximum}; if(false && n+1==0) {{return 0;}} return 42;"),
            ("short-or", f"let {tag} n=0; if(true || n-1==0) {{return 42;}} return 0;"),
        ]:
            case(f"unsigned-{tag}-{name}", body(statements), 42, fuel=1000)
        for name, source in [
            ("call-frames", f"fn {tag} f({tag} n,i32 count) {{if(count==0) {{return n;}} return f(n+1,count-1);}} fn i32 main() {{let {tag} n=f({maximum - 7},7); if(n=={maximum}) {{return 42;}} return 0;}}"),
            ("return-literal", f"fn {tag} f() {{return {maximum};}} fn i32 main() {{if(f()=={maximum}) {{return 42;}} return 0;}}"),
            ("switch-return", f"fn {tag} f(Option<i32> x) {{return switch(x) {{case .some(_): {{return {maximum};}} case .none: {{0}}}};}} fn i32 main() {{if(f(.some(1))=={maximum}) {{return 42;}} return 0;}}"),
        ]:
            case(f"unsigned-{tag}-{name}", ("module main; " + source).encode(), 42)
        invalid = [
            f"let {tag} n={maximum + 1};", f"let {tag} n=-0;", f"let {tag} n=-1;",
            f"let {tag} n=true;", f"let {tag} n=1; let bool b=!n;",
            f"let {tag} n=1; let bool b=-n==0;", f"let {tag} n=1; if(n) {{}}",
            f"let {tag} n=1; let i64 m=n;", f"let i32 n=1; let {tag} m=n;",
            f"let {tag} n=1; let i32 m=n;", f"var {tag} n=0; let i32 m=1; n=m;",
            f"let {tag} n=1; let i32 m=1; let bool b=n==m;",
            f"let {tag} n=1; let bool b=1==n;", f"let {tag} n=1; let {tag} m=n?;",
            f"let Option<{tag}> n=.some(1);", f"let Result<i32,{tag}> n=.err(1);",
            f"let {tag} n=1; let Option<i32> m=.some(n);",
        ]
        for index, statements in enumerate(invalid):
            case(f"unsigned-{tag}-reject-{index}", body(statements + "return 0;"), error="type")
        for name, expression, error in [
            ("fault-left", f"1/0+({maximum}+1)", "zero_divisor"),
            ("fault-right", f"({maximum}+1)+1/0", "overflow"),
        ]:
            case(f"unsigned-{tag}-{name}", body(f"let {tag} n={expression}; return 42;"), error=error)
        exact = body(f"let {tag} n=6*7; return 42;")
        case(f"unsigned-{tag}-fuel-exact", exact, 42, fuel=5)
        case(f"unsigned-{tag}-fuel-short", exact, error="fuel", fuel=4)
        case(f"unsigned-{tag}-check-no-execution", body(f"let {tag} n={maximum}+1; return 42;"), mode="check")
        case(f"unsigned-{tag}-entry-rejected", f"module main; fn {tag} main() {{return 42;}}".encode(), error="type")
    for a, b in [("u8", "u32"), ("u32", "usize"), ("usize", "u8")]:
        case(f"unsigned-reject-mixed-{a}-{b}", body(f"let {a} a=1; let {b} b=1; let {a} n=a+b; return 0;"), error="type")
    case("unsigned-reject-beyond-signed", body("let i64 n=18446744073709551615; return 0;"), error="type")
    case("unsigned-reject-suffix", body("let usize n=1usize; return 0;"), error="syntax")
    case("unsigned-example", (root / "examples/unsigned.brc").read_bytes(), 42)
