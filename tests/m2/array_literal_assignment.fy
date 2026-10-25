module tests::m2::array_literal_assignment;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void result(ref u8[] source,usize limit){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);assert(switch(vm::run_with_array_limit(ref p,1000000,limit)){case .ok(n):{n==42}case .err(_):{false}});}
@test
fn void repeated_assignment_uses_only_existing_storage_at_capacity(){
    result(b"module main;fn i32 main(){var i32[2] a=[0;2];a=[21;2];return a[0]+a[1];}",8);
    result(b"module main;fn i32 main(){var i64[4096] a=[0;4096];a=[-9223372036854775808;4096];if(a[4095]==-9223372036854775808){return 42;}return 0;}",32768);
    result(b"module main;fn i32 main(){var u8[1] a=[0;1];let u8[1] b=[0;1];a=[42;1];if(a[0]==42 && b[0]==0){return 42;}return 0;}",2);
}
@test
fn void fill_evaluates_once_before_writes_and_preserves_argument_snapshots(){
    result(b"module main;fn i32 main(){var i32[2] a=[20;2];a=[a[0]+1;2];return a[0]+a[1];}",8);
    result(b"module main;fn i32 main(){var i32[2] a=[0;2];var i32 n=20;let Option<i32> o=.none;a=[switch(o){case .some(v):{v}case .none:{n=n+1;n}};2];return a[0]+a[1];}",8);
    result(b"module main;fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){var i32[1] a=[21;1];let Option<i32> o=.none;return take(a,switch(o){case .some(v):{v}case .none:{a=[0;1];21}});}",12);
    result(b"module main;fn i32[1] f(){var i32[1] a=[0;1];a=[42;1];return a;}fn i32 main(){let i32[1] a=f();return a[0];}",4);
}
@test
fn void filler_early_exits_keep_old_values_and_release_visible_owners(){
    result(b"module main;fn i32 main(){var i32[1] a=[42;1];let Option<i32> o=.none;a=[switch(o){case .some(v):{v}case .none:{return a[0];}};1];return 0;}",4);
    result(b"module main;fn i32 main(){var i32[1] a=[42;1];var i32 n=0;while(n<42){let Option<i32> o=.none;a=[switch(o){case .some(v):{v}case .none:{n=n+1;continue;}};1];}return a[0];}",4);
    result(b"module main;fn Option<i32> f(Option<i32> x){var i32[1] a=[0;1];a=[x?;1];return .some(a[0]);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}",4);
}
@test
fn void source_fill_is_metered_without_a_second_catalog_site(){
    let ir::Program p=compiled(b"module main;fn i32 main(){var i32[1] a=[0;1];a=[42;1];return a[0];}");
    assert(p.arrays.count==1);
    assert(switch(vm::run_with_array_limit(ref p,224,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,223,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,1000000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
