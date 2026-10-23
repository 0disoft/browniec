"""Source fixtures for scalar wrappers; expected results never decode VM cells."""


def run_tagged(case, body, root):
    def returned(name, scalar):
        return f"return {name};" if scalar == "i32" else f"if({name}) {{return 1;}} return 0;"

    for index, value in enumerate([-2147483648, -17, -1, 0, 1, 42, 2147483647]):
        statements = f"let Option<i32> x=.some({value}); switch(x) {{case .some(v): {{return v;}} case .none: {{return 77;}}}}"
        case(f"option-i32-{index}", body(statements), value)
        for variant in ["ok", "err"]:
            statements = f"let Result<i32,i32> x=.{variant}({value}); switch(x) {{case .ok(v): {{return v;}} case .err(e): {{return e;}}}}"
            case(f"result-{variant}-i32-{index}", body(statements), value)
    case("option-none", body("let Option<i32> x=.none; switch(x) {case .some(v): {return v;} case .none: {return 77;}}"), 77)
    for scalar in ["i32", "bool"]:
        for error_type in ["i32", "bool"]:
            for variant, active_type in [("ok", scalar), ("err", error_type)]:
                for number, expr, expected in [(0, "0" if active_type == "i32" else "false", 0),
                                                (1, "42" if active_type == "i32" else "true", 42 if active_type == "i32" else 1)]:
                    statements = (f"let Result<{scalar},{error_type}> x=.{variant}({expr}); switch(x) {{"
                                  f"case .err(e): {{{returned('e', error_type)}}} case .ok(v): {{{returned('v', scalar)}}}}}")
                    case(f"result-matrix-{scalar}-{error_type}-{variant}-{number}", body(statements), expected)
    for expr, expected in [("true", 1), ("false", 0)]:
        case(f"option-bool-{expr}", body(f"let Option<bool> x=.some({expr}); switch(x) {{case .some(v): {{if(v) {{return 1;}} return 0;}} case .none: {{return 77;}}}}"), expected)
    for name, statements, expected in [
        ("tagged-snapshot", "var Option<i32> x=.some(42); let Option<i32> old=x; x=.none; switch(old) {case .some(v): {return v;} case .none: {return 0;}}",42),
        ("tagged-join", "var i32 out=0; var Option<i32> x=.none; if(true) {x=.some(42);} switch(x) {case .none: {out=0;} case .some(v): {out=v;}} return out;",42),
        ("tagged-reverse-order", "let Option<i32> x=.some(42); switch(x) {case .none: {return 1/0;} case .some(v): {return v;}}",42),
        ("tagged-none-skips-trap", "let Option<i32> x=.none; switch(x) {case .some(v): {return 1/0;} case .none: {return 42;}}",42),
        ("tagged-discard", "let Result<i32,bool> x=.err(true); switch(x) {case .ok(_): {return 0;} case .err(_): {return 42;}}",42),
        ("tagged-sibling-bindings", "let Result<i32,bool> x=.err(true); switch(x) {case .ok(v): {return v;} case .err(v): {if(v) {return 42;} return 0;}}",42),
        ("tagged-no-fallthrough", "var i32 out=0; var Option<i32> x=.some(42); switch(x) {case .some(v): {out=v; x=.none;} case .none: {out=1/0;}} return out;",42),
        ("tagged-for-transfers", "var i32 sum=0; for(var i32 i=0;i<3;i=i+1) {var Result<i32,bool> x=.ok(i); if(i==2) {x=.err(true);} switch(x) {case .ok(v): {sum=sum+v; continue;} case .err(_): {break;}}} return sum;",1),
        ("tagged-while-toggle", "var Option<i32> x=.some(0); var i32 sum=0; while(sum<3) {switch(x) {case .some(v): {sum=sum+v; x=.none;} case .none: {x=.some(1);}}} return sum;",3),
        ("tagged-constructor-parentheses", "let Option<i32> x=(.some(-1)); switch(x) {case .some(v): {return v;} case .none: {return 0;}}",-1),
    ]:
        case(name, body(statements), expected, fuel=10000)
    for name, source, expected in [
        ("tagged-param-context", "module main; fn Option<i32> id(Option<i32> x) {return x;} fn i32 main() {switch(id(.some(42))) {case .some(v): {return v;} case .none: {return 0;}}}",42),
        ("tagged-forward-return", "module main; fn i32 main() {switch(answer()) {case .ok(v): {return v;} case .err(_): {return 0;}}} fn Result<i32,bool> answer() {return .ok(42);}",42),
        ("tagged-frame-reuse", "module main; fn Option<i32> id(Option<i32> x) {return x;} fn i32 get(Option<i32> x) {switch(id(x)) {case .some(v): {return v;} case .none: {return 0;}}} fn i32 main() {return get(.some(20))+get(.some(22))+get(.none);}",42),
        ("tagged-eight-args", "module main; fn Result<i32,bool> f(Option<i32> a,Option<bool> b,Result<i32,i32> c,Result<i32,bool> d,Result<bool,i32> e,Result<bool,bool> f,bool g,i32 h) {return d;} fn i32 main() {switch(f(.none,.some(true),.err(-1),.ok(42),.err(0),.ok(false),true,0)) {case .ok(v): {return v;} case .err(_): {return 0;}}}",42),
    ]:
        case(name, source.encode(), expected)
    for name, statements, error in [
        ("tagged-payload-type", "let Option<i32> x=.some(true); return 0;","type"),
        ("tagged-error-type", "let Result<i32,bool> x=.err(1); return 0;","type"),
        ("tagged-wrong-constructor", "let Option<i32> x=.ok(1); return 0;","type"),
        ("tagged-result-none", "let Result<i32,i32> x=.none; return 0;","type"),
        ("tagged-nested-option", "let Option<Option<i32>> x=.none; return 0;","type"),
        ("tagged-nested-result", "let Result<i32,Option<bool>> x=.ok(1); return 0;","type"),
        ("tagged-no-promotion", "let Option<i32> x=1; return 0;","type"),
        ("tagged-mixed-assignment", "var Option<i32> x=.none; let Option<bool> y=.none; x=y; return 0;","type"),
        ("tagged-equality", "let Option<i32> x=.none; let bool b=x==x; return 0;","type"),
        ("tagged-no-context", "switch(.some(42)) {case .some(v): {return v;} case .none: {return 0;}}","type"),
        ("tagged-integer-switch", "switch(1) {case .none: {return 0;} case .some(v): {return v;}}","type"),
        ("tagged-nonexhaustive", "let Option<i32> x=.none; switch(x) {case .some(v): {return v;}}","type"),
        ("tagged-duplicate-arm", "let Option<i32> x=.none; switch(x) {case .none: {return 0;} case .none: {return 1;}}","type"),
        ("tagged-wrong-pattern", "let Option<i32> x=.none; switch(x) {case .ok(v): {return v;} case .err(e): {return e;}}","type"),
        ("tagged-binding-escape", "let Option<i32> x=.none; switch(x) {case .some(v): {} case .none: {}} return v;","type"),
        ("tagged-binding-immutable", "let Option<i32> x=.none; switch(x) {case .some(v): {v=2; return v;} case .none: {return 0;}}","type"),
        ("tagged-binding-shadow", "let i32 v=1; let Option<i32> x=.none; switch(x) {case .some(v): {return v;} case .none: {return 0;}}","type"),
        ("tagged-unreachable-after-switch", "let Option<i32> x=.none; switch(x) {case .some(v): {return v;} case .none: {return 0;}} return 1;","syntax"),
        ("tagged-missing-return", "let Option<i32> x=.none; switch(x) {case .some(v): {} case .none: {}}","syntax"),
        ("tagged-none-parens", "let Option<i32> x=.none(); return 0;","syntax"),
        ("tagged-nested-pattern", "let Option<i32> x=.none; switch(x) {case .some(.none): {return 0;} case .none: {return 1;}}","syntax"),
        ("tagged-whole-wildcard", "let Option<i32> x=.none; switch(x) {case _: {return 0;} case .some(v): {return v;}}","syntax"),
        ("tagged-for-init", "for(var Option<i32> x=.none;false;) {} return 0;","type"),
        ("tagged-for-post", "var Option<i32> x=.none; for(;false;x=.some(42)) {} return 0;","type"),
        ("tagged-unused-payload-trap", "let Option<i32> x=.some(1/0); return 42;","zero_divisor"),
        ("tagged-payload-first-error", "let Result<i32,bool> x=.ok(1/0+(2147483647+1)); return 0;","zero_divisor"),
        ("tagged-payload-overflow", "let Option<i32> x=.some(2147483647+1); return 0;","overflow"),
    ]:
        case(name, body(statements), error=error)
    some=body("let Option<i32> x=.some(42); switch(x) {case .some(v): {return v;} case .none: {return 0;}}")
    case("tagged-fuel-exact",some,42,fuel=4)
    case("tagged-fuel-short",some,error="fuel",fuel=3)
    none=body("let Option<i32> x=.none; switch(x) {case .some(v): {return 0;} case .none: {return 42;}}")
    case("tagged-none-fuel-exact",none,42,fuel=5)
    case("tagged-none-fuel-short",none,error="fuel",fuel=4)
    once=b"module main; fn Option<i32> f() {return .some(42);} fn i32 main() {switch(f()) {case .some(v): {return v;} case .none: {return 0;}}}"
    case("tagged-subject-once",once,42,fuel=6)
    case("tagged-subject-once-short",once,error="fuel",fuel=5)
    case("tagged-check-no-execution",body("let Option<i32> x=.some(1/0); switch(x) {case .some(v): {return v;} case .none: {return 0;}}"),mode="check")
    for levels in [16,17]:
        nested="return 42;"
        for _ in range(levels):
            nested="switch(x) {case .some(_): {"+nested+"} case .none: {return 0;}}"
        case(f"tagged-control-depth-{levels}",body("let Option<i32> x=.some(1);"+nested),42 if levels==16 else None,
             error=None if levels==16 else "compile_limit")
    case("tagged-example",(root/"examples/tagged.brc").read_bytes(),42)
