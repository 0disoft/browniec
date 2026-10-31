module tests::m2::slice_element_public;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import ir as ir;

fn void run(ref u8[] source,usize fuel,u8 kind) {
    let ir::Program p=switch(compiler::compile(source)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(verifier::inspect(ref p).is_ok && verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,fuel)){case .ok(v):{kind==0 && v==42}case .err(e):{e.kind==kind && e.offset<source.len}});
}
fn void rejected(ref u8[] source) {assert(!compiler::compile(source).is_ok);}

@test
fn void owned_roots_dynamic_ranges_typed_forwarding_and_scoped_writes_execute_publicly() {
    run(b"module main;fn i32 f(ref i32[] p){let ref i32[] q=ref p[..p.len];return q[0];}fn i32 main(){let i32[4] a=[1;4];let ref i32[] p=ref a[1..3];let i32 n=f(ref p);return n+41;}",1000000,0);
    run(b"module main;fn bool f(ref bool[] p){return p[0];}fn i32 main(){let bool[2] a=[true;2];let ref bool[] p=ref a;if(f(ref p)){return 42;}return 0;}",1000000,0);
    run(b"module main;fn i64 f(ref i64[] p){return g(ref p);}fn i64 g(ref i64[] p){return p[0];}fn i32 main(){let i64[1] a=[-9223372036854775808;1];let ref i64[] p=ref a;if(f(ref p)==-9223372036854775808){return 42;}return 0;}",1000000,0);
    run(b"module main;fn u32 f(ref u32[] p){return p[0];}fn i32 main(){let u32[1] a=[4294967295;1];let ref u32[] p=ref a;if(f(ref p)==4294967295){return 42;}return 0;}",1000000,0);
    run(b"module main;fn usize f(ref usize[] p){let ref usize[] q=ref p[0..p.len];return q[0];}fn i32 main(){var usize[1] a=[18446744073709551615;1];var i32 n=0;{let ref usize[] p=ref a;if(f(ref p)==18446744073709551615){n=42;}}a[0]=0;return n;}",1000000,0);
    run(b"module main;fn bool f(ref i32[] p){return p.len==0;}fn i32 main(){let i32[4] a=[42;4];let ref i32[] p=ref a[1..1];if(f(ref p)){return 42;}return 0;}",1000000,0);
}

@test
fn void mixed_arguments_aggregate_returns_and_propagation_clean_borrowed_roots() {
    run(b"module main;struct R{i32 x;}fn i32 f(i32 n,ref i64[] p,u8[1] a,R r,ref i64[] q){if(p[0]==q[0]){return n+a[0] as i32+r.x;}return 0;}fn i32 main(){let i64[1] a=[9223372036854775807;1];let ref i64[] p=ref a;let u8[1] b=[1;1];let R r=R{.x=21};return f(20,ref p,b,r,ref p);}",1000000,0);
    run(b"module main;fn i32[1] f(ref i32[] p){return [p[0];1];}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;let i32[1] b=f(ref p);return b[0];}",1000000,0);
    run(b"module main;struct R{i64 x;}fn R f(ref i64[] p){return R{.x=p[0]};}fn i32 main(){let i64[1] a=[42;1];let ref i64[] p=ref a;let R r=f(ref p);if(r.x==42){return 42;}return 0;}",1000000,0);
    run(b"module main;fn Option<i32> f(ref i32[] p,Option<i32> o){let ref i32[] q=ref p;let i32 n=o?;return .some(n+q[0]);}fn i32 main(){var i32[1] a=[42;1];var i32 n=0;{let ref i32[] p=ref a;let Option<i32> o=.none;let Option<i32> r=f(ref p,o);n=switch(r){case .none:{42}case .some(v):{0}};}a[0]=0;return n;}",1000000,0);
    run(b"module main;fn i32 f(ref i32[] p,i32 n){if(n==0){return p[0];}return f(ref p,n-1);}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return f(ref p,2);}",1000000,0);
}

@test
fn void exact_fuel_errors_and_source_safety_rules_survive_public_promotion() {
    let ref u8[] source=b"module main;fn i32 read(ref i32[] p){if(p[0]==42){return 42;}return 0;}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return read(ref p);}";
    // Preparation65537; main200819+3*4; callee8233+4; total274605.
    run(source,274605,0);run(source,274604,8);
    run(b"module main;fn i32 f(ref i32[] p){return p[1];}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return f(ref p);}",1000000,14);
    run(b"module main;fn i32 f(ref i32[] p){return p[0]/0;}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return f(ref p);}",1000000,7);
    rejected(b"module main;fn i32 main(){var i32[1] a=[42;1];let ref i32[] p=ref a;a[0]=0;return p[0];}");
    rejected(b"module main;fn i32 main(){let i32[1] a=[42;1];let ref u32[] p=ref a;return 42;}");
    rejected(b"module main;fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;if(text::valid_utf8(p)){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){let i32[1] a=[42;1];if(text::valid_utf8(a)){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){let ref i32[] p=ref [42;1];return 42;}");
}
