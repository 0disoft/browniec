module tests::i64_scalars;

import compiler as compiler;
import ir as ir;
import lexer as lexer;
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
fn void full_width_lexer_and_snapshot() {
    var lexer::State s=lexer::empty();
    let usize first=switch(lexer::next(b"9223372036854775808 42",ref mut s)) {case .ok(n): {n} case .err(_): {assert(false);0}};
    assert(s.min_magnitude && s.value == -9223372036854775808);
    let lexer::State copy=lexer::snapshot(ref s);
    assert(copy.min_magnitude && copy.value==s.value && copy.end==19);
    assert(lexer::next(b"9223372036854775808 42",ref mut s).is_ok);
    assert(!s.min_magnitude && s.value==42);
    s=lexer::empty();
    assert(!lexer::next(b"9223372036854775809",ref mut s).is_ok);
    value(b"module main; fn i32 main() {let i64 lo=-9223372036854775808; let i64 hi=9223372036854775807; if(lo+hi == -1) {return 42;} return 0;}");
}
@test
fn void contexts_frames_recursion_and_loops() {
    value(b"module main; fn i64 f(i64 x,i32 n) {if(n==0) {return x;} return f(x+1,n-1);} fn i32 main() {var i64 x=9223372036854775800; let i64 old=x; x=f(x,7); if(x==9223372036854775807 && old==9223372036854775800) {return 42;} return 0;}");
    value(b"module main; fn i64 f() {return -9223372036854775808;} fn bool yes(i64 n) {return n == -9223372036854775808;} fn i32 main() {let i64 n=f(); if(yes(n) && yes(-9223372036854775808)) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {var i64 total=0; for(var i64 i=0;i<7;i=i+1) {if(i==3) {continue;} total=total+i;} while(total<42) {total=total+1;} if(total==42) {return 42;} return 0;}");
}
@test
fn void checked_arithmetic_edges() {
    value(b"module main; fn i32 main() {let i64 lo=-9223372036854775808; let i64 hi=9223372036854775807; let i64 n=lo+hi; let i64 z=lo*0; if(n == -1 && z==0 && hi*1==hi && lo*1==lo && hi/hi==1 && lo%3 == -2) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let i64 lo=-9223372036854775808; let i64 hi=9223372036854775807; if(lo-lo==0 && hi-hi==0 && lo+hi/2<0 && hi/-1 == -9223372036854775807) {return 42;} return 0;}");
}
@test
fn void overflow_is_guest_failure() {
    failure(b"module main; fn i32 main() {let i64 x=9223372036854775807+1; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 x=-9223372036854775808-1; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 x=9223372036854775807*2; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 x=--9223372036854775808; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 x=-9223372036854775808/-1; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 x=-9223372036854775808%-1; return 42;}",6);
    failure(b"module main; fn i32 main() {let i64 x=1/0; return 42;}",7);
    failure(b"module main; fn i32 main() {let i64 x=1%0; return 42;}",7);
}
@test
fn void switch_values_and_short_circuit() {
    value(b"module main; fn i64 f(Option<i32> x) {return switch(x) {case .some(_): {return -9223372036854775808;} case .none: {9223372036854775807}};} fn i32 main() {let i64 n=f(.some(0)); if(n == -9223372036854775808) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let Option<i32> x=.none; let i64 n=switch(x) {case .some(_): {1/0} case .none: {9223372036854775807}}; if(true || n+1==0) {return 42;} return 0;}");
}
@test
fn void no_implicit_conversion_or_wide_wrappers() {
    assert(!compiler::compile(b"module main; fn i32 main() {let i64 x=9223372036854775808; return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i64 x=-9223372036854775809; return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32 x=1; let i64 y=x; return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i64 x=1; let i32 y=2; let i64 z=x+y; return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i64 x=1; if(x==true) {return 42;} return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i64> x=.some(1); return 42;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Result<i32,i64> x=.ok(1); return 42;}").is_ok);
}
@test
fn void fuel_and_failure_order() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let i64 x=6*7; return 42;}");
    assert(switch(vm::run(ref p,5)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,4)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    failure(b"module main; fn i32 main() {let i64 x=1/0+(9223372036854775807+1); return 42;}",7);
    failure(b"module main; fn i32 main() {let i64 x=(9223372036854775807+1)+1/0; return 42;}",6);
}
@test
fn void corrupt_i64_metadata_and_i32_range() {
    let ir::Program good=compiled(b"module main; fn i32 main() {let i64 x=9223372036854775807; let i64 y=x+1; return 42;}");
    var ir::Program bad=good;
    bad.types[0]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[2]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[1]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[3]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.constants[2]=2147483648; assert(!vm::run(ref bad,100).is_ok);
    let ir::Program neg=compiled(b"module main; fn i32 main() {let i64 x=1; let i64 y=-x; return 42;}");
    bad=neg; bad.types[1]=1; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program wrap=compiled(b"module main; fn i32 main() {let Option<i32> x=.some(1); return 42;}");
    bad=wrap; bad.types[0]=9; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program call=compiled(b"module main; fn i64 f(i64 x) {return x;} fn i32 main() {let i64 x=f(1); return 42;}");
    bad=call; bad.types[1]=1; assert(!verifier::verify(ref bad).is_ok);
}
