module tests::m2::array_list_assignment;
import compiler as compiler;
import program_image as programs;
import static_image as images;
import static_call_ir as calls;
import ir as ir;
import verifier as verifier;
import vm as vm;
import errors as errors;
import std::bytes as bytes;

fn void result(Result<i64,errors::Error> r,i64 expected){switch(r){
    case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}
};}
fn void value(ref u8[] source,i64 expected){switch(compiler::compile_program(source,65536)){
    case .ok(p):{var usize i=0;while(i<2){result(programs::run_public(ref p,16000000),expected);i+=1;}}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
@test fn void assignment_reuses_exact_shape_across_six_scalar_domains_and_trailing_commas(){
    value(b"module main;fn i32 main(){var a=[0;2];a=[20,22,];return a[0]+a[1];}",42);
    value(b"module main;fn i32 main(){var bool[2] a=[false;2];a=[true,false];if(a[0] && !a[1]){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){var i64[2] a=[0;2];a=[-9223372036854775808,9223372036854775807];if(a[0]==-9223372036854775808 && a[1]==9223372036854775807){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){var u8[2] a=[0;2];a=[255,42];return a[1] as i32;}",42);
    value(b"module main;fn i32 main(){var u32[2] a=[0;2];a=[4294967295,42];if(a[0]==4294967295 && a[1]==42){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){var usize[2] a=[0;2];a=[18446744073709551615,42];if(a[0]==18446744073709551615 && a[1]==42){return 42;}return 0;}",42);
}
@test fn void cells_evaluate_once_in_order_while_destination_reads_and_rhs_writes_stay_visible(){
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return c[0];}fn i32 main(){var c=[0];var a=[0;2];a=[bump(ref mut c),bump(ref mut c)];return a[0]*10+a[1]+c[0]*15;}",42);
    value(b"module main;fn i32 main(){var a=[20,22];a=[a[1],a[0]];return a[0]+a[1];}",42);
    value(b"module main;fn i32 change(ref mut i32[] a){a[0]=22;return 20;}fn i32 main(){var a=[7,8];a=[change(ref mut a),a[0]];return a[0]+a[1];}",42);
    value(b"module main;fn i32 main(){var n=20;var a=[0;2];let Option<i32> o=.none;a=[n,switch(o){case .some(v):{v}case .none:{n=22;n}}];return a[0]+a[1];}",42);
    value(b"module main;fn i32 add(i32 a,i32 b){return a+b;}fn i32 main(){var a=[0;2];a=[add(20,22)/* ;, */;2];a=[a[0],b\";],\"[0] as i32];return a[0];}",42);
}
@test fn void replacements_keep_independent_copies_calls_results_and_retained_borrows(){
    value(b"module main;fn i32[2] make(i32 n){var a=[0;2];a=[n,22];return a;}fn i32 take(i32[2] a){var b=a;b=[0,0];return a[0]+a[1];}fn i32 main(){var a=make(20);let copy=a;a=[0,0];return take(copy);}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[2] a=[0;2];a=[20,22];{let p=same(ref a);if(p[0]!=20){return 0;}}a=[22,20];let p=same(ref a);return p[0] as i32+p[1] as i32;}",42);
    value(b"module main;fn i32[2] make(){var a=[0;2];a=[20,22];return a;}fn i32 main(){let ref u8[] marker=b\"*\";var n=0;var sum=0;while(n<3){let a=make();sum=sum+a[0]+a[1];n=n+1;}return sum-84;}",42);
}
@test fn void nonlocal_exits_preserve_unreplaced_values_rhs_effects_and_outer_owners(){
    value(b"module main;fn i32 main(){var a=[7,8];let Option<i32> o=.none;a=[20,switch(o){case .some(v):{v}case .none:{return a[0]+a[1]+27;}}];return 0;}",42);
    value(b"module main;fn i32 change(ref mut i32[] a){a[0]=20;return 0;}fn i32 main(){var a=[7,22];let Option<i32> o=.none;a=[change(ref mut a),switch(o){case .some(v):{v}case .none:{return a[0]+a[1];}}];return 0;}",42);
    value(b"module main;fn Option<i32> work(Option<i32> o){var a=[7,8];a=[20,o?];return .some(a[0]+a[1]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32 main(){var a=[20,22];let Option<i32> o=.none;var n=0;while(n<42){let prior=[1];a=[0,switch(o){case .some(v):{v}case .none:{n=n+1;continue;}}];}while(true){a=[0,switch(o){case .some(v):{v}case .none:{break;}}];}return a[0]+a[1];}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var a=[20,22];let Option<i32> o=.none;a=[0,same(ref [42,0])[switch(o){case .some(v):{0}case .none:{return a[0]+a[1];}}] as i32];return 0;}",42);
}
fn void append(ref mut bytes::Buffer b,ref u8[] text){assert(bytes::append(b,text).is_ok);}
@test fn void full_site_and_backing_capacity_and_high_pool_offsets_need_no_new_owner(){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 main(){var a=[0;2];");var usize i=0;
    let ref u8[] letters=b"bcdefghijklmnop";
    while(i<15){append(ref mut source,b"let u8[1] ");append(ref mut source,letters[i..i+1]);append(ref mut source,b"=[0;1];");i+=1;}
    append(ref mut source,b"a=[20,22];return a[0]+a[1];}");
    let ir::Program p=compiled(bytes::view(ref source));assert(p.arrays.count==16 && p.list_used==2);
    result(vm::run_with_array_limit(ref p,16000000,23),42);
    switch(vm::run_with_array_limit(ref p,16000000,22)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==13);}};
    var bytes::Buffer high=bytes::empty();append(ref mut high,b"module main;fn i32 main(){let x=42;var a=[0;257];a=[");i=0;
    while(i<257){if(i!=0){append(ref mut high,b",");}append(ref mut high,b"x");i+=1;}
    append(ref mut high,b"];var b=[0;1];b=[x];return b[0];}");value(bytes::view(ref high),42);
    let ir::Program q=compiled(bytes::view(ref high));assert(q.arrays.count==2 && q.list_used==258);
    var usize seen=0;i=0;while(i<q.count){if(q.code[i*8]==81){if(seen==1){assert(q.code[i*8+2]==1 && q.code[i*8+3]==1);}seen+=1;}i+=1;}assert(seen==2);
}
@test fn void arity_type_immutability_borrow_and_syntax_errors_reject_honestly(){
    rejected(b"module main;fn i32 main(){var a=[0;2];a=[42];return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[0;1];a=[20,22];return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[0;2];a=[1,true];return 0;}",3);
    rejected(b"module main;fn u8 n(){return 42;}fn i32 main(){var a=[0;1];a=[n()];return 0;}",3);
    rejected(b"module main;fn i32 main(){var u8[1] a=[0;1];a=[256];return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[0;2];a=[20,22];return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[0;2];let p=ref a;a=[20,22];return p[0];}",3);
    rejected(b"module main;fn i32 main(){var a=[0;2];let p=ref mut a;a=[20,22];return p[0];}",3);
    rejected(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){var u8[2] a=[0;2];let p=same(ref a);a=[20,22];return p[0] as i32;}",5);
    rejected(b"module main;fn i32 main(){var a=[0;2];a=[];return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[0;2];a=[1,,2];return 0;}",2);
    rejected(b"module main;fn i32 main(){var a=[0;2];a=[1,2;2];return 0;}",2);
    rejected(b"module main;fn i32 main(){var a=[0;2];a=[20,22] return 0;}",2);
    rejected(b"module main;fn i32 main(){var a=[0;2];for(a=[20,22];false;){}return 0;}",3);
}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};}
@test fn void one_replacement_instruction_has_independent_ordinary_and_retained_exact_fuel(){
    let ir::Program p=compiled(b"module main;fn i32 main(){var a=[0;2];a=[20,22];return a[0]+a[1];}");
    assert(verifier::verify(ref p).is_ok && p.arrays.count==1 && p.list_used==2 && p.count==12 && p.code[4*8]==81);
    // Backing 9 + setup 269 + three constants 3 + INIT 72 + REPLACE 75
    // + two indices/READs 76 + ADD/DROP/RETURN 51 = 555.
    result(vm::run_with_array_limit(ref p,555,8),42);result(vm::run_with_array_limit(ref p,556,8),42);
    switch(vm::run_with_array_limit(ref p,554,8)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    let calls::Program code=calls::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let programs::ReferenceReturnProgram retained=switch(programs::retain_reference_returns(ref code,image(),images::metadata_charge())){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    // Public backing adds 65528; entry/leave add 344064; five aggregate dispatches add 5.
    result(programs::run_public_references(ref retained,410152),42);result(programs::run_public_references(ref retained,410153),42);
    switch(programs::run_public_references(ref retained,410151)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
}
