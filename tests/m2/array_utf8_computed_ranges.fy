module tests::m2::array_utf8_computed_ranges;
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
fn void named_bounds_accept_arithmetic_calls_fields_indices_casts_and_defaults() {
    value(b"module main;fn usize start(){return 1;}fn usize end(){return 3;}fn i32 main(){var u8[5] a=[255;5];a[1]=194;a[2]=128;let usize lo=0;if(text::valid_utf8(a[lo+1..a.len-2]) && text::valid_utf8(a[start()..end()]) && !text::valid_utf8(a[..end()]) && !text::valid_utf8(a[start()..])){return 42;}return 0;}",5);
    value(b"module main;struct P{usize lo;usize hi;}fn i32 main(){let P p=P{.lo=0,.hi=2};let usize[1] ends=[2;1];let u8[2] a=[65;2];if(text::valid_utf8(a[p.lo..p.hi]) && text::valid_utf8(a[0..ends[0]])){return 42;}return 0;}",64);
    value(b"module main;fn i32 main(){let u8[2] a=[65;2];let u8 lo=0;if(text::valid_utf8(a[lo as usize..a.len]) && text::valid_utf8(a[(0)..(2)]) && text::valid_utf8(a[0+0..])){return 42;}return 0;}",2);
}

@test
fn void endpoints_evaluate_once_left_to_right_before_scanning() {
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];var i32 n=0;let Option<i32> o=.none;let bool b=text::valid_utf8(a[switch(o){case .some(v):{0}case .none:{n=n+1;0}}..switch(o){case .some(v):{1}case .none:{n=n+1;1}}]);if(b && n==2){return 42;}return 0;}",1);
    value(b"module main;fn i32 main(){let u8[2] a=[255;2];var usize lo=0;let Option<i32> o=.none;let bool b=text::valid_utf8(a[lo+0..switch(o){case .some(v):{1}case .none:{lo=1;1}}]);if(!b && lo==1){return 42;}return 0;}",2);
    value(b"module main;fn i32 main(){var u8[1] a=[65;1];let Option<i32> o=.none;let bool b=text::valid_utf8(a[0+0..switch(o){case .some(v):{1}case .none:{a[0]=255;1}}]);if(!b && a[0]==255){return 42;}return 0;}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn usize bound(bool b){if(b){return 1;}return 0;}fn i32 main(){let u8[1] a=[65;1];var i32 n=0;while(n<42){if(text::valid_utf8(a[0..bound(text::valid_utf8(make()[..]))])){n=n+1;continue;}break;}return n;}",2);
}

@test
fn void endpoint_exits_clean_named_roots_and_short_circuit_skips_expressions() {
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];let Option<i32> o=.none;let bool b=text::valid_utf8(a[switch(o){case .some(v):{0}case .none:{return 42;}}..1]);return 0;}",1);
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..switch(o){case .some(v):{1}case .none:{n=n+1;continue;}}]);}return n+40;}",1);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;while(true){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..switch(o){case .some(v):{1}case .none:{break;}}]);}return 42;}",1);
    value(b"module main;fn Option<i32> f(Option<i32> o){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..switch(o){case .some(v):{1}case .none:{let i32 n=o?;0}}]);return .some(42);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn usize fail(){return 1/0;}fn i32 main(){let u8[1] a=[65;1];if(false && text::valid_utf8(a[0..fail()])){return 0;}if(true || text::valid_utf8(a[0..fail()])){return 42;}return 0;}",1);
}

fn void error(ref u8[] source,u8 kind) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(_):{false}case .err(e):{e.kind==kind}});
}
@test
fn void computed_bounds_use_checked_arithmetic_runtime_bounds_and_existing_fuel() {
    error(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[0..a.len+1]);return 42;}",14);
    error(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize hi=18446744073709551615;let bool b=text::valid_utf8(a[0..hi+0]);return 42;}",14);
    error(b"module main;fn i32 main(){let u8[4] a=[65;4];let usize hi=18446744073709551615;let bool b=text::valid_utf8(a[0..hi+1]);return 42;}",6);
    error(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[0..1/0]);return 42;}",7);
    error(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[1-2..4]);return 42;}",6);
    let ir::Program p=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a[0+0..4]);return 42;}");
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=53){pc+=1;}assert(pc<p.count && p.arrays.count==1);
    assert(switch(vm::run_with_array_limit(ref p,204,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,203,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,152,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==p.offsets[pc]}});
}

@test
fn void wrong_types_malformed_temporary_expressions_and_escaping_views_are_rejected() {
    rejected(b"module main;fn u32 end(){return 1;}fn i32 main(){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..end()]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..true]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..(true)]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let bool b=text::valid_utf8(a[0..(missing)]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;1][0..1+)]);return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let bool b=text::valid_utf8(make()[0+0..(1]);return 0;}");
    rejected(b"module main;struct P{usize lo;}fn i32 main(){let P p=P{.lo=0};let u8[1] a=[65;1];let bool b=text::valid_utf8(a[p.lo.bad..1]);return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] v=ref a[0+0..1];return 0;}");
}
