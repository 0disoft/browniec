module tests::m2::array_length;
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
@test
fn void length_is_exact_usize_for_fixed_shapes_and_copies() {
    result(b"module main; fn i32 main() { let i32[1] a=[42;1]; if(a.len==1) {return a[0];} return 0; }", 42);
    result(b"module main; fn i32 main() { let bool[4096] a=[true;4096]; if(a.len==4096) {return 42;} return 0; }", 42);
    result(b"module main; fn i32 main() { var u8[2] a=[1;2]; let u8[2] b=a; a[0]=0; if(a.len==b.len && b.len==2) {return 42;} return 0; }", 42);
    let ir::Program p = compiled(b"module main; fn i32 main() { let i32[1] a=[42;1]; let usize n=a.len; return a[0]; }");
    assert(p.types[1] == 12 && p.code[16] == 1 && p.constants[1] == 1);
    assert(switch (vm::run_with_array_limit(ref p, 163, 4)) { case .ok(n): { n == 42 } case .err(_): { false } });
    assert(switch (vm::run_with_array_limit(ref p, 162, 4)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
}
@test
fn void length_composes_with_loops_arguments_and_local_len_names() {
    result(b"module main; fn i32 main() { var i32[3] a=[14;3]; var i32 total=0; for(var usize i=0;i<a.len;i=i+1) {total=total+a[i];} return total; }", 42);
    result(b"module main; fn bool full(usize n) {return n==2;} fn i32 main() {let i64[2] a=[1;2]; if(full(a.len)) {return 42;} return 0;}", 42);
    result(b"module main; fn i32 len() {return 42;} fn i32 main() {let usize[1] a=[0;1]; if(a.len==1) {return len();} return 0;}", 42);
    result(b"module main; fn i32 main() {let u32[2] a=[0;2]; let Option<i32> o=.some(0); let usize n=switch(o) {case .some(v): {a.len} case .none: {a.len}}; if(n==2) {return 42;} return 0;}", 42);
}
@test
fn void length_rejects_non_arrays_members_and_implicit_conversion() {
    assert(!compiler::compile(b"module main; fn i32 main() {let i32 a=1; return a.len;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32[1] a=[42;1]; return a.len;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32[1] a=[42;1]; let usize n=a.size; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {var i32[1] a=[42;1]; a.len=2; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32[1] a=[42;1]; let usize n=a.len(); return 0;}").is_ok);
}
