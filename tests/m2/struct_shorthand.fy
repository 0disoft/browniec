module tests::m2::struct_shorthand;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) {
        case .ok(p): { p }
        case .err(_): { assert(false); ir::empty() }
    };
}
fn void value(ref u8[] source) {
    let ir::Program p = compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run(ref p, 1000000)) {
        case .ok(n): { n == 42 }
        case .err(_): { false }
    });
}

@test
fn void scalar_shorthand_is_same_name_typed_and_snapshotted() {
    value(b"module main;struct All{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn i32 main(){var bool a=true;var u8 b=255;var i32 c=-2147483648;var i64 d=-9223372036854775808;var u32 e=4294967295;var usize f=18446744073709551615;let All p=All{.a,.b,.c,.d,.e,.f,};a=false;b=0;c=0;d=0;e=0;f=0;if(p.a && p.b==255 && p.c==-2147483648 && p.d==-9223372036854775808 && p.e==4294967295 && p.f==18446744073709551615){return 42;}return 0;}");
    value(b"module main;struct P{i32 x;i32 y;i32 z;}fn i32 main(){var i32 x=20;var i32 z=1;let P p=P{.x,.y=21,.z};x=0;z=0;return p.x+p.y+p.z;}");
}

@test
fn void plain_record_shorthand_copies_independent_values() {
    value(b"module main;struct I{i32 x;i32 y;}struct R{I pair;i32 tail;}fn i32 main(){var I pair=I{.x=20,.y=0};var i32 tail=0;let R first=R{.pair,.tail};pair.x=22;let R second=R{.pair,.tail};pair.x=0;tail=1;return first.pair.x+second.pair.x;}");
    value(b"module main;struct I{i32 x;i32 y;}struct R{I pair;i32 tail;}fn i32 main(){var i32 x=20;var i32 y=21;var i32 tail=1;let R p=R{.pair=I{.x,.y},.tail};x=0;y=0;tail=0;return p.pair.x+p.pair.y+p.tail;}");
}

@test
fn void calls_assignments_and_returns_share_exact_staging() {
    value(b"module main;struct P{i32 x;i32 y;}fn i32 take(P p){return p.x+p.y;}fn i32 main(){var i32 x=20;var i32 y=22;return take(P{.x,.y});}");
    value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var i32 x=20;var i32 y=22;var P p=P{.x=0,.y=0};p=P{.x,.y};x=0;y=0;return p.x+p.y;}");
    value(b"module main;struct P{i32 x;i32 y;}fn P make(i32 x,i32 y){return P{.x,.y};}fn i32 main(){let P p=make(20,22);return p.x+p.y;}");
}

@test
fn void order_types_names_and_missing_fields_stay_rejected() {
    assert(!compiler::compile(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var i32 y=1;var i32 x=2;let P p=P{.y,.x};return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var bool x=true;let P p=P{.x};return 0;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x};return 0;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var i32 x=1;let P p=P{.x};return p.x;}").is_ok);
    assert(!compiler::compile(b"module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){var J i=J{.x=42};let R p=R{.i};return 0;}").is_ok);
    assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 main(){var i32 x=42;let P p=P{.x true};return p.x;}").is_ok);
    value(b"module main;struct P{i32 x;}fn i32 main(){let P p=P{.x=42};return p.x;}");
}
