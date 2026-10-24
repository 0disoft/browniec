module tests::m2::array_scopes;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
}
fn void result(ref u8[] source, usize limit) {
    let ir::Program p=compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,limit)) {case .ok(n): {n==42} case .err(_): {false}});
}
@test
fn void scope_exits_reclaim_storage_and_preserve_enclosing_arrays() {
    result(b"module main; fn i32 main() {var i32 n=0; {let i32[1] a=[21;1]; n=a[0];} {let i32[1] a=[21;1]; n=n+a[0];} return n;}",4);
    result(b"module main; fn i32 main() {var i32 n=0; while(n<42) {let i32[1] a=[1;1]; n=n+a[0];} return n;}",4);
    result(b"module main; fn i32 main() {let i32[1] a=[21;1]; {let i32[1] b=a; if(b.len==1) {return a[0]+b[0];}} return 0;}",8);
    result(b"module main; fn i32 main() {if(false) {let i32[1] a=[0;1];} else {let i32[1] a=[42;1]; return a[0];} return 0;}",4);
}
@test
fn void loop_transfers_drop_only_the_exited_scopes() {
    result(b"module main; fn i32 main() {var i32 n=0; for(var usize i=0;i<42;i=i+1) {let i32[1] a=[1;1]; n=n+a[0]; continue;} return n;}",4);
    result(b"module main; fn i32 main() {var i32 n=0; while(n<42) {let i32[1] a=[1;1]; n=n+a[0]; if(n<42) {continue;} break;} return n;}",4);
    result(b"module main; fn i32 main() {var i32 n=0; for(var usize i=0;i<2;i=i+1) {let i32[1] a=[21;1]; while(true) {let i32[1] b=a; n=n+b[0]; break;} if(a[0]!=21) {return 0;}} return n;}",8);
    result(b"module main; fn i32 main() {var i32 n=0; while(true) {let i32[1] a=[21;1]; {let i32[1] b=a; n=a[0]+b[0]; break;}} let i32[2] c=[0;2]; return n+c[0];}",8);
}
@test
fn void arm_yields_and_initializer_transfers_release_temporaries() {
    result(b"module main; fn i32 main() {let Option<i32> o=.some(0); let i32 n=switch(o) {case .some(v): {let i32[1] a=[21;1]; a[0]} case .none: {let i32[1] a=[0;1]; a[0]}}; let i32[1] b=[21;1]; return n+b[0];}",4);
    result(b"module main; fn i32 main() {let Option<i32> o=.some(0); var i32 n=0; while(switch(o) {case .some(v): {let i32[1] a=[1;1]; n=n+a[0]; if(n==42) {break;} true} case .none: {false}}) {} return n;}",4);
    result(b"module main; fn i32 main() {let Option<i32> o=.none; var i32 n=0; while(n<42) {let i32[1] a=[1;1]; let i32[1] b=[switch(o) {case .some(v): {v} case .none: {n=n+a[0]; continue;}};1];} return n;}",4);
    result(b"module main; fn i32 main() {let Option<i32> o=.none; let i32[1] a=[21;1]; let i32[1] b=[switch(o) {case .some(v): {v} case .none: {let i32[1] c=a; return c[0]+a[0];}};1]; return b[0];}",8);
}
@test
fn void scope_and_verifier_reject_escapes_and_missing_cleanup() {
    assert(!compiler::compile(b"module main; fn i32 main() {{let i32[1] a=[42;1];} return a[0];}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {for(let i32[1] a=[42;1];false;) {} return 0;}").is_ok);
    let ir::Program p=compiled(b"module main; fn i32 main() {{let i32[1] a=[42;1];} return 42;}");
    var ir::Program bad=p; var usize pc=0;
    while(pc<bad.count) {if(bad.code[pc*8]==37) {bad.code[pc*8]=19;assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok);break;} pc+=1;}
    assert(!verifier::verify(ref bad).is_ok);
    let ir::Program loop=compiled(b"module main; fn i32 main() {var i32 n=0; while(n<42) {let i32[1] a=[1;1]; n=n+a[0];} return n;}");
    var ir::Program leaking=loop; pc=0;
    while(pc<leaking.count) {if(leaking.code[pc*8]==37) {leaking.code[pc*8]=19;assert(ir::patch(ref mut leaking,pc,pc+1,0).is_ok);break;} pc+=1;}
    assert(!verifier::verify(ref leaking).is_ok);
}
