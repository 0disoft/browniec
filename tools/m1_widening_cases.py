"""Domain-based widening expectations for the actual native Brownie CLI."""


def run_widening(case, body, root):
    domains = {"i32": (-(1 << 31), (1 << 31) - 1), "i64": (-(1 << 63), (1 << 63) - 1),
               "u8": (0, 255), "u32": (0, (1 << 32) - 1), "usize": (0, (1 << 64) - 1), "bool": None}
    for source, source_range in domains.items():
        for target, target_range in domains.items():
            allowed = (source != target and source_range is not None and target_range is not None
                       and target_range[0] <= source_range[0] and target_range[1] >= source_range[1])
            if allowed:
                lo, hi = source_range
                for index, n in enumerate(sorted({lo, lo + 1, 0, 1, hi - 1, hi})):
                    case(f"widen-{source}-{target}-{index}", body(f"let {source} n={n}; let {target} out=n as {target}; if(out=={n}) {{return 42;}} return 0;"), 42)
            else:
                n = "false" if source == "bool" else "0"
                case(f"widen-reject-{source}-{target}", body(f"let {source} n={n}; let {target} out=n as {target}; return 0;"), error="type")
    for name, statements, expected in [
        ("literal-context", "let i64 n=1 as i64; if(n==1) {return 42;} return 0;", 42),
        ("negative-literal", "let i64 n=-2147483648 as i64; if(n == -2147483648) {return 42;} return 0;", 42),
        ("parenthesized-literal", "let i64 n=(((1))) as i64; if(n==1) {return 42;} return 0;", 42),
        ("typed-literal-unchanged", "let usize n=18446744073709551615; let i64 m=9223372036854775807; if(n>0 && m>0) {return 42;} return 0;", 42),
        ("unsigned-chain", "let u8 n=42; let usize out=n as u32 as usize; if(out==42) {return 42;} return 0;", 42),
        ("signed-chain", "let u8 n=42; let i64 out=n as i32 as i64; if(out==42) {return 42;} return 0;", 42),
        ("unary-before-cast", "let i32 n=21; let i64 out=-n as i64; if(out == -21) {return 42;} return 0;", 42),
        ("cast-before-unary", "let i32 n=-2147483648; let i64 out=-(n as i64); if(out==2147483648) {return 42;} return 0;", 42),
        ("cast-before-binary", "let u8 n=255; let i64 out=n as i64*2+1; if(out==511) {return 42;} return 0;", 42),
        ("binary-before-cast", "let u8 n=21; return (n+n) as i32;", 42),
        ("rhs-outer-context", "let i32 n=41; let i64 out=1+n as i64; if(out==42) {return 42;} return 0;", 42),
        ("source-snapshot", "var u8 n=42; let i32 old=n as i32; n=0; return old;", 42),
        ("assignment", "let u8 n=42; var i64 out=0; out=n as i64; if(out==42) {return 42;} return 0;", 42),
        ("for-header", "let u8 one=1; var i64 n=0; for(var i64 i=one as i64;i<7;i=i+(one as i64)) {n=n+7;} if(n==42) {return 42;} return 0;", 42),
        ("switch-after", "let Option<i32> x=.some(42); let i64 n=switch(x) {case .some(v): {v} case .none: {0}} as i64; if(n==42) {return 42;} return 0;", 42),
        ("switch-arm", "let u8 n=42; let Option<bool> x=.some(true); let i64 out=switch(x) {case .some(_): {n as i64} case .none: {0}}; if(out==42) {return 42;} return 0;", 42),
        ("constructor-payload", "let u8 n=42; let Option<i32> x=.some(n as i32); return switch(x) {case .some(v): {v} case .none: {0}};", 42),
        ("short-circuit", "let u8 n=255; if(true || ((n+1) as i32)==0) {return 42;} return 0;", 42),
        ("target-type-no-shadow", "let u8 n=42; let i64 out=n as i64; return n as i32;", 42),
    ]:
        case("widen-" + name, body(statements), expected, fuel=1000)
    for name, source in [
        ("argument", "fn i64 f(i64 n) {return n+1;} fn i32 main() {let u8 n=41; if(f(n as i64)==42) {return 42;} return 0;}"),
        ("return", "fn i64 f(u8 n) {return n as i64;} fn i32 main() {if(f(42)==42) {return 42;} return 0;}"),
        ("frame-copy", "fn i64 f(u32 n,i32 count) {if(count==0) {return n as i64;} return f(n+1,count-1);} fn i32 main() {if(f(4294967288,7)==4294967295) {return 42;} return 0;}"),
        ("propagation-success", "fn Option<i32> f(Option<i32> x) {let i64 n=x? as i64; if(n==42) {return .some(42);} return .none;} fn i32 main() {return switch(f(.some(42))) {case .some(v): {v} case .none: {0}};}"),
        ("propagation-failure", "fn Option<i32> f(Option<i32> x) {let i64 n=x? as i64; let i64 bad=1/0; return .some(0);} fn i32 main() {return switch(f(.none)) {case .some(v): {v} case .none: {42}};}"),
    ]:
        case("widen-" + name, ("module main; " + source).encode(), 42)
    for name, statements in [
        ("literal-too-wide", "let i64 n=2147483648 as i64;"),
        ("literal-parenthesized", "let i64 n=(2147483648) as i64;"),
        ("literal-no-narrowing", "let u8 n=1 as u8;"),
        ("literal-no-unsigned", "let usize n=1 as usize;"),
        ("literal-no-identity", "let i32 n=1 as i32;"),
        ("chain-invalid", "let u8 n=1; let i32 out=n as usize as i32;"),
        ("chain-identity", "let u8 n=1; let i64 out=n as i64 as i64;"),
        ("negative-unsigned", "let u8 n=1; let i64 out=-n as i64;"),
        ("wrapper-source", "let Option<i32> x=.some(1); let i64 out=x as i64;"),
        ("wrapper-target", "let u8 n=1; let Option<i32> x=n as Option<i32>;"),
        ("implicit-still-rejected", "let u8 n=1; let i32 out=n;"),
        ("for-call-still-rejected", "let u8 n=1; for(var i64 x=n as i64;false;x=f() as i64) {}"),
    ]:
        prefix = b"module main; fn u8 f() {return 1;} fn i32 main() {" if "for-call" in name else b"module main; fn i32 main() {"
        case("widen-reject-" + name, prefix + (statements + "return 0;}").encode(), error="type")
    for index, expression in enumerate(["1 as", "1 as 42", "1 as i64 as", "1 as i64 extra"]):
        case(f"widen-syntax-{index}", body(f"let i64 n={expression}; return 0;"), error="syntax")
    for name, statements, error in [
        ("narrow-source-overflow", "let u8 n=255; return (n+1) as i32;", "overflow"),
        ("neg-before-overflow", "let i32 n=-2147483648; let i64 out=-n as i64; return 42;", "overflow"),
        ("sum-before-overflow", "let i64 n=(2147483647+1) as i64; return 42;", "overflow"),
        ("zero-before", "let i64 n=(1/0) as i64; return 42;", "zero_divisor"),
    ]:
        case("widen-" + name, body(statements), error=error)
    for name, statements, fuel in [
        ("single", "let u8 n=42; return n as i32;", 3),
        ("chain", "let u8 n=42; let i64 out=n as i32 as i64; return 42;", 5),
    ]:
        exact = body(statements)
        case("widen-fuel-" + name, exact, 42, fuel=fuel)
        case("widen-fuel-short-" + name, exact, error="fuel", fuel=fuel - 1)
    case("widen-check-no-execution", body("let i64 n=(1/0) as i64; return 42;"), mode="check")
    for count in [64, 65]:
        source = body("let u8 n=1; return " + "+".join(["(n as i32)"] * count) + ";")
        case(f"widen-registers-{count}", source, 64 if count == 64 else None,
             error=None if count == 64 else "compile_limit", fuel=1000)
    for depth in [32, 33]:
        source = body("let u8 n=42; return " + "(" * depth + "n as i32" + ")" * depth + ";")
        case(f"widen-depth-{depth}", source, 42 if depth == 32 else None,
             error=None if depth == 32 else "compile_limit")
    case("widen-example", (root / "examples/widening.brc").read_bytes(), 42)
