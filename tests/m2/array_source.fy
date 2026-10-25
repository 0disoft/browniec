module tests::m2::array_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } };
}
fn void result(ref u8[] source, i64 expected) {
    let ir::Program p = compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run(ref p, 1000000)) { case .ok(n): { n == expected } case .err(_): { false } });
}
fn void rejected(ref u8[] source, u8 kind) {
    assert(switch (compiler::compile(source)) { case .ok(_): { false } case .err(e): { e.kind == kind } });
}
@test
fn void six_scalar_types_and_literal_limits() {
    result(b"module main; fn i32 main() { let i32[2] a = [21; 2]; return a[0] + a[1]; }", 42);
    result(b"module main; fn i32 main() { let bool[4096] a = [true; 4096]; if (a[4095]) { return 42; } return 0; }", 42);
    result(b"module main; fn i32 main() { let i64[1] a = [-9223372036854775808; 1]; if (a[0] == -9223372036854775808) { return 42; } return 0; }", 42);
    result(b"module main; fn i32 main() { let u8[1] a = [255; 1]; return a[0] as i32; }", 255);
    result(b"module main; fn i32 main() { let u32[1] a = [4294967295; 1]; if (a[0] == 4294967295) { return 42; } return 0; }", 42);
    result(b"module main; fn i32 main() { let usize[1] a = [18446744073709551615; 1]; if (a[0] == 18446744073709551615) { return 42; } return 0; }", 42);
}
@test
fn void repeated_fill_and_index_evaluate_once_with_scalar_calls() {
    result(b"module main; fn i32 fill() { return 21; } fn usize ix() { return 1; } fn i32 main() { let i32[2] a = [fill(); 2]; return a[ix()] * 2; }", 42);
    result(b"module main; fn i32 main() { let i32[2] a = [21; 2]; let usize[1] ix = [1; 1]; return a[ix[0]] * 2; }", 42);
    result(b"module main; fn i32 main() { let i32[2] a = [21; 2]; let usize i = 1; if ((a[i] as i64 == 21) && true) { return 42; } return 0; }", 42);
}
@test
fn void every_return_drops_visible_arrays_in_reverse_order() {
    result(b"module main; fn i32 main() { let i32[2] a = [21; 2]; let bool[1] b = [true; 1]; if (b[0]) { return a[0] + a[1]; } return 0; }", 42);
    result(b"module main; fn i32 main() { let i32[1] a = [42; 1]; let Option<i32> x = .some(1); return switch(x) { case .some(n): { if (n == 1) { return a[0]; } 0 } case .none: { 0 } }; }", 42);
    result(b"module main; fn i32 main() { let i32[1] a = [42; 1]; let Option<i32> seed = .none; let i32[1] b = [switch (seed) { case .some(n): { n } case .none: { return a[0]; } }; 1]; return b[0]; }", 42);
}
@test
fn void array_reads_preserve_loop_lifetimes_and_cast_binding() {
    result(b"module main; fn i32 main() { let i32[2] a = [21; 2]; var i32 n = 0; for (var usize i = 0; i < 2; i = i + 1) { n = n + a[i]; } return n; }", 42);
    result(b"module main; fn i32 main() { let i32[1] a = [42; 1]; var i32 n = 0; while (true) { n = a[0]; break; } return n; }", 42);
    result(b"module main; fn i32 main() { let u8[1] a = [42; 1]; let u8 i = 0; return a[i as usize] as i32; }", 42);
}
@test
fn void source_array_types_scope_and_unimplemented_forms_are_rejected() {
    rejected(b"module main; fn i32 main() { let i32[0] a = [0; 0]; return 0; }", 3);
    rejected(b"module main; fn i32 main() { let i32[4097] a = [0; 4097]; return 0; }", 3);
    rejected(b"module main; fn i32 main() { let i32[2] a = [1; 1]; return 0; }", 3);
    rejected(b"module main; fn i32 main() { let i32[1] a = [true; 1]; return 0; }", 3);
    rejected(b"module main; fn i32 main() { let i32[1] a = [1; 1]; let i32 i = 0; return a[i]; }", 3);
    rejected(b"module main; fn i32 f() { let i32[1] a = [1; 1]; return a; } fn i32 main() { return f(); }", 3);
    rejected(b"module main; fn i32 main() { { let i32[1] a = [1; 1]; } return a[0]; }", 3);
    result(b"module main; fn i32 main() { var i32[1] a = [1; 1]; return a[0]; }", 1);
    rejected(b"module main; fn i32 main() { let i32[1] a = [1; 1]; return a; }", 3);
    rejected(b"module main; fn i32 main() { let i32[1] a = [1; 1]; return main(); }", 3);
}
@test
fn void bounds_quota_and_exact_fuel_are_guest_outcomes() {
    let ir::Program p = compiled(b"module main; fn i32 main() { let i32[2] a = [42; 2]; return a[0]; }");
    assert(switch (vm::run_with_array_limit(ref p, 170, 8)) { case .ok(n): { n == 42 } case .err(_): { false } });
    assert(switch (vm::run_with_array_limit(ref p, 169, 8)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    let ir::Program bounds = compiled(b"module main; fn i32 main() { let i32[1] a = [42; 1]; return a[18446744073709551615]; }");
    assert(switch (vm::run(ref bounds, 100000)) { case .ok(_): { false } case .err(e): { e.kind == 14 } });
    let ir::Program quota = compiled(b"module main; fn i32 main() { let usize[4096] a = [1; 4096]; let usize[4096] b = [1; 4096]; let bool[1] c = [true; 1]; return 0; }");
    assert(switch (vm::run(ref quota, 1000000)) { case .ok(_): { false } case .err(e): { e.kind == 13 } });
}
