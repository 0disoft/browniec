"""Fixed-width expectations from Python integer operations for the native CLI."""
import random


def run_bitwise(case, body, root):
    tags = {"i32": (32, True), "i64": (64, True), "u8": (8, False),
            "u32": (32, False), "usize": (64, False)}
    rng = random.Random(20261024)
    for tag, (width, signed) in tags.items():
        mask = (1 << width) - 1
        lo, hi = (-(1 << (width - 1)), (1 << (width - 1)) - 1) if signed else (0, mask)
        values = [lo, lo + 1, -1 if signed else hi // 2, 0 if signed else hi // 2 + 1, 1, hi]

        def decoded(value):
            value &= mask
            return value - (1 << width) if signed and value >= (1 << (width - 1)) else value

        for index, a in enumerate(values):
            case(f"bit-{tag}-not-{index}", body(f"let {tag} a={a}; let {tag} n=~a; if(n=={decoded(~a)}) {{return 42;}} return 0;"), 42)
        pairs = list(zip(values, reversed(values))) + [(rng.randint(lo, hi), rng.randint(lo, hi)) for _ in range(4)]
        for index, (a, b) in enumerate(pairs):
            for name, op, expected in [("and", "&", a & b), ("xor", "^", a ^ b), ("or", "|", a | b)]:
                case(f"bit-{tag}-{name}-{index}", body(f"let {tag} a={a}; let {tag} b={b}; let {tag} n=a{op}b; if(n=={decoded(expected)}) {{return 42;}} return 0;"), 42)
    for a in [*tags, "bool"]:
        for b in [*tags, "bool"]:
            if a == b and a != "bool":
                continue
            av, bv = ("false" if a == "bool" else "0"), ("false" if b == "bool" else "0")
            for op, name in [("&", "and"), ("^", "xor"), ("|", "or")]:
                case(f"bit-reject-{a}-{b}-{name}", body(f"let {a} a={av}; let {b} b={bv}; let {a} n=a{op}b; return 0;"), error="type")
    for name, statements in [
        ("precedence", "if((1|2^3&6)==1 && (1+2&6)==2) {return 42;} return 0;"),
        ("cast-unary", "let u8 b=21; let i64 n=~b as i64; if(n==234 && (~(b as i64)) == -22) {return 42;} return 0;"),
        ("cast-boundary", "let i32 n=1; let i64 out=1|n as i64; if(out==1) {return 42;} return 0;"),
        ("contextual-literal", "let usize n=~0; if((n&9223372036854775808)==9223372036854775808) {return 42;} return 0;"),
        ("assignment-snapshot", "var u8 n=0; let u8 old=n; n=~n; if(old==0 && n==255) {return 42;} return 0;"),
        ("switch-join", "let Option<i32> n=.some(42); return switch(n) {case .some(v): {v&255} case .none: {~0}};"),
        ("short-skipped", "if(true || (0 & (1/0))==0) {return 42;} return 0;"),
        ("loop", "var u8 n=0; for(var u8 i=0;i<4;i=i+1) {n=n|i;} if(n==3) {return 42;} return 0;"),
    ]:
        case("bit-" + name, body(statements), 42)
    for name, expr in [("and-eager", "0 & (1/0)"), ("or-eager", "-1 | (1/0)"), ("xor-eager", "1 ^ (1/0)")]:
        case("bit-" + name, body("return " + expr + ";"), error="zero_divisor")
    for name, statements in [
        ("bool-not", "let bool n=~true;"),
        ("wrapper", "let Option<i32> n=.some(1); let i32 out=~n;"),
        ("wrapper-pair", "let Option<i32> n=.some(1); let i32 out=n&n;"),
    ]:
        case("bit-reject-" + name, body(statements + "return 0;"), error="type")
    for name, expr, fuel, expected in [("unary", "~0", 3, -1), ("binary", "6^7", 4, 1)]:
        case("bit-fuel-" + name, body("return " + expr + ";"), expected, fuel=fuel)
        case("bit-fuel-short-" + name, body("return " + expr + ";"), error="fuel", fuel=fuel - 1)
    case("bit-check-no-execution", body("return 0&(1/0);"), mode="check")
