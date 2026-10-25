module tests::m2::array_helpers;

import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) {
        case .ok(p): { p } case .err(_): { assert(false); ir::empty() }
    };
}
fn void result(ref u8[] source, usize limit) {
    let ir::Program p = compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run_with_array_limit(ref p, 1000000, limit)) {
        case .ok(n): { n == 42 } case .err(_): { false }
    });
}

@test
fn void helper_local_arrays_and_copies_use_their_declaring_function() {
    let ir::Program p = compiled(b"module main; fn i32 f(){let i32[2] a=[21;2]; var i32[2] b=a; b=a; return b[0]+b[1];} fn i32 main(){return f();}");
    assert(p.entry == 1 && p.array_functions[0] == 0 && p.array_functions[1] == 0);
    assert(verifier::verify(ref p).is_ok);
    result(b"module main; fn i32 f(){let i32[2] a=[21;2]; var i32[2] b=a; b=a; return b[0]+b[1];} fn i32 main(){return f();}",16);
    result(b"module main; fn bool f(){var bool[1] a=[false;1]; a[0]=true; return a[0];} fn i32 main(){if(f()){return 42;} return 0;}",1);
    result(b"module main; fn u8 f(){let u8[1] a=[255;1]; return a[0];} fn i32 main(){if(f()==255){return 42;} return 0;}",1);
    result(b"module main; fn i64 f(){let i64[1] a=[-9223372036854775808;1]; return a[0];} fn i32 main(){if(f()==-9223372036854775808){return 42;} return 0;}",8);
    result(b"module main; fn u32 f(){let u32[1] a=[4294967295;1]; return a[0];} fn i32 main(){if(f()==4294967295){return 42;} return 0;}",4);
    result(b"module main; fn usize f(){let usize[1] a=[18446744073709551615;1]; return a[0];} fn i32 main(){if(f()==18446744073709551615){return 42;} return 0;}",8);
}

@test
fn void recursive_forward_and_mutual_calls_preserve_each_parent() {
    result(b"module main; fn i32 sum(i32 n){let i32[1] a=[n;1]; if(n==0){return a[0];} let i32 child=sum(n-1); return a[0]+child;} fn i32 main(){let i32[1] root=[36;1]; return root[0]+sum(3);}",20);
    result(b"module main; fn i32 main(){let i32[1] a=[21;1]; return f()+a[0];} fn i32 f(){let i32[1] a=[21;1]; return a[0];}",8);
    result(b"module main; fn i32 a(i32 n){let i32[1] own=[n;1]; if(n==0){return own[0];} return own[0]+b(n-1);} fn i32 b(i32 n){let i32[1] own=[n;1]; if(n==0){return own[0];} return own[0]+a(n-1);} fn i32 main(){return a(3)+36;}",16);
    result(b"module main; fn i32 f(){let i32[1] a=[21;1]; return a[0];} fn i32 main(){var i32 n=0; for(var i32 i=0;i<2;i=i+1){n=n+f();} return n;}",4);
}

@test
fn void helper_scope_loop_and_arm_exits_reclaim_temporary_arrays() {
    result(b"module main; fn i32 f(){var i32 n=0; while(n<42){let i32[1] a=[1;1]; n=n+a[0]; if(n<42){continue;} break;} return n;} fn i32 main(){return f();}",4);
    result(b"module main; fn usize f(){let u8[2] a=[0;2]; var usize n=0; for(var usize i=0;i<a.len;i=i+1){let bool[1] b=[true;1]; if(b[0]){n=n+1;}} return n;} fn i32 main(){if(f()==2){return 42;} return 0;}",3);
    result(b"module main; fn i32 f(){let Option<i32> o=.none; return switch(o){case .some(n):{n} case .none:{let i32[1] a=[42;1]; a[0]}};} fn i32 main(){return f();}",4);
}

