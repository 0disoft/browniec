module tests::m2::struct_values;
import compiler as compiler;
import ir as ir;
import vm as vm;
import verifier as verifier;
fn ir::Program compiled(ref u8[] text) {
    return switch (compiler::compile(text)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } };
}
fn void value(ref u8[] text) {
    let ir::Program p = compiled(text);
    assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run(ref p,1000000)) { case .ok(n): { n == 42 } case .err(_): { false } });
}
@test
fn void six_scalar_fields_are_typed_and_complete() {
    value(b"module main;struct All{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 main(){let All p=All{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615,};if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}");
}
@test
fn void initializer_snapshots_precede_publication_and_calls_preserve_owners() {
    value(b"module main;struct Pair{i32 x;i32 y;}fn i32 helper(i32 x){return x;}fn i32 main(){var i32 n=20;let Option<i32> f=.some(1);let Pair p=Pair{.x=n,.y=switch(f){case .some(_):{n=22;n}case .none:{0}}};return helper(p.x)+p.y;}");
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=p.x};return p.x;}").is_ok);
}
@test
fn void lexical_loop_and_mixed_aggregate_cleanup_use_one_reverse_order() {
    value(b"module main;struct P{i32 x;}fn i32 main(){let P outer=P{.x=40};var i32 n=0;while(n<3){let i32[1] a=[1;1];let P inner=P{.x=a[0]};n=n+inner.x;if(n<3){continue;}break;}let i32[1] b=[2;1];if(true){let P tail=P{.x=b[0]};return outer.x+tail.x;}return 0;}");
    value(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};{var P q=P{.x=1};}return p.x;}");
}
@test
fn void exact_fuel_and_payload_bounds_are_preserved() {
    let ir::Program p=compiled(b"module main;struct Pair{i32 x;i32 y;}fn i32 main(){let Pair p=Pair{.x=20,.y=22};return p.x+p.y;}");
    assert(p.records.count==1 && p.records.layouts.count==1);
    assert(switch(vm::run_with_array_limit(ref p,128789,8)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,128788,8)){case .err(e):{e.kind==8}case .ok(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void unsupported_aggregate_operations_and_partial_initializers_fail() {
    assert(!compiler::compile(b"module main;struct P{i32 x;i32 y;}fn i32 main(){let P p=P{.x=1};return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;i32 y;}fn i32 main(){let P p=P{.y=1,.x=2};return p.x;}").is_ok);
    value(b"module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};return p.x;}fn i32 main(){return helper();}");
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};p.x=1;return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){for(let P p=P{.x=42};false;){}return 42;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return main();}").is_ok);
}
