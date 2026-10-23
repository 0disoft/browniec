module tests::bitwise;

import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    let ir::Program p=switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
    assert(verifier::verify(ref p).is_ok); return p;
}
fn void value(ref u8[] source) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,10000)) {case .ok(n): {n==42} case .err(_): {false}});
}
@test
fn void fixed_width_signed_and_unsigned_patterns() {
    value(b"module main; fn i32 main() {let u8 a=~0; let u32 b=~0; let usize c=~0; let i64 d=~0; if(a==255 && b==4294967295 && c==18446744073709551615 && d == -1 && ~-2147483648==2147483647) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let i32 a=-2147483648; let i64 b=-9223372036854775808; let usize c=9223372036854775808; if((a|1) == -2147483647 && (b^1) == -9223372036854775807 && (c&18446744073709551615)==c && (a&2147483647)==0) {return 42;} return 0;}");
}
@test
fn void precedence_context_and_eager_evaluation() {
    value(b"module main; fn i32 main() {let u8 b=21; let i64 n=~b as i64; if((1|2^3&6)==1 && (1+2&6)==2 && n==234 && (~(b as i64)) == -22) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let Option<i32> x=.some(42); return switch(x) {case .some(v): {v&255} case .none: {~0}};}");
    let ir::Program p=compiled(b"module main; fn i32 main() {return 0 & (1/0);}");
    assert(switch(vm::run(ref p,100)) {case .ok(_): {false} case .err(e): {e.kind==7}});
    assert(!compiler::compile(b"module main; fn i32 main() {return true & false;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {return ~true;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u8 a=1; return a|1 as i64;}").is_ok);
}
@test
fn void bitwise_ir_types_operands_and_reserved_bytes() {
    let ir::Program good=compiled(b"module main; fn i32 main() {return ~0;}");
    assert(good.code[8]==27);
    var ir::Program bad=good;
    bad.code[11]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[1]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[0]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[12]=1; assert(!vm::run(ref bad,100).is_ok);
    let ir::Program pair=compiled(b"module main; fn i32 main() {return 6|7;}");
    assert(pair.code[16]==30);
    bad=pair; bad.code[19]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=pair; bad.types[1]=9; assert(!verifier::verify(ref bad).is_ok);
    bad=pair; bad.code[17]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=pair; bad.slots[2]=true; assert(!verifier::verify(ref bad).is_ok);
}
@test
fn void bitwise_fuel_calls_and_loop_slots() {
    let ir::Program p=compiled(b"module main; fn i32 main() {return ~(1|2);}");
    assert(switch(vm::run(ref p,5)) {case .ok(n): {n == -4} case .err(_): {false}});
    assert(switch(vm::run(ref p,4)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    value(b"module main; fn i64 f(i64 n) {return ~n;} fn i32 main() {let i64 n=f(-43); var u8 flags=0; for(var u8 i=0;i<4;i=i+1) {flags=flags|i;} if(n==42 && flags==3) {return 42;} return 0;}");
}
