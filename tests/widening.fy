module tests::widening;

import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    let ir::Program p=switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
    assert(verifier::verify(ref p).is_ok);
    return p;
}
fn void value(ref u8[] source) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,10000)) {case .ok(n): {n==42} case .err(_): {false}});
}
fn void failure(ref u8[] source,u8 kind) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,10000)) {case .ok(_): {false} case .err(e): {e.kind==kind}});
}
@test
fn void all_seven_pairs_preserve_signed_and_unsigned_edges() {
    value(b"module main; fn i32 main() {let u8 b=255; let i32 a=b as i32; let i64 c=b as i64; let u32 d=b as u32; let usize e=b as usize; if(a==255 && c==255 && d==255 && e==255) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let u32 x=4294967295; let i64 a=x as i64; let usize b=x as usize; if(a==4294967295 && b==4294967295) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let i32 lo=-2147483648; let i32 hi=2147483647; let i64 a=lo as i64; let i64 b=hi as i64; if(a == -2147483648 && b==2147483647) {return 42;} return 0;}");
}
@test
fn void explicit_source_has_no_outer_or_target_literal_context() {
    value(b"module main; fn i32 main() {let i64 a=1 as i64; let i64 b=(-2147483648) as i64; if(a==1 && b == -2147483648) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let usize n=18446744073709551615; let u32 x=4294967295; let i64 y=(1+x as i64); if(n>0 && y==4294967296) {return 42;} return 0;}");
    assert(!compiler::compile(b"module main; fn i32 main() {let i64 n=2147483648 as i64; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u8 n=1 as u8; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i64 n=(2147483648) as i64; return 0;}").is_ok);
}
@test
fn void cast_precedence_chains_and_first_failure() {
    value(b"module main; fn i32 main() {let u8 x=21; let usize a=x as u32 as usize; let i64 b=x as i32 as i64; if(a*2==42 && b*2==42) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let i32 x=-2147483648; let i64 n=-(x as i64); if(n==2147483648) {return 42;} return 0;}");
    failure(b"module main; fn i32 main() {let i32 x=-2147483648; let i64 n=-x as i64; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 n=(2147483647+1) as i64; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 n=(1/0) as i64; return 42;}",7);
}
@test
fn void contexts_calls_loops_and_switch_joins() {
    value(b"module main; fn i64 f(i64 x) {return x+1;} fn i32 main() {let u8 b=41; var i64 n=0; n=f(b as i64); let Option<i32> x=.some(b as i32); let i64 z=switch(x) {case .some(v): {v as i64} case .none: {0}}; if(n==42 && z==41) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let u8 one=1; var i64 n=0; for(var i64 i=one as i64;i<7;i=i+(one as i64)) {n=n+7;} if(n==42) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let Option<i32> x=.some(42); let i64 n=switch(x) {case .some(v): {v} case .none: {0}} as i64; if(n==42) {return 42;} return 0;}");
}
@test
fn void propagation_runs_before_widening() {
    value(b"module main; fn Option<i32> f(Option<i32> x) {let i64 n=x? as i64; if(n==42) {return .some(42);} return .none;} fn i32 main() {return switch(f(.some(42))) {case .some(v): {v} case .none: {0}};}");
    value(b"module main; fn Option<i32> f(Option<i32> x) {let i64 n=x? as i64; let i64 bad=1/0; return .some(0);} fn i32 main() {return switch(f(.none)) {case .some(v): {v} case .none: {42}};}");
}
@test
fn void reject_identity_narrowing_signedness_bool_and_wrapper_casts() {
    assert(!compiler::compile(b"module main; fn i32 main() {let i32 x=0; return x as i32;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u32 x=0; return x as i32;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let usize x=0; let i64 y=x as i64; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32 x=0; let usize y=x as usize; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {return true as i32;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u8 x=1; let bool y=x as bool; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.some(1); return x as i32;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u8 x=1; let Option<i32> y=x as Option<i32>; return 0;}").is_ok);
}
@test
fn void widening_metadata_and_readability_are_verified() {
    let ir::Program good=compiled(b"module main; fn i32 main() {let u8 x=42; return x as i32;}");
    assert(good.code[8]==26);
    var ir::Program bad=good;
    bad.code[11]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[12]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[10]=1; assert(!vm::run(ref bad,100).is_ok);
    bad=good; bad.code[9]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[0]=11; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[1]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.slots[1]=true; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program call=compiled(b"module main; fn i32 f(u8 x) {return x as i32;} fn i32 main() {return f(42);}");
    bad=call; bad.code[2]=2; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program local=compiled(b"module main; fn i32 main() {var u8 x=42; return x as i32;}");
    assert(local.code[24]==26);
    bad=local; bad.code[26]=1; assert(!verifier::verify(ref bad).is_ok);
}
@test
fn void each_executed_cast_costs_fuel_and_keeps_source_snapshot() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let u8 b=42; return b as i32;}");
    assert(switch(vm::run(ref p,3)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,2)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref p,3)) {case .ok(n): {n==42} case .err(_): {false}});
    value(b"module main; fn i32 main() {var u8 b=42; let i32 old=b as i32; b=0; return old;}");
}
