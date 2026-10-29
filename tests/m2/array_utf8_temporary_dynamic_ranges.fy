module tests::m2::array_utf8_temporary_dynamic_ranges;
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
fn void temporary_calls_and_literals_accept_named_mixed_and_omitted_bounds() {
    value(b"module main;fn u8[6] make(){var u8[6] a=[255;6];a[1]=240;a[2]=159;a[3]=141;a[4]=171;return a;}fn i32 main(){let usize lo=1;let usize hi=5;if(text::valid_utf8(make()[lo..hi]) && !text::valid_utf8(make()[2..hi]) && !text::valid_utf8(make()[lo..]) && !text::valid_utf8(make()[..hi])){return 42;}return 0;}",6);
    value(b"module main;fn bool valid(usize lo,usize hi){return text::valid_utf8([65;4096][lo..hi]);}fn i32 main(){let usize end=4096;if(valid(256,end) && text::valid_utf8([255;4096][end..]) && text::valid_utf8([65;4096][..end])){return 42;}return 0;}",4096);
    value(b"module main;fn u8[1] make(){return [255;1];}fn i32 main(){let usize end=1;if(text::valid_utf8(make()[end..end]) && text::valid_utf8([255;1][end..]) && text::valid_utf8([255;1][..0])){return 42;}return 0;}",1);
}

@test
fn void bounds_reload_after_arguments_and_fillers_and_scan_drops_immediately() {
    value(b"module main;fn u8[1] make(i32 n){return [255;1];}fn i32 main(){var usize hi=1;var i32 n=0;let Option<i32> o=.none;let bool a=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{hi=0;n=n+1;0}})[..hi]);hi=1;let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{hi=0;n=n+1;255}};1][..hi]);if(a && b && n==2){return 42;}return 0;}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn u8[1] wrap(bool b){return make();}fn u8 choose(bool b){if(b){return 65;}return 255;}fn i32 main(){let usize hi=1;if(text::valid_utf8(wrap(text::valid_utf8(make()[..hi]))[..hi]) && text::valid_utf8([choose(text::valid_utf8([65;1][..hi]));1][..hi])){return 42;}return 0;}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){var i32 n=0;var usize hi=0;while(n<42){hi=1;if(text::valid_utf8(make()[..hi]) && text::valid_utf8([65;1][0..hi])){n=n+1;continue;}break;}return n;}",1);
    let ir::Program p=compiled(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){var usize hi=4;let bool b=text::valid_utf8(make()[..hi]);return 42;}");
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=53){pc+=1;}assert(pc>0 && pc+1<p.count);
    assert(p.code[(pc+1)*8]==37 && p.code[(pc+1)*8+1]==p.code[pc*8+2]);
    assert(p.code[(pc-2)*8]==17 && p.code[(pc-3)*8]==9);
    let ir::Program named=compiled(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){var usize hi=4;let u8[4] a=make();let bool b=text::valid_utf8(a[..hi]);return 42;}");
    assert(p.arrays.count==named.arrays.count && p.count==named.count && p.registers==named.registers);
    var ir::Program bad=p;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
    assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok && !verifier::verify(ref bad).is_ok);
}

