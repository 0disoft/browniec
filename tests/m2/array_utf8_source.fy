module tests::m2::array_utf8_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } };
}
fn void value(ref u8[] source, usize limit) {
    let ir::Program p = compiled(source);
    assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run_with_array_limit(ref p, 1000000, limit)) { case .ok(n): { n == 42 } case .err(_): { false } });
}
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }

@test
fn void named_arrays_validate_ascii_nul_multibyte_and_invalid_encodings() {
    value(b"module main;fn i32 main(){let u8[1] a=[0;1];if(text::valid_utf8(a)){return 42;}return 0;}", 1);
    value(b"module main;fn i32 main(){let u8[4096] a=[65;4096];if(text::valid_utf8(a)){return 42;}return 0;}", 4096);
    value(b"module main;fn i32 main(){var u8[4] a=[0;4];a[0]=240;a[1]=159;a[2]=152;a[3]=128;if(text::valid_utf8(a)){return 42;}return 0;}", 4);
    value(b"module main;fn i32 main(){let u8[1] a=[255;1];if(!text::valid_utf8(a)){return 42;}return 0;}", 1);
    value(b"module main;fn i32 main(){var u8[2] a=[128;2];a[0]=192;if(!text::valid_utf8(a)){return 42;}return 0;}", 2);
}

@test
fn void lowering_emits_one_predicate_without_an_array_copy_or_extra_owner() {
    let ir::Program p = compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool valid=text::valid_utf8(a);return 42;}");
    assert(p.count == 6 && p.arrays.count == 1);
    assert(p.code[16] == 51 && p.code[18] == 0 && p.code[19] == 0 && p.types[p.code[17] as usize] == 2);
    assert(p.code[32] == 37 && p.code[40] == 8);
    assert(switch (vm::run_with_array_limit(ref p, 168, 4)) { case .ok(n): { n == 42 } case .err(_): { false } });
    assert(switch (vm::run_with_array_limit(ref p, 1000000, 3)) { case .ok(_): { false } case .err(e): { e.kind == 13 } });
}

@test
fn void mutable_arrays_remain_live_and_scans_observe_current_bytes() {
    value(b"module main;fn bool keep(bool b){return b;}fn i32 main(){var u8[1] a=[65;1];let bool before=text::valid_utf8(a);a[0]=255;let bool bad=text::valid_utf8(a);a[0]=0;if(keep(before) && !bad && text::valid_utf8(a) && a[0]==0){return 42;}return 0;}", 1);
    value(b"module main;fn i32 main(){var i32 n=0;while(n<42){let u8[1] a=[65;1];if(text::valid_utf8(a)){n=n+1;continue;}break;}return n;}", 1);
    value(b"module main;fn bool valid(u8[1] a){return text::valid_utf8(a);}fn u8[1] make(){return [65;1];}fn i32 main(){let u8[1] a=make();if(valid(a) && text::valid_utf8(a)){return 42;}return 0;}", 2);
    value(b"module main;fn bool check(i32 n){let u8[1] a=[65;1];if(n==0){return text::valid_utf8(a);}return check(n-1) && text::valid_utf8(a);}fn i32 main(){if(check(3)){return 42;}return 0;}", 4);
}

@test
fn void names_types_scope_and_argument_grammar_remain_explicit() {
    value(b"module main;fn i32 text(){return 42;}fn i32 main(){let u8[1] a=[0;1];if(text::valid_utf8(a)){return text();}return 0;}", 1);
    value(b"module main;fn i32 main(){let i32 text=42;let u8[1] a=[0;1];if(text::valid_utf8(a)){return text;}return 0;}", 1);
    rejected(b"module main;fn i32 main(){let bool[1] a=[true;1];let bool b=text::valid_utf8(a);return 0;}");
    rejected(b"module main;fn i32 main(){let u8 a=0;let bool b=text::valid_utf8(a);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];return text::valid_utf8(a);}");
    rejected(b"module main;fn i32 main(){{let u8[1] a=[0;1];}let bool b=text::valid_utf8(a);return 0;}");
    rejected(b"module main;fn u8[1] make(){return [0;1];}fn i32 main(){let bool b=text::valid_utf8(make());return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a,a);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8();return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::unknown(a);return 0;}");
}

@test
fn void exact_source_fuel_and_short_budget_report_the_intrinsic_offset() {
    let ir::Program p = compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool valid=text::valid_utf8(a);return 42;}");
    assert(switch (vm::run_with_array_limit(ref p, 167, 4)) { case .ok(_): { false } case .err(e): { e.kind == 8 } });
    assert(switch (vm::run_with_array_limit(ref p, 116, 4)) { case .ok(_): { false } case .err(e): { e.kind == 8 && e.offset == p.offsets[2] } });
    assert(switch (vm::run_with_array_limit(ref p, 168, 4)) { case .ok(n): { n == 42 } case .err(_): { false } });
}
