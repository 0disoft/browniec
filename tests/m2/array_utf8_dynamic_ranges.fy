module tests::m2::array_utf8_dynamic_ranges;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
}
fn void value(ref u8[] source,usize limit) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,limit)){case .ok(n):{n==42}case .err(_):{false}});
}
fn void rejected(ref u8[] source) {assert(!compiler::compile(source).is_ok);}

@test
fn void names_parameters_and_mixed_omitted_bounds_scan_live_arrays() {
    value(b"module main;fn i32 main(){var u8[5] a=[255;5];a[1]=194;a[2]=128;let usize lo=1;let usize hi=3;if(text::valid_utf8(a[lo..hi]) && !text::valid_utf8(a[0..hi]) && !text::valid_utf8(a[lo..]) && !text::valid_utf8(a[..hi]) && text::valid_utf8(a[hi..hi])){return 42;}return 0;}",5);
    value(b"module main;fn bool valid(u8[2] a,usize lo,usize hi){return text::valid_utf8(a[lo..hi]);}fn u8[2] make(){return [65;2];}fn i32 main(){let u8[2] a=make();if(valid(a,0,2) && a[1]==65){return 42;}return 0;}",4);
    value(b"module main;fn i32 main(){let u8[4096] a=[65;4096];let usize lo=256;let usize hi=a.len;if(text::valid_utf8(a[lo..hi]) && text::valid_utf8(a[..hi]) && text::valid_utf8(a[lo..])){return 42;}return 0;}",4096);
}

@test
fn void mutable_names_reload_in_loops_and_short_circuit_skips_invalid_bounds() {
    value(b"module main;fn i32 main(){var u8[2] a=[255;2];a[0]=65;var usize lo=0;var usize hi=1;if(!text::valid_utf8(a[lo..hi])){return 0;}lo=1;hi=2;if(text::valid_utf8(a[lo..hi])){return 0;}a[1]=0;if(text::valid_utf8(a[lo..hi]) && a[0]==65){return 42;}return 0;}",2);
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];var i32 n=0;while(n<42){var usize hi=0;hi=1;if(text::valid_utf8(a[..hi])){n=n+1;continue;}break;}return n;}",1);
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];let usize lo=18446744073709551615;if(false && text::valid_utf8(a[lo..])){return 0;}if(true || text::valid_utf8(a[..lo])){return 42;}return 0;}",1);
    value(b"module main;fn bool valid(i32 n,usize hi){let u8[1] a=[65;1];if(n==0){return text::valid_utf8(a[..hi]);}return valid(n-1,hi) && text::valid_utf8(a[hi..]);}fn i32 main(){if(valid(3,1)){return 42;}return 0;}",4);
}

fn void bounds(ref u8[] source) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=53){pc+=1;}assert(pc<p.count);
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(_):{false}case .err(e):{e.kind==14 && e.offset==p.offsets[pc]}});
}
@test
fn void runtime_rejects_reversed_outside_and_full_unsigned_bounds() {
    bounds(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize lo=3;let usize hi=1;let bool b=text::valid_utf8(a[lo..hi]);return 42;}");
    bounds(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize hi=5;let bool b=text::valid_utf8(a[..hi]);return 42;}");
    bounds(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize hi=18446744073709551615;let bool b=text::valid_utf8(a[0..hi]);return 42;}");
    bounds(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize lo=9223372036854775808;let bool b=text::valid_utf8(a[lo..]);return 42;}");
}

fn void fuel(ref u8[] source) {
    let ir::Program p=compiled(source);var usize pc=0;while(pc<p.count && p.code[pc*8]!=53){pc+=1;}assert(pc<p.count);
    assert(switch(vm::run_with_array_limit(ref p,202,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,201,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,150,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==p.offsets[pc]}});
    assert(p.arrays.count==1);
}
@test
fn void full_partial_and_empty_ranges_prepay_root_cost_without_an_owner_copy() {
    fuel(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize lo=0;let usize hi=4;let bool b=text::valid_utf8(a[lo..hi]);return 42;}");
    fuel(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize lo=1;let usize hi=3;let bool b=text::valid_utf8(a[lo..hi]);return 42;}");
    fuel(b"module main;fn i32 main(){let u8[4] a=[255;4];let usize lo=4;let usize hi=4;let bool b=text::valid_utf8(a[lo..hi]);return 42;}");
}

@test
fn void only_in_scope_usize_names_are_dynamic_and_other_types_are_rejected() {
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let i32 lo=0;let bool b=text::valid_utf8(a[lo..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let usize[1] lo=[0;1];let bool b=text::valid_utf8(a[lo..1]);return 0;}");
    rejected(b"module main;fn bool test(usize[1] lo){let u8[1] a=[65;1];return text::valid_utf8(a[lo..1]);}fn i32 main(){return 0;}");
    rejected(b"module main;struct P{usize x;}fn i32 main(){let u8[1] a=[65;1];let P lo=P{.x=0};let bool b=text::valid_utf8(a[lo..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];{let usize lo=0;}let bool b=text::valid_utf8(a[lo..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[missing..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let usize lo=0;let bool b=text::valid_utf8(a[lo+0..(1]);return 0;}");
    rejected(b"module main;fn u32 end(){return 1;}fn i32 main(){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..end()]);return 0;}");
    rejected(b"module main;fn i32 main(){let u32 hi=1;let bool b=text::valid_utf8([65;1][..hi]);return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let u32 hi=1;let bool b=text::valid_utf8(make()[0..hi]);return 0;}");
}
