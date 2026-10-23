"""Native source cases for typed switch values and their control-flow joins."""


def run_switch_expression(case, body, root):
    for index, value in enumerate([-2147483648, -17, -1, 0, 1, 42, 2147483647]):
        case(f"switch-value-i32-{index}", body(f"let Option<i32> x=.some({value}); return switch(x) {{case .some(v): {{v}} case .none: {{0}}}};"), value)
    for success_type in ["i32", "bool"]:
        for error_type in [None, "i32", "bool"]:
            tag = f"Option<{success_type}>" if error_type is None else f"Result<{success_type},{error_type}>"
            tag_id = f"{success_type}-{error_type or 'option'}"
            variants = [("some" if error_type is None else "ok", success_type), ("none" if error_type is None else "err", error_type)]
            for variant, payload_type in variants:
                payload = "42" if payload_type == "i32" else "true"
                constructor = ".none" if payload_type is None else f".{variant}({payload})"
                good = "v" if success_type == "i32" else "!v"
                bad = "77" if error_type is None else ("e" if error_type == "i32" else "!e")
                # All arms yield i32, even when the selected payload is bool.
                if success_type == "bool":
                    good = "let bool b=v; var i32 n=0; n=42; n"
                if error_type == "bool":
                    bad = "let bool b=e; 42"
                arms = f"case .some(v): {{{good}}} case .none: {{{bad}}}" if error_type is None else f"case .ok(v): {{{good}}} case .err(e): {{{bad}}}"
                case(f"switch-value-input-{tag_id}-{variant}", body(f"let {tag} x={constructor}; return switch(x) {{{arms}}};"), 77 if payload_type is None else 42)
            # Typed constructor contexts support all six wrapper output types.
            some = ".some(42)" if success_type == "i32" else ".some(true)"
            ctor = some if error_type is None else (".ok(42)" if success_type == "i32" else ".ok(true)")
            selected = "return v;" if success_type == "i32" else "if(v) {return 42;} return 0;"
            inspect = f"case .some(v): {{{selected}}} case .none: {{return 0;}}" if error_type is None else f"case .ok(v): {{{selected}}} case .err(_): {{return 0;}}"
            source = "let Option<i32> x=.some(1); let " + tag + " y=switch(x) {case .some(_): {" + ctor + "} case .none: {" + ctor + "}}; switch(y) {" + inspect + "}"
            case(f"switch-value-output-{tag_id}", body(source), 42)
    for name, statements, expected in [
        ("reverse-order", "let Option<i32> x=.some(42); return switch(x) {case .none: {1/0} case .some(v): {v}};", 42),
        ("none-skips-trap", "let Option<i32> x=.none; return switch(x) {case .some(v): {1/0} case .none: {42}};", 42),
        ("bool-result", "let Option<bool> x=.some(false); let bool yes=switch(x) {case .some(v): {!v} case .none: {false}}; if(yes) {return 42;} return 0;", 42),
        ("binary", "let Option<i32> x=.some(20); return 2*switch(x) {case .some(v): {v+1} case .none: {0}};", 42),
        ("unary", "let Option<i32> x=.some(-42); return -switch(x) {case .some(v): {v} case .none: {0}};", 42),
        ("outer-assignment", "let Option<i32> x=.some(41); var i32 n=0; n=switch(x) {case .some(v): {v+1} case .none: {0}}; return n;", 42),
        ("local-and-store", "var Option<i32> x=.some(40); var i32 n=0; let i32 out=switch(x) {case .some(v): {x=.none; var i32 local=v; local=local+2; n=local; local} case .none: {n=1/0; 0}}; return out+n-42;", 42),
        ("sibling-scope", "let Option<i32> x=.none; return switch(x) {case .some(v): {let i32 n=v; n} case .none: {let i32 n=42; n}};", 42),
        ("early-return-first", "let Option<i32> x=.some(0); return 1/0+switch(x) {case .some(v): {return 42;} case .none: {0}};", None),
        ("early-return-second", "let Option<i32> x=.none; return switch(x) {case .some(v): {v} case .none: {return 42;}}+1/0;", 42),
        ("skip-early-return", "let Option<i32> x=.none; let bool b=false && switch(x) {case .some(v): {v==1/0} case .none: {return 0;}}; return 42;", 42),
        ("nested", "let Option<i32> x=.some(20); return switch(x) {case .some(v): {switch(x) {case .some(w): {v+w+2} case .none: {0}}} case .none: {0}};", 42),
        ("loop-values", "var Option<i32> x=.some(20); var i32 n=0; for(var i32 i=0;i<2;i=i+1) {n=n+switch(x) {case .some(v): {v+1} case .none: {0}};} return n;", 42),
        ("while-condition", "let Option<bool> x=.some(true); while(switch(x) {case .some(v): {v} case .none: {false}}) {return 42;} return 0;", 42),
    ]:
        case(f"switch-value-{name}", body(statements), expected, error="zero_divisor" if expected is None else None, fuel=10000)
    for name, source in [
        ("call-arg", "module main; fn i32 id(i32 x) {return x;} fn i32 main() {let Option<i32> x=.some(42); return id(switch(x) {case .some(v): {v} case .none: {0}});}"),
        ("inferred-wrapper-subject", "module main; fn i32 main() {let Option<i32> x=.some(1); let Option<i32> y=.some(42); switch(switch(x) {case .some(_): {y} case .none: {.none}}) {case .some(v): {return v;} case .none: {return 0;}}}"),
        ("postfix", "module main; fn Option<i32> f(Option<i32> x) {let Option<i32> y=.some(42); return .some((switch(x) {case .some(_): {y} case .none: {.none}})?);} fn i32 main() {return switch(f(.some(1))) {case .some(v): {v} case .none: {0}};}"),
        ("arm-propagation", "module main; fn Option<i32> f(Option<i32> x) {return .some(switch(x) {case .some(v): {v} case .none: {let i32 n=x?; n}});} fn i32 main() {return switch(f(.none)) {case .some(v): {0} case .none: {42}};}"),
        ("context-return", "module main; fn Result<i32,bool> f(Option<i32> x) {return switch(x) {case .some(v): {.ok(v)} case .none: {return .err(false);}};} fn i32 main() {return switch(f(.some(42))) {case .ok(v): {v} case .err(_): {0}};}"),
    ]:
        case(f"switch-value-{name}", source.encode(), 42)
    invalid = [
        ("mismatch", "let Option<i32> x=.none; return switch(x) {case .some(v): {v} case .none: {true}};", "type"),
        ("nonexhaustive", "let Option<i32> x=.none; return switch(x) {case .some(v): {v}};", "type"),
        ("duplicate", "let Option<i32> x=.none; return switch(x) {case .none: {0} case .none: {1}};", "type"),
        ("both-return", "let Option<i32> x=.none; return switch(x) {case .some(v): {return v;} case .none: {return 0;}};", "type"),
        ("binding-escape", "let Option<i32> x=.none; let i32 n=switch(x) {case .some(v): {v} case .none: {0}}; return v;", "type"),
        ("local-escape", "let Option<i32> x=.none; let i32 n=switch(x) {case .some(v): {let i32 local=v; local} case .none: {0}}; return local;", "type"),
        ("immutable", "let Option<i32> x=.none; return switch(x) {case .some(v): {v=1; v} case .none: {0}};", "type"),
        ("shadow", "let i32 v=1; let Option<i32> x=.none; return switch(x) {case .some(v): {v} case .none: {0}};", "type"),
        ("subject-scalar", "return switch(1) {case .some(v): {v} case .none: {0}};", "type"),
        ("subject-context", "return switch(.none) {case .some(v): {v} case .none: {0}};", "type"),
        ("for-init", "let Option<i32> x=.none; for(var i32 n=switch(x) {case .some(v): {v} case .none: {0}};false;) {} return 0;", "type"),
        ("for-cond", "let Option<bool> x=.none; for(;switch(x) {case .some(v): {v} case .none: {false}};) {} return 0;", "type"),
        ("for-post", "let Option<i32> x=.none; var i32 n=0; for(;false;n=switch(x) {case .some(v): {v} case .none: {0}}) {} return 0;", "type"),
        ("semicolon", "let Option<i32> x=.none; return switch(x) {case .some(v): {v;} case .none: {0}};", "syntax"),
        ("empty-arm", "let Option<i32> x=.none; return switch(x) {case .some(v): {} case .none: {0}};", "syntax"),
        ("missing-yield", "let Option<i32> x=.none; return switch(x) {case .some(v): {let i32 n=v;} case .none: {0}};", "syntax"),
        ("extra-arm", "let Option<i32> x=.none; return switch(x) {case .some(v): {v} case .none: {0} case .none: {1}};", "syntax"),
    ]
    for name, statements, error in invalid:
        case(f"switch-value-reject-{name}", body(statements), error=error)
    case("switch-value-if-in-arm", body("let Option<i32> x=.none; return switch(x) {case .some(v): {if(true) {return v;} v} case .none: {0}};"), 0)
    exact = body("let Option<i32> x=.some(42); return switch(x) {case .some(v): {v} case .none: {0}};")
    case("switch-value-fuel-exact", exact, 42, fuel=7)
    case("switch-value-fuel-short", exact, error="fuel", fuel=6)
    once = b"module main; fn Option<i32> f() {return .some(42);} fn i32 main() {return switch(f()) {case .some(v): {v} case .none: {0}};}"
    case("switch-value-once-exact", once, 42, fuel=9)
    case("switch-value-once-short", once, error="fuel", fuel=8)
    case("switch-value-check", exact.replace(b".some(42)", b".some(1/0)"), mode="check")
    for depth in [16, 17]:
        nested="42"
        for _ in range(depth):
            nested="switch(x) {case .some(_): {"+nested+"} case .none: {0}}"
        case(f"switch-value-depth-{depth}", body("let Option<i32> x=.some(1); return "+nested+";"),
             42 if depth==16 else None,error=None if depth==16 else "compile_limit")
    case("switch-value-example", (root / "examples/switch-expression.brc").read_bytes(), 42)
