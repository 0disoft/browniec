module tests::m2::array_utf8_temporary_computed_ranges;
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
fn void calls_and_literals_accept_computed_endpoints_and_defaults() {
    value(b"module main;fn u8[6] make(){var u8[6] a=[255;6];a[1]=240;a[2]=159;a[3]=141;a[4]=171;return a;}fn usize end(){return 5;}fn i32 main(){if(text::valid_utf8(make()[1+0..end()]) && !text::valid_utf8(make()[2+0..end()]) && text::valid_utf8(make()[6+0..]) && !text::valid_utf8(make()[..end()])){return 42;}return 0;}",6);
    value(b"module main;fn usize end(){return 4096;}fn bool valid(usize lo){return text::valid_utf8([65;4096][lo+1..end()]);}fn i32 main(){if(valid(255) && text::valid_utf8([255;4096][end()..]) && text::valid_utf8([65;4096][..end()])){return 42;}return 0;}",4096);
    value(b"module main;struct P{usize lo;usize hi;}fn u8[2] make(){return [65;2];}fn i32 main(){let P p=P{.lo=0,.hi=2};let u8 lo=0;if(text::valid_utf8(make()[p.lo..p.hi]) && text::valid_utf8([65;2][lo as usize..(2)])){return 42;}return 0;}",32);
}

@test
fn void construction_precedes_once_only_ordered_bounds_and_cleanup_reuses_capacity() {
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{n=n*10+1;255}};1][switch(o){case .some(v):{1}case .none:{n=n*10+2;1}}..switch(o){case .some(v):{1}case .none:{n=n*10+3;1}}]);if(b && n==123){return 42;}return 0;}",1);
    value(b"module main;fn u8[1] make(i32 n){return [255;1];}fn i32 main(){var i32 n=0;let Option<i32> o=.none;let bool b=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{n=n*10+1;0}})[switch(o){case .some(v):{1}case .none:{n=n*10+2;1}}..switch(o){case .some(v):{1}case .none:{n=n*10+3;1}}]);if(b && n==123){return 42;}return 0;}",1);
    value(b"module main;fn i32 main(){var usize lo=0;let Option<i32> o=.none;let bool b=text::valid_utf8([255;2][lo+0..switch(o){case .some(v):{1}case .none:{lo=1;1}}]);if(!b && lo==1){return 42;}return 0;}",2);
    value(b"module main;fn u8[1] make(){return [65;1];}fn usize bound(bool b){if(b){return 1;}return 0;}fn i32 main(){var i32 n=0;while(n<42){if(text::valid_utf8(make()[0..bound(text::valid_utf8([65;1][0+0..1]))])){n=n+1;continue;}break;}return n;}",2);
    let ir::Program p=compiled(b"module main;fn u8[1] make(){return [65;1];}fn usize bound(bool b){return 1;}fn i32 main(){if(text::valid_utf8(make()[0..bound(text::valid_utf8([65;1][0+0..1]))])){return 42;}return 0;}");
    assert(switch(vm::run_with_array_limit(ref p,1000000,1)){case .ok(_):{false}case .err(e):{e.kind==13}});
}

@test
fn void endpoint_exits_drop_published_temporaries_in_reverse_order() {
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let bool b=text::valid_utf8([65;1][switch(o){case .some(v):{0}case .none:{return 42;}}..1]);return 0;}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let Option<i32> o=.none;let bool b=text::valid_utf8(make()[0..switch(o){case .some(v):{1}case .none:{return 42;}}]);return 0;}",1);
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let bool b=text::valid_utf8([65;1][0..switch(o){case .some(v):{1}case .none:{n=n+1;continue;}}]);}return n+40;}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let bool b=text::valid_utf8(make()[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}..1]);}return n+40;}",1);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;while(true){let bool b=text::valid_utf8([65;1][0..switch(o){case .some(v):{1}case .none:{break;}}]);}if(text::valid_utf8([65;1][0+0..1])){return 42;}return 0;}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let Option<i32> o=.none;while(true){let bool b=text::valid_utf8(make()[switch(o){case .some(v):{0}case .none:{break;}}..1]);}if(text::valid_utf8(make()[0+0..1])){return 42;}return 0;}",1);
    value(b"module main;fn Option<i32> f(Option<i32> o){let bool b=text::valid_utf8([65;1][0..switch(o){case .some(v):{1}case .none:{let i32 n=o?;0}}]);return .some(42);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn Option<i32> f(Option<i32> o){let bool b=text::valid_utf8(make()[switch(o){case .some(v):{0}case .none:{let i32 n=o?;0}}..1]);return .some(42);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn usize bound(bool b){return 1;}fn i32 main(){let Option<i32> o=.none;let bool b=text::valid_utf8(make()[0..bound(text::valid_utf8(make()[0..switch(o){case .some(v):{1}case .none:{return 42;}}]))]);return 0;}",2);
    value(b"module main;struct P{i32 x;}fn i32 take(P p,bool b){return p.x;}fn u8[1] make(){return [65;1];}fn i32 main(){let Option<i32> o=.none;return take(P{.x=0},text::valid_utf8(make()[0..switch(o){case .some(v):{1}case .none:{return 42;}}]));}",8);
    value(b"module main;fn usize fail(){return 1/0;}fn u8[4096] make(){return [65;4096];}fn i32 main(){if(false && text::valid_utf8(make()[0..fail()])){return 0;}if(true || text::valid_utf8([65;4096][0..fail()])){return 42;}return 0;}",0);
}

fn void error(ref u8[] source,u8 kind) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(_):{false}case .err(e):{e.kind==kind}});
}
fn void fuel(ref u8[] source,usize exact) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=53){pc+=1;}assert(pc<p.count);
    assert(p.code[(pc+1)*8]==37 && p.code[(pc+1)*8+1]==p.code[pc*8+2]);
    assert(switch(vm::run_with_array_limit(ref p,exact,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,exact-1,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,exact-52,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==p.offsets[pc]}});
    var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
    assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok && !verifier::verify(ref bad).is_ok);
}
@test
fn void bounds_arithmetic_errors_and_fuel_keep_existing_vm_rules() {
    error(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;4][0+0..5]);return 42;}",14);
    error(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let usize hi=18446744073709551615;let bool b=text::valid_utf8(make()[0..hi+0]);return 42;}",14);
    error(b"module main;fn i32 main(){let usize hi=18446744073709551615;let bool b=text::valid_utf8([65;4][0..hi+1]);return 42;}",6);
    error(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let bool b=text::valid_utf8(make()[0..1/0]);return 42;}",7);
    fuel(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;4][0+0..4]);return 42;}",204);
    fuel(b"module main;fn i32 main(){let bool b=text::valid_utf8([255;4][4+0..4]);return 42;}",204);
    fuel(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let bool b=text::valid_utf8(make()[0+0..4]);return 42;}",270);
    fuel(b"module main;fn u8[4] make(){return [255;4];}fn i32 main(){let bool b=text::valid_utf8(make()[4+0..4]);return 42;}",270);
}

@test
fn void wrong_types_and_escaping_views_remain_rejected() {
    rejected(b"module main;fn u32 end(){return 1;}fn i32 main(){let bool b=text::valid_utf8([65;1][0..end()]);return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let bool b=text::valid_utf8(make()[0..(true)]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;1][0..1+)]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;1][0+0..1][..]);return 0;}");
    rejected(b"module main;fn i32 main(){let ref u8[] v=ref [65;1][0+0..1];return 0;}");
}
