module tests::m2::array_utf8_open_ranges;
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
fn void defaults_select_full_prefix_suffix_and_empty_ranges_on_every_source_form() {
    value(b"module main;fn i32 main(){var u8[3] a=[255;3];a[0]=65;a[1]=0;if(!text::valid_utf8(a[..]) && text::valid_utf8(a[..2]) && !text::valid_utf8(a[2..]) && text::valid_utf8(a[..0]) && text::valid_utf8(a[3..])){return 42;}return 0;}",3);
    value(b"module main;fn u8[3] make(){var u8[3] a=[255;3];a[0]=65;a[1]=0;return a;}fn i32 main(){if(!text::valid_utf8(make()[..]) && text::valid_utf8(make()[..2]) && !text::valid_utf8(make()[2..]) && text::valid_utf8(make()[3..])){return 42;}return 0;}",3);
    value(b"module main;fn i32 main(){if(text::valid_utf8([65;4096][..]) && !text::valid_utf8([255;2][..1]) && !text::valid_utf8([255;2][1..]) && text::valid_utf8([255;2][..0])){return 42;}return 0;}",4096);
    value(b"module main;fn bool valid(u8[1] a){return text::valid_utf8(a[..]);}fn u8[1] make(){return [65;1];}fn i32 main(){let u8[1] a=make();if(valid(a) && text::valid_utf8(a[0..])){return 42;}return 0;}",2);
    value(b"module main;fn i32 main(){var i32 n=0;while(n<42){let u8[1] a=[65;1];if(text::valid_utf8(a[..1]) && text::valid_utf8([65;1][..])){n=n+1;continue;}break;}return n;}",2);
}

fn void same(ref u8[] a,ref u8[] b) {
    let ir::Program x=compiled(a);let ir::Program y=compiled(b);
    assert(x.count==y.count && x.registers==y.registers && x.constant_count==y.constant_count && x.arrays.count==y.arrays.count);
    var usize i=0;while(i<x.count*8){assert(x.code[i]==y.code[i]);i+=1;}
    i=0;while(i<x.registers){assert(x.types[i]==y.types[i] && x.slots[i]==y.slots[i]);i+=1;}
    i=0;while(i<x.constant_count){assert(x.constants[i]==y.constants[i]);i+=1;}
    i=0;while(i<x.arrays.count){assert(x.arrays.elements[i]==y.arrays.elements[i] && x.arrays.lengths[i]==y.arrays.lengths[i] && x.array_functions[i]==y.array_functions[i]);i+=1;}
}
@test
fn void omitted_endpoints_emit_identical_code_and_registers_to_explicit_endpoints() {
    same(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[..]);return 42;}",b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[0..4]);return 42;}");
    same(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;4][..2]);return 42;}",b"module main;fn i32 main(){let bool b=text::valid_utf8([65;4][0..2]);return 42;}");
    same(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let bool b=text::valid_utf8(make()[2..]);return 42;}",b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let bool b=text::valid_utf8(make()[2..4]);return 42;}");
}

@test
fn void open_ranges_preserve_temporary_evaluation_cleanup_and_short_circuiting() {
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{n=n+1;255}};4][4..]);if(b && n==1){return 42;}return 0;}",4);
    value(b"module main;fn u8[1] make(){return [65;1];}fn u8[1] wrap(bool b){return make();}fn i32 main(){if(text::valid_utf8(wrap(text::valid_utf8(make()[..]))[..1])){return 42;}return 0;}",1);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{return 42;}};4096][..]);return 0;}",0);
    value(b"module main;fn u8[4096] make(){return [65;4096];}fn i32 main(){if(false && text::valid_utf8(make()[..])){return 0;}if(true || text::valid_utf8([255;4096][..])){return 42;}return 0;}",0);
}

fn void fuel(ref u8[] source,usize exact) {
    let ir::Program p=compiled(source);var usize pc=0;while(pc<p.count && p.code[pc*8]!=52){pc+=1;}
    assert(pc<p.count);
    assert(switch(vm::run_with_array_limit(ref p,exact,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,exact-1,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,exact-52,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==p.offsets[pc]}});
}
@test
fn void inferred_bounds_keep_exact_fuel_and_reject_reversed_or_malformed_ranges() {
    fuel(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[..]);return 42;}",200);
    fuel(b"module main;fn i32 main(){let bool b=text::valid_utf8([255;4][4..]);return 42;}",184);
    fuel(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let bool b=text::valid_utf8(make()[..2]);return 42;}",258);
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[..2]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;1][2..]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[...]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let bool b=text::valid_utf8(a[..-1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[0;1];let u32 n=1;let bool b=text::valid_utf8(a[..n]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;1][..][..]);return 0;}");
}
