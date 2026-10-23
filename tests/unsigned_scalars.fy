module tests::unsigned_scalars;

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
fn void full_unsigned_literals_and_snapshot() {
    var lexer::State s=lexer::empty();
    assert(lexer::next(b"18446744073709551615 0",ref mut s).is_ok);
    assert(s.value == -1 && !s.min_magnitude);
    let lexer::State copy=lexer::snapshot(ref s);
    assert(copy.value == -1 && copy.end==20);
    assert(lexer::next(b"18446744073709551615 0",ref mut s).is_ok);
    assert(s.value==0 && !s.min_magnitude);
    s=lexer::empty();
    assert(!lexer::next(b"18446744073709551616",ref mut s).is_ok);
    value(b"module main; fn i32 main() {let u8 a=255; let u32 b=4294967295; let usize c=18446744073709551615; if(a==255 && b==4294967295 && c>9223372036854775808) {return 42;} return 0;}");
}
@test
fn void checked_unsigned_arithmetic_and_ordering() {
    value(b"module main; fn i32 main() {let usize hi=18446744073709551615; let usize half=9223372036854775808; if(hi/2==9223372036854775807 && hi%2==1 && half+1==9223372036854775809 && hi-half==9223372036854775807 && hi*0==0 && hi*1==hi && hi>half && half>0) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let u8 a=255; let u32 b=4294967295; if(a/2==127 && a%2==1 && a-255==0 && b*1==4294967295 && b-4294967295==0) {return 42;} return 0;}");
}
@test
fn void overflow_underflow_and_zero_divisor() {
    failure(b"module main; fn i32 main() {let u8 x=255+1; return 42;}",6);
    failure(b"module main; fn i32 main() {let u8 x=0-1; return 42;}",6);
    failure(b"module main; fn i32 main() {let u32 x=4294967295*2; return 42;}",6);
    failure(b"module main; fn i32 main() {let u32 x=4294967295+1; return 42;}",6);
    failure(b"module main; fn i32 main() {let usize x=18446744073709551615+1; return 42;}",6);
    failure(b"module main; fn i32 main() {let usize x=0-18446744073709551615; return 42;}",6);
    failure(b"module main; fn i32 main() {let usize x=9223372036854775808*2; return 42;}",6);
    failure(b"module main; fn i32 main() {let usize x=18446744073709551615/0; return 42;}",7);
    failure(b"module main; fn i32 main() {let usize x=18446744073709551615%0; return 42;}",7);
}
@test
fn void unsigned_frames_recursion_locals_and_loops() {
    value(b"module main; fn usize f(usize n,i32 count) {if(count==0) {return n;} return f(n+1,count-1);} fn i32 main() {var usize n=18446744073709551608; let usize old=n; n=f(n,7); if(n==18446744073709551615 && old==18446744073709551608) {return 42;} return 0;}");
    value(b"module main; fn u8 f(u8 a) {return a+1;} fn u32 g(u32 a) {return a+1;} fn i32 main() {if(f(254)==255 && g(4294967294)==4294967295) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {var usize total=0; for(var usize i=9223372036854775806;i<9223372036854775810;i=i+1) {if(i==9223372036854775807) {continue;} total=total+1;} while(total<42) {total=total+1;} if(total==42) {return 42;} return 0;}");
}
@test
fn void unsigned_switch_joins_and_untaken_paths() {
    value(b"module main; fn usize f(Option<i32> x) {return switch(x) {case .some(_): {return 18446744073709551615;} case .none: {0}};} fn i32 main() {let usize n=f(.some(1)); let Option<bool> x=.some(true); let usize z=switch(x) {case .some(_): {n} case .none: {1/0}}; if(z==18446744073709551615) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let u8 n=255; if(true || n+1==0) {return 42;} return 0;}");
}
@test
fn void reject_unsigned_negation_conversion_and_wrappers() {
    assert(!compiler::compile(b"module main; fn i32 main() {let u8 x=-0; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let usize x=0; let bool b=-x==0; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u8 x=256; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u32 x=4294967296; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i64 x=18446744073709551615; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let usize x=1; let u32 y=x; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u32 x=1; let usize y=x+1; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<u8> x=.some(1); return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Result<i32,usize> x=.ok(1); return 0;}").is_ok);
}
@test
fn void unsigned_verifier_checks_narrow_cells_and_types() {
    let ir::Program good=compiled(b"module main; fn i32 main() {let u8 x=255; let u8 y=x+0; return 42;}");
    var ir::Program bad=good;
    bad.constants[0]=256; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.constants[0]=-1; assert(!vm::run(ref bad,100).is_ok);
    bad=good; bad.types[2]=11; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[16]=7; bad.code[19]=0; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program wide=compiled(b"module main; fn i32 main() {let usize x=18446744073709551615; let bool b=x>0; return 42;}");
    bad=wide; bad.types[0]=11; assert(!verifier::verify(ref bad).is_ok);
    bad=wide; bad.types[2]=12; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program call=compiled(b"module main; fn u32 f(u32 x) {return x;} fn i32 main() {let u32 x=f(1); return 42;}");
    bad=call; bad.types[1]=12; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program wrapper=compiled(b"module main; fn i32 main() {let Option<i32> x=.some(1); return 42;}");
    bad=wrapper; bad.types[0]=10; assert(!verifier::verify(ref bad).is_ok);
}
@test
fn void unsigned_fuel_and_failure_order() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let usize n=6*7; return 42;}");
    assert(switch(vm::run(ref p,5)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,4)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    failure(b"module main; fn i32 main() {let usize n=1/0+(18446744073709551615+1); return 42;}",7);
    failure(b"module main; fn i32 main() {let usize n=(18446744073709551615+1)+1/0; return 42;}",6);
}
