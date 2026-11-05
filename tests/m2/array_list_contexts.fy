module tests::m2::array_list_contexts;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn void value(ref u8[] source,i64 expected){switch(compiler::compile_program(source,65536)){
    case .ok(p):{var usize i=0;while(i<2){switch(programs::run_public(ref p,16000000)){
        case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}
    };i+=1;}}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
@test fn void list_arguments_have_exact_contextual_types_and_evaluate_before_later_arguments(){
    value(b"module main;fn i32 main(){return take([20,22]);}fn i32 take(i32[2] a){return a[0]+a[1];}",42);
    value(b"module main;fn i32 take(bool[2] a){if(a[0] && !a[1]){return 42;}return 0;}fn i32 main(){return take([true,false,]);}",42);
    value(b"module main;fn i32 take(i64[2] a){if(a[0]==-9223372036854775808 && a[1]==9223372036854775807){return 42;}return 0;}fn i32 main(){return take([-9223372036854775808,9223372036854775807]);}",42);
    value(b"module main;fn i32 take(u8[2] a,u32[2] b,usize[1] c){if(a[0]==255 && b[0]==4294967295 && c[0]==18446744073709551615){return a[1] as i32;}return 0;}fn i32 main(){return take([255,42],[4294967295,0],[18446744073709551615]);}",42);
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return c[0];}fn i32 take(i32[2] a,i32 n){return a[0]*10+a[1]+n*15;}fn i32 main(){var c=[0];return take([bump(ref mut c),bump(ref mut c)],c[0]);}",42);
    value(b"module main;fn i32 take(i32[2] a,i32 n){return a[0]+a[1]+n;}fn i32 main(){var n=20;let Option<i32> o=.none;return take([n,22],switch(o){case .some(v):{v}case .none:{n=0;n}});}",42);
}
@test fn void returned_lists_move_complete_values_through_nested_calls_and_loop_reentry(){
    value(b"module main;fn i32[2] make(i32 n){return [n,22];}fn i32[2] relay(i32[2] a){return [a[0],a[1]];}fn i32 main(){var a=relay(make(20));let b=relay(a);a[0]=0;return b[0]+b[1];}",42);
    value(b"module main;fn bool[2] bits(){return [true,false];}fn u8[2] bytes(){return [255,42];}fn u32[1] words(){return [4294967295];}fn usize[1] sizes(){return [18446744073709551615];}fn i64[1] wide(){return [-9223372036854775808];}fn i32 main(){let a=bits();let b=words();let c=sizes();let d=wide();if(a[0] && !a[1] && b[0]==4294967295 && c[0]==18446744073709551615 && d[0]==-9223372036854775808){return bytes()[1] as i32;}return 0;}",42);
    value(b"module main;fn i32[1] make(i32 n){if(n==0){return [42];}return make(n-1);}fn i32 main(){var n=0;while(n<2){let a=make(30);if(a[0]!=42){return 0;}n=n+1;}return 42;}",42);
    value(b"module main;fn i32 take(i32[2] a){return a[0]+a[1];}fn i32[2] id(i32[2] a){return a;}fn i32 main(){let ref u8[] marker=b\"*\";return take(id([20,22]));}",42);
}
@test fn void list_element_and_later_argument_exits_release_only_complete_captures(){
    value(b"module main;fn i32 take(i32[1] a,i32[2] b){return 0;}fn i32 main(){let Option<i32> o=.none;return take([7],[20,switch(o){case .some(v):{v}case .none:{return 42;}}]);}",42);
    value(b"module main;fn i32 take(i32[1] a,i32[2] b){return b[0]+b[1];}fn Option<i32> work(Option<i32> o){return .some(take([7],[20,o?]));}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32[1] make(){let Option<i32> o=.none;return [switch(o){case .some(v):{v}case .none:{return [42];}}];}fn i32 main(){let a=make();return a[0];}",42);
    value(b"module main;fn i32 take(i32[1] a,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let unused=take([7],switch(o){case .some(v):{v}case .none:{n=n+1;continue;}});}while(true){let unused=take([7],switch(o){case .some(v):{v}case .none:{break;}});}return n;}",42);
    value(b"module main;fn i32[1] make(){let Option<i32> o=.none;var n=0;while(n<42){let prior=[1];return [switch(o){case .some(v):{v}case .none:{n=n+1;continue;}}];}return [n];}fn i32 main(){let a=make();return a[0];}",42);
}
@test fn void temporary_list_borrows_keep_modes_ranges_and_selected_returned_owners(){
    value(b"module main;fn i32 take(ref i32[] a){return a[0]+a[1];}fn i32 main(){return take(ref [20,22]);}",42);
    value(b"module main;fn i32 take(ref mut i32[] a){a[0]=a[0]+2;return a[0]+a[1];}fn i32 main(){return take(ref mut [20,20][..]);}",42);
    value(b"module main;fn i32 take(ref u32[] a){if(a.len==1 && a[0]==4294967295){return 42;}return 0;}fn i32 main(){return take(ref [0,4294967295][1..]);}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let p=same(ref [20,22]);let q=p[1..];return p[0] as i32+q[0] as i32;}",42);
    value(b"module main;fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref a;}fn i32 main(){let p=pick(ref [20,22],ref [0]);return p[0] as i32+p[1] as i32;}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let p=same(ref [b\"*\"[0],0])[..1];return p[0] as i32;}",42);
}
@test fn void borrow_endpoints_and_following_arguments_preserve_nonlocal_exit_cleanup(){
    value(b"module main;fn i32 take(ref i32[] a){return 0;}fn i32 main(){let Option<i32> o=.none;return take(ref [20,22][..switch(o){case .some(v):{1}case .none:{return 42;}}]);}",42);
    value(b"module main;fn i32 take(ref i32[] a,i32 n){return 0;}fn i32 main(){let Option<i32> o=.none;return take(ref [20,22],switch(o){case .some(v):{v}case .none:{return 42;}});}",42);
    value(b"module main;fn i32 take(ref mut i32[] a){return 0;}fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let unused=take(ref mut [20,22][switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}..]);}while(true){let unused=take(ref mut [20,22][..switch(o){case .some(v):{1}case .none:{break;}}]);}return n;}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;let p=same(ref [20,22])[..switch(o){case .some(v):{1}case .none:{return 42;}}];return 0;}",42);
}
@test fn void wrong_arity_type_mode_empty_and_malformed_lists_fail_before_publication(){
    rejected(b"module main;fn i32 take(i32[2] a){return 0;}fn i32 main(){return take([42]);}",3);
    rejected(b"module main;fn i32 take(i32[1] a){return 0;}fn i32 main(){return take([20,22]);}",3);
    rejected(b"module main;fn i32[2] make(){return [42];}fn i32 main(){return 0;}",3);
    rejected(b"module main;fn i32[1] make(){return [true];}fn i32 main(){return 0;}",3);
    rejected(b"module main;fn i32 take(u8[1] a){return 0;}fn i32 main(){let i32 n=42;return take([n]);}",3);
    rejected(b"module main;fn i32 take(ref i32[] a){return 0;}fn i32 main(){return take(ref [true]);}",3);
    rejected(b"module main;fn i32 take(ref mut i32[] a){return 0;}fn i32 main(){return take(ref [42]);}",2);
    rejected(b"module main;fn i32 take(i32[1] a){return 0;}fn i32 main(){return take([]);}",3);
    rejected(b"module main;fn i32 take(i32[2] a){return 0;}fn i32 main(){return take([1,,2]);}",2);
    rejected(b"module main;fn i32[2] make(){return [1,2;2];}fn i32 main(){return 0;}",2);
}
fn void same(ref ir::Program a,ref ir::Program b){
    assert(verifier::verify(a).is_ok && verifier::verify(b).is_ok);
    assert(a.count==b.count && a.registers==b.registers && a.list_used==b.list_used);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<4096){assert(a.list_operands[i]==b.list_operands[i]);i+=1;}
}
fn void exact(ref ir::Program p,usize backing,usize fuel){
    switch(vm::run_with_array_limit(p,fuel,backing)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(vm::run_with_array_limit(p,fuel-1,backing)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(vm::run_with_array_limit(p,fuel+1,backing)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
}
@test fn void literal_contexts_match_named_ir_and_independent_exact_fuel(){
    let ir::Program argument=compiled(b"module main;fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){return take([20,22]);}");
    let ir::Program named=compiled(b"module main;fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){let a=[20,22];return take(a);}");
    same(ref argument,ref named);
    // Backing 17 + scratch 269 + caller 407 + callee 127.
    // CALL = dispatch/arity 2 + owner transaction 128 + 128 + 8 + 7.
    exact(ref argument,16,820);
    let ir::Program returned=compiled(b"module main;fn i32[2] make(){return [20,22];}fn i32 main(){let a=make();return a[0]+a[1];}");
    let ir::Program bound=compiled(b"module main;fn i32[2] make(){let a=[20,22];return a;}fn i32 main(){let a=make();return a[0]+a[1];}");
    same(ref returned,ref bound);
    // Backing 9 + scratch 269 + callee 149 (ARET 65) + caller 128.
    exact(ref returned,8,555);
}
