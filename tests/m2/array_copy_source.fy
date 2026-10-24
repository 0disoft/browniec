module tests::m2::array_copy_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false); ir::empty()}};
}
fn void result(ref u8[] source, i64 expected) {
    let ir::Program p=compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,1000000)) {case .ok(n): {n==expected} case .err(_): {false}});
}
fn void rejected(ref u8[] source) {
    assert(switch(compiler::compile(source)) {case .ok(_): {false} case .err(e): {e.kind==3}});
}
@test
fn void six_scalar_domains_and_independent_copy_mutability() {
    result(b"module main; fn i32 main() {var i32[2] a=[21;2]; var i32[2] b=a; a[0]=0; b[1]=22; return a[1]+b[0];}",42);
    result(b"module main; fn i32 main() {let bool[1] a=[true;1]; var bool[1] b=a; b[0]=false; if(a[0] && !b[0]) {return 42;} return 0;}",42);
    result(b"module main; fn i32 main() {var i64[1] a=[-9223372036854775808;1]; let i64[1] b=a; a[0]=0; if(b[0]==-9223372036854775808) {return 42;} return 0;}",42);
    result(b"module main; fn i32 main() {let u8[1] a=[255;1]; let u8[1] b=a; return b[0] as i32;}",255);
    result(b"module main; fn i32 main() {let u32[1] a=[4294967295;1]; let u32[1] b=a; if(b[0]==4294967295) {return 42;} return 0;}",42);
    result(b"module main; fn i32 main() {let usize[1] a=[18446744073709551615;1]; let usize[1] b=a; if(b[0]==18446744073709551615) {return 42;} return 0;}",42);
}
@test
fn void copies_snapshot_current_bytes_and_keep_return_loop_lifetimes() {
    result(b"module main; fn i32 main() {var i32[1] a=[0;1]; a[0]=42; let i32[1] b=a; a[0]=1; let i32[1] c=b; return c[0];}",42);
    result(b"module main; fn i32 main() {var i32[2] a=[0;2]; var i32[2] b=a; for(var usize i=0;i<2;i=i+1) {b[i]=21;} return b[0]+b[1]+a[0];}",42);
    result(b"module main; fn i32 main() {let i32[1] a=[42;1]; let i32[1] b=a; let Option<i32> o=.some(0); return switch(o) {case .some(n): {return b[0];} case .none: {a[0]}};}",42);
    result(b"module main; fn i32 main() {let i32[1] a=[42;1]; let i32[1] b=a; let Option<i32> o=.none; let i32[1] c=[switch(o) {case .some(n): {n} case .none: {return b[0];}};1]; return c[0];}",42);
}
@test
fn void copies_enforce_shapes_scope_quota_and_exact_fuel() {
    rejected(b"module main; fn i32 main() {let i32[1] a=[42;1]; let i32[2] b=a; return 0;}");
    rejected(b"module main; fn i32 main() {let i32[1] a=[42;1]; let i64[1] b=a; return 0;}");
    rejected(b"module main; fn i32 main() {let i32 x=42; let i32[1] b=x; return 0;}");
    rejected(b"module main; fn i32 main() {let i32[1] a=[42;1]; {let i32[1] b=a;} return b[0];}");
    rejected(b"module main; fn i32 main() {let i32[1] a=[42;1]; for(let i32[1] b=a;false;) {} return 0;}");
    rejected(b"module main; fn i32 main() {let i32[1] a=[42;1]; let i32[1] b=a; b[0]=0; return 0;}");
    let ir::Program p=compiled(b"module main; fn i32 main() {let i32[1] a=[42;1]; let i32[1] b=a; return b[0];}");
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,275,8)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run_with_array_limit(ref p,274,8)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,100000,7)) {case .ok(_): {false} case .err(e): {e.kind==13}});
    assert(switch(vm::run_with_array_limit(ref p,275,8)) {case .ok(n): {n==42} case .err(_): {false}});
}
