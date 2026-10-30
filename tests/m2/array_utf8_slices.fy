module tests::m2::array_utf8_slices;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import ir as ir;

fn ir::Program compiled(ref u8[] source) { return switch(compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } }; }
fn void value(ref u8[] source,usize limit) {
    let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,3000000,limit)) { case .ok(n): { n==42 } case .err(_): { false } });
}
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }
fn void error(ref u8[] source,u8 kind) {
    let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,3000000,16)) { case .ok(_): { false } case .err(e): { e.kind==kind } });
}

@test
fn void named_roots_whole_open_computed_and_multibyte_ranges_are_read_only() {
    value(b"module main;fn i32 main(){var u8[6] a=[255;6];a[1]=240;a[2]=159;a[3]=141;a[4]=171;let ref u8[] p=ref a[1+0..a.len-1];let ref u8[] q=ref a[2..5];let ref u8[] e=ref a[6..];if(text::valid_utf8(p) && !text::valid_utf8(q) && text::valid_utf8(e)){return 42;}return 0;}",6);
    value(b"module main;fn bool valid(u8[4] a,usize lo){let ref u8[] p=ref a[lo..];let ref u8[] q=ref a[..4];return text::valid_utf8(p) && text::valid_utf8(q);}fn u8[4] make(){return [65;4];}fn i32 main(){let u8[4] a=make();let ref u8[] p=ref a;if(text::valid_utf8(p) && valid(a,1)){return 42;}return 0;}",8);
    value(b"module main;struct R{usize lo;usize hi;}fn usize end(){return 4;}fn i32 main(){let R r=R{.lo=0,.hi=4};let u8 lo=0;let u8[4] a=[65;4];let ref u8[] p=ref a[r.lo..end()];let ref u8[] q=ref a[lo as usize..r.hi];if(text::valid_utf8(p) && text::valid_utf8(q)){return 42;}return 0;}",32);
    value(b"module main;fn i32 main(){let u8[4096] a=[65;4096];let ref u8[] p=ref a[..];if(text::valid_utf8(p)){return 42;}return 0;}",4096);
}

@test
fn void lexical_cleanup_unlocks_roots_and_adds_no_array_owner_or_payload_copy() {
    value(b"module main;fn i32 main(){var u8[1] a=[65;1];{let ref u8[] p=ref a;{let ref u8[] q=ref a[..];if(!text::valid_utf8(q)){return 0;}}if(!text::valid_utf8(p)){return 0;}}a[0]=255;{let ref u8[] p=ref a;if(text::valid_utf8(p)){return 0;}}a=[65;1];if(text::valid_utf8(a)){return 42;}return 0;}",1);
    value(b"module main;fn i32 main(){var u8[1] a=[65;1];{let ref u8[] p=ref a;let u8[1] b=a;if(!text::valid_utf8(b)){return 0;}}a[0]=66;return 42;}",2);
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];var i32 n=0;while(n<3){let ref u8[] p=ref a;let ref u8[] q=ref a[..1];if(!text::valid_utf8(p) || !text::valid_utf8(q)){return 0;}n=n+1;}return n+39;}",1);
}

@test
fn void return_question_break_continue_and_value_arms_close_borrows_before_owners() {
    value(b"module main;fn i32 main(){var u8[1] a=[65;1];var i32 n=0;while(n<2){let ref u8[] p=ref a;n=n+1;continue;}a[0]=66;while(true){let ref u8[] q=ref a;break;}a=[65;1];return 42;}",1);
    value(b"module main;fn Option<i32> f(Option<i32> o){let u8[1] a=[65;1];let ref u8[] p=ref a;let i32 n=o?;return .some(n);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn u8[1] make(){let u8[1] a=[65;1];let ref u8[] p=ref a;return a;}struct P{i32 x;}fn P record(){let u8[1] a=[65;1];let ref u8[] p=ref a;let P r=P{.x=42};return r;}fn i32 main(){let u8[1] a=make();let P r=record();if(text::valid_utf8(a)){return r.x;}return 0;}",16);
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];let Option<i32> o=.none;let bool b=switch(o){case .some(v):{false}case .none:{let ref u8[] p=ref a;text::valid_utf8(p)}};if(b){return 42;}return 0;}",1);
}

@test
fn void endpoints_evaluate_once_in_order_and_pending_slices_do_not_leak_on_exits() {
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let u8[1] a=[255;1];let ref u8[] p=ref a[switch(o){case .some(v):{0}case .none:{n=n*10+1;1}}..switch(o){case .some(v):{1}case .none:{n=n*10+2;1}}];if(n==12 && text::valid_utf8(p)){return 42;}return 0;}",1);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;let u8[1] a=[65;1];let ref u8[] old=ref a;let ref u8[] p=ref a[0..switch(o){case .some(v):{1}case .none:{return 42;}}];return 0;}",1);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;var u8[1] a=[65;1];var i32 n=0;while(n<2){let ref u8[] p=ref a[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}..1];}a[0]=66;return n+40;}",1);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;var u8[1] a=[65;1];while(true){let ref u8[] p=ref a[0..switch(o){case .some(v):{1}case .none:{break;}}];}a[0]=66;return 42;}",1);
}

@test
fn void unavailable_escapes_mutation_and_scalar_uses_fail_before_verification() {
    rejected(b"module main;fn i32 main(){var u8[1] a=[65;1];let ref u8[] p=ref a;a[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){var u8[1] a=[65;1];let ref u8[] p=ref a;a=[0;1];return 42;}");
    rejected(b"module main;fn i32 main(){var u8[1] a=[65;1];let u8[1] b=[0;1];let ref u8[] p=ref a;a=b;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;let i32 n=p;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;let usize n=p.capacity;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;let u8 n=p[true];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];var ref u8[] p=ref a;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;let ref u8[] q=ref p;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];{let ref u8[] p=ref a;}if(text::valid_utf8(p)){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;if(text::valid_utf8(p[..])){return 42;}return 0;}");
    rejected(b"module main;fn u8[1] make(){return [65;1];}fn i32 main(){let ref u8[] p=ref make();return 42;}");
    rejected(b"module main;fn i32 main(){let ref u8[] p=ref [65;1];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];for(let ref u8[] p=ref a;false;){return 0;}return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let u32 end=1;let ref u8[] p=ref a[0..end];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a[p..1];return 42;}");
    rejected(b"module main;fn i32 main(){let i32[1] a=[65;1];let ref u8[] p=ref a;return 42;}");
}

@test
fn void runtime_bounds_and_fuel_are_checked_and_missing_close_is_independently_rejected() {
    error(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a[0..2];return 42;}",14);
    error(b"module main;fn i32 main(){let u8[1] a=[65;1];let usize lo=18446744073709551615;let ref u8[] p=ref a[lo..1];return 42;}",14);
    error(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a[0..1/0];return 42;}",7);
    let ir::Program p=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] part=ref a[..];if(text::valid_utf8(part)){return 42;}return 0;}");
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,73869,4)) { case .ok(v): { v==42 } case .err(_): { false } });
    assert(switch(vm::run_with_array_limit(ref p,73868,4)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
    var usize pc=0; while(pc<p.count && p.code[pc*8]!=56) { pc+=1; } assert(pc<p.count);
    var ir::Program bad=p; bad.code[pc*8]=19; bad.code[pc*8+1]=0; bad.code[pc*8+2]=0; bad.code[pc*8+3]=0;
    assert(ir::patch(ref mut bad,pc,pc+1,0).is_ok && !verifier::verify(ref bad).is_ok);
}