@test
fn void propagation_failure_drops_all_visible_arrays_and_success_retains_them() {
    result(b"module main; fn Option<i32> f(Option<i32> x){let i32[1] a=[21;1]; {let i32[1] b=a; let i32 n=x?; return .some(a[0]+b[0]+n);}} fn i32 main(){switch(f(.some(0))){case .some(n):{return n;} case .none:{return 0;}}}",8);
    result(b"module main; fn Option<i32> f(Option<i32> x){let i32[1] a=[21;1]; {let i32[1] b=a; let i32 n=x?; return .some(a[0]+b[0]+n);}} fn i32 main(){var i32 n=0; while(n<42){switch(f(.none)){case .some(v):{return 0;} case .none:{n=n+1;}}} return n;}",8);
    result(b"module main; fn Result<bool,bool> f(Result<i32,bool> x){let i32[1] a=[42;1]; return .ok(x?==a[0]);} fn i32 main(){let i32[1] a=[21;1]; switch(f(.err(true))){case .ok(v):{return 0;} case .err(e):{if(e){return a[0]+21;} return 0;}}}",8);
    result(b"module main; fn Option<bool> f(Option<bool> x){let bool[1] a=[true;1]; return .some(false && x? || a[0]);} fn i32 main(){switch(f(.none)){case .some(v):{if(v){return 42;} return 0;} case .none:{return 0;}}}",1);
}

@test
fn void early_propagation_does_not_publish_initializers_or_pending_writes() {
    result(b"module main; fn Option<i32> f(Option<i32> x){let i32[1] a=[21;1]; let i32[1] b=[x?;1]; return .some(a[0]+b[0]);} fn i32 main(){var i32 n=0; while(n<42){switch(f(.none)){case .some(v):{return 0;} case .none:{n=n+1;}}} return n;}",4);
    result(b"module main; fn Option<i32> f(Option<i32> x){let i32[1] a=[21;1]; let i32[1] b=[x?;1]; return .some(a[0]+b[0]);} fn i32 main(){switch(f(.some(21))){case .some(v):{return v;} case .none:{return 0;}}}",8);
    result(b"module main; fn Option<i32> f(Option<i32> x){var i32[1] a=[0;1]; a[999]=x?; return .some(a[0]);} fn i32 main(){switch(f(.none)){case .some(v):{return 0;} case .none:{return 42;}}}",4);
    let ir::Program p = compiled(b"module main; fn Option<i32> f(Option<i32> x){let i32[1] a=[42;1]; return .some(x?+a[0]);} fn i32 main(){switch(f(.none)){case .some(v):{return 0;} case .none:{return 42;}}}");
    assert(verifier::verify(ref p).is_ok);
    var ir::Program bad = p;
    var usize pc = 0;
    while (pc < bad.ends[0] && bad.code[pc * 8] != 37) { pc += 1; }
    assert(pc < bad.ends[0]);
    bad.code[pc * 8] = 19;
    assert(ir::patch(ref mut bad, pc, pc + 1, 0).is_ok);
    assert(!verifier::verify(ref bad).is_ok);
}

@test
fn void helper_fuel_boundary_and_existing_source_exclusions_are_preserved() {
    let ir::Program p = compiled(b"module main; fn i32 f(){let i32[1] a=[42;1]; return a[0];} fn i32 main(){return f();}");
    assert(switch (vm::run_with_array_limit(ref p,164,4)) {case .ok(n):{n==42} case .err(_):{false}});
    assert(switch (vm::run_with_array_limit(ref p,163,4)) {case .ok(_):{false} case .err(e):{e.kind==8}});
    assert(!compiler::compile(b"module main; fn i32 f(){for(let i32[1] a=[0;1];false;){} return 0;} fn i32 main(){return f();}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 f(){let i32[1] a=[0;1]; return a;} fn i32 main(){return f();}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 f(){return a[0];} fn i32 main(){let i32[1] a=[42;1]; return f();}").is_ok);
}
