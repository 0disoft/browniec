module tests::functions;
import functions as functions;

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
