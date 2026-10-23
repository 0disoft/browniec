"""Black-box propagation fixtures for the native VM, with scalar expectations."""


def run_propagation(case, root):
    def observed(result_type, function_body, argument_type, argument, expected, *, name, fuel=None):
        source = (f"module main; fn {result_type} f({argument_type} x) {{{function_body}}} "
                  "fn i32 main() {switch(f(" + argument + ")) {"
                  + ("case .some(v): {return v;} case .none: {return 77;}" if result_type.startswith("Option")
                     else "case .ok(v): {return v;} case .err(e): {return e;}") + "}}")
        case(name, source.encode(), expected, fuel=fuel)

    for index, value in enumerate([-2147483648, -17, -1, 0, 1, 42, 2147483647]):
        observed("Option<i32>", "return .some(x?);", "Option<i32>", f".some({value})", value, name=f"prop-option-{index}")
        for variant in ["ok", "err"]:
            observed("Result<i32,i32>", "return .ok(x?);", "Result<i32,i32>", f".{variant}({value})", value,
                     name=f"prop-result-{variant}-{index}")
    observed("Option<i32>", "return .some(x?);", "Option<i32>", ".none", 77, name="prop-option-none")
    for payload in ["i32", "bool"]:
        for output in ["i32", "bool"]:
            for error in [None, "i32", "bool"]:
                family = "Option" if error is None else "Result"
                arg_type = f"Option<{payload}>" if error is None else f"Result<{payload},{error}>"
                out_type = f"Option<{output}>" if error is None else f"Result<{output},{error}>"
                constructor = "some" if error is None else "ok"
                if payload == output:
                    success_body = f"return .{constructor}(v);"
                elif output == "bool":
                    success_body = f"return .{constructor}(v==42);"
                else:
                    success_body = f"if(v) {{return .{constructor}(42);}} return .{constructor}(0);"
                extract = f"let {payload} v=x?; " + success_body
                for success in [True, False]:
                    ctor = (".some(42)" if payload == "i32" else ".some(true)") if error is None else (".ok(42)" if payload == "i32" else ".ok(true)")
                    if not success:
                        ctor = ".none" if error is None else (".err(-17)" if error == "i32" else ".err(false)")
                    yes = "if(v) {return 42;} return 0;" if output == "bool" else "return v;"
                    no = "return 77;" if error is None else ("return e;" if error == "i32" else "if(!e) {return 77;} return 0;")
                    arms = (f"case .some(v): {{{yes}}} case .none: {{{no}}}" if error is None else
                            f"case .ok(v): {{{yes}}} case .err(e): {{{no}}}")
                    source = f"module main; fn {out_type} f({arg_type} x) {{{extract}}} fn i32 main() {{switch(f({ctor})) {{{arms}}}}}"
                    expected = 42 if success else (-17 if error == "i32" else 77)
                    case(f"prop-matrix-{payload}-{output}-{error}-{success}", source.encode(), expected)
    sources = [
        ("unary-precedence", "fn Option<i32> f(Option<i32> x) {return .some(-x?*2+44);}", "f(.some(1))", 42),
        ("parentheses", "fn Option<i32> f(Option<i32> x) {return .some((x)?+1);}", "f(.some(41))", 42),
        ("two-successes", "fn Option<i32> f(Option<i32> x) {return .some(x?+x?);}", "f(.some(21))", 42),
        ("early-none", "fn Option<i32> f(Option<i32> x) {return .some(x?+1/0);}", "f(.none)", 77),
        ("argument-order", "fn i32 add(i32 a,i32 b) {return a+b;} fn Option<i32> f(Option<i32> x) {return .some(add(x?,1/0));}", "f(.none)", 77),
        ("assignment", "fn Option<i32> f(Option<i32> x) {var i32 n=1; n=x?; return .some(n+1);}", "f(.some(41))", 42),
        ("if-condition", "fn Option<i32> f(Option<bool> x) {if(!x?) {return .some(42);} return .some(0);}", "f(.some(false))", 42),
        ("while-success", "fn Option<i32> f(Option<bool> x) {while(x?) {return .some(42);} return .some(0);}", "f(.some(true))", 42),
        ("while-none", "fn Option<i32> f(Option<bool> x) {while(x?) {return .some(1/0);} return .some(0);}", "f(.none)", 77),
        ("for-body", "fn Option<i32> f(Option<i32> x) {var Option<i32> y=x; for(var i32 i=0;i<2;i=i+1) {let i32 n=y?; y=.none;} return .some(0);}", "f(.some(42))", 77),
        ("skip-for-post", "fn Option<i32> f(Option<i32> x) {var i32 n=0; for(;true;n=1/0) {let i32 v=x?;} return .some(0);}", "f(.none)", 77),
        ("short-and", "fn Option<i32> f(Option<bool> x) {let bool b=false && x?; return .some(42);}", "f(.none)", 42),
        ("short-or", "fn Option<i32> f(Option<bool> x) {let bool b=true || x?; return .some(42);}", "f(.none)", 42),
        ("taken-and", "fn Option<i32> f(Option<bool> x) {let bool b=true && x?; return .some(42);}", "f(.none)", 77),
        ("untaken-branch", "fn Option<i32> f(Option<i32> x) {if(false) {let i32 n=x?;} return .some(42);}", "f(.none)", 42),
        ("snapshot", "fn Option<i32> f(Option<i32> x) {var Option<i32> y=x; let Option<i32> old=y; y=.none; return .some(old?);}", "f(.some(42))", 42),
        ("recursive-frames", "fn Option<i32> f(i32 n) {if(n==0) {return .some(0);} return .some(f(n-1)?+1);}", "f(10)", 10),
        ("recursive-none", "fn Option<i32> f(i32 n) {if(n==0) {return .none;} return .some(f(n-1)?+1/0);}", "f(10)", 77),
    ]
    for name, declaration, call, expected in sources:
        source = f"module main; {declaration} fn i32 main() {{switch({call}) {{case .some(v): {{return v;}} case .none: {{return 77;}}}}}}"
        case(f"prop-{name}", source.encode(), expected, fuel=10000)
    invalid = [
        ("entry", "fn i32 main() {let Option<i32> x=.some(42); return x?;}"),
        ("option-from-result", "fn Option<i32> f(Result<i32,i32> x) {return .some(x?);}"),
        ("result-from-option", "fn Result<i32,i32> f(Option<i32> x) {return .ok(x?);}"),
        ("wrong-error", "fn Result<i32,bool> f(Result<i32,i32> x) {return .ok(x?);}"),
        ("scalar-operand", "fn Option<i32> f() {return .some(1?);}"),
        ("bool-operand", "fn Option<bool> f() {return .some(true?);}"),
        ("double", "fn Option<i32> f(Option<i32> x) {return .some(x??);}"),
        ("raw-return", "fn Option<i32> f(Option<i32> x) {return x?;}"),
        ("no-constructor-context", "fn Option<i32> f() {return .some(.some(42)?);}"),
        ("for-init", "fn Option<i32> f(Option<i32> x) {for(var i32 n=x?;false;) {} return .none;}"),
        ("for-condition", "fn Option<i32> f(Option<bool> x) {for(;x?;) {} return .none;}"),
        ("for-post", "fn Option<i32> f(Option<i32> x) {var i32 n=0; for(;false;n=x?) {} return .none;}"),
    ]
    for name, declarations in invalid:
        source = "module main; " + declarations + ("" if name == "entry" else " fn i32 main() {return 0;}")
        case(f"prop-reject-{name}", source.encode(), error="type")
    exact = b"module main; fn Option<i32> f(Option<i32> x) {return .some(x?);} fn i32 main() {switch(f(.some(42))) {case .some(v): {return v;} case .none: {return 0;}}}"
    case("prop-fuel-exact", exact, 42, fuel=10)
    case("prop-fuel-short", exact, error="fuel", fuel=9)
    # A one-call operand must be evaluated exactly once.
    once = b"module main; fn Option<i32> get() {return .some(42);} fn Option<i32> f() {return .some(get()?);} fn i32 main() {switch(f()) {case .some(v): {return v;} case .none: {return 0;}}}"
    case("prop-once-exact", once, 42, fuel=11)
    case("prop-once-short", once, error="fuel", fuel=10)
    none = exact.replace(b"f(.some(42))", b"f(.none)").replace(b"case .none: {return 0;}", b"case .none: {return 77;}")
    case("prop-none-fuel-exact", none, 77, fuel=11)
    case("prop-none-fuel-short", none, error="fuel", fuel=10)
    prior = b"module main; fn Option<i32> f(Option<i32> x) {return .some(1/0+x?);} fn i32 main() {switch(f(.none)) {case .some(v): {return v;} case .none: {return 77;}}}"
    case("prop-prior-guest-trap", prior, error="zero_divisor")
    after = prior.replace(b"1/0+x?", b"x?+1/0").replace(b"f(.none)", b"f(.some(42))")
    case("prop-success-later-trap", after, error="zero_divisor")
    truth = b"module main; fn Result<i32,bool> f(Result<bool,bool> x) {if(x?) {return .ok(0);} return .ok(1);} fn i32 main() {switch(f(.err(true))) {case .ok(v): {return 0;} case .err(e): {if(e) {return 42;} return 1;}}}"
    case("prop-error-bool-true", truth, 42)
    case("prop-check-no-execution", exact.replace(b".some(42)", b".some(1/0)"), mode="check")
    case("prop-example", (root / "examples/propagation.brc").read_bytes(), 42)
