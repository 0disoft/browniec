module tests::m2::array_assignment;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
}
fn void result(ref u8[] source, usize limit) {
    let ir::Program p=compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,limit)) {case .ok(n): {n==42} case .err(_): {false}});
}
fn void invalid(ref ir::Program p, usize pc) {
    assert(switch(verifier::verify(p)) {case .ok(_): {false} case .err(e): {e.kind==5 && e.offset==pc}});
}
@test
fn void assignment_is_independent_in_scopes_loops_and_value_arms() {
    result(b"module main; fn i32 main() {var i32[2] a=[0;2]; {var i32[2] b=[21;2]; a=b; b[0]=0;} return a[0]+a[1];}",16);
    result(b"module main; fn i32 main() {let i32[1] a=[42;1]; var i32[1] b=[0;1]; for(var usize i=0;i<42;i=i+1) {b=a; b=b;} return b[0];}",8);
    result(b"module main; fn i32 main() {let bool[1] a=[true;1]; var bool[1] b=[false;1]; b=a; if(b[0]) {return 42;} return 0;}",2);
    result(b"module main; fn i32 main() {let u8[1] a=[255;1]; var u8[1] b=[0;1]; b=a; if(b[0]==255) {return 42;} return 0;}",2);
    result(b"module main; fn i32 main() {let i64[1] a=[-9223372036854775808;1]; var i64[1] b=[0;1]; b=a; if(b[0]==a[0]) {return 42;} return 0;}",16);
    result(b"module main; fn i32 main() {let u32[1] a=[4294967295;1]; var u32[1] b=[0;1]; b=a; if(b[0]==a[0]) {return 42;} return 0;}",8);
    result(b"module main; fn i32 main() {let usize[1] a=[18446744073709551615;1]; var usize[1] b=[0;1]; b=a; if(b[0]==a[0]) {return 42;} return 0;}",16);
    result(b"module main; fn i32 main() {var i32[1] a=[0;1]; let Option<i32> o=.none; return switch(o) {case .some(v): {v} case .none: {let i32[1] b=[42;1]; a=b; a[0]}};}",8);
}
@test
fn void exact_fuel_and_quota_do_not_require_a_third_array() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let i32[1] a=[42;1]; var i32[1] b=[0;1]; b=a; return b[0];}");
    assert(switch(vm::run_with_array_limit(ref p,369,8)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run_with_array_limit(ref p,368,8)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,7)) {case .ok(_): {false} case .err(e): {e.kind==13}});
    assert(!compiler::compile(b"module main; fn i32 main() {let i32[1] a=[42;1]; let i32[1] b=a; b=a; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32[1] a=[42;1]; var i64[1] b=[0;1]; b=a; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32[1] a=[42;1]; var i32[1] b=[0;1]; for(b=a;false;) {} return 0;}").is_ok);
}
@test
fn void verifier_requires_live_exact_shape_mutable_destinations() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let i32[1] a=[42;1]; var i32[1] b=[0;1]; {let i32[1] c=[0;1];} b=a; return b[0];}");
    var usize pc=0; while(pc<p.count && p.code[pc*8]!=38) {pc+=1;}
    assert(pc<p.count && verifier::verify(ref p).is_ok);
    var ir::Program bad=p; bad.code[pc*8+3]=1; invalid(ref bad,pc);
    bad=p; bad.code[pc*8+1]=0; invalid(ref bad,pc);
    bad=p; bad.code[pc*8+2]=2; invalid(ref bad,pc);
    bad=p; bad.code[pc*8+2]=255; invalid(ref bad,pc);
    bad=p; bad.arrays.lengths[1]=2; invalid(ref bad,pc);
    bad=p; bad.arrays.elements[1]=9; bad.types[1]=9; invalid(ref bad,pc);
    bad=p; bad.arrays.mutable[1]=false; invalid(ref bad,pc);
    bad=p; bad.code[3*8]=19; bad.code[3*8+1]=0; bad.code[3*8+2]=4; bad.code[3*8+3]=0; invalid(ref bad,pc);
}
