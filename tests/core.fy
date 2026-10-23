module tests::core;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) {
        case .ok(p): { p } case .err(_): { assert(false); ir::empty() }
    };
}
fn void result(ref u8[] source, i64 expected) {
    let ir::Program p = compiled(source);
    let i64 actual = switch (vm::run(ref p, 256)) {
        case .ok(value): { value } case .err(_): { assert(false); 0 }
    };
    assert(actual == expected);
}
fn void rejected(ref u8[] source, u8 kind) {
    assert(switch (compiler::compile(source)) {
        case .ok(_): { false } case .err(error): { error.kind == kind }
    });
}
fn void trapped(ref u8[] source, u8 kind) {
    let ir::Program p = compiled(source);
    assert(switch (vm::run(ref p, 256)) {
        case .ok(_): { false } case .err(error): { error.kind == kind }
    });
}
@test
fn void precedence_and_order() {
    result(b"module main; fn i32 main() { return 6 * 7; }", 42);
    result(b"module main; fn i32 main() { return 20 - 6 - 3; }", 11);
    result(b"module main; fn i32 main() { return 2 + 3 * 4 - 18 / 3; }", 8);
    result(b"module main; fn i32 main() { return (2 + 3) * 4; }", 20);
    result(b"module main; fn i32 main() { return -7 / 3 * 10 + -7 % 3; }", -21);
    result(b"// comment\nmodule main; fn i32 main() { // next\nreturn --42; }", 42);
}
@test
fn void type_and_syntax_rejections() {
    rejected(b"module main; fn i32 main() { return 2147483648; }", 3);
    rejected(b"module main; fn i64 main() { return 1; }", 3);
    rejected(b"module main; fn i32 main() { return true; }", 2);
    rejected(b"module main; fn i32 main() { return 1 }", 2);
    rejected(b"module main; fn i32 main() { return 1; } garbage", 2);
    rejected(b"module main; fn i32 main() { return 1 @ 2; }", 1);
    rejected(b"\xff", 1);
    rejected(b"module main; fn i32 main() { return 999999999999999999999; }", 3);
}
@test
fn void checked_arithmetic() {
    result(b"module main; fn i32 main() { return -2147483648; }", -2147483648);
    result(b"module main; fn i32 main() { return 2147483647; }", 2147483647);
    trapped(b"module main; fn i32 main() { return 2147483647 + 1; }", 6);
    trapped(b"module main; fn i32 main() { return -2147483648 - 1; }", 6);
    trapped(b"module main; fn i32 main() { return 2147483647 * 2; }", 6);
    trapped(b"module main; fn i32 main() { return --2147483648; }", 6);
    trapped(b"module main; fn i32 main() { return -2147483648 / -1; }", 6);
    trapped(b"module main; fn i32 main() { return -2147483648 % -1; }", 6);
    trapped(b"module main; fn i32 main() { return 1 / 0; }", 7);
    trapped(b"module main; fn i32 main() { return 1 % 0; }", 7);
    // Guest execution order: left division fails before right overflow.
    trapped(b"module main; fn i32 main() { return 1 / 0 + (2147483647 + 1); }", 7);
}
@test
fn void fuel_and_program_reuse() {
    let ir::Program p = compiled(b"module main; fn i32 main() { return 6 * 7; }");
    assert(p.count == 4);
    assert(switch (vm::run(ref p, 3)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    assert(switch (vm::run(ref p, 4)) { case .ok(n): { n == 42 } case .err(_): { false } });
    assert(switch (vm::run(ref p, 0)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    assert(switch (vm::run(ref p, 4)) { case .ok(n): { n == 42 } case .err(_): { false } });
}
@test
fn void verifier_rejects_corrupt_private_code() {
    var ir::Program p = compiled(b"module main; fn i32 main() { return 6 * 7; }");
    p.code[0] = 255;
    assert(!verifier::verify(ref p).is_ok);
    p.code[0] = 1; p.code[4] = 1;
    assert(!verifier::verify(ref p).is_ok);
    p.code[4] = 0; p.code[18] = 127;
    assert(!vm::run(ref p, 256).is_ok);
    p.code[18] = 0; p.code[17] = 0;
    assert(!verifier::verify(ref p).is_ok);
    p.code[17] = 2; p.constant_count = 0;
    assert(!verifier::verify(ref p).is_ok);
    p.constant_count = 2; p.count = 257;
    assert(!verifier::verify(ref p).is_ok);
    p.count = 3;
    assert(!verifier::verify(ref p).is_ok);
    p.count = 4; p.constants[0] = 2147483648;
    assert(!verifier::verify(ref p).is_ok);
}

@test
fn void local_values_and_assignments() {
    result(b"module main; fn i32 main() { let i32 x = 6; var i32 y = x; let i32 old = y; y = y * 7; return y + old; }", 48);
    result(b"module main; fn i32 main() { var i32 x = 1; x = x + 2; x = x * 3; return x; }", 9);
    result(b"module main; fn i32 main() { var i32 x = 10; var i32 y = x; x = 20; return y; }", 10);
    result(b"module main; fn i32 main() { let i32 a = -2147483648; return a; }", -2147483648);
    result(b"module main; fn i32 main() { let i32 alpha = 2; let i32 alphabet = 3; return alphabet * 10 + alpha; }", 32);
}
@test
fn void local_rejections() {
    rejected(b"module main; fn i32 main() { return missing; }", 3);
    rejected(b"module main; fn i32 main() { var i32 x = x; return x; }", 3);
    rejected(b"module main; fn i32 main() { x = 1; var i32 x = 2; return x; }", 3);
    rejected(b"module main; fn i32 main() { let i32 x = 1; x = 2; return x; }", 3);
    rejected(b"module main; fn i32 main() { var i32 x = 1; let i32 x = 2; return x; }", 3);
    rejected(b"module main; fn i32 main() { var i32 x; return x; }", 2);
    rejected(b"module main; fn i32 main() { let i64 x = 1; return x; }", 3);
    rejected(b"module main; fn i32 main() { var i32 x = 1; x = missing; return x; }", 3);
    rejected(b"module main; fn i32 main() { let i32 return = 1; return 0; }", 2);
    rejected(b"module main; fn i32 main() { let i32 x = 1; return x = 2; }", 2);
    rejected(b"module main; fn i32 main() { var i32 x = 1; x += 2; return x; }", 2);
    rejected(b"module main; fn i32 main() { var i32 x = 1; }", 2);
}
@test
fn void local_traps_fuel_and_reuse() {
    trapped(b"module main; fn i32 main() { let i32 unused = 1 / 0; return 42; }", 7);
    trapped(b"module main; fn i32 main() { var i32 x = 2147483647; x = x + 1; return 0; }", 6);
    trapped(b"module main; fn i32 main() { var i32 x = 1; x = x / 0; return x; }", 7);
    let ir::Program p = compiled(b"module main; fn i32 main() { var i32 x = 6; let i32 old = x; x = x * 7; return x + old; }");
    assert(switch (vm::run(ref p, 4)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    assert(switch (vm::run(ref p, 5)) { case .ok(n): { n == 48 } case .err(_): { false } });
    assert(switch (vm::run(ref p, 5)) { case .ok(n): { n == 48 } case .err(_): { false } });
    // The verifier still rejects a read of a register never defined by the source path.
    var ir::Program corrupt = p;
    corrupt.code[26] = 127;
    assert(!verifier::verify(ref corrupt).is_ok);
}
