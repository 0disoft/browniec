module tests::switch_arm_statements;

import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import std::num as num;

fn ir::Program compiled(ref u8[] source) {
    let ir::Program p=switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
    assert(verifier::verify(ref p).is_ok); return p;
}
fn void value(ref u8[] source) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,10000)) {case .ok(n): {n==42} case .err(_): {false}});
}
@test
fn void branches_blocks_and_terminal_arms() {
    value(b"module main; fn i32 main() {let Option<i32> x=.some(40); return switch(x) {case .some(v): {var i32 n=v; if(n==40) {{let i32 extra=2; n=n+extra;}} else {n=0;} n} case .none: {return 0;}};}");
    value(b"module main; fn i32 main() {let Option<i32> x=.some(42); return 1+switch(x) {case .some(v): {if(v>0) {return v;} else {return 0;}} case .none: {0}};}");
    value(b"module main; fn i32 main() {let Option<i32> x=.some(21); let i64 n=switch(x) {case .some(v): {var i64 n=v as i64; if(n>0) {n=n<<1;} n} case .none: {0}}; if(n==42) {return 42;} return 0;}");
}
@test
fn void local_loops_and_nested_statement_switches() {
    value(b"module main; fn i32 main() {let Option<i32> x=.some(7); return switch(x) {case .some(v): {var i32 n=0; for(var i32 i=0;i<7;i=i+1) {if(i==3) {continue;} n=n+v;} n} case .none: {0}};}");
    value(b"module main; fn i32 main() {let Option<i32> x=.some(42); return switch(x) {case .some(v): {var i32 n=0; while(true) {n=v; break;} {switch(x) {case .some(_): {n=n|0;} case .none: {return 0;}}} n} case .none: {0}};}");
}
@test
fn void outer_loop_transfers_skip_pending_expression_work() {
    value(b"module main; fn i32 main() {let Option<i32> x=.some(1); var i32 post=0; for(var i32 i=0;i<3;post=post+100) {let i32 n=switch(x) {case .some(_): {break;} case .none: {1/0}}; return n/0;} return 42+post;}");
    value(b"module main; fn i32 main() {let Option<i32> x=.some(1); var i32 post=0; var i32 sum=0; for(;post<3;post=post+1) {let i32 n=switch(x) {case .some(_): {if(post<2) {continue;} 42} case .none: {0}}; sum=sum+n;} return sum;}");
    value(b"module main; fn i32 main() {let Option<i32> x=.some(1); var i32 n=0; while(n<3) {n=n+1; let i32 out=switch(x) {case .some(_): {continue;} case .none: {1/0}}; return out/0;} return n+39;}");
}
@test
fn void while_condition_owns_transfers_and_propagation() {
    value(b"module main; fn i32 main() {let Option<bool> x=.some(true); while(switch(x) {case .some(_): {break;} case .none: {true}}) {return 0;} return 42;}");
    value(b"module main; fn i32 main() {let Option<bool> x=.some(true); var i32 n=0; while(switch(x) {case .some(_): {n=n+1; if(n<3) {continue;} false} case .none: {true}}) {return 0;} return n+39;}");
    value(b"module main; fn Option<i32> f(Option<i32> x) {let Option<i32> y=.some(0); let i32 n=switch(y) {case .some(_): {if(true) {let i32 v=x?;} 0} case .none: {0}}; return .some(n);} fn i32 main() {return switch(f(.none)) {case .some(_): {0} case .none: {42}};}");
}
@test
fn void reject_missing_values_unreachable_work_and_scope_escape() {
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(v): {if(true) {return v;}} case .none: {0}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(v): {if(true) {return v;} else {return 0;} 42} case .none: {0}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(_): {{let i32 n=42;} n} case .none: {0}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(_): {break;} case .none: {0}};}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; return switch(x) {case .some(_): {if(true) {return 1;} else {return 2;}} case .none: {return 0;}};}").is_ok);
}
@test
fn void conditional_join_initialization_and_exact_fuel() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let Option<i32> x=.some(42); return switch(x) {case .some(v): {if(false) {return 0;} v} case .none: {0}};}");
    assert(switch(vm::run(ref p,9)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,8)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    let usize load=(p.count-2)*8;
    assert(p.code[load]==17);
    let u8 slot=p.code[load+2];
    var ir::Program bad=p;
    var usize pc=0;
    while(pc<p.count) {
        let usize at=pc*8;
        if(p.code[at]==18 && p.code[at+1]==slot) {
            let i64 wide=switch(num::i64_from_usize(pc+1)) {case .ok(n): {n} case .err(_): {assert(false);0}};
            let u8 target=switch(num::u8_from_i64(wide)) {case .ok(n): {n} case .err(_): {assert(false);0}};
            bad.code[at]=19; bad.code[at+1]=0; bad.code[at+2]=target; bad.code[at+3]=0;
            break;
        }
        pc+=1;
    }
    assert(pc<p.count);
    assert(!verifier::verify(ref bad).is_ok);
    assert(!vm::run(ref bad,100).is_ok);
}
