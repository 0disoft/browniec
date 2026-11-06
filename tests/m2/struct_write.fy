module tests::m2::struct_write;
import compiler as compiler;
import ir as ir;
import vm as vm;
import verifier as verifier;
fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void all_six_scalar_fields_accept_exact_typed_writes() {
    value(b"module main;struct All{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 main(){var All p=All{.a=false,.b=0,.c=0,.d=0,.e=0,.f=0};p.a=true;p.b=255;p.c=-2147483648;p.d=-9223372036854775808;p.e=4294967295;p.f=18446744073709551615;if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}");
}
@test
fn void rhs_runs_once_before_write_and_final_member_read_remains_a_value() {
    value(b"module main;struct P{i32 x;}fn i32 helper(i32 x){return x;}fn i32 main(){var P p=P{.x=0};var i32 calls=0;let Option<i32> f=.some(1);p.x=switch(f){case .some(_):{calls=calls+1;p.x=20;helper(p.x)+22}case .none:{0}};if(calls==1){return p.x;}return 0;}");
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};let Option<i32> f=.some(1);let i32 x=switch(f){case .some(_):{p.x=42;p.x}case .none:{0}};return x;}");
}
@test
fn void rhs_transfers_and_mixed_scopes_preserve_owner_lifetimes() {
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=40};var i32 n=0;let Option<i32> f=.some(1);while(n<2){let i32[1] a=[1;1];p.x=switch(f){case .some(_):{n=n+a[0];continue;}case .none:{0}};}p.x=p.x+2;return p.x;}");
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=40};let Option<i32> f=.some(1);p.x=switch(f){case .some(_):{return p.x+2;}case .none:{0}};return p.x;}");
    value(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=40};let Option<i32> f=.some(1);while(true){var P q=P{.x=0};q.x=switch(f){case .some(_):{break;}case .none:{0}};}p.x=p.x+2;return p.x;}");
}
@test
fn void exact_fuel_uses_existing_payload_without_a_second_extent() {
    let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x=42;return p.x;}");
    assert(p.records.count==1 && p.arrays.count==0);
    assert(switch(vm::run_with_array_limit(ref p,174658,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,174657,4)){case .err(e):{e.kind==8}case .ok(_):{false}});
}
@test
fn void immutable_wrong_type_unknown_field_and_for_header_writes_fail() {
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=0};p.x=42;return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x=true;return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.missing=42;return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};for(p.x=1;false;){}return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};for(;false;p.x=1){}return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p.x.y=42;return p.x;}").is_ok);
}
