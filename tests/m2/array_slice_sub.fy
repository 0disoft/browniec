module tests::m2::array_slice_sub;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) { return switch(compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } }; }
fn void value(ref u8[] source,usize limit) { let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok); assert(switch(vm::run_with_array_limit(ref p,3000000,limit)) { case .ok(v): { v==42 } case .err(_): { false } }); }
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }
fn void error(ref u8[] source,u8 kind) { let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok); assert(switch(vm::run_with_array_limit(ref p,1000000,65536)) { case .ok(_): { false } case .err(e): { e.kind==kind } }); }

@test
fn void relative_computed_open_empty_and_nested_selections_share_the_same_bytes() {
    value(b"module main;fn i32 main(){var u8[5] a=[0;5];a[2]=20;a[3]=22;let ref u8[] p=ref a[1..5];let ref u8[] q=ref p[1..3];return (q[0] as i32)+(q[1] as i32);}",5);
    value(b"module main;fn i32 main(){let u8[4096] a=[42;4096];let ref u8[] p=ref a[1..];let ref u8[] q=ref p[1..];let ref u8[] r=ref q[..];let ref u8[] empty=ref r[r.len..];if(r.len==4094 && empty.len==0 && text::valid_utf8(empty)){return r[r.len-1] as i32;}return 0;}",4096);
    value(b"module main;fn i32 main(){var u8[6] a=[255;6];a[1]=240;a[2]=159;a[3]=141;a[4]=171;let ref u8[] p=ref a[..];let ref u8[] q=ref p[1..5];if(q.len==4 && text::valid_utf8(q)){return 42;}return 0;}",6);
    value(b"module main;fn u8 read(u8[4] a,usize i){let ref u8[] p=ref a[1..];let ref u8[] q=ref p[i..];return q[0];}fn i32 main(){let u8[4] a=[42;4];return read(a,2) as i32;}",8);
    value(b"module main;fn u8[3] make(){return [42;3];}fn i32 main(){let u8[3] a=make();let ref u8[] p=ref a;let ref u8[] q=ref p[..2];return q[1] as i32;}",3);
    value(b"module main;fn i32 main(){var usize hi=2;let u8[4] a=[42;4];let ref u8[] p=ref a[..hi];let ref u8[] q=ref p[0..hi];hi=4;if(q.len==2 && p.len==2){return q[1] as i32;}return 0;}",4);
}

@test
fn void endpoints_run_once_in_order_and_pending_children_follow_existing_exit_cleanup() {
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let u8[3] a=[42;3];let ref u8[] p=ref a;let ref u8[] q=ref p[switch(o){case .some(v):{0}case .none:{n=n*10+1;0}}..switch(o){case .some(v):{1}case .none:{n=n*10+2;1}}];if(q.len==1 && q[0]==42 && q[0]==42 && n==12){return 42;}return 0;}",3);
    value(b"module main;fn i32 main(){var u8[1] a=[42;1];var u8 b=0;{let ref u8[] p=ref a;{let ref u8[] q=ref p[..];b=q[0];}let ref u8[] r=ref p[..];b=r[0];}a[0]=0;return b as i32;}",1);
    value(b"module main;fn Option<i32> f(Option<i32> o){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p[0..switch(o){case .some(v):{1}case .none:{let i32 v=o?;1}}];return .some(q[0] as i32);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn i32 main(){var u8[1] a=[42;1];var i32 n=0;let Option<i32> o=.none;while(n<2){let ref u8[] p=ref a;let ref u8[] q=ref p[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}..1];}a[0]=0;return n+40;}",1);
    value(b"module main;fn i32 main(){var u8[1] a=[42;1];let Option<i32> o=.none;while(true){let ref u8[] p=ref a;let ref u8[] q=ref p[0..switch(o){case .some(v):{1}case .none:{break;}}];}a[0]=0;return 42;}",1);
    value(b"module main;fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;let Option<i32> o=.none;let u8 b=switch(o){case .some(v):{0}case .none:{let ref u8[] q=ref p[1..];q[0]}};return b as i32;}",2);
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p;return 42;}");
    rejected(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;{let ref u8[] q=ref p[..];}a[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p[true..];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let i32 i=0;let ref u8[] q=ref p[..i];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;var ref u8[] q=ref p[..];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p[..];q[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;{let ref u8[] q=ref p[..];}let u8 b=q[0];return 42;}");
    rejected(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let Option<i32> o=.none;let ref u8[] q=ref p[0..switch(o){case .some(v):{1}case .none:{a[0]=0;1}}];return 42;}");
}

@test
fn void selected_parent_bounds_and_exact_fuel_are_checked_before_child_publication() {
    error(b"module main;fn i32 main(){let u8[8] a=[42;8];let ref u8[] p=ref a[2..5];let ref u8[] q=ref p[..4];return 42;}",14);
    error(b"module main;fn i32 main(){let u8[4] a=[42;4];let ref u8[] p=ref a[4..];let ref u8[] q=ref p[..1];return 42;}",14);
    error(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p[..18446744073709551615];return 42;}",14);
    error(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p[0..1/0];return 42;}",7);
    let ir::Program p=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] parent=ref a[..];let ref u8[] part=ref parent[1..3];if(part[0]==65){return 42;}return 0;}");
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,143526,4)) { case .ok(v): { v==42 } case .err(_): { false } });
    assert(switch(vm::run_with_array_limit(ref p,143525,4)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
}
