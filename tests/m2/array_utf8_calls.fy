module tests::m2::array_utf8_calls;
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
fn void direct_forward_and_nested_calls_validate_their_returned_bytes() {
    value(b"module main;fn i32 main(){if(text::valid_utf8(make())){return 42;}return 0;}fn u8[1] make(){return [65;1];}",1);
    value(b"module main;fn u8[1] make(u8 n){return [n;1];}fn i32 main(){if(!text::valid_utf8(make(255)) && text::valid_utf8(make(0))){return 42;}return 0;}",1);
    value(b"module main;fn u8[3] make(){var u8[3] a=[128;3];a[0]=234;a[1]=176;return a;}fn bool valid(){return text::valid_utf8(make());}fn i32 main(){if(valid()){return 42;}return 0;}",3);
    value(b"module main;fn u8[1] make(){return [65;1];}fn u8[1] wrap(bool b){return make();}fn i32 main(){if(text::valid_utf8(wrap(text::valid_utf8(make())))){return 42;}return 0;}",1);
    value(b"module main;struct P{i32 x;}fn u8[1] make(){return [65;1];}fn i32 take(P p,bool b){if(b){return p.x+22;}return 0;}fn i32 main(){return take(P{.x=20},text::valid_utf8(make()));}",8);
}

@test
fn void immediate_drop_reuses_exact_capacity_and_matches_named_fuel() {
    value(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){if(text::valid_utf8(make()) && text::valid_utf8(make())){return 42;}return 0;}",1);
    value(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){var i32 n=0;while(n<42){if(text::valid_utf8(make())){n=n+1;continue;}break;}return n;}",1);
    let ir::Program direct=compiled(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let bool b=text::valid_utf8(make());return 42;}");
    let ir::Program named=compiled(b"module main;fn u8[4] make(){return [65;4];}fn i32 main(){let u8[4] a=make();let bool b=text::valid_utf8(a);return 42;}");
    assert(direct.count==named.count && direct.arrays.count==named.arrays.count);
    var usize pc=0;while(pc<direct.count && direct.code[pc*8]!=51){pc+=1;}
    assert(pc>0 && pc+1<direct.count && direct.code[(pc-1)*8]==9 && direct.code[(pc+1)*8]==37);
    assert(direct.code[(pc+1)*8+1]==direct.code[pc*8+2]);
    assert(switch(vm::run_with_array_limit(ref direct,234,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref named,234,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref direct,233,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref direct,182,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==direct.offsets[pc]}});
    assert(switch(vm::run_with_array_limit(ref direct,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
    var ir::Program bad=direct;bad.code[(pc+1)*8]=19;bad.code[(pc+1)*8+1]=0;
    assert(ir::patch(ref mut bad,pc+1,pc+2,0).is_ok && !verifier::verify(ref bad).is_ok);
}

@test
fn void pending_argument_exits_and_short_circuit_do_not_publish_results() {
    value(b"module main;fn u8[1] make(i32 n){return [65;1];}fn i32 main(){let Option<i32> o=.none;let bool b=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{return 42;}}));return 0;}",0);
    value(b"module main;fn u8[1] make(i32 n){return [65;1];}fn i32 main(){var i32 n=0;let Option<i32> o=.none;while(n<2){let bool b=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}));}return n+40;}",0);
    value(b"module main;fn u8[1] make(i32 n){return [65;1];}fn i32 main(){let Option<i32> o=.none;while(true){let bool b=text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{break;}}));}return 42;}",0);
    value(b"module main;fn u8[4096] make(){return [65;4096];}fn i32 main(){if(false && text::valid_utf8(make())){return 0;}if(true || text::valid_utf8(make())){return 42;}return 0;}",0);
    value(b"module main;struct P{i32 x;}fn i32 take(P p,bool b){return p.x;}fn u8[1] make(i32 n){return [65;1];}fn i32 main(){let Option<i32> o=.none;return take(P{.x=0},text::valid_utf8(make(switch(o){case .some(v):{0}case .none:{return 42;}})));}",4);
    value(b"module main;fn u8[1] make(i32 n){return [65;1];}fn Option<i32> f(Option<i32> o){let bool b=text::valid_utf8(make(switch(o){case .some(v):{v}case .none:{let i32 n=o?;0}}));return .some(42);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
}

@test
fn void call_resolution_types_arity_and_delimiters_are_checked() {
    rejected(b"module main;fn i32 main(){let bool b=text::valid_utf8(missing());return 0;}");
    rejected(b"module main;fn u8 make(){return 65;}fn i32 main(){let bool b=text::valid_utf8(make());return 0;}");
    rejected(b"module main;fn i32[1] make(){return [0;1];}fn i32 main(){let bool b=text::valid_utf8(make());return 0;}");
    rejected(b"module main;struct P{i32 x;}fn P make(){return P{.x=0};}fn i32 main(){let bool b=text::valid_utf8(make());return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let u8[1] make=[0;1];let bool b=text::valid_utf8(make());return 0;}");
    rejected(b"module main;fn u8[1] make(u8 n){return [n;1];}fn i32 main(){let bool b=text::valid_utf8(make());return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let bool b=text::valid_utf8(make(),make());return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let bool b=text::valid_utf8(make()[0]);return 0;}");
}
