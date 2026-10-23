module tests::propagation;

import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    let ir::Program p=switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
    assert(verifier::verify(ref p).is_ok);
    return p;
}
fn void value(ref u8[] source,i64 expected) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,10000)) {case .ok(n): {n==expected} case .err(_): {false}});
}
@test
fn void scalar_success_and_failure_type_changes() {
    value(b"module main; fn Option<bool> f(Option<i32> x) {return .some(x?==42);} fn i32 main() {switch(f(.some(42))) {case .some(v): {if(v) {return 42;} return 1;} case .none: {return 0;}}}",42);
    value(b"module main; fn Option<bool> f(Option<i32> x) {return .some(x?==42);} fn i32 main() {switch(f(.none)) {case .some(v): {return 0;} case .none: {return 42;}}}",42);
    value(b"module main; fn Result<bool,i32> f(Result<i32,i32> x) {return .ok(x?==42);} fn i32 main() {switch(f(.err(-2147483648))) {case .ok(v): {return 0;} case .err(e): {return e;}}}",-2147483648);
    value(b"module main; fn Result<i32,bool> f(Result<bool,bool> x) {if(!x?) {return .ok(42);} return .ok(0);} fn i32 main() {switch(f(.ok(false))) {case .ok(v): {return v;} case .err(e): {return 0;}}}",42);
    value(b"module main; fn Result<i32,bool> f(Result<bool,bool> x) {if(x?) {return .ok(0);} return .ok(1);} fn i32 main() {switch(f(.err(false))) {case .ok(v): {return 0;} case .err(e): {if(!e) {return 42;} return 1;}}}",42);
}
@test
fn void failure_order_short_circuit_and_loops() {
    value(b"module main; fn i32 sum(i32 a,i32 b) {return a+b;} fn Option<i32> f(Option<i32> x) {return .some(sum(x?,1/0));} fn i32 main() {switch(f(.none)) {case .some(v): {return 0;} case .none: {return 42;}}}",42);
    value(b"module main; fn Option<bool> f(Option<bool> x) {return .some(false && x? || true);} fn i32 main() {switch(f(.none)) {case .some(v): {if(v) {return 42;} return 0;} case .none: {return 1;}}}",42);
    value(b"module main; fn Option<i32> f(Option<bool> x) {while(x?) {return .some(0);} return .some(42);} fn i32 main() {switch(f(.none)) {case .some(v): {return 0;} case .none: {return 42;}}}",42);
    value(b"module main; fn Option<i32> f(Option<i32> x) {var i32 n=0; var Option<i32> current=x; for(var i32 i=0;i<2;i=i+1) {n=n+current?; current=.none;} return .some(n);} fn i32 main() {switch(f(.some(1))) {case .some(v): {return 0;} case .none: {return 42;}}}",42);
    value(b"module main; fn Option<i32> f(Option<i32> x) {var Option<i32> current=x; let Option<i32> old=current; current=.none; return .some(-old?+43);} fn i32 main() {switch(f(.some(1))) {case .some(v): {return v;} case .none: {return 0;}}}",42);
}
@test
fn void propagation_type_and_header_rejections() {
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.some(42); return x?;}").is_ok);
    assert(!compiler::compile(b"module main; fn Option<i32> f(Result<i32,i32> x) {return .some(x?);} fn i32 main() {return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn Result<i32,bool> f(Result<i32,i32> x) {return .ok(x?);} fn i32 main() {return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn Option<i32> f() {return .some(1?);} fn i32 main() {return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn Option<i32> f(Option<i32> x) {return .some(x??);} fn i32 main() {return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn Option<i32> f(Option<i32> x) {for(var i32 n=x?;false;) {} return .none;} fn i32 main() {return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn Option<i32> f(Option<bool> x) {for(;x?;) {} return .none;} fn i32 main() {return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn Option<i32> f(Option<i32> x) {var i32 n=0; for(;false;n=x?) {} return .none;} fn i32 main() {return 0;}").is_ok);
}
@test
fn void propagation_fuel_reuse_and_guarded_initialization() {
    let ir::Program p=compiled(b"module main; fn Option<i32> f(Option<i32> x) {return .some(x?);} fn i32 main() {switch(f(.some(42))) {case .some(v): {return v;} case .none: {return 0;}}}");
    assert(switch(vm::run(ref p,9)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref p,10)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,10)) {case .ok(n): {n==42} case .err(_): {false}});
    let ir::Program none=compiled(b"module main; fn Option<i32> f(Option<i32> x) {return .some(x?);} fn i32 main() {switch(f(.none)) {case .some(v): {return v;} case .none: {return 42;}}}");
    assert(switch(vm::run(ref none,10)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref none,11)) {case .ok(n): {n==42} case .err(_): {false}});
    var ir::Program bad=p;
    assert(bad.code[0]==24);
    bad.code[4]=1;
    assert(!verifier::verify(ref bad).is_ok);
}
