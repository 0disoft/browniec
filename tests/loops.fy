module tests::loops;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
}
fn void result(ref u8[] source,i64 expected) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,10000)) {case .ok(n): {n==expected} case .err(_): {false}});
}
@test
fn void while_values_and_transfers() {
    result(b"module main; fn i32 main() {var i32 i=0; var i32 sum=0; while(i<10) {i=i+1; if(i%2==0) {continue;} sum=sum+i; if(i==7) {break;}} return sum;}",16);
    result(b"module main; fn i32 main() {var i32 x=0; while(false) {x=1/0;} return x;}",0);
    result(b"module main; fn i32 main() {var i32 i=0; var i32 sum=0; while(i<3) {i=i+1; var i32 j=0; while(j<5) {j=j+1; if(j==3) {break;} sum=sum+1;}} return sum;}",6);
    result(b"module main; fn i32 f(i32 n) {while(n>0) {return 42;} return 0;} fn i32 main() {return f(1);}",42);
    result(b"module main; fn i32 main() {var bool again=true; while(again) {let bool old=again; again=false; if(!old) {return 0;}} return 42;}",42);
    result(b"module main; fn i32 main() {var i32 i=0; var i32 sum=0; while(i<3) {let i32 old=i; i=i+1; {var i32 x=old; x=x+10; sum=sum+x;}} return sum;}",33);
    assert(!compiler::compile(b"module main; fn i32 main() {break; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {continue; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {while(1) {} return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {while(false) {let i32 x=1;} return x;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {while(true) {break; return 1;} return 0;}").is_ok);
}
@test
fn void loop_fuel_and_reuse() {
    let ir::Program p=compiled(b"module main; fn i32 main() {while(true) {} return 0;}");
    assert(switch(vm::run(ref p,1000)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref p,0)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    let ir::Program once=compiled(b"module main; fn i32 main() {var bool again=true; while(again) {again=false;} return 42;}");
    assert(switch(vm::run(ref once,10)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref once,11)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref once,11)) {case .ok(n): {n==42} case .err(_): {false}});
}
@test
fn void backedge_invariants_and_bounds() {
    let ir::Program p=compiled(b"module main; fn i32 main() {var i32 n=0; while(n<2) {n=n+1;} return n;}");
    var usize back=0;
    while(back<p.count && p.code[back*8]!=22) {back+=1;}
    assert(back<p.count);
    var ir::Program bad=p;
    bad.code[back*8+2]=255; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.code[back*8+3]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.code[back*8+1]=1; assert(!vm::run(ref bad,100).is_ok);
    // One forward path skips a definition, then enters the loop header through
    // a backedge. Checking only the header's first entry would accept this.
    let ir::Program join=compiled(b"module main; fn i32 main() {if(true) {let i32 x=7; return x;} return 0;}");
    bad=join;
    bad.code[32]=22; bad.code[33]=0; bad.code[34]=3; bad.code[35]=0;
    assert(!verifier::verify(ref bad).is_ok);
}
