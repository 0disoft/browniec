module tests::m2::array_utf8_literals;
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
fn void literals_infer_exact_u8_and_validate_all_initialized_bytes() {
    value(b"module main;fn i32 main(){if(text::valid_utf8([0;1])){return 42;}return 0;}",1);
    value(b"module main;fn i32 main(){if(text::valid_utf8([65;4096])){return 42;}return 0;}",4096);
    value(b"module main;fn i32 main(){if(!text::valid_utf8([255;4])){return 42;}return 0;}",4);
    value(b"module main;fn i32 main(){let u8 byte=128;if(!text::valid_utf8([byte;2])){return 42;}return 0;}",2);
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([true;1]);return 0;}");
    rejected(b"module main;fn i32 main(){let i32 n=65;let bool b=text::valid_utf8([n;1]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([256;1]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([-1;1]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;0]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;4097]);return 0;}");
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8([65,1]);return 0;}");
}

@test
fn void fillers_evaluate_once_and_exits_publish_no_pending_literal() {
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{n=n+1;65}};4096]);if(b && n==1){return 42;}return 0;}",4096);
    value(b"module main;fn i32 main(){var i32 n=0;while(n<42){if(text::valid_utf8([65;1])){n=n+1;continue;}break;}return n;}",1);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{return 42;}};4096]);return 0;}",0);
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{n=n+1;continue;}};4096]);}return n+40;}",0);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;while(true){let bool b=text::valid_utf8([switch(o){case .some(v):{0}case .none:{break;}};4096]);}return 42;}",0);
    value(b"module main;fn Option<i32> f(Option<i32> o){let bool b=text::valid_utf8([switch(o){case .some(v):{65}case .none:{let i32 n=o?;0}};1]);return .some(42);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
}

@test
fn void nested_fillers_release_their_owners_before_literal_initialization() {
    value(b"module main;fn u8 choose(bool b){if(b){return 65;}return 255;}fn i32 main(){if(text::valid_utf8([choose(text::valid_utf8([0;1]));1])){return 42;}return 0;}",1);
    value(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){if(text::valid_utf8([make()[0];4])){return 42;}return 0;}",4);
    value(b"module main;struct P{i32 x;}fn i32 take(P p,bool b){if(b){return p.x+22;}return 0;}fn i32 main(){return take(P{.x=20},text::valid_utf8([65;1]));}",8);
    value(b"module main;struct P{i32 x;}fn i32 take(P p,bool b){return p.x;}fn i32 main(){let Option<i32> o=.none;return take(P{.x=0},text::valid_utf8([switch(o){case .some(v):{0}case .none:{return 42;}};4096]));}",4);
    value(b"module main;fn i32 main(){if(false && text::valid_utf8([65;4096])){return 0;}if(true || text::valid_utf8([255;4096])){return 42;}return 0;}",0);
}

@test
fn void immediate_cleanup_and_exact_fuel_match_a_named_array() {
    let ir::Program p=compiled(b"module main;fn i32 main(){let bool b=text::valid_utf8([65;4]);return 42;}");
    let ir::Program named=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let bool b=text::valid_utf8(a);return 42;}");
    assert(p.count==6 && p.count==named.count && p.arrays.count==1 && named.arrays.count==1);
    assert(p.code[8]==33 && p.code[16]==51 && p.code[24]==37 && p.code[25]==p.code[18]);
    assert(switch(vm::run_with_array_limit(ref p,168,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,167,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,116,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==p.offsets[2]}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
    var ir::Program bad=p;bad.code[24]=19;bad.code[25]=0;
    assert(ir::patch(ref mut bad,3,4,0).is_ok && !verifier::verify(ref bad).is_ok);
}
