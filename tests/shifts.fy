module tests::shifts;

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
fn void failure(ref u8[] source,u8 kind) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,100)) {case .ok(_): {false} case .err(e): {e.kind==kind}});
}
@test
fn void signed_shift_edges_are_defined_without_host_signed_shifts() {
    value(b"module main; fn i32 main() {let i32 a=-1; let i64 b=-1; if((a<<31) == -2147483648 && (b<<63) == -9223372036854775808 && (a>>31) == -1 && (b>>63) == -1 && (-7>>1) == -4) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let i32 a=-2147483648; let i64 b=-9223372036854775808; if((a<<0)==a && (b<<0)==b && (a>>1) == -1073741824 && (b>>1) == -4611686018427387904 && (b>>63) == -1) {return 42;} return 0;}");
    value(b"module main; fn i32 main() {let u8 a=1; let u32 b=1; let usize c=1; if((a<<7)==128 && (b<<31)==2147483648 && (c<<63)==9223372036854775808 && ((~c)>>63)==1) {return 42;} return 0;}");
}
@test
fn void shift_counts_and_left_overflow_return_guest_errors() {
    failure(b"module main; fn i32 main() {return 1<<31;}",6);
    failure(b"module main; fn i32 main() {return -2<<31;}",6);
    failure(b"module main; fn i32 main() {let i64 n=1<<63; return 0;}",6);
    failure(b"module main; fn i32 main() {let u8 n=255<<1; return 0;}",6);
    failure(b"module main; fn i32 main() {let usize n=18446744073709551615<<1; return 0;}",6);
    failure(b"module main; fn i32 main() {return 0<<32;}",6);
    failure(b"module main; fn i32 main() {return 0>>-1;}",6);
    failure(b"module main; fn i32 main() {let usize n=0>>18446744073709551615; return 0;}",6);
    failure(b"module main; fn i32 main() {return (1/0) << 32;}",7);
    failure(b"module main; fn i32 main() {return 0 << (1/0);}",7);
}
@test
fn void shift_precedence_casts_and_pure_loop_headers() {
    value(b"module main; fn i32 main() {let u8 b=21; let i64 n=1<<b as i64; if((1<<2+1)==8 && (16>>1>>1)==4 && (1|2<<3)==17 && n==2097152) {return b as i32<<1;} return 0;}");
    value(b"module main; fn i32 main() {var u8 n=1; for(var u8 i=0;i<5;i=i+1) {n=n<<1;} if(n==32) {return 42;} return 0;}");
    assert(!compiler::compile(b"module main; fn i32 main() {return true<<false;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let u8 a=1; let i32 n=1; return n<<a;}").is_ok);
}
@test
fn void shift_verifier_and_exact_fuel() {
    let ir::Program good=compiled(b"module main; fn i32 main() {return 21<<1;}");
    assert(good.code[16]==31);
    assert(switch(vm::run(ref good,4)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref good,3)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    var ir::Program bad=good;
    bad.types[1]=9; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[19]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[20]=1; assert(!vm::run(ref bad,100).is_ok);
    bad=good; bad.code[17]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[2]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[16]=33; assert(!verifier::verify(ref bad).is_ok);
}
