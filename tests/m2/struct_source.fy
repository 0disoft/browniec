module tests::m2::struct_source;
import struct_source as source;
import struct_layout as layouts;
import compiler as compiler;
import ir as ir;
import vm as vm;
import verifier as verifier;

fn void rejected(ref u8[] text, u8 kind) {
    assert(switch (source::scan(text)) {
        case .ok(_): { false } case .err(e): { e.kind == kind && e.offset <= text.len }
    });
}
fn ir::Program compiled(ref u8[] text) {
    return switch (compiler::compile(text)) {
        case .ok(p): { p } case .err(_): { assert(false); ir::empty() }
    };
}
@test
fn void scalar_tags_forward_names_and_interleaved_functions() {
    let ref u8[] text = b"module main; struct Outer { Inner child; bool flag; } fn i32 main() { return 42; } struct Inner { i32 a; bool b; i64 c; u8 d; u32 e; usize f; }";
    let source::Table t = switch (source::scan(text)) {
        case .ok(t): { t } case .err(_): { assert(false); return; }
    };
    assert(t.layouts.count == 2 && t.layouts.fields[0] == 2 && t.layouts.fields[1] == 6);
    assert(t.layouts.kinds[0] == 1 && t.layouts.types[0] == 1 && t.layouts.types[1] == 2);
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    var usize i = 0;
    while (i < 6) { assert(t.layouts.types[16+i] == tags[i]); i += 1; }
    assert(t.layouts.fields[31] == 0 && t.layouts.types[511] == 0 && t.layouts.kinds[511] == 0);
    assert(source::find(text, ref t, 20, 25) == 0);
    assert(source::find(text, ref t, 0, 6) == 32);
}
@test
fn void declarations_publish_no_owners_instructions_or_payload_fuel() {
    let ir::Program p = compiled(b"module main; struct Point { i32 x; i32 y; } fn i32 main() { return 42; }");
    assert(p.records.layouts.count == 1 && p.records.count == 0 && p.arrays.count == 0);
    assert(p.count == 2 && verifier::verify(ref p).is_ok);
    assert(switch (vm::run_with_array_limit(ref p, 2, 0)) { case .ok(n): { n == 42 } case .err(_): { false } });
    assert(switch (vm::run(ref p, 1)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    let ir::Program arrays = compiled(b"module main; struct Point { i32 x; } fn i32[1] make() { return [42;1]; } fn i32 main() { let i32[1] a=make(); return a[0]; }");
    assert(arrays.records.count == 0 && arrays.records.layouts.count == 1);
    assert(switch (vm::run(ref arrays, 1000000)) { case .ok(n): { n == 42 } case .err(_): { false } });
    let ir::Program calls = compiled(b"module main; fn i32 main() { return helper(); } struct Point { i32 x; } fn i32 helper() { return 42; }");
    assert(switch (vm::run(ref calls, 20)) { case .ok(n): { n == 42 } case .err(_): { false } });
}
@test
fn void names_fields_and_unsupported_types_are_checked() {
    rejected(b"struct Point { i32 x; }", 2);
    rejected(b"module main; struct Point { i32 x; } struct Point { i32 y; }", 3);
    rejected(b"module main; struct Point { i32 x; bool x; }", 3);
    rejected(b"module main; struct i32 { i32 x; }", 2);
    rejected(b"module main; struct Point { i32 return; }", 2);
    rejected(b"module main; struct Point { Unknown x; }", 3);
    rejected(b"module main; struct Point { Option<i32> x; }", 3);
    rejected(b"module main; struct Point { i32[2] x; }", 3);
    rejected(b"module main; struct Point {}", 3);
    rejected(b"module main; struct Point { i32 x }", 2);
    rejected(b"module main; struct Point { i32 x;", 2);
}
@test
fn void cycles_and_structural_limits_are_checked_without_native_recursion() {
    rejected(b"module main; struct A { A child; }", 3);
    rejected(b"module main; struct A { B child; } struct B { A child; }", 3);
    rejected(b"module main; struct A { i32 a; i32 b; i32 c; i32 d; i32 e; i32 f; i32 g; i32 h; i32 i; i32 j; i32 k; i32 l; i32 m; i32 n; i32 o; i32 p; i32 q; }", 4);
}
@test
fn void global_collisions_and_object_syntax_remain_rejected() {
    assert(!compiler::compile(b"module main; struct main { i32 x; } fn i32 main() { return 42; }").is_ok);
    assert(!compiler::compile(b"module main; fn i32 Point() { return 0; } struct Point { i32 x; } fn i32 main() { return 42; }").is_ok);
    assert(!compiler::compile(b"module main; struct Point { i32 x; } fn i32 main() { let Point p = Point { .x = 42 }; let Point q = (p); return q.x; }").is_ok);
    assert(!compiler::compile(b"module main; struct Point { i32 x; } fn Point helper() { return 0; } fn i32 main() { return 42; }").is_ok);
    assert(!compiler::compile(b"module main; struct Point { i32 x; } fn i32 helper(ref Point p) { return 42; } fn i32 main() { return 42; }").is_ok);
}
