module tests::switch_expression;

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
fn void scalar_and_wrapper_result_contexts() {
    value(b"module main; fn i32 main() {let Option<i32> x=.some(41); return switch(x) {case .some(v): {v+1} case .none: {0}};}",42);
    value(b"module main; fn i32 main() {let Option<bool> x=.some(false); let bool yes=switch(x) {case .none: {false} case .some(v): {!v}}; if(yes) {return 42;} return 0;}",42);
    value(b"module main; fn Result<i32,bool> f(Option<i32> x) {return switch(x) {case .some(v): {.ok(v)} case .none: {.err(false)}};} fn i32 main() {return switch(f(.some(42))) {case .ok(v): {v} case .err(_): {0}};}",42);
    value(b"module main; fn i32 main() {let Option<i32> x=.some(1); return switch(x) {case .some(v): {switch(x) {case .some(w): {v+w+40} case .none: {0}}} case .none: {0}};}",42);
    value(b"module main; fn Option<i32> f(Option<i32> x) {let Option<i32> y=.some(42); return .some((switch(x) {case .some(_): {y} case .none: {.none}})?);} fn i32 main() {return switch(f(.some(0))) {case .some(v): {v} case .none: {0}};}",42);
}
@test
fn void scoped_effects_returns_and_untaken_paths() {
    value(b"module main; fn i32 main() {var Option<i32> x=.some(40); var i32 out=0; let i32 n=switch(x) {case .some(v): {x=.none; var i32 n=v; n=n+2; out=n; n} case .none: {out=1/0; 0}}; return n+out-42;}",42);
    value(b"module main; fn i32 main() {let Option<i32> x=.none; return 1+switch(x) {case .some(v): {v} case .none: {return 42;}};}",42);
    value(b"module main; fn i32 main() {let Option<i32> x=.some(42); return switch(x) {case .none: {return 0;} case .some(v): {v}};}",42);
    value(b"module main; fn i32 main() {let Option<i32> x=.none; let bool b=false && switch(x) {case .some(v): {v==1/0} case .none: {return 0;}}; return 42;}",42);
    value(b"module main; fn Option<i32> f(Option<i32> x) {return .some(switch(x) {case .some(v): {v} case .none: {let i32 n=x?; n}});} fn i32 main() {return switch(f(.none)) {case .some(v): {0} case .none: {42}};}",42);
}
@test
fn void switch_value_source_rejections() {
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(v): {v} case .none: {true}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(v): {v}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .none: {0} case .none: {1}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; let i32 n=switch(x) {case .some(v): {let i32 local=v; local} case .none: {0}}; return local;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(v): {v=1; v} case .none: {0}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(v): {return v;} case .none: {return 0;}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(v): {v;} case .none: {0}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; for(var i32 n=switch(x) {case .some(v): {v} case .none: {0}};false;) {} return 0;}").is_ok);
}
@test
fn void switch_value_fuel_and_join_initialization() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let Option<i32> x=.some(42); return switch(x) {case .some(v): {v} case .none: {0}};}");
    assert(switch(vm::run(ref p,6)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref p,7)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,7)) {case .ok(n): {n==42} case .err(_): {false}});
    var ir::Program bad=p;
    // Bypass the first STORE. The value join must not acquire initialization
    // from the other variant's STORE or from a recycled runtime frame.
    assert(bad.code[24]==18);
    bad.code[24]=19; bad.code[25]=0; bad.code[26]=4; bad.code[27]=0;
    assert(!verifier::verify(ref bad).is_ok);
    assert(!vm::run(ref bad,100).is_ok);
}
