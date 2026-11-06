module tests::m2::array_write;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import ir as ir;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } };
}
fn void result(ref u8[] source, i64 expected) {
    let ir::Program p = compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run(ref p, 1000000)) { case .ok(n): { n == expected } case .err(_): { false } });
}
fn void rejected(ref u8[] source) {
    assert(switch (compiler::compile(source)) { case .ok(_): { false } case .err(e): { e.kind == 3 } });
}
@test
fn void writes_preserve_scalar_domains_loops_and_value_arms() {
    result(b"module main; fn i32 main() { var i32[2] a = [0; 2]; a[0] = 20; a[1] = 22; return a[0]+a[1]; }", 42);
    result(b"module main; fn i32 main() { var bool[1] a = [false; 1]; a[0] = true; if(a[0]) {return 42;} return 0; }", 42);
    result(b"module main; fn i32 main() { var i64[1] a = [0; 1]; a[0] = -9223372036854775808; if(a[0] == -9223372036854775808) {return 42;} return 0; }", 42);
    result(b"module main; fn i32 main() { var u8[1] a = [0; 1]; a[0] = 255; return a[0] as i32; }", 255);
    result(b"module main; fn i32 main() { var u32[1] a = [0; 1]; a[0] = 4294967295; if(a[0] == 4294967295) {return 42;} return 0; }", 42);
    result(b"module main; fn i32 main() { var usize[1] a = [0; 1]; a[0] = 18446744073709551615; if(a[0] == 18446744073709551615) {return 42;} return 0; }", 42);
    result(b"module main; fn i32 main() { var i32[2] a = [0; 2]; for(var usize i=0; i<2; i=i+1) { a[i]=21; } return a[0]+a[1]; }", 42);
    result(b"module main; fn i32 main() { var i32[1] a = [0; 1]; let Option<i32> o = .some(1); return switch(o) {case .some(n): {a[0]=42; a[0]} case .none: {a[0]=1; a[0]}}; }", 42);
    result(b"module main; fn i32 main() { var i32[1] a = [0; 1]; let Option<i32> o = .none; return switch(o) {case .some(n): {a[0]} case .none: {a[0]}}; }", 0);
}
@test
fn void index_then_rhs_once_and_early_returns_keep_lifetimes() {
    result(b"module main; fn i32 main() { var i32[2] a = [0; 2]; var usize i=0; let Option<i32> o=.some(0); a[i]=switch(o) {case .some(n): {i=1; 42} case .none: {0}}; return a[0]; }", 42);
    result(b"module main; fn i32 main() { var i32[1] a=[0;1]; var i32 hits=0; let Option<i32> o=.some(0); a[switch(o) {case .some(n): {hits=hits+1; 0} case .none: {0}}]=switch(o) {case .some(n): {hits=hits+1; 42} case .none: {0}}; if(hits==2) {return a[0];} return 0; }", 42);
    result(b"module main; fn i32 main() { var i32[1] a=[0;1]; let Option<i32> o=.some(0); a[switch(o) {case .some(n): {return 42;} case .none: {0}}]=1/0; return 0; }", 42);
    let ir::Program early=compiled(b"module main; fn i32 main() { var i32[1] a=[0;1]; let Option<i32> o=.some(0); a[999]=switch(o) {case .some(n): {return 42;} case .none: {0}}; return 0; }");
    assert(switch(vm::run(ref early,1000000)){case .ok(_):{false}case .err(e):{e.kind==14}});
    result(b"module main; fn i32 main() { var i32[1] a=[0;1]; let Option<i32> o=.some(0); return switch(o) {case .some(n): {a[switch(o) {case .some(m): {0} case .none: {0}}]=42; a[0]} case .none: {0}}; }", 42);
}
@test
fn void writes_reject_bad_targets_and_meter_failures() {
    rejected(b"module main; fn i32 main() { let i32[1] a=[0;1]; a[0]=42; return 0; }");
    rejected(b"module main; fn i32 main() { var i32[1] a=[0;1]; a=42; return 0; }");
    rejected(b"module main; fn i32 main() { var i32[1] a=[0;1]; a[true]=42; return 0; }");
    rejected(b"module main; fn i32 main() { var i32[1] a=[0;1]; a[0]=true; return 0; }");
    rejected(b"module main; fn i32 main() { var i32[1] a=[0;1]; for(a[0]=1;false;) {} return 0; }");
    rejected(b"module main; fn i32 main() { var i32[1] a=[0;1]; for(;false;a[0]=1) {} return 0; }");
    let ir::Program p=compiled(b"module main; fn i32 main() { var i32[1] a=[0;1]; a[0]=42; return a[0]; }");
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,3776,4)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run_with_array_limit(ref p,3775,4)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    let ir::Program bounds=compiled(b"module main; fn i32 main() {var i32[1] a=[0;1]; a[1]=42; return 0;}");
    assert(switch(vm::run(ref bounds,100000)) {case .ok(_): {false} case .err(e): {e.kind==14}});
    let ir::Program rhs=compiled(b"module main; fn i32 main() {var i32[1] a=[0;1]; a[999]=1/0; return 0;}");
    assert(switch(vm::run(ref rhs,100000)) {case .ok(_): {false} case .err(e): {e.kind==14}});
    // A failed one-shot execution cannot poison a new invocation.
    assert(switch(vm::run_with_array_limit(ref p,3776,4)) {case .ok(n): {n==42} case .err(_): {false}});
}
