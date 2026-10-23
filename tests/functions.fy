module tests::functions;
import functions as functions;
import compiler as compiler;
import ir as ir;
import vm as vm;
import verifier as verifier;

@test
fn void signature_pass() {
    let functions::Table t = switch (functions::scan(b"module main; fn i32 twice(i32 x) { return x * 2; } fn i32 main() { return twice(21); }")) {
        case .ok(value): { value } case .err(_): { assert(false); functions::empty() }
    };
    assert(t.count == 2 && t.entry == 1 && t.arities[0] == 1 && t.arities[1] == 0);
    assert(!functions::scan(b"module main; fn i32 main(i32 x) { return x; }").is_ok);
    assert(!functions::scan(b"module main; fn i32 main() { return 0; } fn i32 main() { return 1; }").is_ok);
    assert(!functions::scan(b"module main; fn i32 f(i32 x, i32 x) { return x; } fn i32 main() { return f(1, 2); }").is_ok);
    assert(!functions::scan(b"module main; fn i32 helper() { return 0; }").is_ok);
}

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } };
}
fn void value(ref u8[] source, i64 expected) {
    let ir::Program p = compiled(source);
    assert(switch (vm::run(ref p, 256)) { case .ok(n): { n == expected } case .err(_): { false } });
}
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }
@test
fn void calls_and_frames() {
    value(b"module main; fn i32 main() { return add(6, twice(18)); } fn i32 add(i32 a, i32 b) { return a+b; } fn i32 twice(i32 x) { return x*2; }", 42);
    value(b"module main; fn i32 id(i32 x) { return x; } fn i32 main() { return id(20)+id(22); }", 42);
    value(b"module main; fn i32 next(i32 x) { var i32 y=x; y=y+1; return y; } fn i32 main() { let i32 x=41; let i32 y=next(x); return x+y; }", 83);
    value(b"module main; fn i32 bad() { return 1/0; } fn i32 main() { return 42; }", 42);
    value(b"module main; fn i32 main() { return last(0,1,2,3,4,5,6,7); } fn i32 last(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,i32 h) { return h; }", 7);
    let ir::Program p = compiled(b"module main; fn i32 inc(i32 x) { return x+1; } fn i32 main() { return inc(41); }");
    assert(switch (vm::run(ref p, 6)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    assert(switch (vm::run(ref p, 7)) { case .ok(n): { n == 42 } case .err(_): { false } });
    assert(switch (vm::run(ref p, 7)) { case .ok(n): { n == 42 } case .err(_): { false } });
    let ir::Program recursion = compiled(b"module main; fn i32 main() { return main(); }");
    assert(switch (vm::run(ref recursion, 31)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    assert(switch (vm::run(ref recursion, 32)) { case .ok(_): { false } case .err(e): { e.kind == 12 } });
}
@test
fn void call_rejections_and_order() {
    rejected(b"module main; fn i32 main() { return unknown(); }");
    rejected(b"module main; fn i32 f(i32 x) { return x; } fn i32 main() { return f(); }");
    rejected(b"module main; fn i32 f(i32 x) { return x; } fn i32 main() { return f(1,2); }");
    rejected(b"module main; fn i32 f(i32 x) { x=1; return x; } fn i32 main() { return f(2); }");
    rejected(b"module main; fn i32 f(i32 x) { let i32 x=1; return x; } fn i32 main() { return f(2); }");
    rejected(b"module main; fn i32 f() { return x; } fn i32 main() { let i32 x=1; return f(); }");
    rejected(b"module main; fn i32 f() { return 1; } fn i32 main() { let i32 f=2; return f(); }");
    rejected(b"module main; fn i32 f() { return 1; } fn i32 main() { return f; }");
    let ir::Program p = compiled(b"module main; fn i32 main() { return add(1/0,2147483647+1); } fn i32 add(i32 a,i32 b) { return a+b; }");
    assert(switch (vm::run(ref p, 256)) { case .ok(_): { false } case .err(e): { e.kind == 7 } });
}
@test
fn void call_verifier_boundaries() {
    let ir::Program good = compiled(b"module main; fn i32 main() { return id(42); } fn i32 id(i32 x) { return x; }");
    var ir::Program bad = good;
    bad.code[10] = 16;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.call_arities[0]=0;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.call_args[0]=127;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.call_args[1]=1;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.call_count=2;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.starts[1]=0;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.register_starts[1]=0;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.entry=1;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.function_count=17;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.arities[1]=9;
    assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[26]=0;
    assert(!vm::run(ref bad, 256).is_ok);
}
