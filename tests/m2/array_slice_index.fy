module tests::m2::array_slice_index;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) { return switch(compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } }; }
fn void value(ref u8[] source,usize limit) { let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok); assert(switch(vm::run_with_array_limit(ref p,3000000,limit)) { case .ok(v): { v==42 } case .err(_): { false } }); }
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }
fn void error(ref u8[] source,u8 kind) { let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok); assert(switch(vm::run_with_array_limit(ref p,1000000,65536)) { case .ok(_): { false } case .err(e): { e.kind==kind } }); }

@test
fn void reads_relative_bytes_with_ordinary_usize_expressions_and_scalar_results() {
    value(b"module main;fn i32 main(){var u8[4] a=[0;4];a[1]=20;a[2]=22;let ref u8[] part=ref a[1..3];return (part[0] as i32)+(part[1] as i32);}",4);
    value(b"module main;fn i32 main(){let u8[4096] a=[255;4096];let ref u8[] p=ref a[4095..];if(p[0]==255 && p.len==1 && !text::valid_utf8(p)){return 42;}return 0;}",4096);
    value(b"module main;fn u8 read(u8[4] a,usize i){let ref u8[] p=ref a[1..];return p[i];}fn i32 main(){let u8[4] a=[42;4];return read(a,2) as i32;}",8);
    value(b"module main;fn u8[2] make(){return [42;2];}fn i32 main(){let u8[2] a=make();let ref u8[] p=ref a;return p[p.len-1] as i32;}",2);
    value(b"module main;struct Box{u8 x;}fn i32 main(){let u8[4] a=[42;4];let ref u8[] p=ref a;let Box b=Box{.x=p[1+1]};return b.x as i32;}",16);
    value(b"module main;fn usize next(usize i){return i+1;}fn i32 main(){let u8[4] a=[42;4];let ref u8[] p=ref a;let usize[1] indices=[1;1];return p[next(indices[0])] as i32;}",16);
}

@test
fn void indices_evaluate_once_left_to_right_and_cleanup_keeps_root_loans() {
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let u8[2] a=[21;2];let ref u8[] p=ref a;let u8 b=p[switch(o){case .some(v):{0}case .none:{n=n+1;0}}]+p[switch(o){case .some(v):{0}case .none:{if(n!=1){return 0;}n=n+1;1}}];if(n==2){return b as i32;}return 0;}",2);
    value(b"module main;fn i32 main(){var usize i=0;let u8[2] a=[42;2];let ref u8[] p=ref a;i=1;return p[i] as i32;}",2);
    value(b"module main;fn i32 main(){var u8[1] a=[42;1];var u8 b=0;{let ref u8[] p=ref a;b=p[0];}a[0]=0;return b as i32;}",1);
    value(b"module main;fn Option<i32> read(Option<i32> o){let u8[1] a=[42;1];let ref u8[] p=ref a;let u8 b=p[switch(o){case .some(v):{0}case .none:{let i32 v=o?;0}}];return .some(b as i32);}fn i32 main(){switch(read(.none)){case .some(v):{return 0;}case .none:{}}switch(read(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn i32 main(){var u8[1] a=[42;1];var i32 n=0;let Option<i32> o=.none;while(n<2){let ref u8[] p=ref a;let u8 b=p[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}];}a[0]=0;return n+40;}",1);
    value(b"module main;fn i32 main(){let u8[1] a=[42;1];var u8 b=0;while(true){let ref u8[] p=ref a;b=p[0];break;}return b as i32;}",1);
    rejected(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let u8 b=p[0];a[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;p[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let u8 b=p[true];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let i32 i=0;let u8 b=p[i];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let u8 b=p[-1];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let bool b=p[0];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];{let ref u8[] p=ref a;}let u8 b=p[0];return 42;}");
    rejected(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let Option<i32> o=.none;let u8 b=p[switch(o){case .some(v):{0}case .none:{a[0]=0;0}}];return 42;}");
}

@test
fn void bounds_are_selected_length_and_read_work_is_prepaid() {
    error(b"module main;fn i32 main(){let u8[4] a=[42;4];let ref u8[] p=ref a[1..3];return p[2] as i32;}",14);
    error(b"module main;fn i32 main(){let u8[4] a=[42;4];let ref u8[] p=ref a[4..];return p[0] as i32;}",14);
    error(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return p[18446744073709551615] as i32;}",14);
    error(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return p[1/0] as i32;}",7);
    let ir::Program p=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] part=ref a[..];if(part[0]==65){return 42;}return 0;}");
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,73890,4)) { case .ok(v): { v==42 } case .err(_): { false } });
    assert(switch(vm::run_with_array_limit(ref p,73889,4)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
}
