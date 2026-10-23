"""Full-width signed expectations for the native CLI; Python never runs guest code."""
import random


def run_i64(case, body, root):
    minimum, maximum = -(1 << 63), (1 << 63) - 1

    def result(name, expression, expected):
        case("i64-" + name, body(f"let i64 actual={expression}; let i64 expected={expected}; if(actual==expected) {{return 42;}} return 0;"), 42)

    for index, n in enumerate([minimum, minimum + 1, -2147483649, -2147483648, -1, 0, 1, 2147483648, maximum - 1, maximum]):
        result(f"literal-{index}", str(n), n)
    result("leading-zero-min", "-0009223372036854775808", minimum)
    result("leading-zero-max", "0009223372036854775807", maximum)
    result("neg-i32-min", "--2147483648", 2147483648)
    # These exercise each guard's signs and exact edges without native overflow.
    pairs = [(minimum, 0), (minimum, 1), (minimum, -1), (minimum, minimum),
             (maximum, 1), (maximum, -1), (maximum, maximum), (0, minimum),
             (1, minimum), (-1, minimum), (3037000499, 3037000499),
             (3037000500, 3037000500), (-3037000500, 3037000500),
             (3037000500, -3037000500), (-3037000500, -3037000500),
             (-7, 3), (7, -3)]
    for index, (a, b) in enumerate(pairs):
        for op in ["+", "-", "*", "/", "%"]:
            expression = f"({a}){op}({b})"
            error = None
            expected = None
            if op in ["/", "%"]:
                if b == 0:
                    error = "zero_divisor"
                elif a == minimum and b == -1:
                    error = "overflow"
                else:
                    quotient = (abs(a) // abs(b)) * (-1 if (a < 0) != (b < 0) else 1)
                    expected = quotient if op == "/" else a - quotient * b
            else:
                expected = a + b if op == "+" else a - b if op == "-" else a * b
                if expected < minimum or expected > maximum:
                    error = "overflow"
            name = f"matrix-{index}-{['+', '-', '*', '/', '%'].index(op)}"
            if error:
                case("i64-" + name, body(f"let i64 x={expression}; return 42;"), error=error)
            else:
                result(name, expression, expected)
    for index, n in enumerate([minimum, minimum + 1, -1, 0, 1, maximum]):
        if n == minimum:
            case("i64-neg-overflow", body(f"let i64 n={n}; let i64 x=-n; return 42;"), error="overflow")
        else:
            result(f"neg-{index}", f"-({n})", -n)
    for index, (a, b) in enumerate([(minimum, maximum), (minimum, minimum), (maximum, minimum)]):
        for op_index, op in enumerate(["<", "<=", ">", ">=", "==", "!="]):
            expected = {"<": a < b, "<=": a <= b, ">": a > b, ">=": a >= b, "==": a == b, "!=": a != b}[op]
            case(f"i64-compare-{index}-{op_index}", body(f"let i64 a={a}; let bool b=a{op}{b}; if(b) {{return 42;}} return 0;"), 42 if expected else 0)
    rng = random.Random(64)
    for index in range(12):
        a, b = rng.randrange(-3000000000, 3000000001), rng.randrange(-3000000000, 3000000001)
        result(f"independent-{index}", f"({a})*({b})", a * b)
    valid = [
        ("assignment", "var i64 n=1; let i64 old=n; n=9223372036854775807; if(n>old) {return 42;} return 0;"),
        ("parentheses", "let i64 n=(((9223372036854775807))); if(n>0) {return 42;} return 0;"),
        ("for", "var i64 n=0; for(var i64 i=0;i<8;i=i+1) {if(i==3) {continue;} if(i==7) {break;} n=n+i;} if(n==18) {return 42;} return 0;"),
        ("while", "var i64 n=9223372036854775800; while(n<9223372036854775807) {n=n+1;} if(n==9223372036854775807) {return 42;} return 0;"),
        ("switch-local", "let Option<i32> x=.some(1); let i64 n=switch(x) {case .some(_): {var i64 n=9223372036854775806; n=n+1; n} case .none: {0}}; if(n==9223372036854775807) {return 42;} return 0;"),
        ("switch-inferred", "let Option<i32> x=.some(1); let i64 n=9223372036854775807; if(switch(x) {case .some(_): {n} case .none: {0}}==n) {return 42;} return 0;"),
        ("switch-statement", "let Option<i32> x=.some(1); var i64 n=0; switch(x) {case .some(_): {n=9223372036854775807;} case .none: {n=-9223372036854775808;}} if(n>0) {return 42;} return 0;"),
        ("short-and", "let i64 n=9223372036854775807; if(false && n+1==0) {return 0;} return 42;"),
        ("short-or", "let i64 n=-9223372036854775808; if(true || -n==0) {return 42;} return 0;"),
        ("rhs-literal", "let i64 n=9223372036854775807; if(n-1==9223372036854775806) {return 42;} return 0;"),
    ]
    for name, statements in valid:
        case("i64-" + name, body(statements), 42, fuel=1000)
    for name, source in [
        ("args-return", "fn i64 f(i64 n,i64 m) {return n+m;} fn i32 main() {let i64 n=f(9223372036854775800,7); if(n==9223372036854775807) {return 42;} return 0;}"),
        ("recursive-frames", "fn i64 f(i64 n,i32 count) {if(count==0) {return n;} return f(n+1,count-1);} fn i32 main() {let i64 n=f(9223372036854775800,7); if(n==9223372036854775807) {return 42;} return 0;}"),
        ("switch-return", "fn i64 f(Option<i32> x) {return switch(x) {case .some(_): {return -9223372036854775808;} case .none: {9223372036854775807}};} fn i32 main() {if(f(.some(1)) == -9223372036854775808) {return 42;} return 0;}"),
        ("propagation-adjacent", "fn Option<i32> f(Option<i32> x) {let i64 n=9223372036854775807; let i32 out=x?; if(n>0) {return .some(out);} return .none;} fn i32 main() {return switch(f(.some(42))) {case .some(v): {v} case .none: {0}};}"),
    ]:
        case("i64-" + name, ("module main; " + source).encode(), 42)
    invalid = [
        "let i64 n=9223372036854775808;", "let i64 n=-9223372036854775809;",
        "let i64 n=18446744073709551615;", "let i64 n=-(9223372036854775808);",
        "let i32 n=2147483648;", "let i32 n=-2147483649;",
        "let i64 n=1i64;", "let i64 n=1; let i32 m=n;",
        "let i32 n=1; let i64 m=n;", "let i64 n=1; var i32 m=0; m=n;",
        "var i64 n=0; let i32 m=1; n=m;", "let i64 n=1; let i32 m=2; let i64 z=n+m;",
        "let i64 n=1; let i32 m=2; let bool b=n==m;", "let i64 n=true;",
        "let i64 n=1; let bool b=!n;", "let i64 n=1; if(n) {}",
        "let Option<i64> n=.some(1);", "let Result<i64,i32> n=.ok(1);",
        "let Result<i32,i64> n=.err(1);", "let Result<i64,i64> n=.ok(1);",
        "let i64 n=1; let Option<i32> x=.some(n);",
        "let i64 n=1; let i64 m=n?;",
        # No lookahead inference: a context-free left literal defaults to i32.
        "let i64 n=1; let bool b=1==n;",
    ]
    for index, statements in enumerate(invalid):
        case(f"i64-reject-{index}", body(statements + " return 0;"), error="syntax" if "1i64" in statements else "type")
    for name, source in [
        ("arg-conversion", "fn i64 f(i64 n) {return n;} fn i32 main() {let i32 n=1; let i64 m=f(n); return 0;}"),
        ("return-conversion", "fn i64 f() {let i32 n=1; return n;} fn i32 main() {return 0;}"),
        ("entry", "fn i64 main() {return 42;}"),
    ]:
        case("i64-reject-" + name, ("module main; " + source).encode(), error="type")
    for name, expression, error in [
        ("first-left", "1/0+(9223372036854775807+1)", "zero_divisor"),
        ("first-right", "(9223372036854775807+1)+1/0", "overflow"),
    ]:
        case("i64-" + name, body(f"let i64 n={expression}; return 42;"), error=error)
    exact = body("let i64 n=6*7; return 42;")
    case("i64-fuel-exact", exact, 42, fuel=5)
    case("i64-fuel-short", exact, error="fuel", fuel=4)
    case("i64-check-no-execution", body("let i64 n=9223372036854775807+1; return 42;"), mode="check")
    case("i64-example", (root / "examples/i64.brc").read_bytes(), 42)