@test
fn void pending_exits_publish_no_temporary_and_short_circuit_skips_all_work() {
    value(b"module main;fn i32 main(){let usize hi=1;let Option<i32> o=.none;let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{return 42;}};4096][..hi]);return 0;}",0);
    value(b"module main;fn u8[4096] make(i32 n){return [65;4096];}fn i32 main(){let usize hi=1;let Option<i32> o=.none;let bool b=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{return 42;}})[..hi]);return 0;}",0);
    value(b"module main;fn i32 main(){let usize hi=1;var i32 n=0;let Option<i32> o=.none;while(n<2){let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{n=n+1;continue;}};4096][..hi]);}return n+40;}",0);
    value(b"module main;fn u8[4096] make(i32 n){return [65;4096];}fn i32 main(){let usize hi=1;var i32 n=0;let Option<i32> o=.none;while(n<2){let bool b=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{n=n+1;continue;}})[..hi]);}return n+40;}",0);
    value(b"module main;fn i32 main(){let usize hi=1;let Option<i32> o=.none;while(true){let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{break;}};4096][..hi]);}return 42;}",0);
    value(b"module main;fn u8[4096] make(i32 n){return [65;4096];}fn i32 main(){let usize hi=1;let Option<i32> o=.none;while(true){let bool b=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{break;}})[..hi]);}return 42;}",0);
    value(b"module main;fn Option<i32> f(Option<i32> o){let usize hi=1;let bool b=text::valid_utf8([switch(o){case .some(v):{65}case .none:{let i32 n=o?;0}};1][..hi]);return .some(42);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn u8[1] make(i32 n){return [65;1];}fn Option<i32> f(Option<i32> o){let usize hi=1;let bool b=text::valid_utf8(make(o?)[..hi]);return .some(42);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn u8[4096] make(){return [65;4096];}fn i32 main(){let usize hi=18446744073709551615;if(false && text::valid_utf8(make()[..hi])){return 0;}if(true || text::valid_utf8([255;4096][..hi])){return 42;}return 0;}",0);
    value(b"module main;struct P{i32 x;}fn i32 take(P p,bool b){return p.x;}fn u8[4096] make(i32 n){return [65;4096];}fn i32 main(){let usize hi=1;let Option<i32> o=.none;return take(P{.x=0},text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{return 42;}})[..hi]));}",4);
}

fn void fuel(ref u8[] source,usize exact) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=53){pc+=1;}assert(pc<p.count);
    assert(switch(vm::run_with_array_limit(ref p,exact,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,exact-1,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,exact-52,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==p.offsets[pc]}});
}
fn void bounds(ref u8[] source) {
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    var usize pc=0;while(pc<p.count && p.code[pc*8]!=53){pc+=1;}assert(pc<p.count);
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(_):{false}case .err(e):{e.kind==14 && e.offset==p.offsets[pc]}});
}
@test
fn void runtime_bounds_and_exact_root_fuel_match_the_named_array_path() {
    fuel(b"module main;fn i32 main(){let usize lo=0;let usize hi=4;let bool b=text::valid_utf8([65;4][lo..hi]);return 42;}",202);
    fuel(b"module main;fn i32 main(){let usize lo=1;let usize hi=3;let bool b=text::valid_utf8([65;4][lo..hi]);return 42;}",202);
    fuel(b"module main;fn i32 main(){let usize lo=4;let usize hi=4;let bool b=text::valid_utf8([255;4][lo..hi]);return 42;}",202);
    fuel(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let usize lo=0;let usize hi=4;let bool b=text::valid_utf8(make()[lo..hi]);return 42;}",268);
    fuel(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let usize lo=1;let usize hi=3;let bool b=text::valid_utf8(make()[lo..hi]);return 42;}",268);
    fuel(b"module main;fn u8[4] make(){return [255;4];}fn i32 main(){let usize lo=4;let usize hi=4;let bool b=text::valid_utf8(make()[lo..hi]);return 42;}",268);
    bounds(b"module main;fn i32 main(){let usize lo=3;let usize hi=1;let bool b=text::valid_utf8([65;4][lo..hi]);return 42;}");
    bounds(b"module main;fn i32 main(){let usize hi=18446744073709551615;let bool b=text::valid_utf8([65;4][..hi]);return 42;}");
    bounds(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let usize hi=5;let bool b=text::valid_utf8(make()[..hi]);return 42;}");
    bounds(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let usize lo=9223372036854775808;let bool b=text::valid_utf8(make()[lo..]);return 42;}");
}

@test
fn void endpoint_expressions_wrong_types_and_escaping_views_stay_rejected() {
    rejected(b"module main;fn i32 main(){let u32 hi=1;let bool b=text::valid_utf8([65;1][..hi]);return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let usize hi=1;let bool b=text::valid_utf8(make()[0..hi+)]);return 0;}");
    rejected(b"module main;fn u32 end(){return 1;}fn i32 main(){let bool b=text::valid_utf8([65;1][..end()]);return 0;}");
    rejected(b"module main;fn i32 main(){let usize[1] hi=[1;1];let bool b=text::valid_utf8([65;1][..hi]);return 0;}");
    rejected(b"module main;fn i32 main(){let usize hi=1;let bool b=text::valid_utf8([65;1][..hi][..]);return 0;}");
    rejected(b"module main;fn i32 main(){let usize hi=1;let ref u8[] v=ref [65;1][..hi];return 0;}");
}
