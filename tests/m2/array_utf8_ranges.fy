module tests::m2::array_utf8_ranges;
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
fn void literal_ranges_lower_without_an_extra_array_owner_or_scalar_endpoint_registers() {
    let ir::Program p = compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool valid=text::valid_utf8(a[1..3]);return 42;}");
    assert(p.count == 6 && p.arrays.count == 1 && p.registers == 3);
    assert(p.code[16] == 52 && p.code[18] == 0 && p.code[19] == 0);
    assert(p.code[20] == 1 && p.code[21] == 0 && p.code[22] == 3 && p.code[23] == 0);
    assert(p.types[p.code[17] as usize] == 2 && p.code[32] == 37 && p.code[40] == 8);
    assert(switch(vm::run_with_array_limit(ref p,192,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}

@test
fn void selected_boundaries_preserve_source_and_work_in_calls_scopes_and_recursion() {
    value(b"module main;fn i32 main(){var u8[6] a=[255;6];a[1]=240;a[2]=159;a[3]=141;a[4]=171;if(text::valid_utf8(a[1..5]) && !text::valid_utf8(a[1..4]) && !text::valid_utf8(a[2..5]) && !text::valid_utf8(a[0..6]) && text::valid_utf8(a[6..6])){return 42;}return 0;}", 6);
    value(b"module main;fn i32 main(){var u8[1] a=[255;1];let bool before=text::valid_utf8(a[0..1]);a[0]=0;if(!before && text::valid_utf8(a[0..1]) && a[0]==0){return 42;}return 0;}", 1);
    value(b"module main;fn bool valid(u8[2] a){return text::valid_utf8(a[1..2]);}fn u8[2] make(){return [65;2];}fn i32 main(){let u8[2] a=make();if(valid(a) && text::valid_utf8(a[0..2])){return 42;}return 0;}", 4);
    value(b"module main;fn bool check(i32 n){let u8[1] a=[65;1];if(n==0){return text::valid_utf8(a[0..1]);}return check(n-1) && text::valid_utf8(a[1..1]);}fn i32 main(){if(check(3)){return 42;}return 0;}", 4);
    value(b"module main;fn i32 main(){var i32 n=0;while(n<42){let u8[1] a=[65;1];if(text::valid_utf8(a[0..1])){n=n+1;continue;}break;}return n;}", 1);
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];{let u8[2] b=[255;2];if(text::valid_utf8(b[0..1])){return 0;}}if(text::valid_utf8(a[0..1])){return 42;}return 0;}", 3);
    value(b"module main;fn i32 main(){let u8[4096] a=[65;4096];if(text::valid_utf8(a[256..4096]) && text::valid_utf8(a[4096..4096])){return 42;}return 0;}", 4096);
}

@test
fn void ranges_require_named_u8_arrays_and_valid_static_bounds() {
    rejected(b"module main;fn i32 main(){let i32[1] a=[0;1];let bool b=text::valid_utf8(a[0..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8 a=0;let bool b=text::valid_utf8(a[0..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[2] a=[0;2];let bool b=text::valid_utf8(a[2..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[2] a=[0;2];let bool b=text::valid_utf8(a[0..3]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[-1..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[0..18446744073709551615]);return 0;}");
    rejected(b"module main;fn i32 main(){let u32 start=0;let u8[1] a=[0;1];let bool b=text::valid_utf8(a[start..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[0...]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[...1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[0..1],a);return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let bool b=text::valid_utf8(make()[0..1][0..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;1][0..1][0..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let ref u8[] v=ref a[0..1];return 0;}");
}

fn void fuel(ref u8[] source,usize n,usize exact,usize pre_scan) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run_with_array_limit(ref p,exact,n)){case .ok(v):{v==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,exact-1,n)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,pre_scan,n)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==p.offsets[2]}});
}
@test
fn void exact_fuel_depends_on_selected_length_and_preserves_intrinsic_offsets() {
    fuel(b"module main;fn i32 main(){let u8[1] a=[255;1];let bool b=text::valid_utf8(a[1..1]);return 42;}",1,178,126);
    fuel(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[1..3]);return 42;}",4,192,140);
    fuel(b"module main;fn i32 main(){let u8[4096] a=[255;4096];let bool b=text::valid_utf8(a[4095..4096]);return 42;}",4096,8372,8320);
}
