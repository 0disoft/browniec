module tests::branches;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } };
}
fn void result(ref u8[] source, i64 expected) {
    let ir::Program p = compiled(source);
    assert(switch (vm::run(ref p,10000)) { case .ok(n): { n==expected } case .err(_): { false } });
}
fn void trap(ref u8[] source, u8 kind) {
    let ir::Program p=compiled(source);
    assert(switch (vm::run(ref p,256)) { case .ok(_): { false } case .err(e): { e.kind==kind } });
}
fn usize instruction(ref ir::Program p,u8 op) {
    var usize pc=0;
    while (pc<p.count) { if(p.code[pc*8]==op) {return pc*8;} pc+=1; }
    assert(false); return 0;
}
@test
fn void boolean_values_and_precedence() {
    result(b"module main; fn i32 main() { if(true) {return 1;} else {return 0;} }",1);
    result(b"module main; fn i32 main() { if(false) {return 1;} else {return 0;} }",0);
    result(b"module main; fn i32 main() { if(!false==true && 2+3*4==14 && -1<0 && 2<=2 && 3>2 && 3>=3 && 1!=2) {return 42;} else {return 0;} }",42);
    result(b"module main; fn i32 main() { if(false || true && false) {return 1;} else {return 0;} }",0);
    result(b"module main; fn i32 main() { if((false || true) && !false) {return 1;} else {return 0;} }",1);
    result(b"module main; fn bool f(bool x,i32 n) {return x==false && n<=1;} fn i32 main() {if(f(false,1)) {return 42;} return 0;}",42);
}
@test
fn void short_circuit_and_untaken_traps() {
    result(b"module main; fn i32 main() {if(false && 1/0==0) {return 0;} return 42;}",42);
    result(b"module main; fn i32 main() {if(true || 1/0==0) {return 42;} return 0;}",42);
    result(b"module main; fn bool bad() {return bad();} fn i32 main() {if(true || bad()) {return 42;} return 0;}",42);
    result(b"module main; fn i32 bad() {return 1/0;} fn i32 main() {if(false) {return bad();} return 42;}",42);
    result(b"module main; fn i32 main() {var bool b=true; let bool old=b; b=false; if(old && !b) {return 42;} return 0;}",42);
    trap(b"module main; fn i32 main() {if(true && 1/0==0) {return 1;} return 0;}",7);
    trap(b"module main; fn i32 main() {if(false || 1/0==0) {return 1;} return 0;}",7);
    trap(b"module main; fn i32 main() {if(1/0==0 || 2147483647+1==0) {return 1;} return 0;}",7);
}
@test
fn void branch_slots_and_scopes() {
    result(b"module main; fn i32 main() {var i32 x=1; let i32 old=x; if(true) {x=20;} else {x=30;} return x+old;}",21);
    result(b"module main; fn i32 main() {var i32 x=1; if(false) {x=20;} else {x=30;} return x;}",30);
    result(b"module main; fn i32 main() {var i32 x=1; if(false) {x=20;} return x;}",1);
    result(b"module main; fn i32 main() {var i32 x=1; if(true) {if(false) {x=2;} else {x=42;}} return x;}",42);
    result(b"module main; fn i32 main() {var i32 x=0; {let i32 a=20; x=a;} {let i32 a=22; x=x+a;} return x;}",42);
    result(b"module main; fn i32 f(i32 n) {if(n==0) {return 10;} else if(n==1) {return 20;} else {return 30;}} fn i32 main() {return f(0)+f(1)+f(2);}",60);
    assert(!compiler::compile(b"module main; fn i32 main() {if(1) {return 1;} return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {if(true) {let i32 x=1;} return x;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32 x=1; if(true) {x=2;} return x;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let i32 x=1; {let i32 x=2;} return x;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {if(true) {return 1;}}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {if(true) {return 1;} else {return 0;} return 2;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let bool b=1 && true; return 0;}").is_ok);
}
@test
fn void terminating_recursion_and_branch_fuel() {
    result(b"module main; fn i32 factorial(i32 n) {if(n<=1) {return 1;} return n*factorial(n-1);} fn i32 main() {return factorial(5);}",120);
    result(b"module main; fn i32 f(i32 n) {var i32 saved=n; if(n==0) {return 0;} saved=saved+f(n-1); return saved;} fn i32 main() {return f(10);}",55);
    let ir::Program p=compiled(b"module main; fn i32 main() {if(true) {return 42;} return 1/0;}");
    assert(switch(vm::run(ref p,3)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref p,4)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,4)) {case .ok(n): {n==42} case .err(_): {false}});
}
@test
fn void cfg_and_slot_metadata_rejections() {
    let ir::Program good=compiled(b"module main; fn i32 main() {var i32 x=0; if(true) {x=7;} return x;}");
    let usize branch=instruction(ref good,20);
    let usize load=instruction(ref good,17);
    let usize store=instruction(ref good,18);
    var ir::Program bad=good;
    bad.code[branch+3]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[branch+3]=255; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[branch+2]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.code[load+2]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.slots[1]=false; assert(!verifier::verify(ref bad).is_ok);
    // Remove the initial store. A later conditional store cannot initialize the
    // false path, even though the slot has a definition elsewhere in the code.
    bad=good; bad.code[store]=19; bad.code[store+1]=0; bad.code[store+2]=2;
    assert(!verifier::verify(ref bad).is_ok);
    assert(!vm::run(ref bad,256).is_ok);
    let ir::Program joined=compiled(b"module main; fn i32 main() {if(true) {let i32 x=7;} return 42;}");
    bad=joined; let usize returned=instruction(ref joined,8);
    bad.code[returned+2]=1; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program functions=compiled(b"module main; fn i32 main() {if(true) {return 1;} return 0;} fn i32 f() {return 42;}");
    bad=functions; let usize jump=instruction(ref functions,20);
    assert(functions.starts[1]==6);
    bad.code[jump+3]=6;
    assert(!verifier::verify(ref bad).is_ok);
}
