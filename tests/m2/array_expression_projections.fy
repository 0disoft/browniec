module tests::m2::array_expression_projections;
import compiler as compiler;
import ir as ir;
import vm as vm;
import program_image as programs;
import std::bytes as bytes;
fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void identical(ref u8[] plain,ref u8[] grouped,usize backing){
    let ir::Program a=compiled(plain);let ir::Program b=compiled(grouped);
    assert(a.count==b.count && a.registers==b.registers && a.arrays.count==b.arrays.count && a.list_used==b.list_used);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    switch(vm::run_with_array_limit(ref b,16000000,backing)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
}
@test fn void grouped_names_calls_and_six_scalar_domains_preserve_projection_types(){
    value(b"module main;fn i32[2] make(){return [20,22];}fn i32 main(){let a=[20,22];let n=((a))[0];return n+(make())[1];}");
    value(b"module main;fn i64[1] big(){return [-9223372036854775808];}fn u32[1] word(){return [4294967295];}fn usize[1] size(){return [18446744073709551615];}fn i32 main(){let u8[1] a=[42];let bool[1] b=[true];if((big())[0]==-9223372036854775808 && (word())[0]==4294967295 && (size())[0]==18446744073709551615 && (b)[0]){return (a)[0] as i32;}return 0;}");
    value(b"module main;fn i32[2] make(){return [20,22];}fn i32 take(i32 x){return x;}fn i32 main(){let a=[0,0];let n=(a).len;let m=((make())).len;if(n==2 && m==2){return take((make())[0])+22;}return 0;}");
}
@test fn void whole_values_copy_move_and_replace_through_original_ir(){
    value(b"module main;fn i32[2] make(){return ([20,22]);}fn i32[2] pass(i32[2] a){return ((a));}fn i32 main(){let a=((make()));var i32[2] b=(a);b=([0,22]);return (a)[0]+(pass((b)))[1];}");
    value(b"module main;fn i32[2] make(){return (([20;2]));}fn i32[2] forward(){return ((make()));}fn i32 take(i32[2] a){return a[0]+a[1];}fn i32 main(){var a=([0,0]);a=((forward()));a=([21;2]);return take(((a)));}");
    value(b"module main;fn i32 main(){let a=(([20,22]));let b=((a));var c=([0;2]);c=(b);return (c)[0]+(c)[1];}");
}
@test fn void captures_snapshot_before_later_arguments_and_evaluate_calls_indices_once(){
    value(b"module main;fn i32 change(ref mut i32[] a){a[0]=22;return 0;}fn i32 take(i32[1] a,i32 n){return a[0]+n;}fn i32 main(){var a=[20];let n=take((a),change(ref mut a));return n+(a)[0];}");
    value(b"module main;fn i32[1] make(ref mut i32[] c){c[0]=c[0]+1;return [40];}fn usize pick(ref mut i32[] c){c[0]=c[0]+1;return 0;}fn i32 main(){var c=[0];let n=((make(ref mut c)))[pick(ref mut c)];return n+(c)[0];}");
    value(b"module main;fn i32[1] make(ref mut i32[] a){a[0]=1;return [21];}fn i32 main(){var a=[0];a=((make(ref mut a)));return (a)[0]+21;}");
}
@test fn void completed_call_owners_join_nonlocal_exit_cleanup_and_retained_routing(){
    value(b"module main;fn i32[1] make(){return [0];}fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let v=(make())[switch(o){case .some(v):{0}case .none:{n=n+1;continue;}}];}while(true){let v=((make()))[switch(o){case .some(v):{0}case .none:{break;}}];}return n;}");
    value(b"module main;fn i32[1] make(){return [0];}fn usize pick(i32 n){return 0;}fn Option<i32> work(Option<i32> o){return .some((make())[pick(o?)]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(0))){case .some(v):{return v+42;}case .none:{return 0;}}}");
    value(b"module main;fn i32[1] make(){return [0];}fn i32 main(){let ref u8[] marker=b\"*\";let Option<i32> o=.none;return ((make()))[switch(o){case .some(v):{0}case .none:{return 42;}}];}");
}
@test fn void grouped_utf8_roots_literals_calls_and_endpoint_exits_keep_owner_lifetimes(){
    value(b"module main;fn u8[2] make(){return [195,169];}fn i32 main(){let u8[2] a=[195,169];if(text::valid_utf8(((a))) && text::valid_utf8((make())) && text::valid_utf8(([195,169])) && !text::valid_utf8((a)[1..])){return 42;}return 0;}");
    value(b"module main;fn u8[2] make(){return [65,66];}fn i32 main(){let Option<i32> o=.none;if(text::valid_utf8(((make()))[0..switch(o){case .some(v):{1}case .none:{return 42;}}])){return 0;}return 0;}");
}
@test fn void grouping_keeps_identical_instruction_bytes_and_full_quota_replacement(){
    identical(b"module main;fn i32 main(){let a=[42];return a[0];}",b"module main;fn i32 main(){let a=([42]);return ((a))[0];}",4);
    identical(b"module main;fn i32 main(){var a=[0];a=[42];return a[0];}",b"module main;fn i32 main(){var a=([0]);a=(([42]));return (a)[0];}",4);
    identical(b"module main;fn i32 main(){var a=[0;1];a=[42;1];return a[0];}",b"module main;fn i32 main(){var a=([0;1]);a=(([42;1]));return (a)[0];}",4);
    identical(b"module main;fn i32[1] make(){return [42];}fn i32 main(){return make()[0];}",b"module main;fn i32[1] make(){return ([42]);}fn i32 main(){return ((make()))[0];}",4);
    identical(b"module main;fn i32 take(i32[1] a){return a[0];}fn i32 main(){let a=[42];return take(a);}",b"module main;fn i32 take(i32[1] a){return (a)[0];}fn i32 main(){let a=([42]);return take(((a)));}",8);
}
@test fn void malformed_shapes_and_protected_returned_owners_remain_rejected(){
    rejected(b"module main;fn i32 main(){let a=[42];return (a).missing;}",3);
    rejected(b"module main;fn i32 main(){let a=[42];return (a)[true];}",3);
    rejected(b"module main;fn i32 main(){let a=[42];let i32[2] b=(a);return 0;}",3);
    rejected(b"module main;fn i32 take(u8[1] a){return 0;}fn i32 main(){let a=[42];return take((a));}",3);
    rejected(b"module main;fn i32 main(){let a=[42];return ((a)[0];}",2);
    rejected(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42];let p=id(ref a);a=([0]);return p[0] as i32;}",5);
}
fn void append(ref mut bytes::Buffer b,ref u8[] source){assert(bytes::append(b,source).is_ok);}
fn void grouped_depth(usize outer,usize inner,bool pass){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 main(){let a=[42];return ");
    var usize i=0;while(i<outer){append(ref mut source,b"(");i+=1;}append(ref mut source,b"a");
    i=0;while(i<outer){append(ref mut source,b")");i+=1;}append(ref mut source,b"[");
    i=0;while(i<inner){append(ref mut source,b"(");i+=1;}append(ref mut source,b"0");
    i=0;while(i<inner){append(ref mut source,b")");i+=1;}append(ref mut source,b"];}");
    if(pass){value(bytes::view(ref source));}else{rejected(bytes::view(ref source),4);}
}
fn void calls(usize count,bool pass,bool image,bool first){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 id(");
    append(ref mut source,if(first){b"i32[1] a,i32 n"}else{b"i32 n,i32[1] a"});
    append(ref mut source,b"){return n;}fn i32 main(){let a=[0];");
    if(image){append(ref mut source,b"let ref u8[] marker=b\"*\";");}append(ref mut source,b"return ");
    var usize i=0;while(i<count){append(ref mut source,if(first){b"id((a),"}else{b"id("});i+=1;}
    append(ref mut source,b"42");i=0;while(i<count){append(ref mut source,if(first){b")"}else{b",(a))"});i+=1;}
    append(ref mut source,b";}");if(pass){value(bytes::view(ref source));}else{rejected(bytes::view(ref source),4);}
}
@test fn void combined_group_index_and_32_deep_captured_call_bounds_stay_original(){
    grouped_depth(31,0,true);grouped_depth(32,0,false);grouped_depth(33,0,false);
    grouped_depth(15,15,true);grouped_depth(16,16,false);
    calls(32,true,false,true);calls(33,false,false,true);calls(32,true,true,true);calls(33,false,true,true);
    calls(32,true,false,false);calls(33,false,false,false);calls(32,true,true,false);calls(33,false,true,false);
}
