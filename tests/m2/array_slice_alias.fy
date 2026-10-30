module tests::m2::array_slice_alias;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) { return switch(compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } }; }
fn void value(ref u8[] source,usize limit) { let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok); assert(switch(vm::run_with_array_limit(ref p,3000000,limit)) { case .ok(v): { v==42 } case .err(_): { false } }); }
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }
fn void error(ref u8[] source,u8 kind) { let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok); assert(switch(vm::run_with_array_limit(ref p,1000000,65536)) { case .ok(_): { false } case .err(e): { e.kind==kind } }); }

@test
fn void aliases_reborrow_whole_selected_empty_maximum_and_utf8_ranges() {
    value(b"module main;fn i32 main(){var u8[5] a=[0;5];a[2]=20;a[3]=22;let ref u8[] p=ref a[2..4];let ref u8[] q=ref p;return (q[0] as i32)+(q[1] as i32);}",5);
    value(b"module main;fn i32 main(){let u8[1] a=[255;1];let ref u8[] p=ref a[1..];let ref u8[] q=ref p;if(q.len==0 && text::valid_utf8(q)){return 42;}return 0;}",1);
    value(b"module main;fn i32 main(){let u8[4096] a=[42;4096];let ref u8[] p=ref a[1..];let ref u8[] q=ref p;let ref u8[] r=ref q;if(r.len==4095){return r[r.len-1] as i32;}return 0;}",4096);
    value(b"module main;fn i32 main(){var u8[6] a=[255;6];a[1]=240;a[2]=159;a[3]=141;a[4]=171;let ref u8[] p=ref a[1..5];let ref u8[] q=ref p;if(q.len==4 && text::valid_utf8(q)){return 42;}return 0;}",6);
    value(b"module main;fn u8 read(u8[4] a){let ref u8[] p=ref a[1..];let ref u8[] q=ref p;return q[2];}fn i32 main(){let u8[4] a=[42;4];return read(a) as i32;}",8);
    value(b"module main;fn u8[3] make(){return [42;3];}fn i32 main(){let u8[3] a=make();let ref u8[] p=ref a;let ref u8[] q=ref p;return q[1] as i32;}",3);
}

@test
fn void aliases_preserve_captured_bounds_lexical_conflicts_and_all_exit_cleanup() {
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let u8[3] a=[42;3];let ref u8[] p=ref a[switch(o){case .some(v):{0}case .none:{n=n*10+1;0}}..switch(o){case .some(v):{1}case .none:{n=n*10+2;1}}];let ref u8[] q=ref p;if(q.len==1 && q[0]==42 && n==12){return 42;}return 0;}",3);
    value(b"module main;fn i32 main(){var u8[1] a=[42;1];var u8 b=0;{let ref u8[] p=ref a;{let ref u8[] q=ref p;b=q[0];}let ref u8[] r=ref p;b=r[0];}a[0]=0;return b as i32;}",1);
    value(b"module main;fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;let Option<i32> o=.none;let u8 b=switch(o){case .some(v):{0}case .none:{let ref u8[] q=ref p;q[0]}};return b as i32;}",2);
    value(b"module main;fn Option<i32> f(Option<i32> o){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p;let i32 n=o?;return .some(q[0] as i32);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn i32 main(){var u8[1] a=[42;1];var i32 n=0;while(n<2){let ref u8[] p=ref a;let ref u8[] q=ref p;n=n+1;continue;}while(true){let ref u8[] p=ref a;let ref u8[] q=ref p;break;}a[0]=0;return n+40;}",1);
    value(b"module main;fn i32 main(){let u8[4] a=[42;4];let ref u8[] p=ref a;let ref u8[] q=ref p;let ref u8[] r=ref q[1..3];let ref u8[] s=ref r;if(q.len==4 && s.len==2){return s[1] as i32;}return 0;}",4);
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref q;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;{let ref u8[] q=ref p;}let u8 b=q[0];return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;var ref u8[] q=ref p;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p;q[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;{let ref u8[] q=ref p;}a[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p;q=p;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] p=ref p;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p;let usize n=q;return 42;}");
    error(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a[1..];let ref u8[] q=ref p;return q[0] as i32;}",14);
    error(b"module main;fn i32 main(){let u8[8] a=[42;8];let ref u8[] p=ref a[2..5];let ref u8[] q=ref p;return q[3] as i32;}",14);
}

@test
fn void aliases_match_explicit_whole_subslice_encoding_types_and_exact_fuel() {
    let ir::Program p=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] parent=ref a[..];let ref u8[] part=ref parent;if(part[0]==65){return 42;}return 0;}");
    let ir::Program q=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] parent=ref a[..];let ref u8[] part=ref parent[..];if(part[0]==65){return 42;}return 0;}");
    assert(verifier::verify(ref p).is_ok && verifier::verify(ref q).is_ok);
    assert(p.count==q.count && p.registers==q.registers && p.constant_count==q.constant_count);
    var usize i=0; while(i<p.count*8) { assert(p.code[i]==q.code[i]); i+=1; }
    i=0; while(i<128) { assert(p.types[i]==q.types[i] && p.constants[i]==q.constants[i]); i+=1; }
    i=0; while(i<16) { assert(p.slice_roots[i]==q.slice_roots[i]); i+=1; }
    assert(switch(vm::run_with_array_limit(ref p,147622,4)) { case .ok(v): { v==42 } case .err(_): { false } });
    assert(switch(vm::run_with_array_limit(ref p,147621,4)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
}
