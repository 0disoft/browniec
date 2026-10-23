"""Checked shifts compared with unbounded Python integer arithmetic."""
import random


def run_shifts(case, body, root):
    tags = {"i32": (32, True), "i64": (64, True), "u8": (8, False),
            "u32": (32, False), "usize": (64, False)}
    rng = random.Random(20261025)
    for tag, (width, signed) in tags.items():
        lo, hi = (-(1 << (width - 1)), (1 << (width - 1)) - 1) if signed else (0, (1 << width) - 1)
        # Width guards, sign extension, loss of high bits, and exact negative MIN.
        pairs = [(a, k) for a in dict.fromkeys([lo, hi, 0, 1, -1 if signed else hi // 2 + 1])
                 for k in [0, 1, width - 1, width]]
        pairs += [(1, width + 1), (0, hi)]
        if signed:
            pairs += [(0, -1), (hi, lo), (-7, 1), (-2, width - 1)]
        pairs += [(rng.randint(lo, hi), rng.randrange(width)) for _ in range(4)]
        for index, (a, k) in enumerate(pairs):
            for op, name in [("<<", "left"), (">>", "right")]:
                valid = 0 <= k < width
                expected = ((a << k) if op == "<<" else (a >> k)) if valid else None
                valid = valid and lo <= expected <= hi
                source = body(f"let {tag} a={a}; let {tag} k={k}; let {tag} n=a{op}k; "
                              + (f"if(n=={expected}) {{return 42;}} " if valid else "") + "return 0;")
                case(f"shift-{tag}-{name}-{index}", source, 42 if valid else None, error=None if valid else "overflow")
    for a in [*tags, "bool"]:
        for b in [*tags, "bool"]:
            if a == b and a != "bool":
                continue
            av, bv = ("false" if a == "bool" else "0"), ("false" if b == "bool" else "0")
            for op, name in [("<<", "left"), (">>", "right")]:
                case(f"shift-reject-{a}-{b}-{name}", body(f"let {a} a={av}; let {b} b={bv}; let {a} n=a{op}b; return 0;"), error="type")
    for name, statements in [
        ("precedence", "if((1<<2+1)==8 && (16>>1>>1)==4 && (1|2<<3)==17 && (8>>1+1)==2) {return 42;} return 0;"),
        ("cast-boundary", "let u8 n=21; let i64 out=1<<n as i64; if(out==2097152) {return n as i32<<1;} return 0;"),
        ("cast-before-shift", "let u8 n=255; let i64 out=n as i64<<32; if(out==1095216660480) {return 42;} return 0;"),
        ("unsigned-logical", "let usize n=18446744073709551615; let usize out=n>>63; if(out==1) {return 42;} return 0;"),
        ("short-skipped", "if(true || (1<<32)==0) {return 42;} return 0;"),
        ("for-header", "var i32 sum=0; for(var u8 n=1;n<32;n=n<<1) {sum=sum+1;} return sum+37;"),
        ("switch", "let Option<i32> n=.some(21); return switch(n) {case .some(v): {v<<1} case .none: {0}};"),
    ]:
        case("shift-" + name, body(statements), 42)
    for name, expr, error in [
        ("left-first", "(1/0)<<32", "zero_divisor"),
        ("right-before-check", "0<<(1/0)", "zero_divisor"),
        ("nested-first", "(1<<31)>>(1/0)", "overflow"),
        ("first-count", "(0>>-1)+(1/0)", "overflow"),
    ]:
        case("shift-" + name, body("return " + expr + ";"), error=error)
    case("shift-wrapper", body("let Option<i32> n=.some(1); return n<<1;"), error="type")
    for index, expr in enumerate(["1<<", "1>>", "1<<<2", "1>>>2"]):
        case(f"shift-syntax-{index}", body("return " + expr + ";"), error="syntax")
    exact = body("return 21<<1;")
    case("shift-fuel", exact, 42, fuel=4)
    case("shift-fuel-short", exact, error="fuel", fuel=3)
    case("shift-check-no-execution", body("return 1<<32;"), mode="check")
    case("shift-example", (root / "examples/bitwise.brc").read_bytes(), 42)
