"""Native CLI cases for statement-bearing switch-expression arms."""


def run_arm_statements(case, body, root):
    for tag in ["i32", "i64", "u8", "u32", "usize"]:
        for selected in [".some(40)", ".none"]:
            for condition in ["true", "false"]:
                expected = 42 if selected == ".some(40)" and condition == "true" else 41 if selected == ".some(40)" else 0
                source = body(f"let Option<i32> x={selected}; let {tag} n=switch(x) {{case .some(v): {{var {tag} n=40; if({condition}) {{n=n+2;}} else {{n=n+1;}} n}} case .none: {{0}}}}; if(n=={expected}) {{return 42;}} return 0;")
                case(f"arm-{tag}-{selected[1:5]}-{condition}", source, 42)
    for reverse in [False, True]:
        for selected in [".some(true)", ".none"]:
            arms = ["case .some(v): {var bool out=false; if(v) {out=true;} out}", "case .none: {false}"]
            if reverse:
                arms.reverse()
            expected = "true" if selected == ".some(true)" else "false"
            case(f"arm-bool-{reverse}-{selected[1:5]}", body(f"let Option<bool> x={selected}; let bool n=switch(x) {{{' '.join(arms)}}}; if(n=={expected}) {{return 42;}} return 0;"), 42)
    good = [
        ("nested-block", "let Option<i32> x=.some(40); return switch(x) {case .some(v): {var i32 n=v; {let i32 extra=2; n=n+extra;} n} case .none: {0}};", 42),
        ("else-if", "let Option<i32> x=.some(2); return switch(x) {case .some(v): {var i32 n=0; if(v==0) {n=1;} else if(v==2) {n=42;} else {n=3;} n} case .none: {0}};", 42),
        ("partial-return", "let Option<i32> x=.some(42); return 1+switch(x) {case .some(v): {if(v>0) {return v;} v} case .none: {0}};", 42),
        ("all-branch-return", "let Option<i32> x=.some(42); return 1+switch(x) {case .some(v): {if(v>0) {return v;} else {return 0;}} case .none: {0}};", 42),
        ("terminal-block", "let Option<i32> x=.some(42); return switch(x) {case .some(v): {{return v;}} case .none: {0}};", 42),
        ("subject-snapshot", "var Option<i32> x=.some(42); return switch(x) {case .some(v): {if(true) {x=.none;} v} case .none: {0}};", 42),
        ("nested-value", "let Option<i32> x=.some(42); return switch(x) {case .some(v): {if(false) {return 0;} switch(x) {case .some(w): {w} case .none: {v}}} case .none: {0}};", 42),
        ("statement-switch", "let Option<i32> x=.some(42); return switch(x) {case .some(v): {var i32 n=0; {switch(x) {case .some(w): {n=w;} case .none: {return 0;}}} n} case .none: {0}};", 42),
        ("while-break", "let Option<i32> x=.some(42); return switch(x) {case .some(v): {var i32 n=0; while(true) {n=v; break;} n} case .none: {0}};", 42),
        ("for-continue", "let Option<i32> x=.some(7); return switch(x) {case .some(v): {var i32 n=0; for(var i32 i=0;i<7;i=i+1) {if(i==3) {continue;} n=n+v;} n} case .none: {0}};", 42),
        ("zero-trip", "let Option<i32> x=.some(42); return switch(x) {case .some(v): {while(false) {return 0;} v} case .none: {0}};", 42),
        ("iteration-locals", "let Option<i32> x=.some(21); return switch(x) {case .some(v): {var i32 n=0; for(var i32 i=0;i<2;i=i+1) {var i32 local=v; n=n+local; local=0;} n} case .none: {0}};", 42),
        ("nested-loop-owner", "let Option<i32> x=.some(1); return switch(x) {case .some(_): {var i32 n=0; for(var i32 i=0;i<2;i=i+1) {while(true) {n=n+21; break;}} n} case .none: {0}};", 42),
        ("outer-for-break", "let Option<i32> x=.some(1); for(var i32 i=0;true;i=i/0) {let i32 n=switch(x) {case .some(_): {break;} case .none: {0}}; return n/0;} return 42;", 42),
        ("outer-for-continue", "let Option<i32> x=.some(1); var i32 post=0; var i32 n=0; for(;post<3;post=post+1) {let i32 v=switch(x) {case .some(_): {if(post<2) {continue;} 42} case .none: {0}}; n=n+v;} return n;", 42),
        ("outer-while-continue", "let Option<i32> x=.some(1); var i32 n=0; while(n<3) {n=n+1; let i32 v=switch(x) {case .some(_): {continue;} case .none: {1/0}}; return v/0;} return n+39;", 42),
        ("condition-break", "let Option<bool> x=.some(true); while(switch(x) {case .some(_): {break;} case .none: {true}}) {return 0;} return 42;", 42),
        ("condition-continue", "let Option<bool> x=.some(true); var i32 n=0; while(switch(x) {case .some(_): {n=n+1; if(n<3) {continue;} false} case .none: {true}}) {return 0;} return n+39;", 42),
        ("inner-condition-owner", "let Option<bool> x=.some(true); var i32 n=0; while(n<2) {while(switch(x) {case .some(_): {break;} case .none: {true}}) {return 0;} n=n+1;} return n+40;", 42),
        ("short-circuit", "let Option<bool> x=.some(true); let bool n=false && switch(x) {case .some(v): {if(v) {return 0;} true} case .none: {true}}; return 42;", 42),
        ("wrapper-context", "let Option<i32> x=.some(42); let Result<i32,bool> n=switch(x) {case .some(v): {if(v==0) {return 0;} .ok(v)} case .none: {.err(false)}}; return switch(n) {case .ok(v): {v} case .err(_): {0}};", 42),
        ("sibling-scope", "let Option<i32> x=.some(1); return switch(x) {case .some(_): {{let i32 local=0;} let i32 local=42; local} case .none: {let i32 local=0; local}};", 42),
    ]
    for name, statements, expected in good:
        case("arm-" + name, body(statements), expected, fuel=10000)
    functions = [
        ("calls", "fn i64 f(i64 v) {let Option<i32> x=.some(1); return switch(x) {case .some(_): {var i64 n=v; while(n<42) {n=n+1;} n} case .none: {0}};} fn i32 main() {if(f(40)==42) {return 42;} return 0;}"),
        ("return-before-arguments", "fn i32 f(i32 a,i32 b) {return a+b;} fn i32 main() {let Option<i32> x=.some(42); return f(switch(x) {case .some(v): {if(true) {return v;} 0} case .none: {0}},1/0);}"),
        ("propagation", "fn Option<i32> f(Option<i32> x) {let Option<i32> y=.some(0); let i32 n=switch(y) {case .some(_): {if(true) {let i32 v=x?;} 0} case .none: {0}}; return .some(n);} fn i32 main() {return switch(f(.none)) {case .some(_): {0} case .none: {42}};}"),
    ]
    for name, source in functions:
        case("arm-" + name, ("module main; " + source).encode(), 42)
    prefix = "let Option<i32> x=.some(42); return switch(x) {case .some(v): {"
    suffix = "} case .none: {0}};"
    for name, arm, error in [
        ("missing-value", "if(true) {return v;}", "syntax"),
        ("unreachable", "if(true) {return v;} else {return 0;} 42", "syntax"),
        ("loop-only", "while(true) {return v;}", "syntax"),
        ("block-local-escape", "{let i32 n=42;} n", "type"),
        ("loop-local-escape", "for(var i32 n=0;false;) {} n", "type"),
        ("shadow", "{let i32 v=42;} v", "type"),
        ("integer-condition", "if(1) {return v;} v", "type"),
        ("break-outside", "break;", "syntax"),
        ("continue-outside", "continue;", "syntax"),
        ("bare-statement-switch", "switch(x) {case .some(_): {return v;} case .none: {return 0;}}", "type"),
    ]:
        case("arm-reject-" + name, body(prefix + arm + suffix), error=error)
    case("arm-reject-no-value-arm", body("let Option<i32> x=.some(42); return switch(x) {case .some(v): {if(true) {return v;} else {return 0;}} case .none: {return 0;}};"), error="type")
    for kind, depth, limit in [("blocks", 30, 30), ("blocks", 31, 30), ("return-expression", 30, 30), ("return-expression", 31, 30)]:
        arm = "{" * depth + "}" * depth + "v" if kind == "blocks" else "if(true) {return " + "(" * depth + "v" + ")" * depth + ";} v"
        case(f"arm-depth-{kind}-{depth}", body(prefix + arm + suffix), 42 if depth == limit else None, error=None if depth == limit else "compile_limit")
    for depth in [10, 11]:
        nested = "42"
        for i in range(depth):
            nested = f"switch(x) {{case .some(_): {{if(true) {{let i32 n{i}={nested};}} 42}} case .none: {{0}}}}"
        case(f"arm-depth-mixed-{depth}", body("let Option<i32> x=.some(1); return " + nested + ";"), 42 if depth == 10 else None, error=None if depth == 10 else "compile_limit", fuel=10000)
    # Exercise the native frontend stack in both CLI entry paths. These budgets
    # cross value-arm / statement boundaries without being reset by the helper.
    for shape in ["mixed", "block", "return", "while", "for"]:
        for depth in [10, 11, 32]:
            nested = "42"
            for i in range(depth):
                inner = {"mixed": f"if(true) {{let i32 n{i}={nested};}} 42",
                         "block": f"{{let i32 n{i}={nested};}} 42",
                         "return": f"if(true) {{return {nested};}} 42",
                         "while": f"while(false) {{let i32 n{i}={nested};}} 42",
                         "for": f"for(;false;) {{let i32 n{i}={nested};}} 42"}[shape]
                nested = f"switch(x) {{case .some(_): {{{inner}}} case .none: {{0}}}}"
            source = body("let Option<i32> x=.some(1); return " + nested + ";")
            assert len(source) <= 4096, (shape, depth)
            for mode in ["check", "run"]:
                case(f"arm-stack-{shape}-{depth}-{mode}", source,
                     42 if depth == 10 and mode == "run" else None,
                     error=None if depth == 10 else "compile_limit", mode=mode,
                     fuel=10000 if mode == "run" else None)
    for depth in [32, 33, 64]:
        source = ("module main; fn i32 id(i32 n) {return n;} fn i32 main() {return "
                  + "id(" * depth + "42" + ")" * depth + ";}").encode()
        for mode in ["check", "run"]:
            case(f"arm-stack-calls-{depth}-{mode}", source,
                 42 if depth == 32 and mode == "run" else None,
                 error=None if depth == 32 else "compile_limit", mode=mode,
                 fuel=10000 if mode == "run" else None)
    # Structural and expression budgets are independent, both remain available.
    source = body("{" * 32 + "return " + "(" * 32 + "42" + ")" * 32 + ";" + "}" * 32)
    for mode in ["check", "run"]:
        case(f"arm-stack-combined-budgets-{mode}", source, 42 if mode == "run" else None, mode=mode)
    exact = body(prefix + "if(false) {return 0;} v" + suffix)
    case("arm-fuel-exact", exact, 42, fuel=9)
    case("arm-fuel-short", exact, error="fuel", fuel=8)
    forever = body(prefix + "while(true) {} v" + suffix)
    case("arm-infinite-fuel", forever, error="fuel", fuel=100)
    case("arm-check-no-execution", forever, mode="check")
    case("arm-example", (root / "examples/switch-arm-statements.brc").read_bytes(), 42)
